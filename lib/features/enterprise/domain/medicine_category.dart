/// Nested medicine category (tenant-scoped).
class MedicineCategory {
  const MedicineCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? parentId;
  final int sortOrder;

  static String newClientId() =>
      'cat-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  MedicineCategory copyWith({
    String? name,
    String? parentId,
    int? sortOrder,
    bool clearParent = false,
  }) {
    return MedicineCategory(
      id: id,
      name: name ?? this.name,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentId': parentId,
        'sortOrder': sortOrder,
      };

  static MedicineCategory fromJson(Map<String, dynamic> j) => MedicineCategory(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        parentId: j['parentId'] as String?,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      );
}
