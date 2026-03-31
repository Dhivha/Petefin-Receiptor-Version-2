enum ExpenseCategory {
  EcoCashCharges,
  OperatingLicense,
  RentAndRates,
  OfficeRepairsAndMaintenance,
  ComputerAccessories,
  ElectricalGadgets,
  Marketing,
  FuelAndTollgates,
  CollectionBagUmbrellaSunhats,
  SettlementAllowance,
  Accommodation,
  TransportAndSubsistence,
  LegalFees,
  MotorVehicleRepairs,
  LocalTransport,
  LunchAndTeas,
  MainCashPrintingAndStationery,
  PettyPrintingAndStationery,
  AirtimeAndWiFiBundles,
  CleaningAndToiletries,
  TransfeToMainCash,
  Miscellaneous,
}

class Expense {
  final int? id;
  final String branchName;
  final String category;
  final double amount;
  final DateTime expenseDate;
  final bool isSynced;
  final DateTime? syncedAt;
  final DateTime createdAt;

  Expense({
    this.id,
    required this.branchName,
    required this.category,
    required this.amount,
    required this.expenseDate,
    this.isSynced = false,
    this.syncedAt,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['Id'],
      branchName: json['BranchName'] ?? '',
      category: json['Category'] ?? '',
      amount: (json['Amount'] ?? 0.0).toDouble(),
      expenseDate: DateTime.parse(json['ExpenseDate']),
      isSynced: json['IsSynced'] ?? false,
      syncedAt: json['SyncedAt'] != null
          ? DateTime.parse(json['SyncedAt'])
          : null,
      createdAt: json['CreatedAt'] != null
          ? DateTime.parse(json['CreatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    // Zero out time portion - backend only cares about the date
    final dateOnly = DateTime.utc(expenseDate.year, expenseDate.month, expenseDate.day);
    return {
      'BranchName': branchName,
      'Category': category,
      'Amount': amount,
      'ExpenseDate': dateOnly.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchName': branchName,
      'category': category,
      'amount': amount,
      'expenseDate': expenseDate.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
      'syncedAt': syncedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      branchName: map['branchName'] ?? '',
      category: map['category'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      expenseDate: DateTime.parse(map['expenseDate']),
      isSynced: (map['isSynced'] ?? 0) == 1,
      syncedAt: map['syncedAt'] != null
          ? DateTime.parse(map['syncedAt'])
          : null,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  String get formattedAmount {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String get formattedDate {
    return '${expenseDate.day}/${expenseDate.month}/${expenseDate.year}';
  }

  String get categoryDisplayName {
    return category
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (Match match) => ' ${match.group(0)}',
        )
        .trim();
  }

  bool get isExpired {
    // Synced expenses disappear after 7 days
    return isSynced &&
        syncedAt != null &&
        DateTime.now().difference(syncedAt!).inDays > 7;
  }

  bool get canBeDeleted {
    return !isSynced;
  }

  // Check if this expense is similar to another (for duplicate warning)
  bool isSimilarTo(Expense other) {
    return branchName == other.branchName &&
        category == other.category &&
        amount == other.amount &&
        expenseDate.year == other.expenseDate.year &&
        expenseDate.month == other.expenseDate.month &&
        expenseDate.day == other.expenseDate.day;
  }

  Expense copyWith({
    int? id,
    String? branchName,
    String? category,
    double? amount,
    DateTime? expenseDate,
    bool? isSynced,
    DateTime? syncedAt,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      branchName: branchName ?? this.branchName,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Expense{id: $id, branchName: $branchName, category: $category, amount: $amount, expenseDate: $expenseDate, isSynced: $isSynced}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Expense &&
        other.id == id &&
        other.branchName == branchName &&
        other.category == category &&
        other.amount == amount &&
        other.expenseDate == expenseDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        branchName.hashCode ^
        category.hashCode ^
        amount.hashCode ^
        expenseDate.hashCode;
  }
}

// Helper class for expense categories
class ExpenseCategoryHelper {
  static const List<String> categories = [
    'EcoCashCharges',
    'OperatingLicense',
    'RentAndRates',
    'OfficeRepairsAndMaintenance',
    'ComputerAccessories',
    'ElectricalGadgets',
    'Marketing',
    'FuelAndTollgates',
    'CollectionBagUmbrellaSunhats',
    'SettlementAllowance',
    'Accommodation',
    'TransportAndSubsistence',
    'LegalFees',
    'MotorVehicleRepairs',
    'LocalTransport',
    'LunchAndTeas',
    'MainCashPrintingAndStationery',
    'PettyPrintingAndStationery',
    'AirtimeAndWiFiBundles',
    'CleaningAndToiletries',
    'TransfeToMainCash',
    'Miscellaneous',
  ];

  static const Map<String, String> categoryDisplayNames = {
    'EcoCashCharges': 'EcoCash Charges',
    'OperatingLicense': 'Operating License',
    'RentAndRates': 'Rent And Rates',
    'OfficeRepairsAndMaintenance': 'Office Repairs And Maintenance',
    'ComputerAccessories': 'Computer Accessories',
    'ElectricalGadgets': 'Electrical Gadgets',
    'Marketing': 'Marketing',
    'FuelAndTollgates': 'Fuel And Tollgates',
    'CollectionBagUmbrellaSunhats': 'Collection Bag Umbrella Sunhats',
    'SettlementAllowance': 'Settlement Allowance',
    'Accommodation': 'Accommodation',
    'TransportAndSubsistence': 'Transport And Subsistence',
    'LegalFees': 'Legal Fees',
    'MotorVehicleRepairs': 'Motor Vehicle Repairs',
    'LocalTransport': 'Local Transport',
    'LunchAndTeas': 'Lunch And Teas',
    'MainCashPrintingAndStationery': 'Main Cash Printing And Stationery',
    'PettyPrintingAndStationery': 'Petty Printing And Stationery',
    'AirtimeAndWiFiBundles': 'Airtime And WiFi Bundles',
    'CleaningAndToiletries': 'Cleaning And Toiletries',
    'TransfeToMainCash': 'Transfer To Main Cash',
    'Miscellaneous': 'Miscellaneous',
  };

  static String getDisplayName(String category) {
    return categoryDisplayNames[category] ?? category;
  }
}
