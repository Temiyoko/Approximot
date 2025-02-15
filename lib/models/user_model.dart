import 'package:cloud_firestore/cloud_firestore.dart';
import 'guess_result.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final Map<String, String> activeGames;
  final List<GuessResult> lexitomGuesses;
  final List<GuessResult> wikitomGuesses;
  final int? loginAttempts;
  final DateTime? lastLoginAttempt;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.activeGames,
    required this.lexitomGuesses,
    required this.wikitomGuesses,
    this.loginAttempts,
    this.lastLoginAttempt,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'photoURL': photoURL,
    'activeGames': activeGames,
    'lexitomGuesses': lexitomGuesses.map((g) => g.toJson()).toList(),
    'wikitomGuesses': wikitomGuesses.map((g) => g.toJson()).toList(),
    'loginAttempts': loginAttempts,
    'lastLoginAttempt': lastLoginAttempt != null ? Timestamp.fromDate(lastLoginAttempt!) : null,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    uid: json['uid'],
    email: json['email'],
    displayName: json['displayName'],
    photoURL: json['photoURL'],
    activeGames: Map<String, String>.from(json['activeGames'] ?? {}),
    lexitomGuesses: (json['lexitomGuesses'] as List?)?.map((g) => GuessResult.fromJson(g)).toList() ?? [],
    wikitomGuesses: (json['wikitomGuesses'] as List?)?.map((g) => GuessResult.fromJson(g)).toList() ?? [],
    loginAttempts: json['loginAttempts'],
    lastLoginAttempt: json['lastLoginAttempt'] != null ? (json['lastLoginAttempt'] as Timestamp).toDate() : null,
  );
} 