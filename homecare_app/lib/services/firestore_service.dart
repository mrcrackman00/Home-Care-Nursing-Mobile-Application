import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/booking_model.dart';
import '../models/earning_model.dart';
import '../config/constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ======== USER OPERATIONS ========

  Future<UserModel?> getUser(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) return UserModel.fromSnapshot(doc);
    return null;
  }

  Stream<UserModel?> streamUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) return UserModel.fromSnapshot(doc);
      return null;
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // ======== NURSE OPERATIONS ========

  // Get nearby online nurses (simplified - within a radius)
  Stream<List<UserModel>> streamOnlineNurses() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'nurse')
        .where('isOnline', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .where('verified', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromSnapshot(doc))
            .toList());
  }

  Future<void> updateNurseLocation(String uid, GeoPoint location) async {
    await _firestore.collection('users').doc(uid).update({
      'currentLocation': location,
    });
  }

  Future<void> setNurseOnlineStatus(String uid, bool isOnline) async {
    await _firestore.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'isAvailable': isOnline,
    });
  }

  // ======== BOOKING OPERATIONS ========

  Future<void> createBooking(BookingModel booking) async {
    await _firestore.collection('bookings').doc(booking.id).set(booking.toMap());
  }

  Stream<BookingModel?> streamBooking(String bookingId) {
    return _firestore.collection('bookings').doc(bookingId).snapshots().map((doc) {
      if (doc.exists) return BookingModel.fromSnapshot(doc);
      return null;
    });
  }

  // Get pending bookings for nurses to accept
  Stream<List<BookingModel>> streamPendingBookings() {
    return _firestore
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .where('nurseId', isNull: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromSnapshot(doc))
            .toList());
  }

  // Get bookings for a patient
  Stream<List<BookingModel>> streamPatientBookings(String patientId) {
    return _firestore
        .collection('bookings')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromSnapshot(doc))
            .toList());
  }

  // Get bookings for a nurse
  Stream<List<BookingModel>> streamNurseBookings(String nurseId) {
    return _firestore
        .collection('bookings')
        .where('nurseId', isEqualTo: nurseId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromSnapshot(doc))
            .toList());
  }

  // Get active booking for a nurse
  Stream<BookingModel?> streamActiveNurseBooking(String nurseId) {
    return _firestore
        .collection('bookings')
        .where('nurseId', isEqualTo: nurseId)
        .where('status', whereIn: ['accepted', 'in_progress'])
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return BookingModel.fromSnapshot(snapshot.docs.first);
          }
          return null;
        });
  }

  // Nurse accepts booking
  Future<void> acceptBooking(String bookingId, String nurseId, String nurseName) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'nurseId': nurseId,
      'nurseName': nurseName,
      'status': 'accepted',
    });
    
    // Set nurse as unavailable
    await _firestore.collection('users').doc(nurseId).update({
      'isAvailable': false,
    });
  }

  // Start service
  Future<void> startService(String bookingId) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': 'in_progress',
    });
  }

  // Complete booking
  Future<void> completeBooking(String bookingId, String nurseId) async {
    final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
    final booking = BookingModel.fromSnapshot(bookingDoc);

    // Update booking
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': 'completed',
      'completedAt': Timestamp.now(),
    });

    // Calculate earnings
    double commission = AppConstants.calculateCommission(booking.totalAmount);
    double nurseEarning = AppConstants.calculateNurseEarning(booking.totalAmount);
    
    // Check if private hire (no commission)
    if (booking.serviceType == 'private_hire') {
      commission = 0;
      nurseEarning = booking.totalAmount;
    }

    // Update nurse earnings
    await _firestore.collection('earnings').doc(nurseId).update({
      'totalEarnings': FieldValue.increment(nurseEarning),
      'withdrawableBalance': FieldValue.increment(nurseEarning),
      'totalJobs': FieldValue.increment(1),
    });

    // Add transaction record
    final txnId = _firestore.collection('earnings').doc(nurseId)
        .collection('transactions').doc().id;
    await _firestore.collection('earnings').doc(nurseId)
        .collection('transactions').doc(txnId).set({
      'id': txnId,
      'type': 'earning',
      'amount': nurseEarning,
      'bookingId': bookingId,
      'status': 'completed',
      'timestamp': Timestamp.now(),
      'description': 'Earning from ${booking.serviceName}',
    });

    // Store payment record
    final paymentId = _firestore.collection('payments').doc().id;
    await _firestore.collection('payments').doc(paymentId).set({
      'id': paymentId,
      'bookingId': bookingId,
      'patientId': booking.patientId,
      'nurseId': nurseId,
      'amount': booking.totalAmount,
      'commission': commission,
      'nurseEarning': nurseEarning,
      'method': 'razorpay',
      'status': 'completed',
      'timestamp': Timestamp.now(),
    });

    // Set nurse as available again
    await _firestore.collection('users').doc(nurseId).update({
      'isAvailable': true,
    });
  }

  // Cancel booking
  Future<void> cancelBooking(String bookingId, String reason) async {
    final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
    final booking = BookingModel.fromSnapshot(bookingDoc);
    
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': 'cancelled',
      'cancellationReason': reason,
    });

    // If nurse was assigned, make them available again
    if (booking.nurseId != null) {
      await _firestore.collection('users').doc(booking.nurseId!).update({
        'isAvailable': true,
      });
    }
  }

  // Rate booking
  Future<void> rateBooking(String bookingId, String nurseId, double rating, String feedback) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'rating': rating,
      'feedback': feedback,
    });

    // Update nurse rating
    final nurseDoc = await _firestore.collection('users').doc(nurseId).get();
    final nurse = UserModel.fromSnapshot(nurseDoc);
    final currentRating = nurse.rating ?? 0.0;
    final totalRatings = nurse.totalRatings ?? 0;
    final newTotalRatings = totalRatings + 1;
    final newRating = ((currentRating * totalRatings) + rating) / newTotalRatings;

    await _firestore.collection('users').doc(nurseId).update({
      'rating': newRating,
      'totalRatings': newTotalRatings,
    });
  }

  // ======== EARNINGS OPERATIONS ========

  Stream<EarningModel?> streamEarnings(String nurseId) {
    return _firestore.collection('earnings').doc(nurseId).snapshots().map((doc) {
      if (doc.exists) return EarningModel.fromSnapshot(doc);
      return null;
    });
  }

  Stream<List<TransactionModel>> streamTransactions(String nurseId) {
    return _firestore
        .collection('earnings')
        .doc(nurseId)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data()))
            .toList());
  }

  // Today's earnings
  Future<double> getTodayEarnings(String nurseId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    final snapshot = await _firestore
        .collection('earnings')
        .doc(nurseId)
        .collection('transactions')
        .where('type', isEqualTo: 'earning')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    
    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['amount'] as num).toDouble();
    }
    return total;
  }

  // Weekly earnings
  Future<double> getWeeklyEarnings(String nurseId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    final snapshot = await _firestore
        .collection('earnings')
        .doc(nurseId)
        .collection('transactions')
        .where('type', isEqualTo: 'earning')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();
    
    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['amount'] as num).toDouble();
    }
    return total;
  }

  // ======== WITHDRAWAL OPERATIONS ========

  Future<void> requestWithdrawal(WithdrawalModel withdrawal) async {
    final batch = _firestore.batch();
    
    // Create withdrawal record
    batch.set(
      _firestore.collection('withdrawals').doc(withdrawal.id),
      withdrawal.toMap(),
    );

    // Deduct from withdrawable balance
    batch.update(
      _firestore.collection('earnings').doc(withdrawal.nurseId),
      {
        'withdrawableBalance': FieldValue.increment(-withdrawal.amount),
        'totalWithdrawn': FieldValue.increment(withdrawal.amount),
      },
    );

    // Add transaction
    final txnId = _firestore.collection('earnings').doc(withdrawal.nurseId)
        .collection('transactions').doc().id;
    batch.set(
      _firestore.collection('earnings').doc(withdrawal.nurseId)
          .collection('transactions').doc(txnId),
      {
        'id': txnId,
        'type': 'withdrawal',
        'amount': withdrawal.amount,
        'status': 'pending',
        'timestamp': Timestamp.now(),
        'description': 'Withdrawal request',
      },
    );

    await batch.commit();
  }

  Stream<List<WithdrawalModel>> streamWithdrawals(String nurseId) {
    return _firestore
        .collection('withdrawals')
        .where('nurseId', isEqualTo: nurseId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WithdrawalModel.fromMap(doc.data()))
            .toList());
  }

  // ======== ADMIN OPERATIONS ========

  Future<Map<String, dynamic>> getAdminStats() async {
    final users = await _firestore.collection('users').where('role', isEqualTo: 'patient').get();
    final nurses = await _firestore.collection('users').where('role', isEqualTo: 'nurse').get();
    final bookings = await _firestore.collection('bookings').get();
    final completed = await _firestore.collection('bookings').where('status', isEqualTo: 'completed').get();
    final payments = await _firestore.collection('payments').get();
    
    double totalRevenue = 0;
    double totalCommission = 0;
    for (var doc in payments.docs) {
      totalRevenue += (doc.data()['amount'] as num).toDouble();
      totalCommission += (doc.data()['commission'] as num).toDouble();
    }

    return {
      'totalPatients': users.docs.length,
      'totalNurses': nurses.docs.length,
      'totalBookings': bookings.docs.length,
      'completedBookings': completed.docs.length,
      'totalRevenue': totalRevenue,
      'totalCommission': totalCommission,
    };
  }
}
