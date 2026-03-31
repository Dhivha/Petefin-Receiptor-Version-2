class CashCount {
  final int? id;
  final String branchName;
  final String capturedBy;
  final double amount;
  final DateTime cashbookDate;
  final bool isSynced;
  final DateTime? syncedAt;
  final DateTime createdAt;

  CashCount({
    this.id,
    required this.branchName,
    required this.capturedBy,
    required this.amount,
    required this.cashbookDate,
    this.isSynced = false,
    this.syncedAt,
    required this.createdAt,
  });

  factory CashCount.fromJson(Map<String, dynamic> json) {
    return CashCount(
      id: json['Id'],
      branchName: json['BranchName'] ?? '',
      capturedBy: json['CapturedBy'] ?? '',
      amount: (json['Amount'] ?? 0.0).toDouble(),
      cashbookDate: DateTime.parse(json['CashbookDate']),
      isSynced: json['IsSynced'] ?? false,
      syncedAt: json['SyncedAt'] != null
          ? DateTime.parse(json['SyncedAt'])
          : null,
      createdAt: json['CreatedAt'] != null
          ? DateTime.parse(json['CreatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'BranchName': branchName,
      'CashbookDate': cashbookDate.toIso8601String(),
      'CapturedBy': capturedBy,
      'Amount': amount,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchName': branchName,
      'capturedBy': capturedBy,
      'amount': amount,
      'cashbookDate': cashbookDate.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
      'syncedAt': syncedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CashCount.fromMap(Map<String, dynamic> map) {
    return CashCount(
      id: map['id'],
      branchName: map['branchName'] ?? '',
      capturedBy: map['capturedBy'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      cashbookDate: DateTime.parse(map['cashbookDate']),
      isSynced: (map['isSynced'] ?? 0) == 1,
      syncedAt: map['syncedAt'] != null
          ? DateTime.parse(map['syncedAt'])
          : null,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  String get formattedAmount {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String get formattedDate {
    return '${cashbookDate.day}/${cashbookDate.month}/${cashbookDate.year}';
  }

  bool get canBeDeleted {
    // Can only delete queued (non-synced) entries
    return !isSynced;
  }

  bool get isExpired {
    // Synced cash counts disappear after 7 days
    return isSynced &&
        syncedAt != null &&
        DateTime.now().difference(syncedAt!).inDays > 7;
  }
}

class CashCountResult {
  final bool success;
  final String message;
  final CashCount? cashCount;

  CashCountResult({
    required this.success,
    required this.message,
    this.cashCount,
  });
}

class CashCountSyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  CashCountSyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
  });
}
