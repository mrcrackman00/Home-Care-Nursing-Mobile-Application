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

  String _friendlyErrorMessage(Object error) {
    if (error is FirebaseException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }

      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to complete this action right now.';
        case 'not-found':
          return 'The requested booking data is no longer available.';
        case 'unavailable':
          return 'The network is unstable right now. Please try again.';
      }
    }

    final raw = error.toString().trim();
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length).trim();
    }
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    if (raw.contains('permission-denied')) {
      return 'You do not have permission to complete this action right now.';
    }
    if (raw.contains('Dart exception thrown from converted Future')) {
      return 'This request could not be processed on web right now. Refresh the requests list and try again.';
    }
    return raw;
  }

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

  Map<String, dynamic> _buildBookingRequestData(
    BookingModel booking,
    String nurseId,
  ) {
    return {
      'id': bookingRequestId(booking.id, nurseId),
      'bookingId': booking.id,
      'nurseId': nurseId,
      'patientId': booking.patientId,
      'patientName': booking.patientName,
      'patientPhone': booking.patientPhone,
      'patientLocation': booking.patientLocation,
      'patientAddress': booking.patientAddress,
      'serviceType': booking.serviceType,
      'serviceName': booking.serviceName,
      'duration': booking.duration,
      'isInstant': booking.isInstant,
      'scheduledTime': booking.scheduledTime != null
          ? Timestamp.fromDate(booking.scheduledTime!)
          : null,
      'totalAmount': booking.totalAmount,
      'nurseEarning': booking.nurseEarning,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
    };
  }

  // ======== NURSE OPERATIONS ========

  Stream<List<UserModel>> streamOnlineNurses() {
    return _users
        .where('role', isEqualTo: 'nurse')
        .where('isOnline', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final nurses = snapshot.docs.map(UserModel.fromSnapshot).toList();
      nurses.sort((a, b) {
        final aVerified = a.verified == true ? 1 : 0;
        final bVerified = b.verified == true ? 1 : 0;
        return bVerified.compareTo(aVerified);
      });
      return nurses;
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

  Future<void> createBooking(
    BookingModel booking, {
    UserModel? preferredNurse,
  }) async {
    final bookingRef = _bookings.doc(booking.id);
    final batch = _firestore.batch();

    batch.set(bookingRef, {
      ...booking.toMap(),
      'preferredNurseId': preferredNurse?.uid,
      'dispatchState': preferredNurse != null
          ? 'requested_to_nurse'
          : 'awaiting_admin_assignment',
      'dispatchIndex': 0,
      'dispatchCandidateIds': preferredNurse != null
          ? [preferredNurse.uid]
          : const [],
      'rejectedNurseIds': const [],
      'offeredNurseId': preferredNurse?.uid,
      'paymentStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (preferredNurse != null) {
      final requestRef = _bookingRequests.doc(
        bookingRequestId(booking.id, preferredNurse.uid),
      );
      batch.set(requestRef, _buildBookingRequestData(booking, preferredNurse.uid));
    }

    await batch.commit();
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
    final chatRef = _chatThreads.doc(bookingId);

    try {
      final result =
          await _firestore.runTransaction<Map<String, String?>>((transaction) async {
        final bookingDoc = await transaction.get(bookingRef);
        final requestDoc = await transaction.get(requestRef);
        final nurseDoc = await transaction.get(nurseRef);

        if (!bookingDoc.exists) {
          return {'error': 'Booking request no longer exists.'};
        }
        if (!requestDoc.exists) {
          return {'error': 'This request is no longer available.'};
        }
        if (!nurseDoc.exists) {
          return {'error': 'Nurse profile not found.'};
        }

        final bookingData = bookingDoc.data()!;
        final requestData = requestDoc.data()!;
        final nurseData = nurseDoc.data()!;

        final bookingStatus = bookingData['status'] as String? ?? 'pending';
        final requestStatus = requestData['status'] as String? ?? 'pending';
        final isAvailable = nurseData['isAvailable'] as bool? ?? false;
        final isOnline = nurseData['isOnline'] as bool? ?? false;

        if (bookingStatus != 'pending' || bookingData['nurseId'] != null) {
          return {'error': 'Another nurse has already accepted this booking.'};
        }
        if (requestStatus != 'pending') {
          return {'error': 'This request has already been handled.'};
        }
        if (!isOnline || !isAvailable) {
          return {'error': 'Go online and stay available before accepting requests.'};
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
        transaction.set(
          chatRef,
          {
            'id': bookingId,
            'bookingId': bookingId,
            'participantIds': [bookingData['patientId'], nurseId]
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .toList(),
            'patientId': bookingData['patientId'],
            'nurseId': nurseId,
            'lastMessage': '',
            'lastMessageSenderId': '',
            'lastMessageAt': null,
            'unreadCounts': {
              if (bookingData['patientId'] is String &&
                  (bookingData['patientId'] as String).isNotEmpty)
                bookingData['patientId'] as String: 0,
              nurseId: 0,
            },
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return {'error': null};
      });

      final errorMessage = result['error'];
      if (errorMessage != null && errorMessage.isNotEmpty) {
        throw StateError(errorMessage);
      }
    } catch (error) {
      throw StateError(_friendlyErrorMessage(error));
    }
  }

  Future<void> rejectBooking(String bookingId, String nurseId) async {
    final bookingRef = _bookings.doc(bookingId);
    final requestRef = _bookingRequests.doc(bookingRequestId(bookingId, nurseId));

    try {
      final result =
          await _firestore.runTransaction<Map<String, String?>>((transaction) async {
        final bookingDoc = await transaction.get(bookingRef);
        final requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) {
          return {'error': 'This request is no longer available.'};
        }

        final requestData = requestDoc.data()!;
        if ((requestData['status'] as String? ?? 'pending') != 'pending') {
          return {'error': 'This request has already been handled.'};
        }

        transaction.update(requestRef, {
          'status': 'rejected',
          'respondedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (bookingDoc.exists) {
          final bookingData = bookingDoc.data()!;
          if ((bookingData['status'] as String? ?? 'pending') == 'pending' &&
              bookingData['nurseId'] == null) {
            transaction.update(bookingRef, {
              'dispatchState': 'needs_reassignment',
              'offeredNurseId': null,
              'rejectedNurseIds': FieldValue.arrayUnion([nurseId]),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        return {'error': null};
      });

      final errorMessage = result['error'];
      if (errorMessage != null && errorMessage.isNotEmpty) {
        throw StateError(errorMessage);
      }
    } catch (error) {
      throw StateError(_friendlyErrorMessage(error));
    }
  }

  Future<void> startService(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status': 'in_progress',
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeBooking(String bookingId) async {
    final bookingRef = _bookings.doc(bookingId);

    try {
      final result =
          await _firestore.runTransaction<Map<String, String?>>((transaction) async {
        final bookingDoc = await transaction.get(bookingRef);
        if (!bookingDoc.exists) {
          return {'error': 'This booking is no longer available.'};
        }

        final bookingData = bookingDoc.data()!;
        final status = bookingData['status'] as String? ?? 'pending';
        final paymentStatus = bookingData['paymentStatus'] as String? ?? 'pending';
        final nurseId = bookingData['nurseId'] as String?;

        if (status != 'in_progress') {
          return {'error': 'Only an active service can be completed right now.'};
        }
        if (nurseId == null || nurseId.isEmpty) {
          return {'error': 'A nurse must be assigned before completing the service.'};
        }
        if (paymentStatus == 'manual_settled') {
          return {'error': 'This booking has already been settled.'};
        }

        final totalAmount =
            (bookingData['totalAmount'] as num?)?.toDouble() ?? 0;
        final platformCommission =
            (bookingData['platformCommission'] as num?)?.toDouble() ?? 0;
        final nurseEarning =
            (bookingData['nurseEarning'] as num?)?.toDouble() ??
            (totalAmount - platformCommission);

        final earningsRef = _earnings.doc(nurseId);
        final earningsDoc = await transaction.get(earningsRef);
        final paymentRef = _payments.doc(bookingId);
        final earningTransactionRef = earningsRef
            .collection('transactions')
            .doc(bookingId);

        final currentTotalEarnings =
            (earningsDoc.data()?['totalEarnings'] as num?)?.toDouble() ?? 0;
        final currentWithdrawableBalance =
            (earningsDoc.data()?['withdrawableBalance'] as num?)?.toDouble() ??
            0;
        final currentTotalWithdrawn =
            (earningsDoc.data()?['totalWithdrawn'] as num?)?.toDouble() ?? 0;
        final currentPendingWithdrawalBalance =
            (earningsDoc.data()?['pendingWithdrawalBalance'] as num?)
                ?.toDouble() ??
            0;
        final currentTotalJobs =
            (earningsDoc.data()?['totalJobs'] as num?)?.toInt() ?? 0;

        transaction.update(bookingRef, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'paymentStatus': 'manual_settled',
          'settledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (earningsDoc.exists) {
          transaction.update(earningsRef, {
            'nurseId': nurseId,
            'totalEarnings': currentTotalEarnings + nurseEarning,
            'withdrawableBalance':
                currentWithdrawableBalance + nurseEarning,
            'totalWithdrawn': currentTotalWithdrawn,
            'pendingWithdrawalBalance': currentPendingWithdrawalBalance,
            'totalJobs': currentTotalJobs + 1,
            'lastSettledBookingId': bookingId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(earningsRef, {
            'nurseId': nurseId,
            'totalEarnings': nurseEarning,
            'withdrawableBalance': nurseEarning,
            'totalWithdrawn': 0.0,
            'pendingWithdrawalBalance': 0.0,
            'totalJobs': 1,
            'lastSettledBookingId': bookingId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.set(
          paymentRef,
          {
            'id': bookingId,
            'bookingId': bookingId,
            'patientId': bookingData['patientId'],
            'nurseId': nurseId,
            'amount': totalAmount,
            'platformCommission': platformCommission,
            'nurseEarning': nurseEarning,
            'method': 'manual_patient_completion',
            'status': 'completed',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.set(
          earningTransactionRef,
          {
            'id': bookingId,
            'type': 'earning',
            'amount': nurseEarning,
            'bookingId': bookingId,
            'status': 'completed',
            'timestamp': FieldValue.serverTimestamp(),
            'description':
                'Service completed by patient confirmation',
          },
          SetOptions(merge: true),
        );

        return {'error': null};
      });

      final errorMessage = result['error'];
      if (errorMessage != null && errorMessage.isNotEmpty) {
        throw StateError(errorMessage);
      }
    } catch (error) {
      throw StateError(_friendlyErrorMessage(error));
    }
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
    final threadRef = _chatThreads.doc(threadId);
    final message = ChatMessageModel(
      id: messageRef.id,
      threadId: threadId,
      bookingId: bookingId,
      senderId: senderId,
      senderName: senderName,
      text: trimmed,
      readBy: [senderId],
    );

    await _firestore.runTransaction((transaction) async {
      final threadDoc = await transaction.get(threadRef);
      if (!threadDoc.exists) {
        throw Exception('Chat thread is not available yet.');
      }

      final threadData = threadDoc.data()!;
      final participantIds =
          List<String>.from(threadData['participantIds'] ?? const []);
      final unreadCounts = Map<String, dynamic>.from(
        threadData['unreadCounts'] ?? const {},
      );

      for (final participantId in participantIds) {
        if (participantId == senderId) {
          unreadCounts[participantId] = 0;
        } else {
          unreadCounts[participantId] =
              (unreadCounts[participantId] as num? ?? 0).toInt() + 1;
        }
      }

      transaction.set(messageRef, message.toMap());
      transaction.update(threadRef, {
        'lastMessage': trimmed,
        'lastMessageSenderId': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts': unreadCounts.map(
          (key, value) => MapEntry(key, (value as num).toInt()),
        ),
      });
    });
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
