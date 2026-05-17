# KPMS — KULMIS Pharmacy Management System

Flutter client for the multi-tenant pharmacy SaaS described in `../kulmis_pharmacy_management_system_full_prd.md` (at repo root).

**Brand / UI:** **Clinical Precision** design tokens live in `lib/core/theme/app_colors.dart` — primary `#8069BF`, secondary `#7C7296`, tertiary `#C9A74D`, neutral `#79767D`; typography **Plus Jakarta Sans** via `app_theme.dart`; cards use **16px** radius.

## Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable), `flutter doctor` clean

## Supabase (auth + database)

1. Create a Supabase project and run all SQL in `supabase/migrations/` in order (SQL Editor or `supabase db push`). Includes: core schema + RLS, idempotent `register_pharmacy`, and `ensure_my_profile()` so older accounts get a `profiles` row without relying only on the signup trigger.
2. In **Authentication → Providers**, enable Email; if **Confirm email** is on, new users get no session until they confirm — the app sends them to **Verify email** and they complete pharmacy registration after first sign-in when a session exists.
3. Run the Flutter app with your project URL and anon key:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Without those defines, the app shows a **configuration screen** — Supabase URL and anon key are required to run KPMS.

## Run the app

From this folder (`kpms`):

```bash
cd kpms
flutter pub get
flutter devices
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

**Pick a device** when prompted, or target one explicitly:

| Target        | Command |
|---------------|---------|
| Chrome (web)  | `flutter run -d chrome` |
| Windows       | `flutter run -d windows` (enable with `flutter config --enable-windows-desktop` if needed) |
| Android       | `flutter run -d <deviceId>` (emulator or USB) |

**First-time flow:** branding splash → sign in / register pharmacy → dashboard. Use the **drawer**, **All** sheet on mobile, or **Modules** to open screens.

## Verify the build (CI / local)

```bash
flutter analyze
flutter test
flutter build web --release
```

## Feature coverage

All routes in `lib/core/constants/app_routes.dart` are registered in `lib/routes/app_router.dart`. Navigation hubs:

- **Drawer:** `lib/core/widgets/kpms_app_drawer.dart` — pharmacy + platform destinations  
- **Mobile bottom nav & All hub:** `lib/core/widgets/kpms_mobile_bottom_nav.dart` + `kpms_all_features_sheet.dart`  
- **Lists:** `lib/core/navigation/kpms_destinations.dart`

Included modules: authentication (login, forgot password, verify email), pharmacy registration, dashboard, medicines, inventory, POS, sales/purchases & returns, suppliers, customers, prescriptions, staff, reports, subscriptions, notifications, settings, barcode scan stub, Super Admin (home, pharmacies, plans, support, announcements). Unknown URLs show a **not found** screen with a path to home.

## Project layout

- `lib/core/` — theme, routes, navigation, shared widgets  
- `lib/features/<module>/` — feature screens per PRD  
- `lib/routes/app_router.dart` — GoRouter + page transitions  

For Flutter help, see the [documentation](https://docs.flutter.dev/).
