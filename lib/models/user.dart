class User {
  final bool isAuthenticated;
  final String message;
  final String initial;
  final String lastName;
  final String firstName;
  final String position;
  final int currentUserId;
  final String branch;
  final int branchId;
  final String whatsAppContact;

  User({
    required this.isAuthenticated,
    required this.message,
    required this.initial,
    required this.lastName,
    required this.firstName,
    required this.position,
    required this.currentUserId,
    required this.branch,
    required this.branchId,
    required this.whatsAppContact,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      isAuthenticated: json['IsAuthenticated'] ?? false,
      message: json['Message'] ?? '',
      initial: json['Initial'] ?? '',
      lastName: json['LastName'] ?? '',
      firstName: json['FirstName'] ?? '',
      position: json['Position'] ?? '',
      currentUserId: json['CurrentUserId'] ?? 0,
      branch: json['Branch'] ?? '',
      branchId: json['BranchId'] ?? 0,
      whatsAppContact: json['WhatsAppContact'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'IsAuthenticated': isAuthenticated,
      'Message': message,
      'Initial': initial,
      'LastName': lastName,
      'FirstName': firstName,
      'Position': position,
      'CurrentUserId': currentUserId,
      'Branch': branch,
      'BranchId': branchId,
      'WhatsAppContact': whatsAppContact,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'isAuthenticated': isAuthenticated ? 1 : 0,
      'message': message,
      'initial': initial,
      'lastName': lastName,
      'firstName': firstName,
      'position': position,
      'currentUserId': currentUserId,
      'branch': branch,
      'branchId': branchId,
      'whatsAppContact': whatsAppContact,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      isAuthenticated: map['isAuthenticated'] == 1,
      message: map['message'] ?? '',
      initial: map['initial'] ?? '',
      lastName: map['lastName'] ?? '',
      firstName: map['firstName'] ?? '',
      position: map['position'] ?? '',
      currentUserId: map['currentUserId'] ?? 0,
      branch: map['branch'] ?? '',
      branchId: map['branchId'] ?? 0,
      whatsAppContact: map['whatsAppContact'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName';

  @override
  String toString() {
    return 'User{firstName: $firstName, lastName: $lastName, branch: $branch, position: $position}';
  }
}
