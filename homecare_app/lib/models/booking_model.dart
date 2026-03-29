import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String patientId;
  final String patientName;
  final String patientPhone;
  String? nurseId;
  String? nurseName;
  final String serviceType;
  final String serviceName;
  String status; // pending, accepted, in_progress, completed, cancelled
  final GeoPoint patientLocation;
  final String patientAddress;
  final DateTime? scheduledTime;
  final bool isInstant;
  final String duration;
  final double totalAmount;
  final double platformCommission;
  final double nurseEarning;
  String paymentStatus; // pending, paid, failed
  String? paymentId;
  final DateTime createdAt;
  DateTime? completedAt;
  double? rating;
  String? feedback;
  String? cancellationReason;

  BookingModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientPhone,
    this.nurseId,
    this.nurseName,
    required this.serviceType,
    required this.serviceName,
    this.status = 'pending',
    required this.patientLocation,
    required this.patientAddress,
    this.scheduledTime,
    this.isInstant = true,
    required this.duration,
    required this.totalAmount,
    required this.platformCommission,
    required this.nurseEarning,
    this.paymentStatus = 'pending',
    this.paymentId,
    DateTime? createdAt,
    this.completedAt,
    this.rating,
    this.feedback,
    this.cancellationReason,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'nurseId': nurseId,
      'nurseName': nurseName,
      'serviceType': serviceType,
      'serviceName': serviceName,
      'status': status,
      'patientLocation': patientLocation,
      'patientAddress': patientAddress,
      'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime!) : null,
      'isInstant': isInstant,
      'duration': duration,
      'totalAmount': totalAmount,
      'platformCommission': platformCommission,
      'nurseEarning': nurseEarning,
      'paymentStatus': paymentStatus,
      'paymentId': paymentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'rating': rating,
      'feedback': feedback,
      'cancellationReason': cancellationReason,
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      patientPhone: map['patientPhone'] ?? '',
      nurseId: map['nurseId'],
      nurseName: map['nurseName'],
      serviceType: map['serviceType'] ?? '',
      serviceName: map['serviceName'] ?? '',
      status: map['status'] ?? 'pending',
      patientLocation: map['patientLocation'] ?? const GeoPoint(0, 0),
      patientAddress: map['patientAddress'] ?? '',
      scheduledTime: map['scheduledTime'] != null 
          ? (map['scheduledTime'] as Timestamp).toDate() 
          : null,
      isInstant: map['isInstant'] ?? true,
      duration: map['duration'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      platformCommission: (map['platformCommission'] as num?)?.toDouble() ?? 0,
      nurseEarning: (map['nurseEarning'] as num?)?.toDouble() ?? 0,
      paymentStatus: map['paymentStatus'] ?? 'pending',
      paymentId: map['paymentId'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      completedAt: map['completedAt'] != null 
          ? (map['completedAt'] as Timestamp).toDate() 
          : null,
      rating: (map['rating'] as num?)?.toDouble(),
      feedback: map['feedback'],
      cancellationReason: map['cancellationReason'],
    );
  }

  factory BookingModel.fromSnapshot(DocumentSnapshot doc) {
    return BookingModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}
