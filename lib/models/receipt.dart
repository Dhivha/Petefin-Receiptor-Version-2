class Receipt {
  final String id;
  final String title;
  final double amount;
  final String description;
  final DateTime createdAt;
  final String? imageUrl;
  final ReceiptStatus status;
  final String? category;
  final Map<String, dynamic>? metadata;

  Receipt({
    required this.id,
    required this.title,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.imageUrl,
    this.status = ReceiptStatus.pending,
    this.category,
    this.metadata,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      imageUrl: json['imageUrl']?.toString(),
      status: ReceiptStatus.values.firstWhere(
        (e) => e.name == json['status']?.toString(),
        orElse: () => ReceiptStatus.pending,
      ),
      category: json['category']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'imageUrl': imageUrl,
      'status': status.name,
      'category': category,
      'metadata': metadata,
    };
  }

  Receipt copyWith({
    String? id,
    String? title,
    double? amount,
    String? description,
    DateTime? createdAt,
    String? imageUrl,
    ReceiptStatus? status,
    String? category,
    Map<String, dynamic>? metadata,
  }) {
    return Receipt(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      category: category ?? this.category,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'Receipt{id: $id, title: $title, amount: $amount, status: $status}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Receipt && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum ReceiptStatus {
  pending,
  approved,
  rejected,
  processing,
}

extension ReceiptStatusExtension on ReceiptStatus {
  String get displayName {
    switch (this) {
      case ReceiptStatus.pending:
        return 'Pending';
      case ReceiptStatus.approved:
        return 'Approved';
      case ReceiptStatus.rejected:
        return 'Rejected';
      case ReceiptStatus.processing:
        return 'Processing';
    }
  }

  String get description {
    switch (this) {
      case ReceiptStatus.pending:
        return 'Waiting for review';
      case ReceiptStatus.approved:
        return 'Receipt has been approved';
      case ReceiptStatus.rejected:
        return 'Receipt was rejected';
      case ReceiptStatus.processing:
        return 'Currently being processed';
    }
  }
}