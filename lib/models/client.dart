class Client {
  final String clientId;
  final int? branchId;
  final String firstName;
  final String lastName;
  final String fullName;
  final String branch;
  final String whatsAppContact;
  final String emailAddress;
  final String nationalIdNumber;
  final String capturedBy;
  final String gender;
  final String nextOfKinContact;
  final String nextOfKinName;
  final String relationshipWithNOK;
  final String pin;
  final String? photo; // Base64 encoded photo or photo URL
  final String syncStatus; // 'queued', 'synced'
  final DateTime createdAt;
  final DateTime? lastSynced;

  Client({
    required this.clientId,
    this.branchId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.branch,
    required this.whatsAppContact,
    required this.emailAddress,
    required this.nationalIdNumber,
    required this.capturedBy,
    required this.gender,
    required this.nextOfKinContact,
    required this.nextOfKinName,
    required this.relationshipWithNOK,
    required this.pin,
    this.photo,
    this.syncStatus = 'queued',
    DateTime? createdAt,
    this.lastSynced,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      clientId: json['ClientId'] ?? '',
      branchId: json['BranchId'],
      firstName: json['FirstName'] ?? '',
      lastName: json['LastName'] ?? '',
      fullName: json['FullName'] ?? '',
      branch: json['Branch'] ?? '',
      whatsAppContact: json['WhatsAppContact'] ?? '',
      emailAddress: json['EmailAddress'] ?? '',
      nationalIdNumber: json['NationalIdNumber'] ?? '',
      capturedBy: json['CapturedBy'] ?? '',
      gender: json['Gender'] ?? '',
      nextOfKinContact: json['NextOfKinContact'] ?? '',
      nextOfKinName: json['NextOfKinName'] ?? '',
      relationshipWithNOK: json['RelationshipWithNOK'] ?? '',
      pin: json['Pin'] ?? '',
      photo: json['Photo'],
      syncStatus: 'synced', // API data is always synced
      createdAt: DateTime.now(),
      lastSynced: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ClientId': clientId,
      'BranchId': branchId,
      'FirstName': firstName,
      'LastName': lastName,
      'FullName': fullName,
      'Branch': branch,
      'WhatsAppContact': whatsAppContact,
      'EmailAddress': emailAddress,
      'NationalIdNumber': nationalIdNumber,
      'CapturedBy': capturedBy,
      'Gender': gender,
      'NextOfKinContact': nextOfKinContact,
      'NextOfKinName': nextOfKinName,
      'RelationshipWithNOK': relationshipWithNOK,
      'Pin': pin,
      if (photo != null) 'Photo': photo,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'branchId': branchId,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'branch': branch,
      'whatsAppContact': whatsAppContact,
      'emailAddress': emailAddress,
      'nationalIdNumber': nationalIdNumber,
      'capturedBy': capturedBy,
      'gender': gender,
      'nextOfKinContact': nextOfKinContact,
      'nextOfKinName': nextOfKinName,
      'relationshipWithNOK': relationshipWithNOK,
      'pin': pin,
      'photo': photo,
      'syncStatus': syncStatus,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastSynced': lastSynced?.millisecondsSinceEpoch,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      clientId: map['clientId'] ?? '',
      branchId: map['branchId'],
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      fullName: map['fullName'] ?? '',
      branch: map['branch'] ?? '',
      whatsAppContact: map['whatsAppContact'] ?? '',
      emailAddress: map['emailAddress'] ?? '',
      nationalIdNumber: map['nationalIdNumber'] ?? '',
      capturedBy: map['capturedBy'] ?? '',
      gender: map['gender'] ?? '',
      nextOfKinContact: map['nextOfKinContact'] ?? '',
      nextOfKinName: map['nextOfKinName'] ?? '',
      relationshipWithNOK: map['relationshipWithNOK'] ?? '',
      pin: map['pin'] ?? '',
      photo: map['photo'],
      syncStatus: map['syncStatus'] ?? 'queued',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      lastSynced: map['lastSynced'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSynced'])
          : null,
    );
  }

  Client copyWith({
    String? clientId,
    int? branchId,
    String? firstName,
    String? lastName,
    String? fullName,
    String? branch,
    String? whatsAppContact,
    String? emailAddress,
    String? nationalIdNumber,
    String? capturedBy,
    String? gender,
    String? nextOfKinContact,
    String? nextOfKinName,
    String? relationshipWithNOK,
    String? pin,
    String? photo,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? lastSynced,
  }) {
    return Client(
      clientId: clientId ?? this.clientId,
      branchId: branchId ?? this.branchId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      branch: branch ?? this.branch,
      whatsAppContact: whatsAppContact ?? this.whatsAppContact,
      emailAddress: emailAddress ?? this.emailAddress,
      nationalIdNumber: nationalIdNumber ?? this.nationalIdNumber,
      capturedBy: capturedBy ?? this.capturedBy,
      gender: gender ?? this.gender,
      nextOfKinContact: nextOfKinContact ?? this.nextOfKinContact,
      nextOfKinName: nextOfKinName ?? this.nextOfKinName,
      relationshipWithNOK: relationshipWithNOK ?? this.relationshipWithNOK,
      pin: pin ?? this.pin,
      photo: photo ?? this.photo,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }

  @override
  String toString() {
    return 'Client{clientId: $clientId, fullName: $fullName, branch: $branch, whatsApp: $whatsAppContact}';
  }
}
