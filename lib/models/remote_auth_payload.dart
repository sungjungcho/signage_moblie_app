import 'user_session.dart';

class RemoteAuthPayload {
  const RemoteAuthPayload({
    required this.userId,
    required this.password,
    required this.keepSignedIn,
  });

  final String userId;
  final String password;
  final bool keepSignedIn;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'password': password,
      'keepSignedIn': keepSignedIn,
    };
  }
}

class RemoteAuthResponse {
  const RemoteAuthResponse({
    required this.userId,
    required this.displayName,
    required this.keepSignedIn,
  });

  final String userId;
  final String displayName;
  final bool keepSignedIn;

  factory RemoteAuthResponse.fromJson(Map<String, dynamic> json) {
    return RemoteAuthResponse(
      userId: (json['userId'] ?? json['id'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['name'] ?? '').toString(),
      keepSignedIn: json['keepSignedIn'] == true,
    );
  }

  UserSession toSession({required bool fallbackKeepSignedIn}) {
    return UserSession(
      userId: userId,
      displayName: displayName.isEmpty ? '사용자' : displayName,
      keepSignedIn: keepSignedIn || fallbackKeepSignedIn,
    );
  }
}
