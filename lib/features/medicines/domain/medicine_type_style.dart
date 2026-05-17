import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'medicine.dart';
import 'medicine_form_type.dart';

/// Visual identity per form type — icons & accent colors for premium UI.
class MedicineTypeStyle {
  const MedicineTypeStyle({
    required this.icon,
    required this.accent,
    required this.softBg,
  });

  final IconData icon;
  final Color accent;
  final Color softBg;

  static MedicineTypeStyle resolve(Medicine m) {
    final custom = m.customFormLabel?.trim();
    if (m.formType == MedicineFormType.other && custom != null && custom.isNotEmpty) {
      return MedicineTypeStyle(
        icon: Icons.medical_information_rounded,
        accent: AppColors.secondary,
        softBg: AppColors.secondary.withValues(alpha: 0.12),
      );
    }

    return switch (m.formType) {
      MedicineFormType.tablet => MedicineTypeStyle(
          icon: Icons.medication_rounded,
          accent: const Color(0xFF2563EB),
          softBg: const Color(0xFF2563EB).withValues(alpha: 0.12),
        ),
      MedicineFormType.injection => MedicineTypeStyle(
          icon: Icons.vaccines_rounded,
          accent: const Color(0xFFDC2626),
          softBg: const Color(0xFFDC2626).withValues(alpha: 0.12),
        ),
      MedicineFormType.syrup => MedicineTypeStyle(
          icon: Icons.local_drink_rounded,
          accent: const Color(0xFFD97706),
          softBg: const Color(0xFFD97706).withValues(alpha: 0.12),
        ),
      MedicineFormType.capsule => MedicineTypeStyle(
          icon: Icons.egg_alt_rounded,
          accent: AppColors.navyMid,
          softBg: AppColors.navyMid.withValues(alpha: 0.14),
        ),
      MedicineFormType.cream => MedicineTypeStyle(
          icon: Icons.spa_rounded,
          accent: const Color(0xFF059669),
          softBg: const Color(0xFF059669).withValues(alpha: 0.12),
        ),
      MedicineFormType.drops => MedicineTypeStyle(
          icon: Icons.opacity_rounded,
          accent: const Color(0xFF0891B2),
          softBg: const Color(0xFF0891B2).withValues(alpha: 0.12),
        ),
      MedicineFormType.sachet => MedicineTypeStyle(
          icon: Icons.inventory_2_rounded,
          accent: const Color(0xFFCA8A04),
          softBg: const Color(0xFFCA8A04).withValues(alpha: 0.12),
        ),
      MedicineFormType.other => MedicineTypeStyle(
          icon: Icons.category_rounded,
          accent: AppColors.neutral,
          softBg: AppColors.neutral.withValues(alpha: 0.12),
        ),
    };
  }
}

/// Optional image bytes for catalog tile / detail (session-local cache).
Uint8List? medicineThumbBytes(Medicine m) => m.imageBytes;
