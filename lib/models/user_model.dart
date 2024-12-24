import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime lastSeen;
  final String? activeGame;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.createdAt,
    required this.lastSeen,
    this.activeGame,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'photoURL': photoURL,
    'createdAt': createdAt.toIso8601String(),
    'lastSeen': lastSeen.toIso8601String(),
    'activeGame': activeGame,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    email: json['email'],
    displayName: json['displayName'],
    photoURL: json['photoURL'],
    createdAt: (json['createdAt'] as Timestamp).toDate(),
    lastSeen: (json['lastSeen'] as Timestamp).toDate(),
    activeGame: json['activeGame'],
  );
} 