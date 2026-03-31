enum BranchDownloadStatus { pending, downloading, completed, failed }

class BranchDownload {
  final int? id;
  final String downloadType;
  final String displayTitle;
  final String parametersSummary;
  final BranchDownloadStatus status;
  final String? filePath;
  final String fileType; // 'pdf' or 'excel'
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final DateTime expiresAt;

  const BranchDownload({
    this.id,
    required this.downloadType,
    required this.displayTitle,
    required this.parametersSummary,
    required this.status,
    this.filePath,
    required this.fileType,
    required this.requestedAt,
    this.completedAt,
    this.errorMessage,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive =>
      status == BranchDownloadStatus.pending ||
      status == BranchDownloadStatus.downloading;
  bool get isCompleted => status == BranchDownloadStatus.completed;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'downloadType': downloadType,
      'displayTitle': displayTitle,
      'parametersSummary': parametersSummary,
      'status': status.index,
      'filePath': filePath,
      'fileType': fileType,
      'requestedAt': requestedAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'errorMessage': errorMessage,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    };
  }

  factory BranchDownload.fromMap(Map<String, dynamic> map) {
    return BranchDownload(
      id: map['id'] as int?,
      downloadType: map['downloadType'] as String? ?? '',
      displayTitle: map['displayTitle'] as String? ?? '',
      parametersSummary: map['parametersSummary'] as String? ?? '',
      status: BranchDownloadStatus.values[map['status'] as int? ?? 0],
      filePath: map['filePath'] as String?,
      fileType: map['fileType'] as String? ?? 'pdf',
      requestedAt: DateTime.fromMillisecondsSinceEpoch(
          map['requestedAt'] as int? ?? 0),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
      errorMessage: map['errorMessage'] as String?,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
          map['expiresAt'] as int? ?? 0),
    );
  }

  BranchDownload copyWith({
    int? id,
    BranchDownloadStatus? status,
    String? filePath,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return BranchDownload(
      id: id ?? this.id,
      downloadType: downloadType,
      displayTitle: displayTitle,
      parametersSummary: parametersSummary,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      fileType: fileType,
      requestedAt: requestedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      expiresAt: expiresAt,
    );
  }
}

