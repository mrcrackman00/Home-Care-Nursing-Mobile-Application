import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user
  User? get currentUser => _auth.currentUser;
  
  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Helper to normalize phone to email
  String normalizePhoneToEmail(String phone) {
    // Remove all non-numeric characters for safety
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return 'phone_$cleanPhone@homecare.com';
  }

  // Register with email and password
  Future<UserModel?> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        UserModel userModel = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          phone: phone,
          role: role,
        );

        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
        await _firestore.collection('user_private').doc(user.uid).set({
          'uid': user.uid,
          'role': role,
          'email': email,
          'phone': phone,
          'fcmTokens': <String>[],
          'bankDetails': <String, dynamic>{},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Create earnings doc for nurses
        if (role == 'nurse') {
          await _firestore.collection('earnings').doc(user.uid).set({
            'nurseId': user.uid,
            'totalEarnings': 0.0,
            'withdrawableBalance': 0.0,
            'totalWithdrawn': 0.0,
            'pendingWithdrawalBalance': 0.0,
            'totalJobs': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        return userModel;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Login with email and password
  Future<UserModel?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return UserModel.fromSnapshot(doc);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Phone Auth - Send OTP
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(UserModel? user) onAutoVerify,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        UserCredential result = await _auth.signInWithCredential(credential);
        if (result.user != null) {
          DocumentSnapshot doc = await _firestore
              .collection('users')
              .doc(result.user!.uid)
              .get();
          if (doc.exists) {
            onAutoVerify(UserModel.fromSnapshot(doc));
          } else {
            onAutoVerify(null);
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // Verify OTP
  Future<User?> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      UserCredential result = await _auth.signInWithCredential(credential);
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // Get user data
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Sign out
  Future<void> signOut() async {
    // If nurse, set offline
    if (currentUser != null) {
      DocumentSnapshot doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['role'] == 'nurse') {
          await _firestore.collection('users').doc(currentUser!.uid).update({
            'isOnline': false,
            'isAvailable': false,
          });
        }
      }
    }
    await _auth.signOut();
  }
}
