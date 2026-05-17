/// Canonical medicine forms — dropdown + optional user-defined labels ([Medicine.customFormLabel]).
enum MedicineFormType {
  tablet,
  injection,
  syrup,
  capsule,
  cream,
  drops,
  sachet,
  other,
}

extension MedicineFormTypeLabel on MedicineFormType {
  String get label => switch (this) {
        MedicineFormType.tablet => 'Tablet',
        MedicineFormType.injection => 'Injection',
        MedicineFormType.syrup => 'Syrup',
        MedicineFormType.capsule => 'Capsule',
        MedicineFormType.cream => 'Cream',
        MedicineFormType.drops => 'Drops',
        MedicineFormType.sachet => 'Sachet',
        MedicineFormType.other => 'Other',
      };
}
