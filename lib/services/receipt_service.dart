import 'dart:convert';
import '../models/receipt.dart';
import 'api_service.dart';

class ReceiptService {
  final ApiService _apiService = ApiService();

  /// Get all receipts
  Future<List<Receipt>> getReceipts() async {
    try {
      final response = await _apiService.get('/api/receipts');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Receipt.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load receipts: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting receipts: $e');
      rethrow;
    }
  }

  /// Get a specific receipt by ID
  Future<Receipt?> getReceiptById(String id) async {
    try {
      final response = await _apiService.get('/api/receipts/$id');

      if (response.statusCode == 200) {
        return Receipt.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load receipt: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting receipt by ID: $e');
      rethrow;
    }
  }

  /// Create a new receipt
  Future<Receipt> createReceipt(Receipt receipt) async {
    try {
      final response = await _apiService.post(
        '/api/receipts',
        body: json.encode(receipt.toJson()),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Receipt.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create receipt: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating receipt: $e');
      rethrow;
    }
  }

  /// Update an existing receipt
  Future<Receipt> updateReceipt(Receipt receipt) async {
    try {
      final response = await _apiService.post(
        '/api/receipts/${receipt.id}',
        body: json.encode(receipt.toJson()),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return Receipt.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update receipt: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating receipt: $e');
      rethrow;
    }
  }

  /// Delete a receipt
  Future<bool> deleteReceipt(String id) async {
    try {
      final response = await _apiService.get('/api/receipts/$id/delete');

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error deleting receipt: $e');
      return false;
    }
  }

  /// Upload receipt image
  Future<String?> uploadReceiptImage(String receiptId, String imagePath) async {
    try {
      // For now, this is a placeholder. You would typically use multipart upload
      final response = await _apiService.post(
        '/api/receipts/$receiptId/upload',
        body: json.encode({'imagePath': imagePath}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['imageUrl'];
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading receipt image: $e');
      return null;
    }
  }

  /// Get receipts by status
  Future<List<Receipt>> getReceiptsByStatus(ReceiptStatus status) async {
    try {
      final response = await _apiService.get(
        '/api/receipts?status=${status.name}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Receipt.fromJson(item)).toList();
      } else {
        throw Exception(
          'Failed to load receipts by status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error getting receipts by status: $e');
      rethrow;
    }
  }

  /// Search receipts by title or description
  Future<List<Receipt>> searchReceipts(String query) async {
    try {
      final response = await _apiService.get(
        '/api/receipts/search?q=${Uri.encodeComponent(query)}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Receipt.fromJson(item)).toList();
      } else {
        throw Exception('Failed to search receipts: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching receipts: $e');
      rethrow;
    }
  }

  /// Get current API URL being used
  String getCurrentApiUrl() {
    return _apiService.getCurrentUrl();
  }

  /// Test both API URLs
  Future<Map<String, bool>> testApiUrls() async {
    return await _apiService.testBothUrls();
  }

  /// Manually switch API URL
  Future<void> switchApiUrl() async {
    await _apiService.forceSwitchUrl();
  }

  /// Reset to primary URL
  Future<void> resetToPrimaryUrl() async {
    await _apiService.resetToPrimaryUrl();
  }
}
