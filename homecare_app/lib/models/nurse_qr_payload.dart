import 'dart:convert';

class NurseQrPayload {
  const NurseQrPayload({
    required this.nurseId,
    required this.nurseName,
    required this.nurseServiceType,
    this.nurseServiceName,
  });

  final String nurseId;
  final String nurseName;
  final String nurseServiceType;
  final String? nurseServiceName;

  Map<String, dynamic> toMap() {
    return {
      'nurseId': nurseId,
      'nurseName': nurseName,
      'nurseServiceType': nurseServiceType,
      'nurseServiceName': nurseServiceName,
    };
  }

  String toEncodedString() => jsonEncode(toMap());

  factory NurseQrPayload.fromMap(Map<String, dynamic> map) {
    return NurseQrPayload(
      nurseId: (map['nurseId'] ?? '').toString(),
      nurseName: (map['nurseName'] ?? '').toString(),
      nurseServiceType: (map['nurseServiceType'] ?? '').toString(),
      nurseServiceName: map['nurseServiceName']?.toString(),
    );
  }

  factory NurseQrPayload.fromEncodedString(String raw) {
    return NurseQrPayload.fromMap(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  bool get isValid =>
      nurseId.isNotEmpty &&
      nurseName.isNotEmpty &&
      nurseServiceType.isNotEmpty;
}
