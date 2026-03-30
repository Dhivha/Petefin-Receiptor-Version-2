class Disbursement {
  final int id;
  final String clientId;
  final int branchId;
  final double amount;
  final int tenure;
  final double interest;
  final double totalAmount;
  final String? productName;
  final DateTime? nextPaymentDate;
  final double weeklyPayment;
  final int fcb;
  final double adminFees;
  final String? collateralImage;
  final String? conditionalDisbursement;
  final int gracePeriodDays;
  final String? collateralVideo;
  final DateTime dateOfDisbursement;
  final String? description;
  final String branch;
  final String clientName;
  final DateTime? firstPayment;
  final DateTime? secondPayment;
  final DateTime? thirdPayment;
  final DateTime? fourthPayment;
  final DateTime? fifthPayment;
  final DateTime? sixthPayment;
  final DateTime? seventhPayment;
  final DateTime? eighthPayment;
  final DateTime? ninthPayment;
  final DateTime? tenthPayment;
  final DateTime? eleventhPayment;
  final DateTime? twelfthPayment;
  final DateTime? thirteenthPayment;

  Disbursement({
    required this.id,
    required this.clientId,
    required this.branchId,
    required this.amount,
    required this.tenure,
    required this.interest,
    required this.totalAmount,
    this.productName,
    this.nextPaymentDate,
    required this.weeklyPayment,
    required this.fcb,
    required this.adminFees,
    this.collateralImage,
    this.conditionalDisbursement,
    required this.gracePeriodDays,
    this.collateralVideo,
    required this.dateOfDisbursement,
    this.description,
    required this.branch,
    required this.clientName,
    this.firstPayment,
    this.secondPayment,
    this.thirdPayment,
    this.fourthPayment,
    this.fifthPayment,
    this.sixthPayment,
    this.seventhPayment,
    this.eighthPayment,
    this.ninthPayment,
    this.tenthPayment,
    this.eleventhPayment,
    this.twelfthPayment,
    this.thirteenthPayment,
  });

  factory Disbursement.fromJson(Map<String, dynamic> json) {
    return Disbursement(
      id: json['Id'] ?? 0,
      clientId: json['ClientId'] ?? '',
      branchId: json['BranchId'] ?? 0,
      amount: (json['Amount'] ?? 0).toDouble(),
      tenure: json['Tenure'] ?? 0,
      interest: (json['Interest'] ?? 0).toDouble(),
      totalAmount: (json['TotalAmount'] ?? 0).toDouble(),
      productName: json['ProductName'],
      nextPaymentDate: json['NextPaymentDate'] != null && json['NextPaymentDate'] != "0001-01-01T00:00:00"
          ? DateTime.parse(json['NextPaymentDate'])
          : null,
      weeklyPayment: (json['WeeklyPayment'] ?? 0).toDouble(),
      fcb: json['FCB'] ?? 0,
      adminFees: (json['AdminFees'] ?? 0).toDouble(),
      collateralImage: json['CollateralImage'],
      conditionalDisbursement: json['ConditionalDisbursement'],
      gracePeriodDays: json['GracePeriodDays'] ?? 0,
      collateralVideo: json['CollateralVideo'],
      dateOfDisbursement: DateTime.parse(json['DateOfDisbursement']),
      description: json['Description'],
      branch: json['Branch'] ?? '',
      clientName: json['ClientName'] ?? '',
      firstPayment: json['FirstPayment'] != null ? DateTime.parse(json['FirstPayment']) : null,
      secondPayment: json['SecondPayment'] != null ? DateTime.parse(json['SecondPayment']) : null,
      thirdPayment: json['ThirdPayment'] != null ? DateTime.parse(json['ThirdPayment']) : null,
      fourthPayment: json['FourthPayment'] != null ? DateTime.parse(json['FourthPayment']) : null,
      fifthPayment: json['FifthPayment'] != null ? DateTime.parse(json['FifthPayment']) : null,
      sixthPayment: json['SixthPayment'] != null ? DateTime.parse(json['SixthPayment']) : null,
      seventhPayment: json['SeventhPayment'] != null ? DateTime.parse(json['SeventhPayment']) : null,
      eighthPayment: json['EighthPayment'] != null ? DateTime.parse(json['EighthPayment']) : null,
      ninthPayment: json['NinthPayment'] != null ? DateTime.parse(json['NinthPayment']) : null,
      tenthPayment: json['TenthPayment'] != null ? DateTime.parse(json['TenthPayment']) : null,
      eleventhPayment: json['EleventhPayment'] != null ? DateTime.parse(json['EleventhPayment']) : null,
      twelfthPayment: json['TwelfthPayment'] != null ? DateTime.parse(json['TwelfthPayment']) : null,
      thirteenthPayment: json['ThirteenthPayment'] != null ? DateTime.parse(json['ThirteenthPayment']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'branchId': branchId,
      'amount': amount,
      'tenure': tenure,
      'interest': interest,
      'totalAmount': totalAmount,
      'productName': productName,
      'nextPaymentDate': nextPaymentDate?.toIso8601String(),
      'weeklyPayment': weeklyPayment,
      'fcb': fcb,
      'adminFees': adminFees,
      'collateralImage': collateralImage,
      'conditionalDisbursement': conditionalDisbursement,
      'gracePeriodDays': gracePeriodDays,
      'collateralVideo': collateralVideo,
      'dateOfDisbursement': dateOfDisbursement.toIso8601String(),
      'description': description,
      'branch': branch,
      'clientName': clientName,
      'firstPayment': firstPayment?.toIso8601String(),
      'secondPayment': secondPayment?.toIso8601String(),
      'thirdPayment': thirdPayment?.toIso8601String(),
      'fourthPayment': fourthPayment?.toIso8601String(),
      'fifthPayment': fifthPayment?.toIso8601String(),
      'sixthPayment': sixthPayment?.toIso8601String(),
      'seventhPayment': seventhPayment?.toIso8601String(),
      'eighthPayment': eighthPayment?.toIso8601String(),
      'ninthPayment': ninthPayment?.toIso8601String(),
      'tenthPayment': tenthPayment?.toIso8601String(),
      'eleventhPayment': eleventhPayment?.toIso8601String(),
      'twelfthPayment': twelfthPayment?.toIso8601String(),
      'thirteenthPayment': thirteenthPayment?.toIso8601String(),
    };
  }

  factory Disbursement.fromMap(Map<String, dynamic> map) {
    return Disbursement(
      id: map['id'] ?? 0,
      clientId: map['clientId'] ?? '',
      branchId: map['branchId'] ?? 0,
      amount: (map['amount'] ?? 0).toDouble(),
      tenure: map['tenure'] ?? 0,
      interest: (map['interest'] ?? 0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      productName: map['productName'],
      nextPaymentDate: map['nextPaymentDate'] != null 
          ? DateTime.parse(map['nextPaymentDate'])
          : null,
      weeklyPayment: (map['weeklyPayment'] ?? 0).toDouble(),
      fcb: map['fcb'] ?? 0,
      adminFees: (map['adminFees'] ?? 0).toDouble(),
      collateralImage: map['collateralImage'],
      conditionalDisbursement: map['conditionalDisbursement'],
      gracePeriodDays: map['gracePeriodDays'] ?? 0,
      collateralVideo: map['collateralVideo'],
      dateOfDisbursement: DateTime.parse(map['dateOfDisbursement']),
      description: map['description'],
      branch: map['branch'] ?? '',
      clientName: map['clientName'] ?? '',
      firstPayment: map['firstPayment'] != null ? DateTime.parse(map['firstPayment']) : null,
      secondPayment: map['secondPayment'] != null ? DateTime.parse(map['secondPayment']) : null,
      thirdPayment: map['thirdPayment'] != null ? DateTime.parse(map['thirdPayment']) : null,
      fourthPayment: map['fourthPayment'] != null ? DateTime.parse(map['fourthPayment']) : null,
      fifthPayment: map['fifthPayment'] != null ? DateTime.parse(map['fifthPayment']) : null,
      sixthPayment: map['sixthPayment'] != null ? DateTime.parse(map['sixthPayment']) : null,
      seventhPayment: map['seventhPayment'] != null ? DateTime.parse(map['seventhPayment']) : null,
      eighthPayment: map['eighthPayment'] != null ? DateTime.parse(map['eighthPayment']) : null,
      ninthPayment: map['ninthPayment'] != null ? DateTime.parse(map['ninthPayment']) : null,
      tenthPayment: map['tenthPayment'] != null ? DateTime.parse(map['tenthPayment']) : null,
      eleventhPayment: map['eleventhPayment'] != null ? DateTime.parse(map['eleventhPayment']) : null,
      twelfthPayment: map['twelfthPayment'] != null ? DateTime.parse(map['twelfthPayment']) : null,
      thirteenthPayment: map['thirteenthPayment'] != null ? DateTime.parse(map['thirteenthPayment']) : null,
    );
  }

  // Get active payment dates as a list
  List<DateTime> get paymentSchedule {
    List<DateTime> payments = [];
    if (firstPayment != null) payments.add(firstPayment!);
    if (secondPayment != null) payments.add(secondPayment!);
    if (thirdPayment != null) payments.add(thirdPayment!);
    if (fourthPayment != null) payments.add(fourthPayment!);
    if (fifthPayment != null) payments.add(fifthPayment!);
    if (sixthPayment != null) payments.add(sixthPayment!);
    if (seventhPayment != null) payments.add(seventhPayment!);
    if (eighthPayment != null) payments.add(eighthPayment!);
    if (ninthPayment != null) payments.add(ninthPayment!);
    if (tenthPayment != null) payments.add(tenthPayment!);
    if (eleventhPayment != null) payments.add(eleventhPayment!);
    if (twelfthPayment != null) payments.add(twelfthPayment!);
    if (thirteenthPayment != null) payments.add(thirteenthPayment!);
    return payments;
  }

  // Get the next payment date
  DateTime? get nextDuePayment {
    final now = DateTime.now();
    final payments = paymentSchedule;
    
    for (final payment in payments) {
      if (payment.isAfter(now)) {
        return payment;
      }
    }
    return null;
  }

  // Check if disbursement has overdue payments
  bool get hasOverduePayments {
    final now = DateTime.now();
    final payments = paymentSchedule;
    
    return payments.any((payment) => payment.isBefore(now));
  }
}