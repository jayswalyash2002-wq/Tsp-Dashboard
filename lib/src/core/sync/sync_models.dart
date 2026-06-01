enum SyncStatus {
  synced,
  pending,
  failed,
  offline;
}

class SyncMetadata {
  final String localId;
  final String? firestoreId;
  final bool synced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int retryCount;

  SyncMetadata({
    required this.localId,
    this.firestoreId,
    this.synced = false,
    required this.createdAt,
    required this.updatedAt,
    this.retryCount = 0,
  });

  SyncMetadata copyWith({
    String? firestoreId,
    bool? synced,
    DateTime? updatedAt,
    int? retryCount,
  }) {
    return SyncMetadata(
      localId: localId,
      firestoreId: firestoreId ?? this.firestoreId,
      synced: synced ?? this.synced,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'firestoreId': firestoreId,
      'synced': synced,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory SyncMetadata.fromMap(Map<String, dynamic> map) {
    return SyncMetadata(
      localId: map['localId'],
      firestoreId: map['firestoreId'],
      synced: map['synced'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      retryCount: map['retryCount'] ?? 0,
    );
  }
}
