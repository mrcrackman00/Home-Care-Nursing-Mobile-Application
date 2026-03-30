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
  final String? qualification;
  final List<String>? languages;
  final double? serviceRadiusKm;
  final String? shiftPreference;
  final String? about;
  final double? startingPrice;
  final String? gender;
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
    this.qualification,
    this.languages,
    this.serviceRadiusKm,
    this.shiftPreference,
    this.about,
    this.startingPrice,
    this.gender,
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
      map['qualification'] = qualification ?? '';
      map['languages'] = languages ?? ['Hindi'];
      map['serviceRadiusKm'] = serviceRadiusKm ?? 10.0;
      map['shiftPreference'] = shiftPreference ?? 'Flexible';
      map['about'] = about ?? '';
      map['startingPrice'] = startingPrice ?? 500.0;
      map['gender'] = gender ?? '';
      map['verified'] = verified ?? false;
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
      qualification: map['qualification'] as String?,
      languages: map['languages'] != null
          ? List<String>.from(map['languages'])
          : null,
      serviceRadiusKm: (map['serviceRadiusKm'] as num?)?.toDouble(),
      shiftPreference: map['shiftPreference'] as String?,
      about: map['about'] as String?,
      startingPrice: (map['startingPrice'] as num?)?.toDouble(),
      gender: map['gender'] as String?,
      verified: map['verified'] as bool?,
      bankDetails: map['bankDetails'] as Map<String, dynamic>?,
    );
  }

  factory UserModel.fromSnapshot(DocumentSnapshot doc) {
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  bool get hasCompleteProfessionalProfile {
    if (role != 'nurse') {
      return false;
    }

    return (qualification?.trim().isNotEmpty ?? false) &&
        (experience?.trim().isNotEmpty ?? false) &&
        (specializations?.isNotEmpty ?? false) &&
        ((about?.trim().length ?? 0) >= 20) &&
        startingPrice != null &&
        serviceRadiusKm != null;
  }

  bool get hasPatientVisibleVerificationBadge {
    return role == 'nurse' && verified == true && hasCompleteProfessionalProfile;
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
    String? qualification,
    List<String>? languages,
    double? serviceRadiusKm,
    String? shiftPreference,
    String? about,
    double? startingPrice,
    String? gender,
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
      qualification: qualification ?? this.qualification,
      languages: languages ?? this.languages,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      shiftPreference: shiftPreference ?? this.shiftPreference,
      about: about ?? this.about,
      startingPrice: startingPrice ?? this.startingPrice,
      gender: gender ?? this.gender,
      verified: verified ?? this.verified,
      bankDetails: bankDetails ?? this.bankDetails,
    );
  }
}
