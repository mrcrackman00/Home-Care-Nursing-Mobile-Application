import 'package:cloud_firestore/cloud_firestore.dart';

class EarningModel {
  final String nurseId;
  final double totalEarnings;
  final double withdrawableBalance;
  final double totalWithdrawn;
  final double pendingWithdrawalBalance;
  final int totalJobs;

  EarningModel({
    required this.nurseId,
    this.totalEarnings = 0,
    this.withdrawableBalance = 0,
    this.totalWithdrawn = 0,
    this.pendingWithdrawalBalance = 0,
    this.totalJobs = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'nurseId': nurseId,
      'totalEarnings': totalEarnings,
      'withdrawableBalance': withdrawableBalance,
      'totalWithdrawn': totalWithdrawn,
      'pendingWithdrawalBalance': pendingWithdrawalBalance,
      'totalJobs': totalJobs,
    };
  }

  factory EarningModel.fromMap(Map<String, dynamic> map) {
    return EarningModel(
      nurseId: map['nurseId'] ?? '',
      totalEarnings: (map['totalEarnings'] as num?)?.toDouble() ?? 0,
      withdrawableBalance: (map['withdrawableBalance'] as num?)?.toDouble() ?? 0,
      totalWithdrawn: (map['totalWithdrawn'] as num?)?.toDouble() ?? 0,
      pendingWithdrawalBalance:
          (map['pendingWithdrawalBalance'] as num?)?.toDouble() ?? 0,
      totalJobs: map['totalJobs'] as int? ?? 0,
    );
  }

  factory EarningModel.fromSnapshot(DocumentSnapshot doc) {
    return EarningModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}

class TransactionModel {
  final String id;
  final String type; // 'earning' or 'withdrawal'
  final double amount;
  final String? bookingId;
  final String status; // 'completed', 'pending', 'failed'
  final DateTime timestamp;
  final String? description;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    this.bookingId,
    this.status = 'completed',
    DateTime? timestamp,
    this.description,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'bookingId': bookingId,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'description': description,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      bookingId: map['bookingId'],
      status: map['status'] ?? 'completed',
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      description: map['description'],
    );
  }
}

class WithdrawalModel {
  final String id;
  final String nurseId;
  final double amount;
  final Map<String, dynamic> bankDetails;
  final String status; // pending, processing, completed, failed
  final String? razorpayPayoutId;
  final DateTime requestedAt;
  final DateTime? completedAt;

  WithdrawalModel({
    required this.id,
    required this.nurseId,
    required this.amount,
    required this.bankDetails,
    this.status = 'pending',
    this.razorpayPayoutId,
    DateTime? requestedAt,
    this.completedAt,
  }) : requestedAt = requestedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nurseId': nurseId,
      'amount': amount,
      'bankDetails': bankDetails,
      'status': status,
      'razorpayPayoutId': razorpayPayoutId,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory WithdrawalModel.fromMap(Map<String, dynamic> map) {
    return WithdrawalModel(
      id: map['id'] ?? '',
      nurseId: map['nurseId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      bankDetails: map['bankDetails'] as Map<String, dynamic>? ?? {},
      status: map['status'] ?? 'pending',
      razorpayPayoutId: map['razorpayPayoutId'],
      requestedAt: map['requestedAt'] != null 
          ? (map['requestedAt'] as Timestamp).toDate() 
          : DateTime.now(),
      completedAt: map['completedAt'] != null 
          ? (map['completedAt'] as Timestamp).toDate() 
          : null,
    );
  }
}
