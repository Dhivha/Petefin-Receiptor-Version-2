class PettyCash {
  final int? id;
  final String branchName;
  final double amount;
  final DateTime dateApplicable;
  final bool isSynced;
  final DateTime? syncedAt;
  final DateTime createdAt;

  PettyCash({
    this.id,
    required this.branchName,
    required this.amount,
    required this.dateApplicable,
    this.isSynced = false,
    this.syncedAt,
    required this.createdAt,
  });

  factory PettyCash.fromJson(Map<String, dynamic> json) {
    return PettyCash(
      id: json['Id'],
      branchName: json['BranchName'] ?? '',
      amount: (json['Amount'] ?? 0.0).toDouble(),
      dateApplicable: DateTime.parse(json['DateApplicable']),
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
    // Zero out time portion - backend only cares about the date, set time to 00:00:00Z
    final dateOnly = DateTime.utc(dateApplicable.year, dateApplicable.month, dateApplicable.day);
    return {
      'BranchName': branchName,
      'Amount': amount,
      'DateApplicable': dateOnly.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchName': branchName,
      'amount': amount,
      'dateApplicable': dateApplicable.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
      'syncedAt': syncedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PettyCash.fromMap(Map<String, dynamic> map) {
    return PettyCash(
      id: map['id'],
      branchName: map['branchName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      dateApplicable: DateTime.parse(map['dateApplicable']),
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
    return '${dateApplicable.day}/${dateApplicable.month}/${dateApplicable.year}';
  }

  bool get canBeDeleted {
    // Can only delete queued (non-synced) entries
    return !isSynced;
  }

  bool get isExpired {
    // Synced petty cash disappears after 7 days
    return isSynced &&
        syncedAt != null &&
        DateTime.now().difference(syncedAt!).inDays > 7;
  }
}

class PettyCashResult {
  final bool success;
  final String message;
  final PettyCash? pettyCash;

  PettyCashResult({
    required this.success,
    required this.message,
    this.pettyCash,
  });
}

class PettyCashSyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  PettyCashSyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
  });
}
