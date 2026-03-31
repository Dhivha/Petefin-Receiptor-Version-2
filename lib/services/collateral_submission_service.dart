import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../models/collateral_submission.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

class CollateralSubmissionService {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final AuthService _authService = AuthService();

  // Singleton pattern
  static final CollateralSubmissionService _instance = CollateralSubmissionService._internal();
  factory CollateralSubmissionService() => _instance;
  CollateralSubmissionService._internal();

  /// Submit collateral documents locally and queue for sync
  Future<Map<String, dynamic>> submitCollateralDocuments({
    required String clientId,
    required DateTime disbursementStartDate,
    required DateTime disbursementEndDate,
    required List<Map<String, dynamic>> images, // [{'bytes': Uint8List, 'extension': String}]
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate a temporary submission ID for queued submission
      final tempSubmissionId = 'TEMP_SUB_${DateTime.now().millisecondsSinceEpoch}';

      // Convert images to base64 for storage
      final List<Map<String, dynamic>> imageFiles = images.map((img) {
        final bytes = img['bytes'] as Uint8List;
        final extension = img['extension'] as String;
        return {
          'data': base64Encode(bytes),
          'extension': extension,
        };
      }).toList();

      // Prepare submission data for local storage
      final submissionData = {
        'submissionId': tempSubmissionId,
        'clientId': clientId,
        'disbursementStartDate': disbursementStartDate.toIso8601String(),
        'disbursementEndDate': disbursementEndDate.toIso8601String(),
        'imageFiles': jsonEncode(imageFiles),
        'syncStatus': 'queued',
        'syncAttempts': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      // Save to local database
      await _databaseHelper.insertQueuedCollateralSubmission(submissionData);

      // Attempt immediate sync
      final syncResult = await _attemptSubmissionSync(tempSubmissionId);

      return {
        'success': true,
        'message': syncResult['success']
            ? 'Collateral documents submitted and synced successfully'
            : 'Collateral documents saved locally. Will sync when online.',
        'submissionId': tempSubmissionId,
        'synced': syncResult['success'],
        'syncedSubmissionId': syncResult['submissionId'],
      };
    } catch (e) {
      print('Error submitting collateral documents: $e');
      return {
        'success': false,
        'message': 'Failed to submit collateral documents: $e'
      };
    }
  }

  /// Attempt to sync a single queued submission
  Future<Map<String, dynamic>> _attemptSubmissionSync(String tempSubmissionId) async {
    try {
      final queuedSubmissions = await _databaseHelper.getQueuedCollateralSubmissions();
      final submissionData = queuedSubmissions.firstWhere(
        (submission) => submission['submissionId'] == tempSubmissionId,
        orElse: () => <String, dynamic>{},
      );

      if (submissionData.isEmpty) {
        return {'success': false, 'message': 'Submission not found'};
      }

      // Parse image files from storage
      final imageFilesJson = submissionData['imageFiles'] as String;
      final imageFilesList = (jsonDecode(imageFilesJson) as List)
          .cast<Map<String, dynamic>>();

      // Convert back to bytes for API call
      final List<Map<String, dynamic>> images = imageFilesList.map((img) {
        final data = img['data'] as String;
        final extension = img['extension'] as String;
        return {
          'bytes': base64Decode(data),
          'extension': extension,
        };
      }).toList();

      final response = await _apiService.submitCollateralDocuments(
        clientId: submissionData['clientId'],
        disbursementStartDate: submissionData['disbursementStartDate'],
        disbursementEndDate: submissionData['disbursementEndDate'],
        images: images,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Check if the response contains success indicators
        if (responseData.containsKey('message') &&
            responseData['message'].toString().contains('successfully') &&
            responseData.containsKey('submissionId')) {

          final syncedSubmissionId = responseData['submissionId'].toString();
          final imageUrls = List<String>.from(responseData['imageUrls'] ?? []);

          try {
            // Move from queued to synced
            await _databaseHelper.moveQueuedCollateralSubmissionToSynced(
              tempSubmissionId,
              syncedSubmissionId,
              imageUrls,
            );

            return {
              'success': true,
              'message': responseData['message'],
              'submissionId': syncedSubmissionId,
              'imageUrls': imageUrls,
            };
          } catch (dbError) {
            print('Database error while syncing collateral submission: $dbError');
            // Just delete the queued submission since API call was successful
            await _databaseHelper.deleteQueuedCollateralSubmission(tempSubmissionId);
            return {
              'success': true,
              'message': 'Collateral documents synced successfully (database updated)',
              'submissionId': syncedSubmissionId,
              'imageUrls': imageUrls,
            };
          }
        } else {
          // API returned 200 but with error content
          final errorMessage = responseData['message'] ?? 'Sync failed';
          await _databaseHelper.updateQueuedCollateralSubmissionSyncAttempt(
            tempSubmissionId,
            errorMessage,
          );
          return {'success': false, 'message': errorMessage};
        }
      } else {
        // Update sync attempt
        final errorMessage = response.statusCode == 400 && response.body.isNotEmpty
            ? json.decode(response.body)['message'] ?? 'Sync failed'
            : 'Server error: ${response.statusCode}';

        await _databaseHelper.updateQueuedCollateralSubmissionSyncAttempt(
          tempSubmissionId,
          errorMessage,
        );

        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      print('Collateral submission sync error: $e');
      await _databaseHelper.updateQueuedCollateralSubmissionSyncAttempt(
        tempSubmissionId,
        e.toString(),
      );

      return {'success': false, 'message': 'Sync failed: $e'};
    }
  }

  /// Pick multiple images from gallery
  Future<List<Map<String, dynamic>>> pickImagesFromGallery({
    int maxImages = 10,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (images.length > maxImages) {
        throw Exception('Maximum $maxImages images allowed');
      }

      final List<Map<String, dynamic>> result = [];

      for (final image in images) {
        final bytes = await image.readAsBytes();
        final extension = image.path.split('.').last.toLowerCase();

        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          throw Exception('Only JPG and PNG images are supported');
        }

        result.add({
          'bytes': bytes,
          'extension': extension,
          'path': image.path,
          'size': bytes.length,
        });
      }

      return result;
    } catch (e) {
      print('Error picking images: $e');
      throw e;
    }
  }

  /// Get all queued collateral submissions
  Future<List<Map<String, dynamic>>> getQueuedCollateralSubmissions() async {
    return await _databaseHelper.getQueuedCollateralSubmissionsByStatus('queued');
  }

  /// Get all synced collateral submissions
  Future<List<Map<String, dynamic>>> getSyncedCollateralSubmissions() async {
    return await _databaseHelper.getSyncedCollateralSubmissions();
  }

  /// Get collateral submissions for a specific client
  Future<List<Map<String, dynamic>>> getCollateralSubmissionsByClient(
    String clientId,
  ) async {
    return await _databaseHelper.getCollateralSubmissionsByClientId(clientId);
  }

  /// Delete queued collateral submission after confirmation
  Future<bool> deleteQueuedSubmission(String submissionId) async {
    try {
      final result =
          await _databaseHelper.deleteQueuedCollateralSubmission(submissionId);
      return result > 0;
    } catch (e) {
      print('Error deleting queued collateral submission: $e');
      return false;
    }
  }

  /// Auto-sync all queued collateral submissions (background service)
  Future<void> autoSyncQueuedSubmissions() async {
    try {
      final queuedSubmissions =
          await _databaseHelper.getQueuedCollateralSubmissionsByStatus('queued');

      for (final submissionData in queuedSubmissions) {
        final submissionId = submissionData['submissionId'] as String;
        final syncAttempts = submissionData['syncAttempts'] as int? ?? 0;

        // Skip if too many attempts (max 3)
        if (syncAttempts >= 3) continue;

        // Skip if recently attempted (wait at least 5 minutes)
        final lastAttempt = submissionData['lastSyncAttempt'] as int?;
        if (lastAttempt != null) {
          final timeSinceLastAttempt =
              DateTime.now().millisecondsSinceEpoch - lastAttempt;
          if (timeSinceLastAttempt < 300000) continue; // 5 minutes
        }

        await _attemptSubmissionSync(submissionId);

        // Small delay between sync attempts
        await Future.delayed(const Duration(seconds: 3));
      }
    } catch (e) {
      print('Auto-sync collateral submissions error: $e');
    }
  }

  /// Get counts for queued and synced submissions
  Future<Map<String, int>> getSubmissionCounts() async {
    final queuedCount =
        await _databaseHelper.getQueuedCollateralSubmissionsCount();
    final syncedSubmissions = await getSyncedCollateralSubmissions();

    return {
      'queued': queuedCount,
      'synced': syncedSubmissions.length,
    };
  }
}