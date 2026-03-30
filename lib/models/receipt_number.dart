import 'package:intl/intl.dart';

/// Model for receipt numbers from the API endpoint
class ReceiptNumber {
  final int id;
  final String receiptNum;
  final int? allocatedToUserId;
  final String? allocatedToFirstName;
  final String? allocatedToLastName;
  final String? allocatedToBranch;
  final String? branchAbbreviation;
  final DateTime? allocatedAt;
  final bool isUsed;
  final DateTime? usedAt;
  final String? usedByClientId;
  final String? usedByClientName;
  final double? usedAmount;
  final String? currency;
  final DateTime createdAt;

  ReceiptNumber({
    required this.id,
    required this.receiptNum,
    this.allocatedToUserId,
    this.allocatedToFirstName,
    this.allocatedToLastName,
    this.allocatedToBranch,
    this.branchAbbreviation,
    this.allocatedAt,
    this.isUsed = false,
    this.usedAt,
    this.usedByClientId,
    this.usedByClientName,
    this.usedAmount,
    this.currency,
    required this.createdAt,
  });

  /// Create from API response JSON
  factory ReceiptNumber.fromApiJson(Map<String, dynamic> json) {
    return ReceiptNumber(
      id: json['Id'] ?? 0,
      receiptNum: json['ReceiptNum'] ?? '',
      allocatedToUserId: json['AllocatedToUserId'],
      allocatedToFirstName: json['AllocatedToFirstName'],
      allocatedToLastName: json['AllocatedToLastName'],
      allocatedToBranch: json['AllocatedToBranch'],
      branchAbbreviation: json['BranchAbbreviation'],
      allocatedAt: json['AllocatedAt'] != null 
          ? DateTime.tryParse(json['AllocatedAt']) 
          : null,
      createdAt: DateTime.now(),
    );
  }

  /// Create from database map
  factory ReceiptNumber.fromMap(Map<String, dynamic> map) {
    return ReceiptNumber(
      id: map['id'] ?? 0,
      receiptNum: map['receiptNum'] ?? '',
      allocatedToUserId: map['allocatedToUserId'],
      allocatedToFirstName: map['allocatedToFirstName'],
      allocatedToLastName: map['allocatedToLastName'],
      allocatedToBranch: map['allocatedToBranch'],
      branchAbbreviation: map['branchAbbreviation'],
      allocatedAt: map['allocatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['allocatedAt'])
          : null,
      isUsed: map['isUsed'] == 1,
      usedAt: map['usedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['usedAt'])
          : null,
      usedByClientId: map['usedByClientId'],
      usedByClientName: map['usedByClientName'],
      usedAmount: map['usedAmount'],
      currency: map['currency'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receiptNum': receiptNum,
      'allocatedToUserId': allocatedToUserId,
      'allocatedToFirstName': allocatedToFirstName,
      'allocatedToLastName': allocatedToLastName,
      'allocatedToBranch': allocatedToBranch,
      'branchAbbreviation': branchAbbreviation,
      'allocatedAt': allocatedAt?.millisecondsSinceEpoch,
      'isUsed': isUsed ? 1 : 0,
      'usedAt': usedAt?.millisecondsSinceEpoch,
      'usedByClientId': usedByClientId,
      'usedByClientName': usedByClientName,
      'usedAmount': usedAmount,
      'currency': currency,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Mark as used with repayment details
  ReceiptNumber markAsUsed({
    required String clientId,
    required String clientName,
    required double amount,
    required String currency,
  }) {
    return ReceiptNumber(
      id: id,
      receiptNum: receiptNum,
      allocatedToUserId: allocatedToUserId,
      allocatedToFirstName: allocatedToFirstName,
      allocatedToLastName: allocatedToLastName,
      allocatedToBranch: allocatedToBranch,
      branchAbbreviation: branchAbbreviation,
      allocatedAt: allocatedAt,
      isUsed: true,
      usedAt: DateTime.now(),
      usedByClientId: clientId,
      usedByClientName: clientName,
      usedAmount: amount,
      currency: currency,
      createdAt: createdAt,
    );
  }

  /// Get status text
  String get statusText => isUsed ? 'Used' : 'Available';

  /// Get formatted allocated date
  String get formattedAllocatedDate {
    return allocatedAt != null
        ? DateFormat('dd MMM yyyy HH:mm').format(allocatedAt!)
        : 'Not allocated';
  }

  /// Get formatted used date
  String get formattedUsedDate {
    return usedAt != null
        ? DateFormat('dd MMM yyyy HH:mm').format(usedAt!)
        : 'Not used';
  }

  /// Get formatted amount if used
  String get formattedUsedAmount {
    if (usedAmount == null || currency == null) return 'N/A';
    
    final currencyFormat = NumberFormat.currency(
      symbol: currency == 'USD' ? '\$' : 'ZWG',
      decimalDigits: 2,
    );
    return currencyFormat.format(usedAmount!);
  }

  /// Get full allocated name
  String get allocatedToFullName {
    if (allocatedToFirstName == null && allocatedToLastName == null) {
      return 'N/A';
    }
    return '${allocatedToFirstName ?? ''} ${allocatedToLastName ?? ''}'.trim();
  }

  @override
  String toString() {
    return 'ReceiptNumber{id: $id, receiptNum: $receiptNum, isUsed: $isUsed}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptNumber &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Result object for receipt number sync operations
class ReceiptNumberSyncResult {
  final bool success;
  final String message;
  final int newReceiptNumbers;
  final int totalReceiptNumbers;
  final List<ReceiptNumber>? receiptNumbers;

  ReceiptNumberSyncResult({
    required this.success,
    required this.message,
    required this.newReceiptNumbers,
    required this.totalReceiptNumbers,
    this.receiptNumbers,
  });

  @override
  String toString() {
    return 'ReceiptNumberSyncResult{success: $success, message: $message, '
        'new: $newReceiptNumbers, total: $totalReceiptNumbers}';
  }
}