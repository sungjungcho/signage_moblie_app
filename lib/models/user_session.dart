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
}
