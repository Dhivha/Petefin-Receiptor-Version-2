class CollateralSubmission {
  final String submissionId;
  final String clientId;
  final String disbursementStartDate;
  final String disbursementEndDate;
  final List<String> imageUrls;
  final String syncStatus;
  final int syncAttempts;
  final String? lastSyncError;
  final int? lastSyncAttempt;
  final int createdAt;
  final int updatedAt;

  CollateralSubmission({
    required this.submissionId,
    required this.clientId,
    required this.disbursementStartDate,
    required this.disbursementEndDate,
    required this.imageUrls,
    this.syncStatus = 'queued',
    this.syncAttempts = 0,
    this.lastSyncError,
    this.lastSyncAttempt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CollateralSubmission.fromMap(Map<String, dynamic> map) {
    return CollateralSubmission(
      submissionId: map['submissionId'] as String,
      clientId: map['clientId'] as String,
      disbursementStartDate: map['disbursementStartDate'] as String,
      disbursementEndDate: map['disbursementEndDate'] as String,
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      syncStatus: map['syncStatus'] as String? ?? 'queued',
      syncAttempts: map['syncAttempts'] as int? ?? 0,
      lastSyncError: map['lastSyncError'] as String?,
      lastSyncAttempt: map['lastSyncAttempt'] as int?,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'submissionId': submissionId,
      'clientId': clientId,
      'disbursementStartDate': disbursementStartDate,
      'disbursementEndDate': disbursementEndDate,
      'imageUrls': imageUrls,
      'syncStatus': syncStatus,
      'syncAttempts': syncAttempts,
      'lastSyncError': lastSyncError,
      'lastSyncAttempt': lastSyncAttempt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  CollateralSubmission copyWith({
    String? submissionId,
    String? clientId,
    String? disbursementStartDate,
    String? disbursementEndDate,
    List<String>? imageUrls,
    String? syncStatus,
    int? syncAttempts,
    String? lastSyncError,
    int? lastSyncAttempt,
    int? createdAt,
    int? updatedAt,
  }) {
    return CollateralSubmission(
      submissionId: submissionId ?? this.submissionId,
      clientId: clientId ?? this.clientId,
      disbursementStartDate: disbursementStartDate ?? this.disbursementStartDate,
      disbursementEndDate: disbursementEndDate ?? this.disbursementEndDate,
      imageUrls: imageUrls ?? this.imageUrls,
      syncStatus: syncStatus ?? this.syncStatus,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastSyncError: lastSyncError ?? this.lastSyncError,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}