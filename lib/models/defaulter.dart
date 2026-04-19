class DefaultClient {
  final int loanId;
  final String clientId;
  final String clientName;
  final String clientContact;
  final double loanAmount;
  final double weeklyPayment;
  final int loanTenure;
  final double expectedAmountByTargetDate;
  final double totalPaidAmount;
  final double defaultAmount;
  final int paymentsExpectedCount;
  final String conditionalDisbursement;
  final int gracePeriodDays;

  DefaultClient({
    required this.loanId,
    required this.clientId,
    required this.clientName,
    required this.clientContact,
    required this.loanAmount,
    required this.weeklyPayment,
    required this.loanTenure,
    required this.expectedAmountByTargetDate,
    required this.totalPaidAmount,
    required this.defaultAmount,
    required this.paymentsExpectedCount,
    required this.conditionalDisbursement,
    required this.gracePeriodDays,
  });

  factory DefaultClient.fromJson(Map<String, dynamic> json) {
    return DefaultClient(
      loanId: json['LoanId'] ?? 0,
      clientId: json['ClientId']?.toString() ?? '',
      clientName: json['ClientName']?.toString() ?? '',
      clientContact: json['ClientContact']?.toString() ?? '',
      loanAmount: (json['LoanAmount'] ?? 0).toDouble(),
      weeklyPayment: (json['WeeklyPayment'] ?? 0).toDouble(),
      loanTenure: json['LoanTenure'] ?? 0,
      expectedAmountByTargetDate: (json['ExpectedAmountByTargetDate'] ?? 0).toDouble(),
      totalPaidAmount: (json['TotalPaidAmount'] ?? 0).toDouble(),
      defaultAmount: (json['DefaultAmount'] ?? 0).toDouble(),
      paymentsExpectedCount: json['PaymentsExpectedCount'] ?? 0,
      conditionalDisbursement: json['ConditionalDisbursement'] ?? '',
      gracePeriodDays: json['GracePeriodDays'] ?? 0,
    );
  }
}

class DefaultDetails {
  final String branchName;
  final String targetDate;
  final double totalDefaultAmount;
  final int numberOfClientsInDefault;
  final List<DefaultClient> clientsInDefault;

  DefaultDetails({
    required this.branchName,
    required this.targetDate,
    required this.totalDefaultAmount,
    required this.numberOfClientsInDefault,
    required this.clientsInDefault,
  });

  factory DefaultDetails.fromJson(Map<String, dynamic> json) {
    final clients = (json['ClientsInDefault'] as List<dynamic>? ?? [])
        .map((e) => DefaultClient.fromJson(e as Map<String, dynamic>))
        .toList();
    return DefaultDetails(
      branchName: json['BranchName'] ?? '',
      targetDate: json['TargetDate'] ?? '',
      totalDefaultAmount: (json['TotalDefaultAmount'] ?? 0).toDouble(),
      numberOfClientsInDefault: json['NumberOfClientsInDefault'] ?? 0,
      clientsInDefault: clients,
    );
  }
}
