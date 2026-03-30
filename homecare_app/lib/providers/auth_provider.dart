import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<User?>? _authStateSubscription;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  String? _verificationId;

  AuthProvider() {
    _authStateSubscription = _authService.authStateChanges.listen(
      (firebaseUser) {
        unawaited(_syncAuthState(firebaseUser));
      },
    );
  }

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _authService.currentUser != null;
  String? get currentUserId => _authService.currentUser?.uid;

  // Initialize - check if user is already logged in
  Future<void> initialize() async {
    await _syncAuthState(_authService.currentUser);
  }

  Future<void> _syncAuthState(User? firebaseUser) async {
    if (firebaseUser == null) {
      if (_user != null) {
        _user = null;
        _error = null;
        notifyListeners();
      }
      return;
    }

    final freshUser = await _authService.getUserData(firebaseUser.uid);
    if (freshUser != null) {
      _notificationService.initialize(freshUser.uid);
    }

    final changed = _user?.uid != freshUser?.uid ||
        _user?.role != freshUser?.role ||
        _user?.isOnline != freshUser?.isOnline;

    _user = freshUser;
    if (changed) {
      notifyListeners();
    }
  }

  // Register
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('[Auth] Starting registration for $email...');

      // Safety timeout for Firebase Web calls
      final registerFuture = _authService.registerWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
      );

      _user = await registerFuture.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('[Auth] Registration timed out after 15s');
          throw TimeoutException('Authentication service is not responding. Check your connection or Firebase Console settings.');
        },
      );

      print('[Auth] Registration successful: ${_user?.uid}');
      if (_user != null) {
        _notificationService.initialize(_user!.uid);
      }
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } on FirebaseAuthException catch (e) {
      print('[Auth Error] Code: ${e.code}, Message: ${e.message}');
      _error = _getAuthErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } on TimeoutException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('[Auth Catch-All] Error: $e');
      _error = 'Error ($e). If this says permission-denied, Firebase Firestore rules need to be updated.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.loginWithEmail(
        email: email,
        password: password,
      );
      if (_user != null) {
        _notificationService.initialize(_user!.uid);
      }
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Send OTP
  Future<void> sendOTP(String phoneNumber) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _authService.sendOTP(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId) {
        _verificationId = verificationId;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _error = error;
        _isLoading = false;
        notifyListeners();
      },
      onAutoVerify: (user) {
        _user = user;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Verify OTP
  Future<bool> verifyOTP(String otp) async {
    if (_verificationId == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      User? firebaseUser = await _authService.verifyOTP(
        verificationId: _verificationId!,
        otp: otp,
      );

      if (firebaseUser != null) {
        _user = await _authService.getUserData(firebaseUser.uid);
        if (_user != null) {
          _notificationService.initialize(_user!.uid);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Invalid OTP';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update profile
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_user == null) {
      _error = 'No active user found for profile update.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.updateUser(_user!.uid, data);
      _user = await _authService.getUserData(_user!.uid);
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      final rawError = e.toString();
      if (rawError.contains('permission-denied')) {
        _error = 'Profile save is blocked by Firestore permissions right now. Refresh the app and try again.';
      } else {
        _error = 'Unable to save profile right now: $rawError';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Guest Login Bypass (Development Only)
  Future<void> loginAsGuest(String role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Simulate a short delay
    await Future.delayed(const Duration(milliseconds: 500));

    _user = UserModel(
      uid: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Guest User',
      email: 'guest@homecare.com',
      phone: '0000000000',
      role: role,
    );

    _isLoading = false;
    notifyListeners();
    print('[Auth] Entered App in GUEST MODE');
  }

  // Logout
  Future<void> logout() async {
    try {
      await _authService.signOut();
    } catch (_) {
      // Ignore errors during logout in guest mode
    }
    _user = null;
    _error = null;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password is too weak';
      case 'email-already-in-use':
        return 'This email or phone is already registered';
      case 'user-not-found':
        return 'No user found with this ID';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email or phone number';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'operation-not-allowed':
        return 'Email/Password login is not enabled in Firebase Console';
      default:
        return 'Registration failed: $code. Please contact support.';
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
