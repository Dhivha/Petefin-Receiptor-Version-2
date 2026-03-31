import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/repayment.dart';
import '../models/admin_fee.dart';
import '../models/fcb_receipt.dart';
import '../models/penalty_fee.dart';

class BluetoothReceiptService {
  static BluetoothDevice? _connectedDevice;

  // Set connected device from Bluetooth screen
  static void setConnectedDevice(BluetoothDevice? device) {
    _connectedDevice = device;
  }

  // Get current connected device
  static BluetoothDevice? get connectedDevice => _connectedDevice;

  // Check if printer is connected
  static bool get isConnected => _connectedDevice != null;

  /// Print receipt for a repayment
  static Future<bool> printRepaymentReceipt(
    Repayment repayment, {
    String? clientName,
  }) async {
    if (!isConnected) {
      print('❌ No Bluetooth printer connected');
      return false;
    }

    try {
      print('🖨️ Printing receipt for ${repayment.receiptNumber}...');

      // Build receipt content
      final receiptData = _buildReceiptData(repayment, clientName);

      // Convert to ESC/POS commands
      final escPosData = _generateEscPosCommands(receiptData);

      // Send to printer
      await _sendToPrinter(escPosData);

      print('✅ Receipt printed successfully: ${repayment.receiptNumber}');
      return true;
    } catch (e) {
      print('❌ Failed to print receipt: $e');
      return false;
    }
  }

  /// Build receipt data structure
  static Map<String, dynamic> _buildReceiptData(
    Repayment repayment,
    String? clientName,
  ) {
    final now = DateTime.now();

    return {
      'header': 'PETEFIN MICROFINANCE',
      'subheader': 'REPAYMENT RECEIPT',
      'receiptNumber': repayment.receiptNumber,
      'date': '${now.day}/${now.month}/${now.year}',
      'time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'clientName': clientName ?? repayment.clientName,
      'clientId': repayment.clientId,
      'amount': repayment.formattedAmount,
      'currency': repayment.currency,
      'paymentNumber': repayment.paymentNumber,
      'disbursementId': repayment.disbursementId.toString(),
      'branch': repayment.branch,
      'footer': 'Thank you for your payment!',
    };
  }

  /// Generate ESC/POS commands for thermal printer
  static List<int> _generateEscPosCommands(Map<String, dynamic> data) {
    List<int> commands = [];

    // Initialize printer
    commands.addAll([27, 64]); // ESC @ (Initialize)
    commands.addAll('\n'.codeUnits); // Top spacing

    // Header - Bold and center
    commands.addAll([27, 69, 1]); // ESC E (Bold on)
    commands.addAll([27, 97, 1]); // ESC a (Center align)
    commands.addAll('${data['header']}\n'.codeUnits);
    commands.addAll('\n'.codeUnits); // Extra spacing

    // Subheader
    commands.addAll('${data['subheader']}\n'.codeUnits);
    commands.addAll([27, 69, 0]); // ESC E (Bold off)
    commands.addAll([27, 97, 0]); // ESC a (Left align)
    commands.addAll('\n'.codeUnits);
    commands.addAll('${'=' * 32}\n'.codeUnits);
    commands.addAll('\n'.codeUnits);

    // Receipt details
    commands.addAll('Receipt No: ${data['receiptNumber']}\n'.codeUnits);
    commands.addAll('Date: ${data['date']}\n'.codeUnits);
    commands.addAll('Time: ${data['time']}\n'.codeUnits);
    commands.addAll('\n'.codeUnits);
    commands.addAll('${'-' * 32}\n'.codeUnits);
    commands.addAll('\n'.codeUnits); // Extra spacing

    // Client information
    commands.addAll([27, 69, 1]); // Bold on
    commands.addAll('CLIENT INFORMATION:\n'.codeUnits);
    commands.addAll([27, 69, 0]); // Bold off
    commands.addAll('\n'.codeUnits);
    commands.addAll('Client Name:\n'.codeUnits);
    commands.addAll('  ${data['clientName']}\n'.codeUnits);
    if (data['clientId'] != null) {
      commands.addAll('Client ID:\n'.codeUnits);
      commands.addAll('  ${data['clientId']}\n'.codeUnits);
    }
    if (data['branch'] != null) {
      commands.addAll('Branch:\n'.codeUnits);
      commands.addAll('  ${data['branch']}\n'.codeUnits);
    }
    commands.addAll('\n'.codeUnits);
    commands.addAll('${'-' * 32}\n'.codeUnits);
    commands.addAll('\n'.codeUnits); // Extra spacing

    // Payment details - Remove irrelevant fields for Admin/FCB
    commands.addAll([27, 69, 1]); // Bold on
    if (data['subheader'].contains('ADMIN')) {
      commands.addAll('ADMIN FEE DETAILS:\n'.codeUnits);
    } else if (data['subheader'].contains('FCB')) {
      commands.addAll('FCB PAYMENT DETAILS:\n'.codeUnits);
    } else {
      commands.addAll('PAYMENT DETAILS:\n'.codeUnits);
    }
    commands.addAll([27, 69, 0]); // Bold off
    commands.addAll('\n'.codeUnits);
    commands.addAll('Currency: ${data['currency']}\n'.codeUnits);
    commands.addAll('\n'.codeUnits);

    // Amount - center aligned and bold for emphasis
    commands.addAll([27, 69, 1]); // Bold on
    commands.addAll([27, 97, 1]); // Center align
    commands.addAll('AMOUNT: ${data['amount']}\n'.codeUnits);
    commands.addAll([27, 69, 0]); // Bold off
    commands.addAll([27, 97, 0]); // Left align
    commands.addAll('\n'.codeUnits);

    // Only show payment/disbursement details for repayments, not admin/FCB
    if (data['paymentNumber'] != null &&
        !data['subheader'].contains('ADMIN') &&
        !data['subheader'].contains('FCB')) {
      commands.addAll('Payment #: ${data['paymentNumber']}\n'.codeUnits);
      commands.addAll('\n'.codeUnits);
    }
    if (data['disbursementId'] != null &&
        !data['subheader'].contains('ADMIN') &&
        !data['subheader'].contains('FCB')) {
      commands.addAll('Disbursement ID: ${data['disbursementId']}\n'.codeUnits);
      commands.addAll('\n'.codeUnits);
    }

    commands.addAll('${'-' * 32}\n'.codeUnits);
    commands.addAll('\n'.codeUnits); // Extra spacing

    // Footer
    commands.addAll([27, 97, 1]); // Center align
    commands.addAll('${data['footer']}\n'.codeUnits);
    commands.addAll('\n'.codeUnits);
    commands.addAll('Keep this receipt for\n'.codeUnits);
    commands.addAll('your records.\n'.codeUnits);
    commands.addAll(
      '\n\n\n\n\n'.codeUnits,
    ); // Extra spacing at end for easy tear-off

    // Cut paper
    commands.addAll([29, 86, 65, 0]); // GS V A (Full cut)

    return commands;
  }

  /// Send data to printer
  static Future<void> _sendToPrinter(List<int> data) async {
    if (_connectedDevice == null) {
      throw Exception('No printer connected');
    }

    try {
      // Get services
      final services = await _connectedDevice!.discoverServices();
      BluetoothCharacteristic? targetCharacteristic;

      // Find write characteristic
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            targetCharacteristic = characteristic;
            break;
          }
        }
        if (targetCharacteristic != null) break;
      }

      if (targetCharacteristic == null) {
        throw Exception('No writable characteristic found');
      }

      // Send data in chunks (some printers have MTU limits)
      const chunkSize = 20;
      for (int i = 0; i < data.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, data.length);
        final chunk = data.sublist(i, end);
        await targetCharacteristic.write(chunk, withoutResponse: false);

        // Small delay between chunks
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Print test receipt
  static Future<bool> printTestReceipt() async {
    if (!isConnected) {
      print('❌ No Bluetooth printer connected');
      return false;
    }

    try {
      final testData = {
        'header': 'PETEFIN RECEIPTOR',
        'subheader': 'TEST RECEIPT',
        'receiptNumber': 'TEST-${DateTime.now().millisecondsSinceEpoch}',
        'date':
            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        'time':
            '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        'clientName': 'Test Client',
        'clientId': 'TEST001',
        'amount': '\$100.00',
        'currency': 'USD',
        'paymentNumber': 'TEST123',
        'disbursementId': '999',
        'branch': 'Test Branch',
        'footer': 'TEST SUCCESSFUL!',
      };

      final escPosData = _generateEscPosCommands(testData);
      await _sendToPrinter(escPosData);

      print('✅ Test receipt printed successfully');
      return true;
    } catch (e) {
      print('❌ Test print failed: $e');
      return false;
    }
  }

  /// Auto-print receipt with error handling and retries
  static Future<void> autoPrintReceipt(
    Repayment repayment, {
    String? clientName,
    int maxRetries = 3,
  }) async {
    if (!isConnected) {
      print('⚠️ Auto-print skipped: No printer connected');
      return;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🖨️ Auto-print attempt $attempt for ${repayment.receiptNumber}');

        final success = await printRepaymentReceipt(
          repayment,
          clientName: clientName,
        );

        if (success) {
          print('✅ Auto-print successful on attempt $attempt');
          return;
        } else {
          if (attempt < maxRetries) {
            print('⚠️ Auto-print attempt $attempt failed, retrying...');
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      } catch (e) {
        print('❌ Auto-print attempt $attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }

    print('❌ Auto-print failed after $maxRetries attempts');
  }

  // ===== ADMIN FEES RECEIPT PRINTING =====

  /// Print receipt for an admin fee
  static Future<bool> printAdminFeeReceipt(AdminFee adminFee) async {
    if (!isConnected) {
      print('❌ No Bluetooth printer connected');
      return false;
    }

    try {
      print('🖨️ Printing admin fee receipt for ${adminFee.receiptNumber}...');

      // Build receipt content
      final receiptData = _buildAdminFeeReceiptData(adminFee);

      // Convert to ESC/POS commands
      final escPosData = _generateEscPosCommands(receiptData);

      // Send to printer
      await _sendToPrinter(escPosData);

      print(
        '✅ Admin fee receipt printed successfully: ${adminFee.receiptNumber}',
      );
      return true;
    } catch (e) {
      print('❌ Failed to print admin fee receipt: $e');
      return false;
    }
  }

  /// Build admin fee receipt data structure
  static Map<String, dynamic> _buildAdminFeeReceiptData(AdminFee adminFee) {
    final now = DateTime.now();

    return {
      'header': 'PETEFIN FINANCIAL SERVICE',
      'subheader': 'ADMIN FEE RECEIPT',
      'receiptNumber': adminFee.receiptNumber,
      'date': '${now.day}/${now.month}/${now.year}',
      'time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'clientName': adminFee.fullName,
      'firstName': adminFee.firstName,
      'lastName': adminFee.lastName,
      'amount': adminFee.formattedAmount,
      'currency': 'USD',
      'barcode': adminFee.barcode,
      'branch': adminFee.branch,
      'footer': 'Thank you for your payment!',
    };
  }

  /// Auto-print admin fee receipt with error handling
  static Future<void> autoPrintAdminFeeReceipt(
    AdminFee adminFee, {
    int maxRetries = 3,
  }) async {
    if (!isConnected) {
      print('⚠️ Auto-print skipped: No printer connected');
      return;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
          '🖨️ Auto-print admin fee attempt $attempt for ${adminFee.receiptNumber}',
        );

        final success = await printAdminFeeReceipt(adminFee);

        if (success) {
          print('✅ Admin fee auto-print successful on attempt $attempt');
          return;
        } else {
          if (attempt < maxRetries) {
            print(
              '⚠️ Admin fee auto-print attempt $attempt failed, retrying...',
            );
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      } catch (e) {
        print('❌ Admin fee auto-print attempt $attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }

    print('❌ Admin fee auto-print failed after $maxRetries attempts');
  }

  // ===== FCB RECEIPT PRINTING =====

  /// Print receipt for an FCB receipt
  static Future<bool> printFCBReceipt(FCBReceipt fcbReceipt) async {
    if (!isConnected) {
      print('❌ No Bluetooth printer connected');
      return false;
    }

    try {
      print('🖨️ Printing FCB receipt for ${fcbReceipt.receiptNumber}...');

      // Build receipt content
      final receiptData = _buildFCBReceiptData(fcbReceipt);

      // Convert to ESC/POS commands with barcode
      final escPosData = _generateFCBEscPosCommands(receiptData);

      // Send to printer
      await _sendToPrinter(escPosData);

      print('✅ FCB receipt printed successfully: ${fcbReceipt.receiptNumber}');
      return true;
    } catch (e) {
      print('❌ Failed to print FCB receipt: $e');
      return false;
    }
  }

  /// Build FCB receipt data structure
  static Map<String, dynamic> _buildFCBReceiptData(FCBReceipt fcbReceipt) {
    final now = DateTime.now();

    return {
      'header': 'PETEFIN MICROFINANCE',
      'subheader': 'FCB RECEIPT',
      'receiptNumber': fcbReceipt.receiptNumber,
      'date': '${now.day}/${now.month}/${now.year}',
      'time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'clientName': fcbReceipt.fullName,
      'firstName': fcbReceipt.firstName,
      'lastName': fcbReceipt.lastName,
      'amount': fcbReceipt.formattedAmount,
      'currency': 'USD',
      'barcode': fcbReceipt.barcode,
      'branch': fcbReceipt.branch,
      'footer': 'Thank you for your business!',
    };
  }

  /// Generate ESC/POS commands for FCB receipt with barcode
  static List<int> _generateFCBEscPosCommands(Map<String, dynamic> data) {
    List<int> commands = [];

    // Initialize printer
    commands.addAll([27, 64]); // ESC @ (Initialize)
    commands.addAll('\n'.codeUnits); // Top spacing

    // Header - Bold and center
    commands.addAll([27, 69, 1]); // ESC E (Bold on)
    commands.addAll([27, 97, 1]); // ESC a (Center align)
    commands.addAll('${data['header']}\n'.codeUnits);
    commands.addAll('\n'.codeUnits); // Extra spacing

    // Subheader
    commands.addAll('${data['subheader']}\n'.codeUnits);
    commands.addAll([27, 69, 0]); // ESC E (Bold off)
    commands.addAll([27, 97, 0]); // ESC a (Left align)
    commands.addAll('\n'.codeUnits);
    commands.addAll('${'=' * 32}\n'.codeUnits);
    commands.addAll('\n'.codeUnits);

    // Receipt details
    commands.addAll('Receipt No: ${data['receiptNumber']}\n'.codeUnits);
    commands.addAll('Date: ${data['date']}\n'.codeUnits);
    commands.addAll('Time: ${data['time']}\n'.codeUnits);
    commands.addAll('\n'.codeUnits);
    commands.addAll('${'-' * 32}\n'.codeUnits);
    commands.addAll('\n'.codeUnits);

    // Client information
    commands.addAll([27, 69, 1]); // Bold on
    commands.addAll('CLIENT INFORMATION:\n'.codeUnits);
    commands.addAll([27, 69, 0]); // Bold off
    commands.addAll('\n'.codeUnits);
    commands.addAll('Client Name:\n'.codeUnits);
    commands.addAll('  ${data['clientName']}\n'.codeUnits);
    if (data['branch'] != null) {
      commands.addAll('Branch:\n'.codeUnits);
      commands.addAll('  ${data['branch']}\n'.codeUnits);
    }
    commands.addAll('\n'.codeUnits);
    commands.addAll('${'-' * 32}\n'.codeUnits);
    commands.addAll('\n'.codeUnits);

    // Payment details
    commands.addAll([27, 69, 1]); // Bold on
    commands.addAll('FCB PAYMENT DETAILS:\n'.codeUnits);
    commands.addAll([27, 69, 0]); // Bold off
    commands.addAll('\n'.codeUnits);
    commands.addAll('Currency: ${data['currency']}\n'.codeUnits);
    commands.addAll('\n'.codeUnits);
    commands.addAll([27, 69, 1]); // Bold on
    commands.addAll([27, 97, 1]); // Center align for amount
    commands.addAll('AMOUNT: ${data['amount']}\n'.codeUnits);
    commands.addAll([27, 69, 0]); // Bold off
    commands.addAll([27, 97, 0]); // Left align
    commands.addAll('\n'.codeUnits);
    commands.addAll('${'-' * 32}\n'.codeUnits);
    commands.addAll('\n'.codeUnits);

    // Footer
    commands.addAll([27, 97, 1]); // Center align
    commands.addAll('${data['footer']}\n'.codeUnits);
    commands.addAll('\n'.codeUnits);
    commands.addAll('Keep this receipt for\n'.codeUnits);
    commands.addAll('your records.\n'.codeUnits);
    commands.addAll('\n\n\n\n\n'.codeUnits); // Extra bottom spacing

    // Cut paper
    commands.addAll([29, 86, 65, 0]); // GS V A (Full cut)

    return commands;
  }

  /// Auto-print FCB receipt with error handling
  static Future<void> autoPrintFCBReceipt(
    FCBReceipt fcbReceipt, {
    int maxRetries = 3,
  }) async {
    if (!isConnected) {
      print('⚠️ Auto-print skipped: No printer connected');
      return;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
          '🖨️ Auto-print FCB attempt $attempt for ${fcbReceipt.receiptNumber}',
        );

        final success = await printFCBReceipt(fcbReceipt);

        if (success) {
          print('✅ FCB auto-print successful on attempt $attempt');
          return;
        } else {
          if (attempt < maxRetries) {
            print('⚠️ FCB auto-print attempt $attempt failed, retrying...');
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      } catch (e) {
        print('❌ FCB auto-print attempt $attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }

    print('❌ FCB auto-print failed after $maxRetries attempts');
  }

  // ===== PENALTY FEE RECEIPT PRINTING =====

  /// Print receipt for a penalty fee
  static Future<bool> printPenaltyFeeReceipt(PenaltyFee penaltyFee) async {
    if (!isConnected) {
      print('❌ No Bluetooth printer connected');
      return false;
    }

    try {
      print(
        '🖨️ Printing penalty fee receipt for ${penaltyFee.receiptNumber}...',
      );

      // Build receipt content
      final receiptData = _buildPenaltyFeeReceiptData(penaltyFee);

      // Convert to ESC/POS commands with barcode
      final escPosData = _generatePenaltyFeeEscPosCommands(receiptData);

      // Send to printer
      await _sendToPrinter(escPosData);

      print(
        '✅ Penalty fee receipt printed successfully: ${penaltyFee.receiptNumber}',
      );
      return true;
    } catch (e) {
      print('❌ Failed to print penalty fee receipt: $e');
      return false;
    }
  }

  /// Build penalty fee receipt data structure
  static Map<String, dynamic> _buildPenaltyFeeReceiptData(
    PenaltyFee penaltyFee,
  ) {
    final now = DateTime.now();

    return {
      'header': 'PETEFIN MICROFINANCE',
      'subheader': 'PENALTY FEE RECEIPT',
      'receiptNumber': penaltyFee.receiptNumber,
      'date': '${now.day}/${now.month}/${now.year}',
      'time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'clientName': penaltyFee.clientName,
      'amount': penaltyFee.formattedAmount,
      'currency': penaltyFee.currency,
      'branch': penaltyFee.branch,
      'barcode': penaltyFee.receiptNumber
          .replaceAll('PEN', '')
          .substring(0, 12),
      'footer': 'Thank you for your payment!',
    };
  }

  /// Generate ESC/POS commands for penalty fee receipt with barcode
  static List<int> _generatePenaltyFeeEscPosCommands(
    Map<String, dynamic> data,
  ) {
    List<int> commands = [];

    // Initialize printer
    commands.addAll([27, 64]); // ESC @ (Initialize)

    // Header - Bold and center
    commands.addAll([27, 69, 1]); // ESC E (Bold on)
    commands.addAll([27, 97, 1]); // ESC a (Center align)
    commands.addAll('${data['header']}\n'.codeUnits);
    commands.addAll([27, 69, 0]); // ESC E (Bold off)

    // Subheader
    commands.addAll('${data['subheader']}\n'.codeUnits);
    commands.addAll([27, 97, 0]); // ESC a (Left align)
    commands.addAll('${'-' * 32}\n'.codeUnits);

    // Receipt details
    commands.addAll('Receipt: ${data['receiptNumber']}\n'.codeUnits);
    commands.addAll('Date: ${data['date']} ${data['time']}\n'.codeUnits);
    commands.addAll('${'-' * 32}\n'.codeUnits);

    // Client information
    commands.addAll([27, 69, 1]); // Bold on
    commands.addAll('CLIENT DETAILS:\n'.codeUnits);
    commands.addAll([27, 69, 0]); // Bold off
    commands.addAll('Name: ${data['clientName']}\n'.codeUnits);
    commands.addAll('Branch: ${data['branch']}\n'.codeUnits);
    commands.addAll('${'-' * 32}\n'.codeUnits);

    // Payment details
    commands.addAll([27, 69, 1]); // Bold on
    commands.addAll('PENALTY FEE DETAILS:\n'.codeUnits);
    commands.addAll([27, 69, 0]); // Bold off
    commands.addAll('Currency: ${data['currency']}\n'.codeUnits);
    commands.addAll([27, 69, 1]); // Bold on
    commands.addAll('Amount: ${data['amount']}\n'.codeUnits);
    commands.addAll([27, 69, 0]); // Bold off
    commands.addAll('${'-' * 32}\n'.codeUnits);

    // Barcode section
    commands.addAll([27, 97, 1]); // Center align
    commands.addAll([27, 69, 1]); // Bold on
    commands.addAll('BARCODE:\n'.codeUnits);
    commands.addAll([27, 69, 0]); // Bold off
    commands.addAll('|||| ||| |||| ||| ||||\n'.codeUnits);
    commands.addAll('${data['barcode']}\n'.codeUnits);
    commands.addAll('${'-' * 32}\n'.codeUnits);

    // Footer
    commands.addAll('${data['footer']}\n'.codeUnits);
    commands.addAll('\n\n\n'.codeUnits);

    // Cut paper
    commands.addAll([29, 86, 65, 0]); // GS V A (Full cut)

    return commands;
  }

  /// Auto-print penalty fee receipt with error handling
  static Future<void> autoPrintPenaltyFeeReceipt(
    PenaltyFee penaltyFee, {
    int maxRetries = 3,
  }) async {
    if (!isConnected) {
      print('⚠️ Auto-print skipped: No printer connected');
      return;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
          '🖨️ Auto-print penalty fee attempt $attempt for ${penaltyFee.receiptNumber}',
        );

        final success = await printPenaltyFeeReceipt(penaltyFee);

        if (success) {
          print('✅ Penalty fee auto-print successful on attempt $attempt');
          return;
        } else {
          if (attempt < maxRetries) {
            print(
              '⚠️ Penalty fee auto-print attempt $attempt failed, retrying...',
            );
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      } catch (e) {
        print('❌ Penalty fee auto-print attempt $attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }

    print('❌ Penalty fee auto-print failed after $maxRetries attempts');
  }
}
