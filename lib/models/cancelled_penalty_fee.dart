import 'package:intl/intl.dart';

class CancelledPenaltyFee {
  final String branch;
  final String receiptNumber;
  final String clientName;
  final double amount;
  final DateTime dateOfPayment;
  final String cancelledBy;
  final String reason;
  final DateTime cancelledAt;
  final int cancellationId;

  CancelledPenaltyFee({
    required this.branch,
    required this.receiptNumber,
    required this.clientName,
    required this.amount,
    required this.dateOfPayment,
    required this.cancelledBy,
    required this.reason,
    required this.cancelledAt,
    required this.cancellationId,
  });

  // Create from API JSON response
  factory CancelledPenaltyFee.fromJson(Map<String, dynamic> json) {
    final cancelledDetails = json['cancelledDetails'] ?? {};

    return CancelledPenaltyFee(
      branch: cancelledDetails['Branch'] ?? json['branch'] ?? '',
      receiptNumber:
          cancelledDetails['ReceiptNumber'] ?? json['receiptNumber'] ?? '',
      clientName: cancelledDetails['ClientName'] ?? json['clientName'] ?? '',
      amount: (cancelledDetails['Amount'] ?? json['amount'] ?? 0.0).toDouble(),
      dateOfPayment: DateTime.parse(
        cancelledDetails['DateOfPayment'] ??
            json['dateOfPayment'] ??
            DateTime.now().toIso8601String(),
      ),
      cancelledBy: cancelledDetails['CancelledBy'] ?? json['cancelledBy'] ?? '',
      reason: cancelledDetails['Reason'] ?? json['reason'] ?? '',
      cancelledAt: DateTime.parse(
        json['cancelledAt'] ?? DateTime.now().toIso8601String(),
      ),
      cancellationId: json['cancellationId'] ?? 0,
    );
  }

  // Create from database map
  factory CancelledPenaltyFee.fromMap(Map<String, dynamic> map) {
    return CancelledPenaltyFee(
      branch: map['branch'] ?? '',
      receiptNumber: map['receiptNumber'] ?? '',
      clientName: map['clientName'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      dateOfPayment: DateTime.parse(map['dateOfPayment']),
      cancelledBy: map['cancelledBy'] ?? '',
      reason: map['reason'] ?? '',
      cancelledAt: DateTime.parse(map['cancelledAt']),
      cancellationId: map['cancellationId'] ?? 0,
    );
  }

  // Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'branch': branch,
      'receiptNumber': receiptNumber,
      'clientName': clientName,
      'amount': amount,
      'dateOfPayment': dateOfPayment.toIso8601String(),
      'cancelledBy': cancelledBy,
      'reason': reason,
      'cancelledAt': cancelledAt.toIso8601String(),
      'cancellationId': cancellationId,
    };
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'branch': branch,
      'receiptNumber': receiptNumber,
      'clientName': clientName,
      'amount': amount,
      'dateOfPayment': dateOfPayment.toIso8601String(),
      'cancelledBy': cancelledBy,
      'reason': reason,
      'cancelledAt': cancelledAt.toIso8601String(),
      'cancellationId': cancellationId,
    };
  }

  // Formatted amount
  String get formattedAmount {
    final formatter = NumberFormat.currency(symbol: '\$');
    return formatter.format(amount);
  }

  // Formatted payment date
  String get formattedPaymentDate {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateOfPayment);
  }

  // Formatted cancellation date
  String get formattedCancellationDate {
    return DateFormat('dd/MM/yyyy HH:mm').format(cancelledAt);
  }

  @override
  String toString() {
    return 'CancelledPenaltyFee{receiptNumber: $receiptNumber, clientName: $clientName, amount: $formattedAmount, reason: $reason}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CancelledPenaltyFee &&
        other.receiptNumber == receiptNumber &&
        other.cancellationId == cancellationId;
  }

  @override
  int get hashCode => receiptNumber.hashCode ^ cancellationId.hashCode;
}
