import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking_model.dart';
import '../models/booking_request_model.dart';
import '../models/chat_model.dart';
import '../models/earning_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  FirestoreService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String bookingRequestId(String bookingId, String nurseId) {
    return '${bookingId}_$nurseId';
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _privateUsers =>
      _firestore.collection('user_private');

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _bookingRequests =>
      _firestore.collection('booking_requests');

  CollectionReference<Map<String, dynamic>> get _earnings =>
      _firestore.collection('earnings');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('payments');

  CollectionReference<Map<String, dynamic>> get _withdrawals =>
      _firestore.collection('withdrawals');

  CollectionReference<Map<String, dynamic>> get _chatThreads =>
      _firestore.collection('chatThreads');

  // ======== USER OPERATIONS ========

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists) {
      return UserModel.fromSnapshot(doc);
    }
    return null;
  }

  Stream<UserModel?> streamUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return UserModel.fromSnapshot(doc);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserField(String uid, String field, dynamic value) async {
    await _users.doc(uid).update({
      field: value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertPrivateUser(
    String uid,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    await _privateUsers.doc(uid).set(
      {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: merge),
    );
  }

  Future<void> addPrivateFcmToken(String uid, String token) async {
    await upsertPrivateUser(uid, {
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  // ======== NURSE OPERATIONS ========

  Stream<List<UserModel>> streamOnlineNurses() {
    return _users
        .where('role', isEqualTo: 'nurse')
        .where('isOnline', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .where('verified', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(UserModel.fromSnapshot).toList();
    });
  }

  Future<void> updateNurseLocation(String uid, GeoPoint location) async {
    await _users.doc(uid).update({
      'currentLocation': location,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setNurseOnlineStatus(String uid, bool isOnline) async {
    await _users.doc(uid).update({
      'isOnline': isOnline,
      'isAvailable': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ======== BOOKING OPERATIONS ========

  Future<void> createBooking(BookingModel booking) async {
    await _bookings.doc(booking.id).set({
      ...booking.toMap(),
      'dispatchState': 'searching',
      'dispatchIndex': 0,
      'dispatchCandidateIds': const [],
      'rejectedNurseIds': const [],
      'offeredNurseId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<BookingModel?> streamBooking(String bookingId) {
    return _bookings.doc(bookingId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return BookingModel.fromSnapshot(doc);
    });
  }

  Stream<List<BookingModel>> streamPendingBookings(String nurseId) {
    return _bookingRequests
        .where('nurseId', isEqualTo: nurseId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(BookingRequestModel.fromSnapshot)
          .map((request) => request.toBookingPreview())
          .toList();
    });
  }

  Stream<List<BookingModel>> streamPatientBookings(String patientId) {
    return _bookings
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(BookingModel.fromSnapshot).toList();
    });
  }

  Stream<List<BookingModel>> streamNurseBookings(String nurseId) {
    return _bookings
        .where('nurseId', isEqualTo: nurseId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(BookingModel.fromSnapshot).toList();
    });
  }

  Stream<BookingModel?> streamActiveNurseBooking(String nurseId) {
    return _bookings
        .where('nurseId', isEqualTo: nurseId)
        .where('status', whereIn: ['accepted', 'in_progress'])
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      final docs = snapshot.docs.toList()
        ..sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        return (bTime?.millisecondsSinceEpoch ?? 0)
            .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
      });

      return BookingModel.fromSnapshot(docs.first);
    });
  }

  Future<void> acceptBooking(
    String bookingId,
    String nurseId,
    String nurseName,
  ) async {
    final bookingRef = _bookings.doc(bookingId);
    final requestRef = _bookingRequests.doc(bookingRequestId(bookingId, nurseId));
    final nurseRef = _users.doc(nurseId);

    await _firestore.runTransaction((transaction) async {
      final bookingDoc = await transaction.get(bookingRef);
      final requestDoc = await transaction.get(requestRef);
      final nurseDoc = await transaction.get(nurseRef);

      if (!bookingDoc.exists) {
        throw Exception('Booking request no longer exists.');
      }
      if (!requestDoc.exists) {
        throw Exception('This request is no longer available.');
      }
      if (!nurseDoc.exists) {
        throw Exception('Nurse profile not found.');
      }

      final bookingData = bookingDoc.data()!;
      final requestData = requestDoc.data()!;
      final nurseData = nurseDoc.data()!;

      final bookingStatus = bookingData['status'] as String? ?? 'pending';
      final requestStatus = requestData['status'] as String? ?? 'pending';
      final isAvailable = nurseData['isAvailable'] as bool? ?? false;
      final isOnline = nurseData['isOnline'] as bool? ?? false;

      if (bookingStatus != 'pending' || bookingData['nurseId'] != null) {
        throw Exception('Another nurse has already accepted this booking.');
      }
      if (requestStatus != 'pending') {
        throw Exception('This request has already been handled.');
      }
      if (!isOnline || !isAvailable) {
        throw Exception('Go online and stay available before accepting requests.');
      }

      transaction.update(bookingRef, {
        'nurseId': nurseId,
        'nurseName': nurseName,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'dispatchState': 'accepted',
        'offeredNurseId': nurseId,
        'chatThreadId': bookingId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(requestRef, {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(nurseRef, {
        'isAvailable': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectBooking(String bookingId, String nurseId) async {
    await _bookingRequests.doc(bookingRequestId(bookingId, nurseId)).update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> startService(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status': 'in_progress',
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'paymentStatus': 'settlement_pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelBooking(String bookingId, String reason) async {
    await _bookings.doc(bookingId).update({
      'status': 'cancelled',
      'cancellationReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rateBooking(
    String bookingId,
    String nurseId,
    double rating,
    String feedback,
  ) async {
    await _bookings.doc(bookingId).update({
      'rating': rating,
      'feedback': feedback,
      'ratedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ======== EARNINGS OPERATIONS ========

  Stream<EarningModel?> streamEarnings(String nurseId) {
    return _earnings.doc(nurseId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return EarningModel.fromSnapshot(doc);
    });
  }

  Stream<List<TransactionModel>> streamTransactions(String nurseId) {
    return _earnings
        .doc(nurseId)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data()))
          .toList();
    });
  }

  Future<double> getTodayEarnings(String nurseId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final snapshot = await _earnings
        .doc(nurseId)
        .collection('transactions')
        .where('type', isEqualTo: 'earning')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .get();

    double total = 0;
    for (final doc in snapshot.docs) {
      total += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  Future<double> getWeeklyEarnings(String nurseId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    final snapshot = await _earnings
        .doc(nurseId)
        .collection('transactions')
        .where('type', isEqualTo: 'earning')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
        )
        .get();

    double total = 0;
    for (final doc in snapshot.docs) {
      total += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  // ======== WITHDRAWAL OPERATIONS ========

  Future<void> requestWithdrawal(WithdrawalModel withdrawal) async {
    await _withdrawals.doc(withdrawal.id).set({
      ...withdrawal.toMap(),
      'status': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<WithdrawalModel>> streamWithdrawals(String nurseId) {
    return _withdrawals
        .where('nurseId', isEqualTo: nurseId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WithdrawalModel.fromMap(doc.data()))
          .toList();
    });
  }

  // ======== CHAT OPERATIONS ========

  Stream<ChatThreadModel?> streamChatThread(String threadId) {
    return _chatThreads.doc(threadId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return ChatThreadModel.fromSnapshot(doc);
    });
  }

  Stream<List<ChatMessageModel>> streamChatMessages(String threadId) {
    return _chatThreads
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(ChatMessageModel.fromSnapshot).toList();
    });
  }

  Future<void> sendChatMessage({
    required String threadId,
    required String bookingId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final messageRef = _chatThreads.doc(threadId).collection('messages').doc();
    final message = ChatMessageModel(
      id: messageRef.id,
      threadId: threadId,
      bookingId: bookingId,
      senderId: senderId,
      senderName: senderName,
      text: trimmed,
      readBy: [senderId],
    );

    await messageRef.set(message.toMap());
  }

  // ======== ADMIN OPERATIONS ========

  Future<Map<String, dynamic>> getAdminStats() async {
    final patientsFuture = _users.where('role', isEqualTo: 'patient').get();
    final nursesFuture = _users.where('role', isEqualTo: 'nurse').get();
    final bookingsFuture = _bookings.get();
    final completedFuture = _bookings.where('status', isEqualTo: 'completed').get();
    final paymentsFuture = _payments.get();

    final results = await Future.wait([
      patientsFuture,
      nursesFuture,
      bookingsFuture,
      completedFuture,
      paymentsFuture,
    ]);

    final patients = results[0];
    final nurses = results[1];
    final bookings = results[2];
    final completed = results[3];
    final payments = results[4];

    double totalRevenue = 0;
    double totalCommission = 0;

    for (final doc in payments.docs) {
      final data = doc.data();
      totalRevenue += (data['amount'] as num?)?.toDouble() ?? 0;
      totalCommission +=
          (data['platformCommission'] as num?)?.toDouble() ??
              (data['commission'] as num?)?.toDouble() ??
              0;
    }

    return {
      'totalPatients': patients.docs.length,
      'totalNurses': nurses.docs.length,
      'totalBookings': bookings.docs.length,
      'completedBookings': completed.docs.length,
      'totalRevenue': totalRevenue,
      'totalCommission': totalCommission,
    };
  }
}
