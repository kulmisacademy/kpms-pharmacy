import '../auth/kpms_permission_context.dart';
import '../constants/app_routes.dart';
import 'kpms_destinations.dart';

/// Bottom dock slots (excluding center “All modules” hub) — built from RBAC.
class KpmsDockModel {
  const KpmsDockModel({
    required this.left,
    required this.right,
  });

  final List<KpmsDestination> left;
  final List<KpmsDestination> right;

  static const KpmsDockModel empty = KpmsDockModel(left: [], right: []);

  Iterable<KpmsDestination> get allInOrder => [...left, ...right];

  /// Dock tile index: 0–1 left, 2 hub, 3–4 right. Returns null if no tile matches [location].
  int? indexMatchingLocation(String location) {
    for (var i = 0; i < left.length; i++) {
      final d = left[i];
      if (location == d.route || location.startsWith('${d.route}/')) return i;
    }
    for (var j = 0; j < right.length; j++) {
      final d = right[j];
      if (location == d.route || location.startsWith('${d.route}/')) return 3 + j;
    }
    if (location == AppRoutes.appRoot || location == '${AppRoutes.appRoot}/') {
      return left.isNotEmpty && left.first.route == AppRoutes.home ? 0 : null;
    }
    return null;
  }
}

KpmsDestination? _dest(String route) {
  for (final d in kpmsPharmacyDestinations) {
    if (d.route == route) return d;
  }
  return null;
}

bool _ok(KpmsPermissionContext perm, String route) => perm.canAccessLocation(route);

/// Pharmacy dock: up to two primary routes left of hub; right side = **Profile** + alerts / shortcuts
/// (Settings opens from Profile — not duplicated on the dock).
KpmsDockModel kpmsDockModelFor(KpmsPermissionContext perm) {
  if (!perm.staffActive || perm.isPlatformSuperAdmin) return KpmsDockModel.empty;

  if (perm.isPharmacyAdminTier) {
    return KpmsDockModel(
      left: [
        _dest(AppRoutes.home)!,
        _dest(AppRoutes.pos)!,
      ],
      right: [
        if (_ok(perm, AppRoutes.notifications)) _dest(AppRoutes.notifications)!,
        _dest(AppRoutes.profile)!,
      ],
    );
  }

  final left = <KpmsDestination>[];
  const leftPriority = <String>[
    AppRoutes.home,
    AppRoutes.pos,
    AppRoutes.medicines,
    AppRoutes.customers,
    AppRoutes.inventory,
  ];
  for (final r in leftPriority) {
    if (!_ok(perm, r)) continue;
    final d = _dest(r);
    if (d != null && !left.any((e) => e.route == d.route)) left.add(d);
    if (left.length >= 2) break;
  }
  if (left.isEmpty) {
    final land = perm.defaultLandingRoute;
    KpmsDestination? d = _dest(land);
    if (d == null) {
      for (final x in kpmsPharmacyDestinations) {
        if (_ok(perm, x.route)) {
          d = x;
          break;
        }
      }
    }
    if (d != null) left.add(d);
  }

  final right = <KpmsDestination>[];
  void pushRight(String route) {
    if (right.length >= 2) return;
    if (!_ok(perm, route)) return;
    final d = _dest(route);
    if (d == null) return;
    if (right.any((e) => e.route == d.route)) return;
    right.add(d);
  }

  pushRight(AppRoutes.notifications);
  pushRight(AppRoutes.profile);

  const fill = <String>[
    AppRoutes.reports,
    AppRoutes.transactions,
    AppRoutes.medicines,
    AppRoutes.customers,
    AppRoutes.pos,
  ];
  for (final r in fill) {
    if (right.length >= 2) break;
    pushRight(r);
  }

  return KpmsDockModel(
    left: left.take(2).toList(growable: false),
    right: right.take(2).toList(growable: false),
  );
}
