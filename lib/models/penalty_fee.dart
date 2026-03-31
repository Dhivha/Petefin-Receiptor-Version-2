import 'package:intl/intl.dart';

class PenaltyFee {
  final String id;
  final String branch;
  final double amount;
  final String clientName;
  final DateTime dateTimeCaptured;
  final String receiptNumber;
  final bool isSynced;
  final DateTime? syncedAt;
  final String currency;

  PenaltyFee({
    required this.id,
    required this.branch,
    required this.amount,
    required this.clientName,
    required this.dateTimeCaptured,
    required this.receiptNumber,
    this.isSynced = false,
    this.syncedAt,
    this.currency = 'USD',
  });

  // Create from database
  factory PenaltyFee.fromMap(Map<String, dynamic> map) {
    return PenaltyFee(
      id: map['id'] ?? '',
      branch: map['branch'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      clientName: map['clientName'] ?? '',
      dateTimeCaptured: DateTime.parse(map['dateTimeCaptured']),
      receiptNumber: map['receiptNumber'] ?? '',
      isSynced: (map['isSynced'] as int?) == 1,
      syncedAt: map['syncedAt'] != null
          ? DateTime.parse(map['syncedAt'])
          : null,
      currency: map['currency'] ?? 'USD',
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch': branch,
      'amount': amount,
      'clientName': clientName,
      'dateTimeCaptured': dateTimeCaptured.toIso8601String(),
      'receiptNumber': receiptNumber,
      'isSynced': isSynced ? 1 : 0,
      'syncedAt': syncedAt?.toIso8601String(),
      'currency': currency,
    };
  }

  // Convert to API payload
  Map<String, dynamic> toApiJson() {
    return {
      'Branch': branch,
      'Amount': amount,
      'ClientName': clientName,
      'DateTimeCaptured': dateTimeCaptured.toIso8601String(),
    };
  }

  // Create a copy with updated fields
  PenaltyFee copyWith({
    String? id,
    String? branch,
    double? amount,
    String? clientName,
    DateTime? dateTimeCaptured,
    String? receiptNumber,
    bool? isSynced,
    DateTime? syncedAt,
    String? currency,
  }) {
    return PenaltyFee(
      id: id ?? this.id,
      branch: branch ?? this.branch,
      amount: amount ?? this.amount,
      clientName: clientName ?? this.clientName,
      dateTimeCaptured: dateTimeCaptured ?? this.dateTimeCaptured,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      currency: currency ?? this.currency,
    );
  }

  // Mark as synced
  PenaltyFee markAsSynced() {
    return copyWith(isSynced: true, syncedAt: DateTime.now());
  }

  // Formatted amount with currency
  String get formattedAmount {
    final formatter = NumberFormat.currency(
      symbol: currency == 'USD' ? '\$' : 'ZWL ',
    );
    return formatter.format(amount);
  }

  // Formatted date
  String get formattedDate {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTimeCaptured);
  }

  // Formatted synced date
  String get formattedSyncedDate {
    if (syncedAt == null) return 'Not synced';
    return DateFormat('dd/MM/yyyy HH:mm').format(syncedAt!);
  }

  // Status text
  String get status {
    return isSynced ? 'Synced' : 'Pending Sync';
  }

  @override
  String toString() {
    return 'PenaltyFee{id: $id, receiptNumber: $receiptNumber, clientName: $clientName, amount: $formattedAmount, isSynced: $isSynced}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PenaltyFee && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
