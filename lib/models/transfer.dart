class Transfer {
  final int? id;
  final double amount;
  final DateTime transferDate;
  final String? narration;
  final int sendingBranchId;
  final String sendingBranch;
  final int receivingBranchId;
  final String receivingBranch;
  final String transferType; // 'USD_CASH', 'USD_BANK', 'ZWG_BANK'
  final bool isSynced;
  final DateTime? syncedAt;
  final DateTime createdAt;

  Transfer({
    this.id,
    required this.amount,
    required this.transferDate,
    this.narration,
    required this.sendingBranchId,
    required this.sendingBranch,
    required this.receivingBranchId,
    required this.receivingBranch,
    required this.transferType,
    this.isSynced = false,
    this.syncedAt,
    required this.createdAt,
  });

  factory Transfer.fromJson(Map<String, dynamic> json) {
    return Transfer(
      id: json['Id'],
      amount: (json['Amount'] ?? 0.0).toDouble(),
      transferDate: DateTime.parse(json['TransferDate']),
      narration: json['Narration'],
      sendingBranchId: json['SendingBranchId'] ?? 0,
      sendingBranch: json['SendingBranch'] ?? '',
      receivingBranchId: json['ReceivingBranchId'] ?? 0,
      receivingBranch: json['ReceivingBranch'] ?? '',
      transferType: json['TransferType'] ?? 'USD_CASH',
      isSynced: json['IsSynced'] ?? false,
      syncedAt: json['SyncedAt'] != null ? DateTime.parse(json['SyncedAt']) : null,
      createdAt: json['CreatedAt'] != null ? DateTime.parse(json['CreatedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id ?? 0,
      'Amount': amount,
      'TransferDate': transferDate.toIso8601String(),
      // Note: Narration is NOT included as per user requirement
      'SendingBranchId': sendingBranchId,
      'SendingBranch': sendingBranch,
      'ReceivingBranchId': receivingBranchId,
      'ReceivingBranch': receivingBranch,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'transferDate': transferDate.toIso8601String(),
      'narration': narration,
      'sendingBranchId': sendingBranchId,
      'sendingBranch': sendingBranch,
      'receivingBranchId': receivingBranchId,
      'receivingBranch': receivingBranch,
      'transferType': transferType,
      'isSynced': isSynced ? 1 : 0,
      'syncedAt': syncedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Transfer.fromMap(Map<String, dynamic> map) {
    return Transfer(
      id: map['id'],
      amount: (map['amount'] ?? 0.0).toDouble(),
      transferDate: DateTime.parse(map['transferDate']),
      narration: map['narration'],
      sendingBranchId: map['sendingBranchId'] ?? 0,
      sendingBranch: map['sendingBranch'] ?? '',
      receivingBranchId: map['receivingBranchId'] ?? 0,
      receivingBranch: map['receivingBranch'] ?? '',
      transferType: map['transferType'] ?? 'USD_CASH',
      isSynced: (map['isSynced'] ?? 0) == 1,
      syncedAt: map['syncedAt'] != null ? DateTime.parse(map['syncedAt']) : null,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  String get formattedAmount {
    final currencySymbol = transferType.startsWith('USD') ? '\$' : 'ZWG ';
    return '$currencySymbol${amount.toStringAsFixed(2)}';
  }

  String get formattedDate {
    return '${transferDate.day}/${transferDate.month}/${transferDate.year}';
  }

  String get typeDisplayName {
    switch (transferType) {
      case 'USD_CASH':
        return 'USD Cash Transfer';
      case 'USD_BANK':
        return 'USD Bank Transfer';
      case 'ZWG_BANK':
        return 'ZWG Bank Transfer';
      default:
        return transferType;
    }
  }

  bool get isExpired {
    // Queued transfers expire after 24 hours
    if (!isSynced) {
      return DateTime.now().difference(createdAt).inHours > 24;
    }
    // Synced transfers disappear after 7 days
    return syncedAt != null && DateTime.now().difference(syncedAt!).inDays > 7;
  }

  bool get canBeDeleted {
    return !isSynced && !isExpired;
  }

  Transfer copyWith({
    int? id,
    double? amount,
    DateTime? transferDate,
    String? narration,
    int? sendingBranchId,
    String? sendingBranch,
    int? receivingBranchId,
    String? receivingBranch,
    String? transferType,
    bool? isSynced,
    DateTime? syncedAt,
    DateTime? createdAt,
  }) {
    return Transfer(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      transferDate: transferDate ?? this.transferDate,
      narration: narration ?? this.narration,
      sendingBranchId: sendingBranchId ?? this.sendingBranchId,
      sendingBranch: sendingBranch ?? this.sendingBranch,
      receivingBranchId: receivingBranchId ?? this.receivingBranchId,
      receivingBranch: receivingBranch ?? this.receivingBranch,
      transferType: transferType ?? this.transferType,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Transfer{id: $id, amount: $amount, sendingBranch: $sendingBranch, receivingBranch: $receivingBranch, transferType: $transferType, isSynced: $isSynced}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transfer &&
        other.id == id &&
        other.amount == amount &&
        other.sendingBranchId == sendingBranchId &&
        other.receivingBranchId == receivingBranchId &&
        other.transferType == transferType;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        amount.hashCode ^
        sendingBranchId.hashCode ^
        receivingBranchId.hashCode ^
        transferType.hashCode;
  }
}