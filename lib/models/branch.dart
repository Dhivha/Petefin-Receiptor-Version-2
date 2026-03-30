class Branch {
  final int branchId;
  final String branchName;

  Branch({
    required this.branchId,
    required this.branchName,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      branchId: json['BranchId'] ?? 0,
      branchName: json['BranchName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'BranchId': branchId,
      'BranchName': branchName,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'branchName': branchName,
      'lastSynced': DateTime.now().millisecondsSinceEpoch,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      branchId: map['branchId'] ?? 0,
      branchName: map['branchName'] ?? '',
    );
  }

  @override
  String toString() {
    return 'Branch{branchId: $branchId, branchName: $branchName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Branch &&
        other.branchId == branchId &&
        other.branchName == branchName;
  }

  @override
  int get hashCode {
    return branchId.hashCode ^ branchName.hashCode;
  }
}