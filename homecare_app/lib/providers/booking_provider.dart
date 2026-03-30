import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../config/constants.dart';

class BookingProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<BookingModel> _bookings = [];
  BookingModel? _activeBooking;
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _bookingsSubscription;
  StreamSubscription? _activeBookingSubscription;

  List<BookingModel> get bookings => _bookings;
  BookingModel? get activeBooking => _activeBooking;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String _presentableError(Object error) {
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
      return 'This request could not be completed on web right now. Refresh and try again.';
    }
    return raw;
  }

  // ======== PATIENT OPERATIONS ========

  // Create a new booking
  Future<String?> createBooking({
    required UserModel patient,
    required Map<String, dynamic> service,
    required GeoPoint location,
    required String address,
    required double price,
    UserModel? preferredNurse,
    bool isInstant = true,
    DateTime? scheduledTime,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bookingId = const Uuid().v4();
      final commission = service['noCommission'] == true
          ? 0.0
          : AppConstants.calculateCommission(price);
      final nurseEarning = service['noCommission'] == true
          ? price
          : AppConstants.calculateNurseEarning(price);

      final booking = BookingModel(
        id: bookingId,
        patientId: patient.uid,
        patientName: patient.name,
        patientPhone: patient.phone,
        serviceType: service['id'],
        serviceName: service['name'],
        status: 'pending',
        patientLocation: location,
        patientAddress: address,
        isInstant: isInstant,
        scheduledTime: scheduledTime,
        duration: service['duration'],
        totalAmount: price,
        platformCommission: commission,
        nurseEarning: nurseEarning,
        preferredNurseId: preferredNurse?.uid,
        offeredNurseId: preferredNurse?.uid,
        dispatchState: preferredNurse != null
            ? 'requested_to_nurse'
            : 'awaiting_admin_assignment',
      );

      await _firestoreService.createBooking(
        booking,
        preferredNurse: preferredNurse,
      );
      _activeBooking = booking;
      _isLoading = false;
      notifyListeners();
      return bookingId;
    } catch (e) {
      _error = _presentableError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Listen to patient's bookings
  void listenToPatientBookings(String patientId) {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = _firestoreService
        .streamPatientBookings(patientId)
        .listen(
          (bookings) {
            _error = null;
            _bookings = bookings;
            notifyListeners();
          },
          onError: (error) {
            _bookings = [];
            _error = 'Unable to load patient bookings right now: $error';
            notifyListeners();
          },
        );
  }

  // Listen to active booking status
  void listenToBooking(String bookingId) {
    _activeBookingSubscription?.cancel();
    _activeBookingSubscription = _firestoreService
        .streamBooking(bookingId)
        .listen((booking) {
          _activeBooking = booking;
          notifyListeners();
        });
  }

  // Cancel booking (patient)
  Future<void> cancelBooking(String bookingId, String reason) async {
    await _firestoreService.cancelBooking(bookingId, reason);
    _activeBooking = null;
    notifyListeners();
  }

  // Rate booking
  Future<void> rateBooking(
    String bookingId,
    String nurseId,
    double rating,
    String feedback,
  ) async {
    await _firestoreService.rateBooking(bookingId, nurseId, rating, feedback);
  }

  // Mark service as completed (patient confirms)
  Future<void> markCompleted(String bookingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.completeBooking(bookingId);
      _activeBooking = null;
    } catch (e) {
      _error = _presentableError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ======== NURSE OPERATIONS ========

  // Listen to pending bookings (for nurses)
  void listenToPendingBookings(String nurseId) {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = _firestoreService
        .streamPendingBookings(nurseId)
        .listen(
          (bookings) {
            _error = null;
            _bookings = bookings;
            notifyListeners();
          },
          onError: (error) {
            _bookings = [];
            _error = 'Unable to load incoming requests right now: $error';
            notifyListeners();
          },
        );
  }

  // Listen to nurse's bookings
  void listenToNurseBookings(String nurseId) {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = _firestoreService
        .streamNurseBookings(nurseId)
        .listen(
          (bookings) {
            _error = null;
            _bookings = bookings;
            notifyListeners();
          },
          onError: (error) {
            _bookings = [];
            _error = 'Unable to load nurse bookings right now: $error';
            notifyListeners();
          },
        );
  }

  // Listen to active nurse booking
  void listenToActiveNurseBooking(String nurseId) {
    _activeBookingSubscription?.cancel();
    _activeBookingSubscription = _firestoreService
        .streamActiveNurseBooking(nurseId)
        .listen((booking) async {
          _activeBooking = booking;
          if (booking == null) {
            try {
              await _firestoreService.updateUserField(
                nurseId,
                'isAvailable',
                true,
              );
            } catch (_) {
              // Ignore availability sync errors here; the nurse can still toggle online manually.
            }
          }
          notifyListeners();
        });
  }

  // Accept booking (nurse)
  Future<void> acceptBooking(
    String bookingId,
    String nurseId,
    String nurseName,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.acceptBooking(bookingId, nurseId, nurseName);
    } catch (e) {
      _error = _presentableError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectBooking(String bookingId, String nurseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.rejectBooking(bookingId, nurseId);
    } catch (e) {
      _error = _presentableError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Start service (nurse)
  Future<void> startService(String bookingId) async {
    await _firestoreService.startService(bookingId);
    notifyListeners();
  }

  void clearActive() {
    _activeBooking = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _activeBookingSubscription?.cancel();
    super.dispose();
  }
}
