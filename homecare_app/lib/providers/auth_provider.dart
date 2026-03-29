import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  String? _verificationId;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _authService.currentUser != null;
  String? get currentUserId => _authService.currentUser?.uid;

  // Initialize - check if user is already logged in
  Future<void> initialize() async {
    User? firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      _user = await _authService.getUserData(firebaseUser.uid);
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
      _user = await _authService.registerWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
      );
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
  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (_user == null) return;
    await _firestoreService.updateUser(_user!.uid, data);
    _user = await _authService.getUserData(_user!.uid);
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    await _authService.signOut();
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
        return 'Email is already registered';
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}
