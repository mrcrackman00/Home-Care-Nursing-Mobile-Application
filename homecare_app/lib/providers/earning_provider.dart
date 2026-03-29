import 'dart:async';
import 'package:flutter/material.dart';
import '../models/earning_model.dart';
import '../services/firestore_service.dart';

class EarningProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  EarningModel? _earnings;
  List<TransactionModel> _transactions = [];
  double _todayEarnings = 0;
  double _weeklyEarnings = 0;
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _earningsSubscription;
  StreamSubscription? _transactionsSubscription;

  EarningModel? get earnings => _earnings;
  List<TransactionModel> get transactions => _transactions;
  double get todayEarnings => _todayEarnings;
  double get weeklyEarnings => _weeklyEarnings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Listen to earnings
  void listenToEarnings(String nurseId) {
    _earningsSubscription?.cancel();
    _earningsSubscription = _firestoreService
        .streamEarnings(nurseId)
        .listen((earnings) {
      _earnings = earnings;
      notifyListeners();
    });

    _transactionsSubscription?.cancel();
    _transactionsSubscription = _firestoreService
        .streamTransactions(nurseId)
        .listen((transactions) {
      _transactions = transactions;
      notifyListeners();
    });

    // Fetch period earnings
    _fetchPeriodEarnings(nurseId);
  }

  Future<void> _fetchPeriodEarnings(String nurseId) async {
    _todayEarnings = await _firestoreService.getTodayEarnings(nurseId);
    _weeklyEarnings = await _firestoreService.getWeeklyEarnings(nurseId);
    notifyListeners();
  }

  // Request withdrawal
  Future<bool> requestWithdrawal({
    required String nurseId,
    required double amount,
    required Map<String, dynamic> bankDetails,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_earnings == null || _earnings!.withdrawableBalance < amount) {
        _error = 'Insufficient balance';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final withdrawal = WithdrawalModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nurseId: nurseId,
        amount: amount,
        bankDetails: bankDetails,
      );

      await _firestoreService.requestWithdrawal(withdrawal);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void refresh(String nurseId) {
    _fetchPeriodEarnings(nurseId);
  }

  @override
  void dispose() {
    _earningsSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}
