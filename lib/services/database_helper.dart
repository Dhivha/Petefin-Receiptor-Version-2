import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/client.dart';
import '../models/disbursement.dart';
import '../models/repayment.dart';
import '../models/receipt_number.dart';
import '../models/penalty_fee.dart';
import '../models/cancelled_penalty_fee.dart';
import '../models/branch.dart';
import '../models/transfer.dart';
import '../models/expense.dart';

class DatabaseHelper {
  static const String _databaseName = "PetefinDb.db";
  static const int _databaseVersion = 8;

  // Table names
  static const String _userTable = 'users';
  static const String _clientTable = 'clients';
  static const String _disbursementTable = 'disbursements';
  static const String _repaymentTable = 'repayments';
  static const String _receiptNumberTable = 'receipt_numbers';
  static const String _penaltyFeeTable = 'penalty_fees';
  static const String _cancelledPenaltyFeeTable = 'cancelled_penalty_fees';
  static const String _allBranchesTable = 'all_branches';
  static const String _transfersTable = 'transfers';
  static const String _expensesTable = 'expenses';

  // Singleton pattern
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._internal();
  
  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE $_userTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        isAuthenticated INTEGER NOT NULL,
        message TEXT NOT NULL,
        initial TEXT NOT NULL,
        lastName TEXT NOT NULL,
        firstName TEXT NOT NULL,
        position TEXT NOT NULL,
        currentUserId INTEGER NOT NULL,
        branch TEXT NOT NULL,
        branchId INTEGER NOT NULL,
        whatsAppContact TEXT NOT NULL UNIQUE,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // Create clients table
    await db.execute('''
      CREATE TABLE $_clientTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clientId TEXT NOT NULL UNIQUE,
        branchId INTEGER,
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        fullName TEXT NOT NULL,
        branch TEXT NOT NULL,
        whatsAppContact TEXT NOT NULL,
        emailAddress TEXT,
        nationalIdNumber TEXT NOT NULL,
        capturedBy TEXT NOT NULL,
        gender TEXT NOT NULL,
        nextOfKinContact TEXT NOT NULL,
        nextOfKinName TEXT NOT NULL,
        relationshipWithNOK TEXT NOT NULL,
        pin TEXT NOT NULL,
        lastSynced INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // Create indexes for faster searches
    await db.execute('CREATE INDEX idx_clients_full_name ON $_clientTable(fullName)');
    await db.execute('CREATE INDEX idx_clients_client_id ON $_clientTable(clientId)');
    await db.execute('CREATE INDEX idx_clients_branch ON $_clientTable(branch)');
    await db.execute('CREATE INDEX idx_clients_whatsapp ON $_clientTable(whatsAppContact)');

    // Create disbursements table
    await db.execute('''
      CREATE TABLE $_disbursementTable (
        id INTEGER PRIMARY KEY,
        clientId TEXT NOT NULL,
        branchId INTEGER NOT NULL,
        amount REAL NOT NULL,
        tenure INTEGER NOT NULL,
        interest REAL NOT NULL,
        totalAmount REAL NOT NULL,
        productName TEXT,
        nextPaymentDate TEXT,
        weeklyPayment REAL NOT NULL,
        fcb INTEGER NOT NULL,
        adminFees REAL NOT NULL,
        collateralImage TEXT,
        conditionalDisbursement TEXT,
        gracePeriodDays INTEGER NOT NULL,
        collateralVideo TEXT,
        dateOfDisbursement TEXT NOT NULL,
        description TEXT,
        branch TEXT NOT NULL,
        clientName TEXT NOT NULL,
        firstPayment TEXT,
        secondPayment TEXT,
        thirdPayment TEXT,
        fourthPayment TEXT,
        fifthPayment TEXT,
        sixthPayment TEXT,
        seventhPayment TEXT,
        eighthPayment TEXT,
        ninthPayment TEXT,
        tenthPayment TEXT,
        eleventhPayment TEXT,
        twelfthPayment TEXT,
        thirteenthPayment TEXT,
        lastSynced INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY (clientId) REFERENCES $_clientTable(clientId)
      )
    ''');

    // Create indexes for disbursements
    await db.execute('CREATE INDEX idx_disbursements_client_id ON $_disbursementTable(clientId)');
    await db.execute('CREATE INDEX idx_disbursements_branch ON $_disbursementTable(branch)');
    await db.execute('CREATE INDEX idx_disbursements_date ON $_disbursementTable(dateOfDisbursement)');

    // Create repayments table
    await db.execute('''
      CREATE TABLE $_repaymentTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        disbursementId INTEGER NOT NULL,
        clientId TEXT NOT NULL,
        amount REAL NOT NULL,
        branch TEXT NOT NULL,
        dateOfPayment INTEGER NOT NULL,
        paymentNumber TEXT NOT NULL,
        force INTEGER NOT NULL DEFAULT 1,
        receiptNumber TEXT NOT NULL UNIQUE,
        currency TEXT NOT NULL,
        clientName TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        syncedAt INTEGER,
        syncResponse TEXT,
        FOREIGN KEY (clientId) REFERENCES $_clientTable(clientId)
      )
    ''');

    // Create indexes for repayments
    await db.execute('CREATE INDEX idx_repayments_client_id ON $_repaymentTable(clientId)');
    await db.execute('CREATE INDEX idx_repayments_disbursement_id ON $_repaymentTable(disbursementId)');
    await db.execute('CREATE INDEX idx_repayments_receipt_number ON $_repaymentTable(receiptNumber)');
    await db.execute('CREATE INDEX idx_repayments_currency ON $_repaymentTable(currency)');
    await db.execute('CREATE INDEX idx_repayments_synced ON $_repaymentTable(isSynced)');
    await db.execute('CREATE INDEX idx_repayments_branch ON $_repaymentTable(branch)');
    await db.execute('CREATE INDEX idx_repayments_date ON $_repaymentTable(dateOfPayment)');

    // Create receipt numbers table
    await db.execute('''
      CREATE TABLE $_receiptNumberTable (
        id INTEGER PRIMARY KEY,
        receiptNum TEXT NOT NULL UNIQUE,
        allocatedToUserId INTEGER,
        allocatedToFirstName TEXT,
        allocatedToLastName TEXT,
        allocatedToBranch TEXT,
        branchAbbreviation TEXT,
        allocatedAt INTEGER,
        isUsed INTEGER NOT NULL DEFAULT 0,
        usedAt INTEGER,
        usedByClientId TEXT,
        usedByClientName TEXT,
        usedAmount REAL,
        currency TEXT,
        createdAt INTEGER NOT NULL
      )
    ''');

    // Create indexes for receipt numbers
    await db.execute('CREATE INDEX idx_receipt_numbers_receipt_num ON $_receiptNumberTable(receiptNum)');
    await db.execute('CREATE INDEX idx_receipt_numbers_is_used ON $_receiptNumberTable(isUsed)');
    await db.execute('CREATE INDEX idx_receipt_numbers_branch ON $_receiptNumberTable(allocatedToBranch)');
    await db.execute('CREATE INDEX idx_receipt_numbers_allocated_user ON $_receiptNumberTable(allocatedToUserId)');
    await db.execute('CREATE INDEX idx_receipt_numbers_used_client ON $_receiptNumberTable(usedByClientId)');

    // Create penalty fees table
    await db.execute('''
      CREATE TABLE $_penaltyFeeTable (
        id TEXT PRIMARY KEY,
        branch TEXT NOT NULL,
        amount REAL NOT NULL,
        clientName TEXT NOT NULL,
        dateTimeCaptured TEXT NOT NULL,
        receiptNumber TEXT NOT NULL UNIQUE,
        isSynced INTEGER NOT NULL DEFAULT 0,
        syncedAt TEXT,
        currency TEXT NOT NULL DEFAULT 'USD',
        createdAt INTEGER NOT NULL
      )
    ''');

    // Create indexes for penalty fees
    await db.execute('CREATE INDEX idx_penalty_fees_branch ON $_penaltyFeeTable(branch)');
    await db.execute('CREATE INDEX idx_penalty_fees_client_name ON $_penaltyFeeTable(clientName)');
    await db.execute('CREATE INDEX idx_penalty_fees_receipt_number ON $_penaltyFeeTable(receiptNumber)');
    await db.execute('CREATE INDEX idx_penalty_fees_synced ON $_penaltyFeeTable(isSynced)');
    await db.execute('CREATE INDEX idx_penalty_fees_date ON $_penaltyFeeTable(dateTimeCaptured)');

    // Create cancelled penalty fees table
    await db.execute('''
      CREATE TABLE $_cancelledPenaltyFeeTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch TEXT NOT NULL,
        receiptNumber TEXT NOT NULL,
        clientName TEXT NOT NULL,
        amount REAL NOT NULL,
        dateOfPayment TEXT NOT NULL,
        cancelledBy TEXT NOT NULL,
        reason TEXT NOT NULL,
        cancelledAt TEXT NOT NULL,
        cancellationId INTEGER NOT NULL
      )
    ''');

    // Create indexes for cancelled penalty fees
    await db.execute('CREATE INDEX idx_cancelled_penalty_fees_branch ON $_cancelledPenaltyFeeTable(branch)');
    await db.execute('CREATE INDEX idx_cancelled_penalty_fees_receipt_number ON $_cancelledPenaltyFeeTable(receiptNumber)');
    await db.execute('CREATE INDEX idx_cancelled_penalty_fees_cancellation_id ON $_cancelledPenaltyFeeTable(cancellationId)');

    // Create all branches table
    await db.execute('''
      CREATE TABLE $_allBranchesTable (
        branchId INTEGER PRIMARY KEY,
        branchName TEXT NOT NULL UNIQUE,
        lastSynced INTEGER NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    // Create indexes for all branches
    await db.execute('CREATE INDEX idx_all_branches_name ON $_allBranchesTable(branchName)');
    await db.execute('CREATE INDEX idx_all_branches_last_synced ON $_allBranchesTable(lastSynced)');

    // Create transfers table
    await db.execute('''
      CREATE TABLE $_transfersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        transferDate TEXT NOT NULL,
        narration TEXT,
        sendingBranchId INTEGER NOT NULL,
        sendingBranch TEXT NOT NULL,
        receivingBranchId INTEGER NOT NULL,
        receivingBranch TEXT NOT NULL,
        transferType TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        syncedAt TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Create indexes for transfers
    await db.execute('CREATE INDEX idx_transfers_sending_branch ON $_transfersTable(sendingBranchId)');
    await db.execute('CREATE INDEX idx_transfers_receiving_branch ON $_transfersTable(receivingBranchId)');
    await db.execute('CREATE INDEX idx_transfers_transfer_type ON $_transfersTable(transferType)');
    await db.execute('CREATE INDEX idx_transfers_synced ON $_transfersTable(isSynced)');
    await db.execute('CREATE INDEX idx_transfers_date ON $_transfersTable(transferDate)');
    await db.execute('CREATE INDEX idx_transfers_created_at ON $_transfersTable(createdAt)');

    // Create expenses table
    await db.execute('''
      CREATE TABLE $_expensesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branchName TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        expenseDate TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        syncedAt TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Create indexes for expenses
    await db.execute('CREATE INDEX idx_expenses_branch_name ON $_expensesTable(branchName)');
    await db.execute('CREATE INDEX idx_expenses_category ON $_expensesTable(category)');
    await db.execute('CREATE INDEX idx_expenses_synced ON $_expensesTable(isSynced)');
    await db.execute('CREATE INDEX idx_expenses_expense_date ON $_expensesTable(expenseDate)');
    await db.execute('CREATE INDEX idx_expenses_created_at ON $_expensesTable(createdAt)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add disbursements table in version 2
      await db.execute('''
        CREATE TABLE $_disbursementTable (
          id INTEGER PRIMARY KEY,
          clientId TEXT NOT NULL,
          branchId INTEGER NOT NULL,
          amount REAL NOT NULL,
          tenure INTEGER NOT NULL,
          interest REAL NOT NULL,
          totalAmount REAL NOT NULL,
          productName TEXT,
          nextPaymentDate TEXT,
          weeklyPayment REAL NOT NULL,
          fcb INTEGER NOT NULL,
          adminFees REAL NOT NULL,
          collateralImage TEXT,
          conditionalDisbursement TEXT,
          gracePeriodDays INTEGER NOT NULL,
          collateralVideo TEXT,
          dateOfDisbursement TEXT NOT NULL,
          description TEXT,
          branch TEXT NOT NULL,
          clientName TEXT NOT NULL,
          firstPayment TEXT,
          secondPayment TEXT,
          thirdPayment TEXT,
          fourthPayment TEXT,
          fifthPayment TEXT,
          sixthPayment TEXT,
          seventhPayment TEXT,
          eighthPayment TEXT,
          ninthPayment TEXT,
          tenthPayment TEXT,
          eleventhPayment TEXT,
          twelfthPayment TEXT,
          thirteenthPayment TEXT,
          lastSynced INTEGER NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY (clientId) REFERENCES $_clientTable(clientId)
        )
      ''');

      // Create indexes for disbursements
      await db.execute('CREATE INDEX idx_disbursements_client_id ON $_disbursementTable(clientId)');
      await db.execute('CREATE INDEX idx_disbursements_branch ON $_disbursementTable(branch)');
      await db.execute('CREATE INDEX idx_disbursements_date ON $_disbursementTable(dateOfDisbursement)');
    }

    if (oldVersion < 3) {
      // Add repayments table in version 3
      await db.execute('''
        CREATE TABLE $_repaymentTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          disbursementId INTEGER NOT NULL,
          clientId TEXT NOT NULL,
          amount REAL NOT NULL,
          branch TEXT NOT NULL,
          dateOfPayment INTEGER NOT NULL,
          paymentNumber TEXT NOT NULL,
          force INTEGER NOT NULL DEFAULT 1,
          receiptNumber TEXT NOT NULL UNIQUE,
          currency TEXT NOT NULL,
          clientName TEXT NOT NULL,
          isSynced INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          syncedAt INTEGER,
          syncResponse TEXT,
          FOREIGN KEY (clientId) REFERENCES $_clientTable(clientId)
        )
      ''');

      // Create indexes for repayments
      await db.execute('CREATE INDEX idx_repayments_client_id ON $_repaymentTable(clientId)');
      await db.execute('CREATE INDEX idx_repayments_disbursement_id ON $_repaymentTable(disbursementId)');
      await db.execute('CREATE INDEX idx_repayments_receipt_number ON $_repaymentTable(receiptNumber)');
      await db.execute('CREATE INDEX idx_repayments_currency ON $_repaymentTable(currency)');
      await db.execute('CREATE INDEX idx_repayments_synced ON $_repaymentTable(isSynced)');
      await db.execute('CREATE INDEX idx_repayments_branch ON $_repaymentTable(branch)');
      await db.execute('CREATE INDEX idx_repayments_date ON $_repaymentTable(dateOfPayment)');
    }

    if (oldVersion < 4) {
      // Add receipt numbers table in version 4
      await db.execute('''
        CREATE TABLE $_receiptNumberTable (
          id INTEGER PRIMARY KEY,
          receiptNum TEXT NOT NULL UNIQUE,
          allocatedToUserId INTEGER,
          allocatedToFirstName TEXT,
          allocatedToLastName TEXT,
          allocatedToBranch TEXT,
          branchAbbreviation TEXT,
          allocatedAt INTEGER,
          isUsed INTEGER NOT NULL DEFAULT 0,
          usedAt INTEGER,
          usedByClientId TEXT,
          usedByClientName TEXT,
          usedAmount REAL,
          currency TEXT,
          createdAt INTEGER NOT NULL
        )
      ''');

      // Create indexes for receipt numbers
      await db.execute('CREATE INDEX idx_receipt_numbers_receipt_num ON $_receiptNumberTable(receiptNum)');
      await db.execute('CREATE INDEX idx_receipt_numbers_is_used ON $_receiptNumberTable(isUsed)');
      await db.execute('CREATE INDEX idx_receipt_numbers_branch ON $_receiptNumberTable(allocatedToBranch)');
      await db.execute('CREATE INDEX idx_receipt_numbers_allocated_user ON $_receiptNumberTable(allocatedToUserId)');
      await db.execute('CREATE INDEX idx_receipt_numbers_used_client ON $_receiptNumberTable(usedByClientId)');
    }

    if (oldVersion < 5) {
      // Add penalty fees tables in version 5
      await db.execute('''
        CREATE TABLE $_penaltyFeeTable (
          id TEXT PRIMARY KEY,
          branch TEXT NOT NULL,
          amount REAL NOT NULL,
          clientName TEXT NOT NULL,
          dateTimeCaptured TEXT NOT NULL,
          receiptNumber TEXT NOT NULL UNIQUE,
          isSynced INTEGER NOT NULL DEFAULT 0,
          syncedAt TEXT,
          currency TEXT NOT NULL DEFAULT 'USD',
          createdAt INTEGER NOT NULL
        )
      ''');

      // Create indexes for penalty fees
      await db.execute('CREATE INDEX idx_penalty_fees_branch ON $_penaltyFeeTable(branch)');
      await db.execute('CREATE INDEX idx_penalty_fees_client_name ON $_penaltyFeeTable(clientName)');
      await db.execute('CREATE INDEX idx_penalty_fees_receipt_number ON $_penaltyFeeTable(receiptNumber)');
      await db.execute('CREATE INDEX idx_penalty_fees_synced ON $_penaltyFeeTable(isSynced)');
      await db.execute('CREATE INDEX idx_penalty_fees_date ON $_penaltyFeeTable(dateTimeCaptured)');

      // Create cancelled penalty fees table
      await db.execute('''
        CREATE TABLE $_cancelledPenaltyFeeTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          branch TEXT NOT NULL,
          receiptNumber TEXT NOT NULL,
          clientName TEXT NOT NULL,
          amount REAL NOT NULL,
          dateOfPayment TEXT NOT NULL,
          cancelledBy TEXT NOT NULL,
          reason TEXT NOT NULL,
          cancelledAt TEXT NOT NULL,
          cancellationId INTEGER NOT NULL
        )
      ''');

      // Create indexes for cancelled penalty fees
      await db.execute('CREATE INDEX idx_cancelled_penalty_fees_branch ON $_cancelledPenaltyFeeTable(branch)');
      await db.execute('CREATE INDEX idx_cancelled_penalty_fees_receipt_number ON $_cancelledPenaltyFeeTable(receiptNumber)');
      await db.execute('CREATE INDEX idx_cancelled_penalty_fees_cancellation_id ON $_cancelledPenaltyFeeTable(cancellationId)');
    }

    if (oldVersion < 6) {
      // Add all branches table in version 6
      await db.execute('''
        CREATE TABLE $_allBranchesTable (
          branchId INTEGER PRIMARY KEY,
          branchName TEXT NOT NULL UNIQUE,
          lastSynced INTEGER NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');

      // Create indexes for all branches
      await db.execute('CREATE INDEX idx_all_branches_name ON $_allBranchesTable(branchName)');
      await db.execute('CREATE INDEX idx_all_branches_last_synced ON $_allBranchesTable(lastSynced)');
    }

    if (oldVersion < 7) {
      // Add transfers table in version 7
      await db.execute('''
        CREATE TABLE $_transfersTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          transferDate TEXT NOT NULL,
          narration TEXT,
          sendingBranchId INTEGER NOT NULL,
          sendingBranch TEXT NOT NULL,
          receivingBranchId INTEGER NOT NULL,
          receivingBranch TEXT NOT NULL,
          transferType TEXT NOT NULL,
          isSynced INTEGER NOT NULL DEFAULT 0,
          syncedAt TEXT,
          createdAt TEXT NOT NULL
        )
      ''');

      // Create indexes for transfers
      await db.execute('CREATE INDEX idx_transfers_sending_branch ON $_transfersTable(sendingBranchId)');
      await db.execute('CREATE INDEX idx_transfers_receiving_branch ON $_transfersTable(receivingBranchId)');
      await db.execute('CREATE INDEX idx_transfers_transfer_type ON $_transfersTable(transferType)');
      await db.execute('CREATE INDEX idx_transfers_synced ON $_transfersTable(isSynced)');
      await db.execute('CREATE INDEX idx_transfers_date ON $_transfersTable(transferDate)');
      await db.execute('CREATE INDEX idx_transfers_created_at ON $_transfersTable(createdAt)');
    }

    if (oldVersion < 8) {
      // Add expenses table in version 8
      await db.execute('''
        CREATE TABLE $_expensesTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          branchName TEXT NOT NULL,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          expenseDate TEXT NOT NULL,
          isSynced INTEGER NOT NULL DEFAULT 0,
          syncedAt TEXT,
          createdAt TEXT NOT NULL
        )
      ''');

      // Create indexes for expenses
      await db.execute('CREATE INDEX idx_expenses_branch_name ON $_expensesTable(branchName)');
      await db.execute('CREATE INDEX idx_expenses_category ON $_expensesTable(category)');
      await db.execute('CREATE INDEX idx_expenses_synced ON $_expensesTable(isSynced)');
      await db.execute('CREATE INDEX idx_expenses_expense_date ON $_expensesTable(expenseDate)');
      await db.execute('CREATE INDEX idx_expenses_created_at ON $_expensesTable(createdAt)');
    }
  }

  // User operations
  Future<int> insertUser(User user) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final userMap = user.toMap();
    userMap['createdAt'] = now;
    userMap['updatedAt'] = now;
    
    return await db.insert(_userTable, userMap);
  }

  Future<User?> getUser() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _userTable,
      limit: 1,
      orderBy: 'updatedAt DESC',
    );
    
    if (results.isNotEmpty) {
      return User.fromMap(results.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final userMap = user.toMap();
    userMap['updatedAt'] = now;
    
    return await db.update(
      _userTable,
      userMap,
      where: 'currentUserId = ?',
      whereArgs: [user.currentUserId],
    );
  }

  Future<void> deleteUser() async {
    final db = await database;
    await db.delete(_userTable);
  }

  Future<bool> isUserLoggedIn() async {
    final user = await getUser();
    return user?.isAuthenticated ?? false;
  }

  // Client operations
  Future<int> insertClient(Client client) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final clientMap = client.toMap();
    clientMap['createdAt'] = now;
    clientMap['updatedAt'] = now;
    
    return await db.insert(
      _clientTable,
      clientMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Client>> insertMultipleClients(List<Client> clients) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (final client in clients) {
      final clientMap = client.toMap();
      clientMap['createdAt'] = now;
      clientMap['updatedAt'] = now;
      
      batch.insert(
        _clientTable,
        clientMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
    return clients;
  }

  Future<List<Client>> getAllClients() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _clientTable,
      orderBy: 'fullName ASC',
    );
    
    return results.map((map) => Client.fromMap(map)).toList();
  }

  Future<List<Client>> searchClients(String query) async {
    final db = await database;
    final searchQuery = '%$query%';
    
    final List<Map<String, dynamic>> results = await db.query(
      _clientTable,
      where: '''
        fullName LIKE ? OR 
        clientId LIKE ? OR 
        whatsAppContact LIKE ? OR 
        nationalIdNumber LIKE ?
      ''',
      whereArgs: [searchQuery, searchQuery, searchQuery, searchQuery],
      orderBy: 'fullName ASC',
    );
    
    return results.map((map) => Client.fromMap(map)).toList();
  }

  Future<Client?> getClientById(String clientId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _clientTable,
      where: 'clientId = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return Client.fromMap(results.first);
    }
    return null;
  }

  Future<List<Client>> getClientsByBranch(String branch) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _clientTable,
      where: 'branch = ?',
      whereArgs: [branch],
      orderBy: 'fullName ASC',
    );
    
    return results.map((map) => Client.fromMap(map)).toList();
  }

  Future<int> updateClient(Client client) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final clientMap = client.toMap();
    clientMap['updatedAt'] = now;
    
    return await db.update(
      _clientTable,
      clientMap,
      where: 'clientId = ?',
      whereArgs: [client.clientId],
    );
  }

  Future<int> deleteClient(String clientId) async {
    final db = await database;
    return await db.delete(
      _clientTable,
      where: 'clientId = ?',
      whereArgs: [clientId],
    );
  }

  Future<void> deleteAllClients() async {
    final db = await database;
    await db.delete(_clientTable);
  }

  Future<int> getClientsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_clientTable');
    return result.first['count'] as int;
  }

  Future<DateTime?> getLastClientSyncTime() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(lastSynced) as lastSync FROM $_clientTable');
    final lastSync = result.first['lastSync'] as int?;
    
    if (lastSync != null) {
      return DateTime.fromMillisecondsSinceEpoch(lastSync);
    }
    return null;
  }

  // Database utilities
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> deleteDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    await databaseFactory.deleteDatabase(path);
  }

  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;
    
    final userCount = await db.rawQuery('SELECT COUNT(*) as count FROM $_userTable');
    final clientCount = await db.rawQuery('SELECT COUNT(*) as count FROM $_clientTable');
    final disbursementCount = await db.rawQuery('SELECT COUNT(*) as count FROM $_disbursementTable');
    final repaymentCount = await db.rawQuery('SELECT COUNT(*) as count FROM $_repaymentTable');
    final receiptNumberCount = await db.rawQuery('SELECT COUNT(*) as count FROM $_receiptNumberTable');
    
    return {
      'users': userCount.first['count'] as int,
      'clients': clientCount.first['count'] as int,
      'disbursements': disbursementCount.first['count'] as int,
      'repayments': repaymentCount.first['count'] as int,
      'receiptNumbers': receiptNumberCount.first['count'] as int,
    };
  }

  // Disbursement operations
  Future<int> insertDisbursement(Disbursement disbursement) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final disbursementMap = disbursement.toMap();
    disbursementMap['lastSynced'] = now;
    disbursementMap['createdAt'] = now;
    disbursementMap['updatedAt'] = now;
    
    return await db.insert(
      _disbursementTable,
      disbursementMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Disbursement>> insertMultipleDisbursements(List<Disbursement> disbursements) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (final disbursement in disbursements) {
      final disbursementMap = disbursement.toMap();
      disbursementMap['lastSynced'] = now;
      disbursementMap['createdAt'] = now;
      disbursementMap['updatedAt'] = now;
      
      batch.insert(
        _disbursementTable,
        disbursementMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
    return disbursements;
  }

  Future<List<Disbursement>> getDisbursementsByClientId(String clientId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _disbursementTable,
      where: 'clientId = ?',
      whereArgs: [clientId],
      orderBy: 'dateOfDisbursement DESC',
    );
    
    return results.map((map) => Disbursement.fromMap(map)).toList();
  }

  Future<List<Disbursement>> getAllDisbursements() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _disbursementTable,
      orderBy: 'dateOfDisbursement DESC',
    );
    
    return results.map((map) => Disbursement.fromMap(map)).toList();
  }

  Future<List<Disbursement>> getDisbursementsByBranch(String branch) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _disbursementTable,
      where: 'branch = ?',
      whereArgs: [branch],
      orderBy: 'dateOfDisbursement DESC',
    );
    
    return results.map((map) => Disbursement.fromMap(map)).toList();
  }

  Future<Disbursement?> getDisbursementById(int currentId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _disbursementTable,
      where: 'id = ?',
      whereArgs: [currentId],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return Disbursement.fromMap(results.first);
    }
    return null;
  }

  Future<int> updateDisbursement(Disbursement disbursement) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final disbursementMap = disbursement.toMap();
    disbursementMap['updatedAt'] = now;
    
    return await db.update(
      _disbursementTable,
      disbursementMap,
      where: 'id = ?',
      whereArgs: [disbursement.id],
    );
  }

  Future<int> deleteDisbursement(int currentId) async {
    final db = await database;
    return await db.delete(
      _disbursementTable,
      where: 'id = ?',
      whereArgs: [currentId],
    );
  }

  Future<int> deleteDisbursementsByClientId(String clientId) async {
    final db = await database;
    return await db.delete(
      _disbursementTable,
      where: 'clientId = ?',
      whereArgs: [clientId],
    );
  }

  Future<void> deleteAllDisbursements() async {
    final db = await database;
    await db.delete(_disbursementTable);
  }

  Future<int> getDisbursementsCount() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_disbursementTable'
    );
    return results.first['count'] as int;
  }

  Future<int> getDisbursementsCountByClientId(String clientId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_disbursementTable WHERE clientId = ?',
      [clientId],
    );
    return results.first['count'] as int;
  }

  // Helper method to get clients with their disbursement count
  Future<List<Map<String, dynamic>>> getClientsWithDisbursementCount() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT c.*, 
             COALESCE(d.disbursement_count, 0) as disbursement_count
      FROM $_clientTable c
      LEFT JOIN (
        SELECT clientId, COUNT(*) as disbursement_count
        FROM $_disbursementTable
        GROUP BY clientId
      ) d ON c.clientId = d.clientId
      ORDER BY c.fullName ASC
    ''');
    
    return results;
  }
  // Repayment operations
  Future<int> insertRepayment(Repayment repayment) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final repaymentMap = repayment.toMap();
    repaymentMap['createdAt'] = now;
    
    return await db.insert(
      _repaymentTable,
      repaymentMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Repayment>> insertMultipleRepayments(List<Repayment> repayments) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (final repayment in repayments) {
      final repaymentMap = repayment.toMap();
      repaymentMap['createdAt'] = now;
      
      batch.insert(
        _repaymentTable,
        repaymentMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
    return repayments;
  }

  Future<List<Repayment>> getRepaymentsByClientId(String clientId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _repaymentTable,
      where: 'clientId = ?',
      whereArgs: [clientId],
      orderBy: 'dateOfPayment DESC',
    );
    
    return results.map((map) => Repayment.fromMap(map)).toList();
  }

  Future<List<Repayment>> getUnsyncedRepayments() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _repaymentTable,
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'createdAt ASC',
    );
    
    return results.map((map) => Repayment.fromMap(map)).toList();
  }

  Future<List<Repayment>> getSyncedRepayments() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _repaymentTable,
      where: 'isSynced = ?',
      whereArgs: [1],
      orderBy: 'syncedAt DESC',
    );
    
    return results.map((map) => Repayment.fromMap(map)).toList();
  }

  Future<List<Repayment>> getRepaymentsByCurrency(String currency) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _repaymentTable,
      where: 'currency = ?',
      whereArgs: [currency],
      orderBy: 'dateOfPayment DESC',
    );
    
    return results.map((map) => Repayment.fromMap(map)).toList();
  }

  Future<List<Repayment>> getAllRepayments() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _repaymentTable,
      orderBy: 'dateOfPayment DESC',
    );
    
    return results.map((map) => Repayment.fromMap(map)).toList();
  }

  Future<Repayment?> getRepaymentByReceiptNumber(String receiptNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _repaymentTable,
      where: 'receiptNumber = ?',
      whereArgs: [receiptNumber],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return Repayment.fromMap(results.first);
    }
    return null;
  }

  Future<int> updateRepaymentSyncStatus(String receiptNumber, bool isSynced, {String? syncResponse}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final updateData = <String, dynamic>{
      'isSynced': isSynced ? 1 : 0,
      'syncResponse': syncResponse,
    };
    
    if (isSynced) {
      updateData['syncedAt'] = now;
    }
    
    return await db.update(
      _repaymentTable,
      updateData,
      where: 'receiptNumber = ?',
      whereArgs: [receiptNumber],
    );
  }

  Future<int> deleteRepayment(String receiptNumber) async {
    final db = await database;
    return await db.delete(
      _repaymentTable,
      where: 'receiptNumber = ?',
      whereArgs: [receiptNumber],
    );
  }

  Future<int> deleteRepaymentsByClientId(String clientId) async {
    final db = await database;
    return await db.delete(
      _repaymentTable,
      where: 'clientId = ?',
      whereArgs: [clientId],
    );
  }

  Future<void> deleteAllRepayments() async {
    final db = await database;
    await db.delete(_repaymentTable);
  }

  Future<int> getRepaymentsCount() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_repaymentTable'
    );
    return results.first['count'] as int;
  }

  Future<int> getUnsyncedRepaymentsCount() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_repaymentTable WHERE isSynced = 0'
    );
    return results.first['count'] as int;
  }

  Future<int> getRepaymentsCountByClientId(String clientId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_repaymentTable WHERE clientId = ?',
      [clientId],
    );
    return results.first['count'] as int;
  }

  Future<double> getTotalRepaymentAmountByClientId(String clientId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT SUM(amount) as total FROM $_repaymentTable WHERE clientId = ? AND isSynced = 1',
      [clientId],
    );
    return (results.first['total'] ?? 0.0).toDouble();
  }

  Future<Map<String, double>> getTotalRepaymentsByCurrency() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT currency, SUM(amount) as total 
      FROM $_repaymentTable 
      WHERE isSynced = 1
      GROUP BY currency
    ''');
    
    final Map<String, double> totals = {};
    for (final result in results) {
      totals[result['currency']] = (result['total'] ?? 0.0).toDouble();
    }
    return totals;
  }

  /// Get clients with their repayment count and total amount
  Future<List<Map<String, dynamic>>> getClientsWithRepaymentSummary() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT c.*, 
             COALESCE(r.repayment_count, 0) as repayment_count,
             COALESCE(r.total_amount, 0.0) as total_repayment_amount
      FROM $_clientTable c
      LEFT JOIN (
        SELECT clientId, 
               COUNT(*) as repayment_count,
               SUM(amount) as total_amount
        FROM $_repaymentTable
        WHERE isSynced = 1
        GROUP BY clientId
      ) r ON c.clientId = r.clientId
      ORDER BY c.fullName ASC
    ''');
    
    return results;
  }

  // Receipt Number operations
  Future<int> insertReceiptNumber(ReceiptNumber receiptNumber) async {
    final db = await database;
    return await db.insert(
      _receiptNumberTable,
      receiptNumber.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ReceiptNumber>> insertMultipleReceiptNumbers(List<ReceiptNumber> receiptNumbers) async {
    final db = await database;
    final batch = db.batch();
    
    for (final receiptNumber in receiptNumbers) {
      batch.insert(
        _receiptNumberTable,
        receiptNumber.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
    return receiptNumbers;
  }

  Future<List<ReceiptNumber>> getUnusedReceiptNumbers() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _receiptNumberTable,
      where: 'isUsed = ?',
      whereArgs: [0],
      orderBy: 'id ASC',
    );
    
    return results.map((map) => ReceiptNumber.fromMap(map)).toList();
  }

  Future<List<ReceiptNumber>> getUsedReceiptNumbers() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _receiptNumberTable,
      where: 'isUsed = ?',
      whereArgs: [1],
      orderBy: 'usedAt DESC',
    );
    
    return results.map((map) => ReceiptNumber.fromMap(map)).toList();
  }

  Future<List<ReceiptNumber>> getAllReceiptNumbers() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _receiptNumberTable,
      orderBy: 'id ASC',
    );
    
    return results.map((map) => ReceiptNumber.fromMap(map)).toList();
  }

  Future<ReceiptNumber?> getNextUnusedReceiptNumber() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _receiptNumberTable,
      where: 'isUsed = ?',
      whereArgs: [0],
      orderBy: 'id ASC',
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return ReceiptNumber.fromMap(results.first);
    }
    return null;
  }

  Future<ReceiptNumber?> getReceiptNumberByReceiptNum(String receiptNum) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _receiptNumberTable,
      where: 'receiptNum = ?',
      whereArgs: [receiptNum],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return ReceiptNumber.fromMap(results.first);
    }
    return null;
  }

  Future<ReceiptNumber?> getReceiptNumberById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _receiptNumberTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return ReceiptNumber.fromMap(results.first);
    }
    return null;
  }

  Future<int> markReceiptNumberAsUsed(
    int id, {
    required String clientId,
    required String clientName,
    required double amount,
    required String currency,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    return await db.update(
      _receiptNumberTable,
      {
        'isUsed': 1,
        'usedAt': now,
        'usedByClientId': clientId,
        'usedByClientName': clientName,
        'usedAmount': amount,
        'currency': currency,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ReceiptNumber>> searchReceiptNumbers(String query) async {
    final db = await database;
    final searchQuery = '%$query%';
    
    final List<Map<String, dynamic>> results = await db.query(
      _receiptNumberTable,
      where: '''
        receiptNum LIKE ? OR 
        allocatedToFirstName LIKE ? OR 
        allocatedToLastName LIKE ? OR 
        usedByClientName LIKE ? OR
        usedByClientId LIKE ?
      ''',
      whereArgs: [searchQuery, searchQuery, searchQuery, searchQuery, searchQuery],
      orderBy: 'id ASC',
    );
    
    return results.map((map) => ReceiptNumber.fromMap(map)).toList();
  }

  Future<List<ReceiptNumber>> getReceiptNumbersByBranch(String branch) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _receiptNumberTable,
      where: 'allocatedToBranch = ?',
      whereArgs: [branch],
      orderBy: 'id ASC',
    );
    
    return results.map((map) => ReceiptNumber.fromMap(map)).toList();
  }

  Future<int> getUnusedReceiptNumbersCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_receiptNumberTable WHERE isUsed = 0');
    return result.first['count'] as int;
  }

  Future<int> getUsedReceiptNumbersCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_receiptNumberTable WHERE isUsed = 1');
    return result.first['count'] as int;
  }

  Future<int> getTotalReceiptNumbersCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_receiptNumberTable');
    return result.first['count'] as int;
  }

  Future<void> deleteAllReceiptNumbers() async {
    final db = await database;
    await db.delete(_receiptNumberTable);
  }

  /// Get receipt numbers summary stats
  Future<Map<String, int>> getReceiptNumbersStats() async {
    final db = await database;
    
    final unusedResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_receiptNumberTable WHERE isUsed = 0');
    final usedResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_receiptNumberTable WHERE isUsed = 1');
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_receiptNumberTable');
    
    return {
      'unused': unusedResult.first['count'] as int,
      'used': usedResult.first['count'] as int,
      'total': totalResult.first['count'] as int,
    };
  }

  // Penalty Fee operations
  Future<int> insertPenaltyFee(PenaltyFee penaltyFee) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final penaltyFeeMap = penaltyFee.toMap();
    penaltyFeeMap['createdAt'] = now;
    
    return await db.insert(_penaltyFeeTable, penaltyFeeMap);
  }

  Future<List<PenaltyFee>> getAllPenaltyFees() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _penaltyFeeTable,
      orderBy: 'dateTimeCaptured DESC',
    );

    return results.map((map) => PenaltyFee.fromMap(map)).toList();
  }

  Future<List<PenaltyFee>> getUnsyncedPenaltyFees() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _penaltyFeeTable,
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'dateTimeCaptured DESC',
    );

    return results.map((map) => PenaltyFee.fromMap(map)).toList();
  }

  Future<List<PenaltyFee>> getSyncedPenaltyFees() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _penaltyFeeTable,
      where: 'isSynced = ?',
      whereArgs: [1],
      orderBy: 'dateTimeCaptured DESC',
    );

    return results.map((map) => PenaltyFee.fromMap(map)).toList();
  }

  Future<PenaltyFee?> getPenaltyFeeById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _penaltyFeeTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isNotEmpty) {
      return PenaltyFee.fromMap(results.first);
    }
    return null;
  }

  Future<PenaltyFee?> getPenaltyFeeByReceiptNumber(String receiptNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _penaltyFeeTable,
      where: 'receiptNumber = ?',
      whereArgs: [receiptNumber],
    );

    if (results.isNotEmpty) {
      return PenaltyFee.fromMap(results.first);
    }
    return null;
  }

  Future<int> updatePenaltyFee(PenaltyFee penaltyFee) async {
    final db = await database;
    return await db.update(
      _penaltyFeeTable,
      penaltyFee.toMap(),
      where: 'id = ?',
      whereArgs: [penaltyFee.id],
    );
  }

  Future<int> markPenaltyFeeAsSynced(String id) async {
    final db = await database;
    return await db.update(
      _penaltyFeeTable,
      {
        'isSynced': 1,
        'syncedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePenaltyFee(String id) async {
    final db = await database;
    return await db.delete(
      _penaltyFeeTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getPenaltyFeesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_penaltyFeeTable');
    return result.first['count'] as int;
  }

  Future<int> getUnsyncedPenaltyFeesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_penaltyFeeTable WHERE isSynced = 0');
    return result.first['count'] as int;
  }

  Future<int> getSyncedPenaltyFeesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_penaltyFeeTable WHERE isSynced = 1');
    return result.first['count'] as int;
  }

  Future<List<PenaltyFee>> getPenaltyFeesByClientName(String clientName) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _penaltyFeeTable,
      where: 'clientName LIKE ?',
      whereArgs: ['%$clientName%'],
      orderBy: 'dateTimeCaptured DESC',
    );

    return results.map((map) => PenaltyFee.fromMap(map)).toList();
  }

  Future<List<PenaltyFee>> getPenaltyFeesByBranch(String branch) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _penaltyFeeTable,
      where: 'branch = ?',
      whereArgs: [branch],
      orderBy: 'dateTimeCaptured DESC',
    );

    return results.map((map) => PenaltyFee.fromMap(map)).toList();
  }

  Future<void> deleteAllPenaltyFees() async {
    final db = await database;
    await db.delete(_penaltyFeeTable);
  }

  /// Get penalty fees summary stats
  Future<Map<String, int>> getPenaltyFeesStats() async {
    final db = await database;

    final unsyncedResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_penaltyFeeTable WHERE isSynced = 0');
    final syncedResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_penaltyFeeTable WHERE isSynced = 1');
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_penaltyFeeTable');
    
    return {
      'unsynced': unsyncedResult.first['count'] as int,
      'synced': syncedResult.first['count'] as int,
      'total': totalResult.first['count'] as int,
    };
  }

  // Cancelled Penalty Fee operations
  Future<int> insertCancelledPenaltyFee(CancelledPenaltyFee cancelledPenaltyFee) async {
    final db = await database;
    return await db.insert(_cancelledPenaltyFeeTable, cancelledPenaltyFee.toMap());
  }

  Future<List<CancelledPenaltyFee>> getAllCancelledPenaltyFees() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _cancelledPenaltyFeeTable,
      orderBy: 'cancelledAt DESC',
    );

    return results.map((map) => CancelledPenaltyFee.fromMap(map)).toList();
  }

  Future<List<CancelledPenaltyFee>> getCancelledPenaltyFeesByBranch(String branch) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _cancelledPenaltyFeeTable,
      where: 'branch = ?',
      whereArgs: [branch],
      orderBy: 'cancelledAt DESC',
    );

    return results.map((map) => CancelledPenaltyFee.fromMap(map)).toList();
  }

  Future<CancelledPenaltyFee?> getCancelledPenaltyFeeByReceiptNumber(String receiptNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _cancelledPenaltyFeeTable,
      where: 'receiptNumber = ?',
      whereArgs: [receiptNumber],
    );

    if (results.isNotEmpty) {
      return CancelledPenaltyFee.fromMap(results.first);
    }
    return null;
  }

  Future<int> deleteCancelledPenaltyFee(int cancellationId) async {
    final db = await database;
    return await db.delete(
      _cancelledPenaltyFeeTable,
      where: 'cancellationId = ?',
      whereArgs: [cancellationId],
    );
  }

  Future<int> getCancelledPenaltyFeesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_cancelledPenaltyFeeTable');
    return result.first['count'] as int;
  }

  Future<void> deleteAllCancelledPenaltyFees() async {
    final db = await database;
    await db.delete(_cancelledPenaltyFeeTable);
  }

  // All Branches operations
  Future<int> insertBranch(Branch branch) async {
    final db = await database;
    return await db.insert(
      _allBranchesTable,
      branch.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Branch>> insertMultipleBranches(List<Branch> branches) async {
    final db = await database;
    final batch = db.batch();
    
    for (final branch in branches) {
      batch.insert(
        _allBranchesTable,
        branch.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
    return branches;
  }

  Future<List<Branch>> getAllBranches() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _allBranchesTable,
      orderBy: 'branchName ASC',
    );

    return results.map((map) => Branch.fromMap(map)).toList();
  }

  Future<Branch?> getBranchById(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _allBranchesTable,
      where: 'branchId = ?',
      whereArgs: [branchId],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return Branch.fromMap(results.first);
    }
    return null;
  }

  Future<Branch?> getBranchByName(String branchName) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _allBranchesTable,
      where: 'branchName = ?',
      whereArgs: [branchName],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return Branch.fromMap(results.first);
    }
    return null;
  }

  Future<int> getBranchesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_allBranchesTable');
    return result.first['count'] as int;
  }

  Future<DateTime?> getLastBranchSyncTime() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _allBranchesTable,
      columns: ['lastSynced'],
      orderBy: 'lastSynced DESC',
      limit: 1,
    );

    if (results.isNotEmpty) {
      final timestamp = results.first['lastSynced'] as int;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  Future<int> updateBranch(Branch branch) async {
    final db = await database;
    return await db.update(
      _allBranchesTable,
      branch.toMap(),
      where: 'branchId = ?',
      whereArgs: [branch.branchId],
    );
  }

  Future<int> deleteBranch(int branchId) async {
    final db = await database;
    return await db.delete(
      _allBranchesTable,
      where: 'branchId = ?',
      whereArgs: [branchId],
    );
  }

  Future<void> deleteAllBranches() async {
    final db = await database;
    await db.delete(_allBranchesTable);
  }

  // ===== TRANSFER OPERATIONS =====

  /// Insert a new transfer
  Future<int> insertTransfer(Transfer transfer) async {
    final db = await database;
    
    final transferMap = transfer.toMap();
    // Remove id for insertion
    transferMap.remove('id');
    
    return await db.insert(
      _transfersTable,
      transferMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all transfers (queued and synced)
  Future<List<Transfer>> getAllTransfers() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _transfersTable,
      orderBy: 'createdAt DESC',
    );
    
    return results.map((map) => Transfer.fromMap(map)).toList();
  }

  /// Get queued transfers (not synced)
  Future<List<Transfer>> getQueuedTransfers() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _transfersTable,
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'createdAt DESC',
    );
    
    return results.map((map) => Transfer.fromMap(map)).toList();
  }

  /// Get synced transfers
  Future<List<Transfer>> getSyncedTransfers() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _transfersTable,
      where: 'isSynced = ?',
      whereArgs: [1],
      orderBy: 'syncedAt DESC',
    );
    
    return results.map((map) => Transfer.fromMap(map)).toList();
  }

  /// Get transfers by type
  Future<List<Transfer>> getTransfersByType(String transferType) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _transfersTable,
      where: 'transferType = ?',
      whereArgs: [transferType],
      orderBy: 'createdAt DESC',
    );
    
    return results.map((map) => Transfer.fromMap(map)).toList();
  }

  /// Get transfers by sending branch
  Future<List<Transfer>> getTransfersBySendingBranch(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _transfersTable,
      where: 'sendingBranchId = ?',
      whereArgs: [branchId],
      orderBy: 'createdAt DESC',
    );
    
    return results.map((map) => Transfer.fromMap(map)).toList();
  }

  /// Get transfers by receiving branch
  Future<List<Transfer>> getTransfersByReceivingBranch(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _transfersTable,
      where: 'receivingBranchId = ?',
      whereArgs: [branchId],
      orderBy: 'createdAt DESC',
    );
    
    return results.map((map) => Transfer.fromMap(map)).toList();
  }

  /// Update transfer sync status
  Future<int> updateTransferSyncStatus(int transferId, bool isSynced) async {
    final db = await database;
    
    final updateData = <String, dynamic>{
      'isSynced': isSynced ? 1 : 0,
    };
    
    if (isSynced) {
      updateData['syncedAt'] = DateTime.now().toIso8601String();
    }
    
    return await db.update(
      _transfersTable,
      updateData,
      where: 'id = ?',
      whereArgs: [transferId],
    );
  }

  /// Delete a transfer (only if not synced)
  Future<int> deleteTransfer(int transferId) async {
    final db = await database;
    return await db.delete(
      _transfersTable,
      where: 'id = ? AND isSynced = ?',
      whereArgs: [transferId, 0], // Only delete if not synced
    );
  }

  /// Delete expired transfers (queued for more than 24 hours)
  Future<int> deleteExpiredTransfers() async {
    final db = await database;
    final twentyFourHoursAgo = DateTime.now().subtract(Duration(hours: 24)).toIso8601String();
    
    return await db.delete(
      _transfersTable,
      where: 'isSynced = ? AND createdAt < ?',
      whereArgs: [0, twentyFourHoursAgo],
    );
  }

  /// Delete synced transfers older than 7 days
  Future<int> deleteOldSyncedTransfers() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).toIso8601String();
    
    return await db.delete(
      _transfersTable,
      where: 'isSynced = ? AND syncedAt < ?',
      whereArgs: [1, sevenDaysAgo],
    );
  }

  /// Get transfer by ID
  Future<Transfer?> getTransferById(int transferId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _transfersTable,
      where: 'id = ?',
      whereArgs: [transferId],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return Transfer.fromMap(results.first);
    }
    return null;
  }

  /// Count queued transfers
  Future<int> getQueuedTransfersCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_transfersTable WHERE isSynced = 0');
    return result.first['count'] as int;
  }

  /// Count synced transfers
  Future<int> getSyncedTransfersCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_transfersTable WHERE isSynced = 1');
    return result.first['count'] as int;
  }

  /// Get total transfer amount by type for reporting
  Future<double> getTotalTransferAmountByType(String transferType, {bool? isSynced}) async {
    final db = await database;
    String query = 'SELECT COALESCE(SUM(amount), 0.0) as total FROM $_transfersTable WHERE transferType = ?';
    List<dynamic> args = [transferType];
    
    if (isSynced != null) {
      query += ' AND isSynced = ?';
      args.add(isSynced ? 1 : 0);
    }
    
    final result = await db.rawQuery(query, args);
    return result.first['total'] as double;
  }

  /// Check if user can create transfer (not exceeding any limits if needed)
  Future<bool> canUserCreateTransfer(int sendingBranchId) async {
    final db = await database;
    
    // Check for any pending transfers from the same branch in the last hour
    // This prevents spam/duplicate submissions
    final oneHourAgo = DateTime.now().subtract(Duration(hours: 1)).toIso8601String();
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_transfersTable WHERE sendingBranchId = ? AND isSynced = 0 AND createdAt > ?',
      [sendingBranchId, oneHourAgo]
    );
    
    int pendingTransfers = result.first['count'] as int;
    
    // Allow up to 10 pending transfers per hour per branch (adjustable)
    return pendingTransfers < 10;
  }

  /// Clean up old data (call this periodically)
  Future<void> cleanupTransfersData() async {
    await deleteExpiredTransfers();
    await deleteOldSyncedTransfers();
    print('Transfer data cleanup completed');
  }

  // ===== EXPENSE OPERATIONS =====

  /// Insert a new expense
  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    
    final expenseMap = expense.toMap();
    // Remove id for insertion
    expenseMap.remove('id');
    
    return await db.insert(
      _expensesTable,
      expenseMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all expenses (queued and synced)
  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _expensesTable,
      orderBy: 'createdAt DESC',
    );
    
    return results.map((map) => Expense.fromMap(map)).toList();
  }

  /// Get queued expenses (not synced)
  Future<List<Expense>> getQueuedExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _expensesTable,
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'createdAt DESC',
    );
    
    return results.map((map) => Expense.fromMap(map)).toList();
  }

  /// Get synced expenses (not expired)
  Future<List<Expense>> getSyncedExpenses() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).toIso8601String();
    
    final List<Map<String, dynamic>> results = await db.query(
      _expensesTable,
      where: 'isSynced = ? AND syncedAt > ?',
      whereArgs: [1, sevenDaysAgo],
      orderBy: 'syncedAt DESC',
    );
    
    return results.map((map) => Expense.fromMap(map)).toList();
  }

  /// Get expenses by category
  Future<List<Expense>> getExpensesByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _expensesTable,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'createdAt DESC',
    );
    
    return results.map((map) => Expense.fromMap(map)).toList();
  }

  /// Get expenses by branch
  Future<List<Expense>> getExpensesByBranch(String branchName) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _expensesTable,
      where: 'branchName = ?',
      whereArgs: [branchName],
      orderBy: 'createdAt DESC',
    );
    
    return results.map((map) => Expense.fromMap(map)).toList();
  }

  /// Check for potential duplicate expenses
  Future<List<Expense>> findSimilarExpenses(Expense expense) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _expensesTable,
      where: 'branchName = ? AND category = ? AND amount = ? AND expenseDate = ?',
      whereArgs: [
        expense.branchName,
        expense.category,
        expense.amount,
        expense.expenseDate.toIso8601String().substring(0, 10), // Compare date only
      ],
    );
    
    return results.map((map) => Expense.fromMap(map)).toList();
  }

  /// Update expense sync status
  Future<int> updateExpenseSyncStatus(int expenseId, bool isSynced) async {
    final db = await database;
    
    final updateData = <String, dynamic>{
      'isSynced': isSynced ? 1 : 0,
    };
    
    if (isSynced) {
      updateData['syncedAt'] = DateTime.now().toIso8601String();
    }
    
    return await db.update(
      _expensesTable,
      updateData,
      where: 'id = ?',
      whereArgs: [expenseId],
    );
  }

  /// Delete an expense (only if not synced)
  Future<int> deleteExpense(int expenseId) async {
    final db = await database;
    return await db.delete(
      _expensesTable,
      where: 'id = ? AND isSynced = ?',
      whereArgs: [expenseId, 0], // Only delete if not synced
    );
  }

  /// Delete expired synced expenses (older than 7 days)
  Future<int> deleteExpiredSyncedExpenses() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).toIso8601String();
    
    return await db.delete(
      _expensesTable,
      where: 'isSynced = ? AND syncedAt < ?',
      whereArgs: [1, sevenDaysAgo],
    );
  }

  /// Get expense by ID
  Future<Expense?> getExpenseById(int expenseId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      _expensesTable,
      where: 'id = ?',
      whereArgs: [expenseId],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return Expense.fromMap(results.first);
    }
    return null;
  }

  /// Count queued expenses
  Future<int> getQueuedExpensesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_expensesTable WHERE isSynced = 0');
    return result.first['count'] as int;
  }

  /// Count synced expenses (not expired)
  Future<int> getSyncedExpensesCount() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).toIso8601String();
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_expensesTable WHERE isSynced = 1 AND syncedAt > ?',
      [sevenDaysAgo]
    );
    return result.first['count'] as int;
  }

  /// Get total expense amount by category for reporting
  Future<double> getTotalExpenseAmountByCategory(String category, {bool? isSynced}) async {
    final db = await database;
    String query = 'SELECT COALESCE(SUM(amount), 0.0) as total FROM $_expensesTable WHERE category = ?';
    List<dynamic> args = [category];
    
    if (isSynced != null) {
      query += ' AND isSynced = ?';
      args.add(isSynced ? 1 : 0);
    }
    
    final result = await db.rawQuery(query, args);
    return result.first['total'] as double;
  }

  /// Get expense statistics by branch
  Future<Map<String, dynamic>> getExpenseStatsByBranch(String branchName) async {
    final db = await database;
    
    final queuedResult = await db.rawQuery(
      'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0.0) as total FROM $_expensesTable WHERE branchName = ? AND isSynced = 0',
      [branchName]
    );
    
    final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7)).toIso8601String();
    final syncedResult = await db.rawQuery(
      'SELECT COUNT(*) as count, COALESCE(SUM(amount), 0.0) as total FROM $_expensesTable WHERE branchName = ? AND isSynced = 1 AND syncedAt > ?',
      [branchName, sevenDaysAgo]
    );
    
    return {
      'queued': {
        'count': queuedResult.first['count'] as int,
        'total': queuedResult.first['total'] as double,
      },
      'synced': {
        'count': syncedResult.first['count'] as int,
        'total': syncedResult.first['total'] as double,
      }
    };
  }

  /// Clean up old expense data (call this periodically)
  Future<void> cleanupExpensesData() async {
    await deleteExpiredSyncedExpenses();
    print('Expense data cleanup completed');
  }

  /// Get expenses for date range
  Future<List<Expense>> getExpensesForDateRange(DateTime startDate, DateTime endDate, {String? branchName}) async {
    final db = await database;
    
    String query = 'SELECT * FROM $_expensesTable WHERE expenseDate >= ? AND expenseDate <= ?';
    List<dynamic> args = [startDate.toIso8601String(), endDate.toIso8601String()];
    
    if (branchName != null) {
      query += ' AND branchName = ?';
      args.add(branchName);
    }
    
    query += ' ORDER BY expenseDate DESC';
    
    final results = await db.rawQuery(query, args);
    return results.map((map) => Expense.fromMap(map)).toList();
  }
}