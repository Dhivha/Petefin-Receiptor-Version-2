class AdminFee {
  final String? id;
  final String firstName;
  final String lastName;
  final DateTime dateTimeCaptured;
  final double amount;
  final String receiptNumber;
  final String barcode;
  final String? branch;
  final bool isSynced;

  AdminFee({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.dateTimeCaptured,
    required this.amount,
    required this.receiptNumber,
    required this.barcode,
    this.branch,
    this.isSynced = false,
  });

  String get fullName => '$firstName $lastName';
  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';

  factory AdminFee.fromJson(Map<String, dynamic> json) {
    return AdminFee(
      id: json['id']?.toString(),
      firstName: json['FirstName'] ?? '',
      lastName: json['LastName'] ?? '',
      dateTimeCaptured: json['DateTimeCaptured'] != null 
          ? DateTime.parse(json['DateTimeCaptured'])
          : DateTime.now(),
      amount: (json['Amount'] ?? 0.0).toDouble(),
      receiptNumber: json['ReceiptNumber'] ?? '',
      barcode: json['Barcode'] ?? '',
      branch: json['Branch'],
      isSynced: json['isSynced'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'FirstName': firstName,
      'LastName': lastName,
      'DateTimeCaptured': dateTimeCaptured.toIso8601String(),
      'Amount': amount,
      'ReceiptNumber': receiptNumber,
      'Barcode': barcode,
      'Branch': branch,
      'isSynced': isSynced,
    };
  }

  AdminFee copyWith({
    String? id,
    String? firstName,
    String? lastName,
    DateTime? dateTimeCaptured,
    double? amount,
    String? receiptNumber,
    String? barcode,
    String? branch,
    bool? isSynced,
  }) {
    return AdminFee(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateTimeCaptured: dateTimeCaptured ?? this.dateTimeCaptured,
      amount: amount ?? this.amount,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      barcode: barcode ?? this.barcode,
      branch: branch ?? this.branch,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

class CancelledAdminFee {
  final String? id;
  final String branch;
  final double amount;
  final DateTime dateOfPayment;
  final String receiptNumber;
  final String cancelledBy;
  final String reason;
  final DateTime? dateTimeCancelled;

  CancelledAdminFee({
    this.id,
    required this.branch,
    required this.amount,
    required this.dateOfPayment,
    required this.receiptNumber,
    required this.cancelledBy,
    required this.reason,
    this.dateTimeCancelled,
  });

  factory CancelledAdminFee.fromJson(Map<String, dynamic> json) {
    return CancelledAdminFee(
      id: json['Id']?.toString(),
      branch: json['Branch'] ?? '',
      amount: (json['Amount'] ?? 0.0).toDouble(),
      dateOfPayment: json['DateOfPayment'] != null
          ? DateTime.parse(json['DateOfPayment'])
          : DateTime.now(),
      receiptNumber: json['ReceiptNumber'] ?? '',
      cancelledBy: json['CancelledBy'] ?? '',
      reason: json['Reason'] ?? '',
      dateTimeCancelled: json['DateTimeCancelled'] != null
          ? DateTime.parse(json['DateTimeCancelled'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Branch': branch,
      'Amount': amount,
      'DateOfPayment': dateOfPayment.toIso8601String(),
      'ReceiptNumber': receiptNumber,
      'CancelledBy': cancelledBy,
      'Reason': reason,
    };
  }
}