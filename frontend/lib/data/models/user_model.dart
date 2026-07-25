class UserModel {
  final int id;
  final String username;
  final String? firstName;
  final String? lastName;
  final String role;
  final String? token;
  final int? terminalId;
  final String? storeName;
  final String? logoUrl;

  UserModel({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    required this.role,
    this.token,
    this.terminalId,
    this.storeName,
    this.logoUrl,
  });

  String get fullName {
    if ((firstName == null || firstName!.isEmpty) && (lastName == null || lastName!.isEmpty)) {
      return username;
    }
    return "${firstName ?? ''} ${lastName ?? ''}".trim();
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? token, String? storeName, String? logoUrl}) {
    final user = map['user'] ?? map;
    return UserModel(
      id: int.tryParse(user['id']?.toString() ?? '0') ?? 0,
      username: user['username'] ?? '',
      firstName: user['first_name'],
      lastName: user['last_name'],
      role: user['role'] ?? 'User',
      token: token ?? map['access_token'],
      terminalId: int.tryParse(user['terminal_id']?.toString() ?? '0'),
      storeName: storeName ?? map['store_name'],
      logoUrl: logoUrl ?? map['logo_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'terminal_id': terminalId,
    };
  }
}
