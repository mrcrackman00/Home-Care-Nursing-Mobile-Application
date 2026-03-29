import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class NurseProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<UserModel> _onlineNurses = [];
  bool _isOnline = false;
  bool _isLoading = false;

  StreamSubscription? _nursesSubscription;

  List<UserModel> get onlineNurses => _onlineNurses;
  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;

  // Start listening to online nurses (for patient map)
  void listenToOnlineNurses() {
    _nursesSubscription?.cancel();
    _nursesSubscription = _firestoreService
        .streamOnlineNurses()
        .listen((nurses) {
      _onlineNurses = nurses;
      notifyListeners();
    });
  }

  // Toggle nurse online/offline
  Future<void> toggleOnlineStatus(String nurseId, bool online) async {
    _isLoading = true;
    notifyListeners();

    await _firestoreService.setNurseOnlineStatus(nurseId, online);
    _isOnline = online;
    
    _isLoading = false;
    notifyListeners();
  }

  void setOnlineStatus(bool online) {
    _isOnline = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _nursesSubscription?.cancel();
    super.dispose();
  }
}
