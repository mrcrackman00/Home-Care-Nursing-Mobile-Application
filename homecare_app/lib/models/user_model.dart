import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // 'patient' or 'nurse'
  final String profileImage;
  final String? fcmToken;
  final DateTime createdAt;
  
  // Patient specific
  final String? address;
  final GeoPoint? location;
  
  // Nurse specific
  final bool? isOnline;
  final bool? isAvailable;
  final GeoPoint? currentLocation;
  final double? rating;
  final int? totalRatings;
  final List<String>? specializations;
  final String? experience;
  final bool? verified;
  final Map<String, dynamic>? bankDetails;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImage = '',
    this.fcmToken,
    DateTime? createdAt,
    this.address,
    this.location,
    this.isOnline,
    this.isAvailable,
    this.currentLocation,
    this.rating,
    this.totalRatings,
    this.specializations,
    this.experience,
    this.verified,
    this.bankDetails,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'profileImage': profileImage,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    
    if (role == 'patient') {
      map['address'] = address ?? '';
      if (location != null) map['location'] = location;
    }
    
    if (role == 'nurse') {
      map['isOnline'] = isOnline ?? false;
      map['isAvailable'] = isAvailable ?? true;
      if (currentLocation != null) map['currentLocation'] = currentLocation;
      map['rating'] = rating ?? 0.0;
      map['totalRatings'] = totalRatings ?? 0;
      map['specializations'] = specializations ?? [];
      map['experience'] = experience ?? '';
      map['verified'] = verified ?? false;
      map['bankDetails'] = bankDetails ?? {};
    }
    
    return map;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'patient',
      profileImage: map['profileImage'] ?? '',
      fcmToken: map['fcmToken'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      address: map['address'],
      location: map['location'] as GeoPoint?,
      isOnline: map['isOnline'] as bool?,
      isAvailable: map['isAvailable'] as bool?,
      currentLocation: map['currentLocation'] as GeoPoint?,
      rating: (map['rating'] as num?)?.toDouble(),
      totalRatings: map['totalRatings'] as int?,
      specializations: map['specializations'] != null 
          ? List<String>.from(map['specializations']) 
          : null,
      experience: map['experience'] as String?,
      verified: map['verified'] as bool?,
      bankDetails: map['bankDetails'] as Map<String, dynamic>?,
    );
  }

  factory UserModel.fromSnapshot(DocumentSnapshot doc) {
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? profileImage,
    String? fcmToken,
    String? address,
    GeoPoint? location,
    bool? isOnline,
    bool? isAvailable,
    GeoPoint? currentLocation,
    double? rating,
    int? totalRatings,
    List<String>? specializations,
    String? experience,
    bool? verified,
    Map<String, dynamic>? bankDetails,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role,
      profileImage: profileImage ?? this.profileImage,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      address: address ?? this.address,
      location: location ?? this.location,
      isOnline: isOnline ?? this.isOnline,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLocation: currentLocation ?? this.currentLocation,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      specializations: specializations ?? this.specializations,
      experience: experience ?? this.experience,
      verified: verified ?? this.verified,
      bankDetails: bankDetails ?? this.bankDetails,
    );
  }
}
