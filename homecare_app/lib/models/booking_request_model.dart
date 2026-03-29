import 'package:cloud_firestore/cloud_firestore.dart';

import 'booking_model.dart';

class BookingRequestModel {
  final String id;
  final String bookingId;
  final String nurseId;
  final String patientId;
  final String patientName;
  final String patientPhone;
  final GeoPoint patientLocation;
  final String patientAddress;
  final String serviceType;
  final String serviceName;
  final String duration;
  final bool isInstant;
  final DateTime? scheduledTime;
  final double totalAmount;
  final double nurseEarning;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  BookingRequestModel({
    required this.id,
    required this.bookingId,
    required this.nurseId,
    required this.patientId,
    required this.patientName,
    required this.patientPhone,
    required this.patientLocation,
    required this.patientAddress,
    required this.serviceType,
    required this.serviceName,
    required this.duration,
    required this.isInstant,
    this.scheduledTime,
    required this.totalAmount,
    required this.nurseEarning,
    required this.status,
    DateTime? createdAt,
    this.respondedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BookingRequestModel.fromMap(Map<String, dynamic> map) {
    return BookingRequestModel(
      id: map['id'] ?? '',
      bookingId: map['bookingId'] ?? '',
      nurseId: map['nurseId'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      patientPhone: map['patientPhone'] ?? '',
      patientLocation: map['patientLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      patientAddress: map['patientAddress'] ?? '',
      serviceType: map['serviceType'] ?? '',
      serviceName: map['serviceName'] ?? '',
      duration: map['duration'] ?? '',
      isInstant: map['isInstant'] ?? true,
      scheduledTime: map['scheduledTime'] != null
          ? (map['scheduledTime'] as Timestamp).toDate()
          : null,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      nurseEarning: (map['nurseEarning'] as num?)?.toDouble() ?? 0,
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      respondedAt: map['respondedAt'] != null
          ? (map['respondedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory BookingRequestModel.fromSnapshot(DocumentSnapshot doc) {
    return BookingRequestModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  BookingModel toBookingPreview() {
    return BookingModel(
      id: bookingId,
      patientId: patientId,
      patientName: patientName,
      patientPhone: patientPhone,
      serviceType: serviceType,
      serviceName: serviceName,
      patientLocation: patientLocation,
      patientAddress: patientAddress,
      scheduledTime: scheduledTime,
      isInstant: isInstant,
      duration: duration,
      totalAmount: totalAmount,
      platformCommission: totalAmount - nurseEarning,
      nurseEarning: nurseEarning,
      status: 'pending',
      createdAt: createdAt,
    );
  }
}
