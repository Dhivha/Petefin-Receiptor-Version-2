import 'package:intl/intl.dart';

/// Model for cancelled repayments
class CancelledRepayment {
  final int? id;
  final String clientId;
  final double amount;
  final String receiptNumber;
  final DateTime dateOfPayment;
  final String reason;
  final String branch;
  final String cancelledBy;
  final DateTime dateTimeCancelled;
  final String? firstName;
  final String? lastName;
  final String? whatsAppContact;
  final String currency;

  CancelledRepayment({
    this.id,
    required this.clientId,
    required this.amount,
    required this.receiptNumber,
    required this.dateOfPayment,
    required this.reason,
    required this.branch,
    required this.cancelledBy,
    required this.dateTimeCancelled,
    this.firstName,
    this.lastName,
    this.whatsAppContact,
    required this.currency,
  });

  /// Create from API response JSON
  factory CancelledRepayment.fromJson(Map<String, dynamic> json) {
    return CancelledRepayment(
      id: json['id'] ?? json['Id'],
      clientId: json['clientId'] ?? json['ClientId'] ?? '',
      amount: (json['amount'] ?? json['Amount'] ?? 0.0).toDouble(),
      receiptNumber: json['receiptNumber'] ?? json['ReceiptNumber'] ?? '',
      dateOfPayment: json['dateOfPayment'] != null
          ? DateTime.parse(json['dateOfPayment'])
          : json['DateOfPayment'] != null
          ? DateTime.parse(json['DateOfPayment'])
          : DateTime.now(),
      reason: json['reason'] ?? json['Reason'] ?? '',
      branch: json['branch'] ?? json['Branch'] ?? '',
      cancelledBy: json['cancelledBy'] ?? json['CancelledBy'] ?? '',
      dateTimeCancelled: json['dateTimeCancelled'] != null
          ? DateTime.parse(json['dateTimeCancelled'])
          : json['DateTimeCancelled'] != null
          ? DateTime.parse(json['DateTimeCancelled'])
          : DateTime.now(),
      firstName: json['firstName'] ?? json['FirstName'],
      lastName: json['lastName'] ?? json['LastName'],
      whatsAppContact: json['whatsAppContact'] ?? json['WhatsAppContact'],
      currency: json['currency'] ?? json['Currency'] ?? 'USD',
    );
  }

  /// Convert to API request JSON
  Map<String, dynamic> toJson() {
    return {
      'ClientId': clientId,
      'Amount': amount,
      'ReceiptNumber': receiptNumber,
      'DateOfPayment': dateOfPayment.toIso8601String(),
      'Reason': reason,
      'Branch': branch,
      'CancelledBy': cancelledBy,
    };
  }

  /// Get full client name
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return 'Unknown Client';
  }

  /// Get formatted amount with currency symbol
  String get formattedAmount {
    final currencyFormat = NumberFormat.currency(
      symbol: currency == 'USD' ? '\$' : 'ZWG',
      decimalDigits: 2,
    );
    return currencyFormat.format(amount);
  }

  /// Get formatted payment date
  String get formattedPaymentDate {
    return DateFormat('dd MMM yyyy').format(dateOfPayment);
  }

  /// Get formatted cancellation date
  String get formattedCancellationDate {
    return DateFormat('dd MMM yyyy HH:mm').format(dateTimeCancelled);
  }

  /// Get currency symbol
  String get currencySymbol {
    return currency == 'USD' ? '\$' : 'ZWG';
  }

  @override
  String toString() {
    return 'CancelledRepayment{id: $id, clientId: $clientId, receiptNumber: $receiptNumber, '
        'amount: $amount, currency: $currency, reason: $reason}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CancelledRepayment &&
          runtimeType == other.runtimeType &&
          receiptNumber == other.receiptNumber;

  @override
  int get hashCode => receiptNumber.hashCode;
}

/// Result object for cancellation operations
class CancellationResult {
  final bool success;
  final String message;
  final int? cancellationId;
  final CancelledRepayment? cancelledRepayment;
  final String? smsNotification;

  CancellationResult({
    required this.success,
    required this.message,
    this.cancellationId,
    this.cancelledRepayment,
    this.smsNotification,
  });

  factory CancellationResult.fromJson(Map<String, dynamic> json) {
    return CancellationResult(
      success: json['status'] == 200,
      message: json['message'] ?? 'Unknown response',
      cancellationId: json['cancellationId'],
      smsNotification: json['smsNotification'],
    );
  }

  @override
  String toString() {
    return 'CancellationResult{success: $success, message: $message, id: $cancellationId}';
  }
}
