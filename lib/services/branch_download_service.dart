import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/branch_download.dart';
import 'database_helper.dart';

class BranchDownloadService {
  final DatabaseHelper _db = DatabaseHelper();

  /// Returns the top [limit] recent downloads for the given [downloadType].
  /// Also cleans up any expired downloads first.
  Future<List<BranchDownload>> getRecentDownloads(
    String downloadType, {
    int limit = 5,
  }) async {
    await _cleanupExpired();
    return await _db.getRecentBranchDownloads(downloadType, limit: limit);
  }

  /// Creates a download record and fires off the download in the background.
  /// Returns immediately — the download continues even if the caller navigates away.
  Future<void> startDownload({
    required String downloadType,
    required String displayTitle,
    required String parametersSummary,
    required String fileType,
    required Future<http.Response> Function() apiFn,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 12));

    final record = BranchDownload(
      downloadType: downloadType,
      displayTitle: displayTitle,
      parametersSummary: parametersSummary,
      status: BranchDownloadStatus.downloading,
      fileType: fileType,
      requestedAt: now,
      expiresAt: expiresAt,
    );

    final id = await _db.insertBranchDownload(record);

    // Fire-and-forget — intentionally not awaited so the UI is not blocked
    // and the download continues even if the user navigates away.
    unawaited(_performDownload(id, fileType, apiFn));
  }

  // ─── Internal helpers ───────────────────────────────────────────────────

  Future<void> _performDownload(
    int id,
    String fileType,
    Future<http.Response> Function() apiFn,
  ) async {
    try {
      print('[BranchDownload] id=$id starting download…');
      final response = await apiFn();
      print('[BranchDownload] id=$id status=${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.bodyBytes.isEmpty) {
          await _db.updateBranchDownloadFailed(id, 'Server returned empty file');
          return;
        }
        final filePath = await _saveFile(response.bodyBytes, fileType, id);
        await _db.updateBranchDownloadCompleted(id, filePath: filePath);
        print('[BranchDownload] id=$id saved to $filePath');
      } else {
        await _db.updateBranchDownloadFailed(
          id,
          'Server returned HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[BranchDownload] id=$id error: $e');
      await _db.updateBranchDownloadFailed(id, e.toString());
    }
  }

  Future<String> _saveFile(List<int> bytes, String fileType, int id) async {
    final dir = await getApplicationDocumentsDirectory();
    final extension = fileType == 'pdf' ? 'pdf' : 'xlsx';
    final fileName =
        'dl_${id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final folder = Directory(p.join(dir.path, 'branch_downloads'));
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File(p.join(folder.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _cleanupExpired() async {
    try {
      final expired = await _db.getExpiredBranchDownloads();
      for (final record in expired) {
        await deleteById(record.id!);
      }
    } catch (e) {
      print('[BranchDownload] cleanup error: $e');
    }
  }

  /// Deletes the download record and its associated file on disk.
  Future<void> deleteById(int id) async {
    try {
      final record = await _db.getBranchDownloadById(id);
      if (record?.filePath != null) {
        final file = File(record!.filePath!);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    await _db.deleteBranchDownload(id);
  }
}

