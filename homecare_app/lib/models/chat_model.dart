import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThreadModel {
  final String id;
  final String bookingId;
  final List<String> participantIds;
  final String? patientId;
  final String? nurseId;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, int> unreadCounts;

  ChatThreadModel({
    required this.id,
    required this.bookingId,
    required this.participantIds,
    this.patientId,
    this.nurseId,
    this.lastMessage = '',
    this.lastMessageSenderId = '',
    this.lastMessageAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.unreadCounts = const {},
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'participantIds': participantIds,
      'patientId': patientId,
      'nurseId': nurseId,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'unreadCounts': unreadCounts,
    };
  }

  factory ChatThreadModel.fromMap(Map<String, dynamic> map) {
    return ChatThreadModel(
      id: map['id'] ?? '',
      bookingId: map['bookingId'] ?? '',
      participantIds: List<String>.from(map['participantIds'] ?? const []),
      patientId: map['patientId'],
      nurseId: map['nurseId'],
      lastMessage: map['lastMessage'] ?? '',
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      lastMessageAt: map['lastMessageAt'] != null
          ? (map['lastMessageAt'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      unreadCounts: Map<String, int>.from(map['unreadCounts'] ?? const {}),
    );
  }

  factory ChatThreadModel.fromSnapshot(DocumentSnapshot doc) {
    return ChatThreadModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}

class ChatMessageModel {
  final String id;
  final String threadId;
  final String bookingId;
  final String senderId;
  final String senderName;
  final String text;
  final String messageType;
  final DateTime createdAt;
  final List<String> readBy;

  ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.bookingId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.messageType = 'text',
    DateTime? createdAt,
    this.readBy = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'threadId': threadId,
      'bookingId': bookingId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'messageType': messageType,
      'createdAt': Timestamp.fromDate(createdAt),
      'readBy': readBy,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] ?? '',
      threadId: map['threadId'] ?? '',
      bookingId: map['bookingId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      messageType: map['messageType'] ?? 'text',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      readBy: List<String>.from(map['readBy'] ?? const []),
    );
  }

  factory ChatMessageModel.fromSnapshot(DocumentSnapshot doc) {
    return ChatMessageModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}
