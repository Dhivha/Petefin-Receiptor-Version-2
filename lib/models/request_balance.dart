import 'package:intl/intl.dart';

enum RequestBalanceStatus { pending, synced, failed }

class RequestBalance {
  final int? id;
  final String branchName;
  final DateTime cashbookDate;
  final double amount;
  final String reason;
  final RequestBalanceStatus status;
  final DateTime requestedAt;
  final DateTime? syncedAt;
  final String? errorMessage;

  RequestBalance({
    this.id,
    required this.branchName,
    required this.cashbookDate,
    required this.amount,
    required this.reason,
    this.status = RequestBalanceStatus.pending,
    required this.requestedAt,
    this.syncedAt,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchName': branchName,
      'cashbookDate': cashbookDate.toIso8601String(),
      'amount': amount,
      'reason': reason,
      'status': status.toString().split('.').last,
      'requestedAt': requestedAt.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory RequestBalance.fromMap(Map<String, dynamic> map) {
    return RequestBalance(
      id: map['id']?.toInt(),
      branchName: map['branchName'] ?? '',
      cashbookDate: DateTime.parse(map['cashbookDate']),
      amount: map['amount']?.toDouble() ?? 0.0,
      reason: map['reason'] ?? '',
      status: RequestBalanceStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => RequestBalanceStatus.pending,
      ),
      requestedAt: DateTime.parse(map['requestedAt']),
      syncedAt: map['syncedAt'] != null ? DateTime.parse(map['syncedAt']) : null,
      errorMessage: map['errorMessage'],
    );
  }

  // API payload format - EXACT as specified
  Map<String, dynamic> toApiPayload() {
    return {
      'BranchName': branchName,
      'CashbookDate': cashbookDate.toIso8601String(),
      'Amount': amount,
      'Reason': reason,
    };
  }

  String get formattedDate => DateFormat('dd/MM/yyyy').format(cashbookDate);
  String get formattedAmount => 'USD ${amount.toStringAsFixed(2)}';
  String get formattedDateTime => DateFormat('dd/MM/yyyy HH:mm').format(requestedAt);

  RequestBalance copyWith({
    int? id,
    String? branchName,
    DateTime? cashbookDate,
    double? amount,
    String? reason,
    RequestBalanceStatus? status,
    DateTime? requestedAt,
    DateTime? syncedAt,
    String? errorMessage,
  }) {
    return RequestBalance(
      id: id ?? this.id,
      branchName: branchName ?? this.branchName,
      cashbookDate: cashbookDate ?? this.cashbookDate,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class RequestBalanceResult {
  final bool success;
  final String message;
  final RequestBalance? request;

  RequestBalanceResult({
    required this.success,
    required this.message,
    this.request,
  });
}