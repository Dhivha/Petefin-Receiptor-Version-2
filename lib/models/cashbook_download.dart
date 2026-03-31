import 'dart:convert';
import 'package:intl/intl.dart';

enum DownloadStatus { pending, downloading, completed, failed }

class CashbookDownload {
  final int? id;
  final String branchName;
  final DateTime cashbookDate;
  final DownloadStatus status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? filePath;
  final String? errorMessage;

  CashbookDownload({
    this.id,
    required this.branchName,
    required this.cashbookDate,
    this.status = DownloadStatus.pending,
    required this.requestedAt,
    this.completedAt,
    this.filePath,
    this.errorMessage,
  });

  /// Helper getters for display
  String get statusDisplay {
    switch (status) {
      case DownloadStatus.pending:
        return 'Pending';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return 'Failed';
    }
  }

  String get formattedDate {
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(cashbookDate);
  }

  /// Helper methods for UI actions
  bool get canDelete {
    return true; // Can always delete any download record
  }

  bool get canOpen {
    return status == DownloadStatus.completed &&
        filePath != null &&
        filePath!.isNotEmpty;
  }

  bool get canShare {
    return status == DownloadStatus.completed &&
        filePath != null &&
        filePath!.isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchName': branchName,
      'cashbookDate': cashbookDate.toIso8601String(),
      'status': status.name,
      'requestedAt': requestedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'filePath': filePath,
      'errorMessage': errorMessage,
    };
  }

  factory CashbookDownload.fromMap(Map<String, dynamic> map) {
    return CashbookDownload(
      id: map['id']?.toInt(),
      branchName: map['branchName'] ?? '',
      cashbookDate: DateTime.parse(map['cashbookDate']),
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DownloadStatus.pending,
      ),
      requestedAt: DateTime.parse(map['requestedAt']),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      filePath: map['filePath'],
      errorMessage: map['errorMessage'],
    );
  }

  String toJson() => json.encode(toMap());

  factory CashbookDownload.fromJson(String source) =>
      CashbookDownload.fromMap(json.decode(source));

  @override
  String toString() {
    return 'CashbookDownload(id: $id, branchName: $branchName, cashbookDate: $cashbookDate, status: $status, requestedAt: $requestedAt, completedAt: $completedAt, filePath: $filePath, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CashbookDownload &&
        other.id == id &&
        other.branchName == branchName &&
        other.cashbookDate == cashbookDate &&
        other.status == status &&
        other.requestedAt == requestedAt &&
        other.completedAt == completedAt &&
        other.filePath == filePath &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        branchName.hashCode ^
        cashbookDate.hashCode ^
        status.hashCode ^
        requestedAt.hashCode ^
        completedAt.hashCode ^
        filePath.hashCode ^
        errorMessage.hashCode;
  }
}
