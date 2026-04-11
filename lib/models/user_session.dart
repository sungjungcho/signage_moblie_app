class UserSession {
  const UserSession({
    required this.userId,
    required this.displayName,
    required this.keepSignedIn,
    this.loginPassword,
  });

  final String userId;
  final String displayName;
  final bool keepSignedIn;
  final String? loginPassword;

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final loginPassword = (json['loginPassword'] ?? '').toString();

    return UserSession(
      userId: (json['userId'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      keepSignedIn: json['keepSignedIn'] == true,
      loginPassword: loginPassword.isEmpty ? null : loginPassword,
    );
  }

  UserSession copyWith({
    String? userId,
    String? displayName,
    bool? keepSignedIn,
    String? loginPassword,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      keepSignedIn: keepSignedIn ?? this.keepSignedIn,
      loginPassword: loginPassword ?? this.loginPassword,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'keepSignedIn': keepSignedIn,
      'loginPassword': loginPassword,
    };
  }
}
