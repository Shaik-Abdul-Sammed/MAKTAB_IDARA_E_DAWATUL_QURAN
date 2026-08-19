class SyncDTO {
  final String lastSyncDate;
  final int pendingItems;
  final bool isSyncing;

  SyncDTO({
    required this.lastSyncDate,
    this.pendingItems = 0,
    this.isSyncing = false,
  });

  Map<String, dynamic> toMap() => {
    'lastSyncDate': lastSyncDate,
    'pendingItems': pendingItems,
    'isSyncing': isSyncing,
  };

  factory SyncDTO.fromMap(Map<String, dynamic> map) => SyncDTO(
    lastSyncDate: map['lastSyncDate'],
    pendingItems: map['pendingItems'] ?? 0,
    isSyncing: map['isSyncing'] ?? false,
  );
}