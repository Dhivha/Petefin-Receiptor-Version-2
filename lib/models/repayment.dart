import 'package:intl/intl.dart';

class Repayment {
  final int? id; // Local database ID
  final int disbursementId;
  final String clientId;
  final double amount;
  final String branch;
  final DateTime dateOfPayment;
  final String paymentNumber;
  final bool force;
  final String receiptNumber;
  final String currency; // 'USD' or 'ZWG'
  final String clientName;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final String? syncResponse;

  Repayment({
    this.id,
    required this.disbursementId,
    required this.clientId,
    required this.amount,
    required this.branch,
    required this.dateOfPayment,
    required this.paymentNumber,
    this.force = true,
    required this.receiptNumber,
    required this.currency,
    required this.clientName,
    this.isSynced = false,
    required this.createdAt,
    this.syncedAt,
    this.syncResponse,
  });

  factory Repayment.fromJson(Map<String, dynamic> json) {
    return Repayment(
      id: json['id'],
      disbursementId: json['DisbursementId'] ?? json['disbursementId'] ?? 0,
      clientId: json['ClientId'] ?? json['clientId'] ?? '',
      amount: (json['Amount'] ?? json['amount'] ?? 0.0).toDouble(),
      branch: json['Branch'] ?? json['branch'] ?? '',
      dateOfPayment: json['DateOfPayment'] != null
          ? DateTime.parse(json['DateOfPayment'])
          : json['dateOfPayment'] != null
          ? DateTime.parse(json['dateOfPayment'])
          : DateTime.now(),
      paymentNumber: json['PaymentNumber'] ?? json['paymentNumber'] ?? '',
      force: json['Force'] ?? json['force'] ?? true,
      receiptNumber: json['ReceiptNumber'] ?? json['receiptNumber'] ?? '',
      currency: json['currency'] ?? 'USD',
      clientName: json['clientName'] ?? '',
      isSynced: json['isSynced'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : DateTime.now(),
      syncedAt: json['syncedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['syncedAt'])
          : null,
      syncResponse: json['syncResponse'],
    );
  }

  factory Repayment.fromMap(Map<String, dynamic> map) {
    return Repayment(
      id: map['id'],
      disbursementId: map['disbursementId'] ?? 0,
      clientId: map['clientId'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      branch: map['branch'] ?? '',
      dateOfPayment: DateTime.fromMillisecondsSinceEpoch(map['dateOfPayment']),
      paymentNumber: map['paymentNumber'] ?? '',
      force: map['force'] == 1,
      receiptNumber: map['receiptNumber'] ?? '',
      currency: map['currency'] ?? 'USD',
      clientName: map['clientName'] ?? '',
      isSynced: map['isSynced'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      syncedAt: map['syncedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['syncedAt'])
          : null,
      syncResponse: map['syncResponse'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DisbursementId': disbursementId,
      'ClientId': clientId,
      'Amount': amount,
      'Branch': branch,
      'DateOfPayment': dateOfPayment.toIso8601String(),
      'PaymentNumber': paymentNumber,
      'Force': force,
      'ReceiptNumber': receiptNumber,
      'Currency': currency, // Added currency field
      'ClientName': clientName, // Added client name
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'disbursementId': disbursementId,
      'clientId': clientId,
      'amount': amount,
      'branch': branch,
      'dateOfPayment': dateOfPayment.millisecondsSinceEpoch,
      'paymentNumber': paymentNumber,
      'force': force ? 1 : 0,
      'receiptNumber': receiptNumber,
      'currency': currency,
      'clientName': clientName,
      'isSynced': isSynced ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'syncedAt': syncedAt?.millisecondsSinceEpoch,
      'syncResponse': syncResponse,
    };
  }

  Repayment copyWith({
    int? id,
    int? disbursementId,
    String? clientId,
    double? amount,
    String? branch,
    DateTime? dateOfPayment,
    String? paymentNumber,
    bool? force,
    String? receiptNumber,
    String? currency,
    String? clientName,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? syncedAt,
    String? syncResponse,
  }) {
    return Repayment(
      id: id ?? this.id,
      disbursementId: disbursementId ?? this.disbursementId,
      clientId: clientId ?? this.clientId,
      amount: amount ?? this.amount,
      branch: branch ?? this.branch,
      dateOfPayment: dateOfPayment ?? this.dateOfPayment,
      paymentNumber: paymentNumber ?? this.paymentNumber,
      force: force ?? this.force,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      currency: currency ?? this.currency,
      clientName: clientName ?? this.clientName,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      syncResponse: syncResponse ?? this.syncResponse,
    );
  }

  /// Generate receipt number: "Petefin" + timestamp to milliseconds
  static String generateReceiptNumber() {
    final now = DateTime.now();
    final formatter =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}'
        '${now.millisecond.toString().padLeft(3, '0')}';
    return 'Petefin$formatter';
  }

  /// Format amount with proper currency symbol
  String get formattedAmount {
    final currencyFormat = NumberFormat.currency(
      symbol: currency == 'USD' ? '\$' : 'ZWG',
      decimalDigits: 2,
    );
    return currencyFormat.format(amount);
  }

  /// Get currency symbol
  String get currencySymbol {
    return currency == 'USD' ? '\$' : 'ZWG';
  }

  /// Check if payment is pending sync
  bool get isPendingSync => !isSynced;

  /// Get sync status text
  String get syncStatusText {
    if (isSynced) {
      return 'Synced';
    } else {
      return 'Pending Sync';
    }
  }

  /// Get formatted date
  String get formattedDate {
    return DateFormat('dd MMM yyyy').format(dateOfPayment);
  }

  /// Get formatted created date
  String get formattedCreatedDate {
    return DateFormat('dd MMM yyyy HH:mm').format(createdAt);
  }

  /// Get formatted synced date
  String get formattedSyncedDate {
    return syncedAt != null
        ? DateFormat('dd MMM yyyy HH:mm').format(syncedAt!)
        : 'Not synced';
  }

  @override
  String toString() {
    return 'Repayment{id: $id, disbursementId: $disbursementId, clientId: $clientId, '
        'amount: $amount, currency: $currency, receiptNumber: $receiptNumber, '
        'isSynced: $isSynced}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Repayment &&
          runtimeType == other.runtimeType &&
          receiptNumber == other.receiptNumber;

  @override
  int get hashCode => receiptNumber.hashCode;
}
