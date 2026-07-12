import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_so.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('so'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'KPMS'**
  String get appTitle;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get commonUpdate;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commonNotSet;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @shellAllModules.
  ///
  /// In en, this message translates to:
  /// **'All modules'**
  String get shellAllModules;

  /// No description provided for @shellBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get shellBack;

  /// No description provided for @shellHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellHome;

  /// No description provided for @shellNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get shellNotifications;

  /// No description provided for @shellToggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle theme'**
  String get shellToggleTheme;

  /// No description provided for @drawerAllModulesTagline.
  ///
  /// In en, this message translates to:
  /// **'All modules'**
  String get drawerAllModulesTagline;

  /// No description provided for @drawerPharmacySection.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get drawerPharmacySection;

  /// No description provided for @drawerPlatformSection.
  ///
  /// In en, this message translates to:
  /// **'Platform (Super Admin)'**
  String get drawerPlatformSection;

  /// No description provided for @dockHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get dockHome;

  /// No description provided for @dockPos.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get dockPos;

  /// No description provided for @dockAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get dockAll;

  /// No description provided for @dockAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get dockAlerts;

  /// No description provided for @dockSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get dockSettings;

  /// No description provided for @dockReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get dockReports;

  /// No description provided for @navDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboardTitle;

  /// No description provided for @navDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Overview and quick actions'**
  String get navDashboardSubtitle;

  /// No description provided for @navMedicinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get navMedicinesTitle;

  /// No description provided for @navMedicinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog, batches, and expiry'**
  String get navMedicinesSubtitle;

  /// No description provided for @navInventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventoryTitle;

  /// No description provided for @navInventorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stock levels and alerts'**
  String get navInventorySubtitle;

  /// No description provided for @navPosTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get navPosTitle;

  /// No description provided for @navPosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage daily pharmacy sales'**
  String get navPosSubtitle;

  /// No description provided for @navSalesReturnsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales returns'**
  String get navSalesReturnsTitle;

  /// No description provided for @navSalesReturnsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Refunds and stock restore'**
  String get navSalesReturnsSubtitle;

  /// No description provided for @navDebtsTitle.
  ///
  /// In en, this message translates to:
  /// **'Debts & credit'**
  String get navDebtsTitle;

  /// No description provided for @navDebtsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customer AR and supplier AP'**
  String get navDebtsSubtitle;

  /// No description provided for @navPurchasesTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get navPurchasesTitle;

  /// No description provided for @navPurchasesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track supplier purchases'**
  String get navPurchasesSubtitle;

  /// No description provided for @navPurchaseReturnsTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase returns'**
  String get navPurchaseReturnsTitle;

  /// No description provided for @navPurchaseReturnsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Supplier credits and stock'**
  String get navPurchaseReturnsSubtitle;

  /// No description provided for @navSuppliersTitle.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get navSuppliersTitle;

  /// No description provided for @navSuppliersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts and payments'**
  String get navSuppliersSubtitle;

  /// No description provided for @navCustomersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomersTitle;

  /// No description provided for @navCustomersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles and visit history'**
  String get navCustomersSubtitle;

  /// No description provided for @navPrescriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get navPrescriptionsTitle;

  /// No description provided for @navPrescriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload and verify scripts'**
  String get navPrescriptionsSubtitle;

  /// No description provided for @navStaffTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get navStaffTitle;

  /// No description provided for @navStaffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Roles and permissions'**
  String get navStaffSubtitle;

  /// No description provided for @navReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReportsTitle;

  /// No description provided for @navReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics and business insights'**
  String get navReportsSubtitle;

  /// No description provided for @navTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get navTransactionsTitle;

  /// No description provided for @navTransactionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sales, purchases, returns, exports'**
  String get navTransactionsSubtitle;

  /// No description provided for @navSubscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get navSubscriptionsTitle;

  /// No description provided for @navSubscriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plans and billing'**
  String get navSubscriptionsSubtitle;

  /// No description provided for @navNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotificationsTitle;

  /// No description provided for @navNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts and reminders'**
  String get navNotificationsSubtitle;

  /// No description provided for @navSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettingsTitle;

  /// No description provided for @navSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy profile and security'**
  String get navSettingsSubtitle;

  /// No description provided for @navBarcodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Barcode scan'**
  String get navBarcodeTitle;

  /// No description provided for @navBarcodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fast lookup and POS add'**
  String get navBarcodeSubtitle;

  /// No description provided for @navProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfileTitle;

  /// No description provided for @navProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Account, language, and sign out'**
  String get navProfileSubtitle;

  /// No description provided for @navSuperHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Super Admin home'**
  String get navSuperHomeTitle;

  /// No description provided for @navSuperHomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Platform KPIs'**
  String get navSuperHomeSubtitle;

  /// No description provided for @navSuperPharmaciesTitle.
  ///
  /// In en, this message translates to:
  /// **'All pharmacies'**
  String get navSuperPharmaciesTitle;

  /// No description provided for @navSuperPharmaciesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tenant directory'**
  String get navSuperPharmaciesSubtitle;

  /// No description provided for @navSuperPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription plans'**
  String get navSuperPlansTitle;

  /// No description provided for @navSuperPlansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create & edit plans'**
  String get navSuperPlansSubtitle;

  /// No description provided for @navSuperSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support tickets'**
  String get navSuperSupportTitle;

  /// No description provided for @navSuperSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help desk'**
  String get navSuperSupportSubtitle;

  /// No description provided for @navSuperAnnouncementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get navSuperAnnouncementsTitle;

  /// No description provided for @navSuperAnnouncementsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Broadcast to tenants'**
  String get navSuperAnnouncementsSubtitle;

  /// No description provided for @navSuperRevenueTitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue & analytics'**
  String get navSuperRevenueTitle;

  /// No description provided for @navSuperRevenueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'MRR, ARR, and platform sales'**
  String get navSuperRevenueSubtitle;

  /// No description provided for @navSuperUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Users & directory'**
  String get navSuperUsersTitle;

  /// No description provided for @navSuperUsersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Active accounts across tenants'**
  String get navSuperUsersSubtitle;

  /// No description provided for @navSuperApprovalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get navSuperApprovalsTitle;

  /// No description provided for @navSuperApprovalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New pharmacy onboarding'**
  String get navSuperApprovalsSubtitle;

  /// No description provided for @navSuperAuditTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit logs'**
  String get navSuperAuditTitle;

  /// No description provided for @navSuperAuditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Immutable activity trail'**
  String get navSuperAuditSubtitle;

  /// No description provided for @navSuperSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get navSuperSessionsTitle;

  /// No description provided for @navSuperSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in footprint'**
  String get navSuperSessionsSubtitle;

  /// No description provided for @navSuperMonitoringTitle.
  ///
  /// In en, this message translates to:
  /// **'System health'**
  String get navSuperMonitoringTitle;

  /// No description provided for @navSuperMonitoringSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Latency, errors, quotas'**
  String get navSuperMonitoringSubtitle;

  /// No description provided for @navSuperGlobalSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Global settings'**
  String get navSuperGlobalSettingsTitle;

  /// No description provided for @navSuperGlobalSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Feature flags & policies'**
  String get navSuperGlobalSettingsSubtitle;

  /// No description provided for @platformRememberDevice.
  ///
  /// In en, this message translates to:
  /// **'Remember this device'**
  String get platformRememberDevice;

  /// No description provided for @platformRememberDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Preference is saved on this device. You can sign out from Profile in the pharmacy app.'**
  String get platformRememberDeviceHint;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy profile, pricing, and security'**
  String get settingsSubtitle;

  /// No description provided for @settingsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load pharmacy settings'**
  String get settingsLoadError;

  /// No description provided for @settingsNoPharmacy.
  ///
  /// In en, this message translates to:
  /// **'No pharmacy is linked to this account. Complete registration first.'**
  String get settingsNoPharmacy;

  /// No description provided for @settingsRestoringWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Restoring your pharmacy workspace…'**
  String get settingsRestoringWorkspace;

  /// No description provided for @settingsRetryingProfile.
  ///
  /// In en, this message translates to:
  /// **'Retrying profile connection…'**
  String get settingsRetryingProfile;

  /// No description provided for @settingsLicenseNotSet.
  ///
  /// In en, this message translates to:
  /// **'License not set'**
  String get settingsLicenseNotSet;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionRegionFormats.
  ///
  /// In en, this message translates to:
  /// **'Region & formats'**
  String get settingsSectionRegionFormats;

  /// No description provided for @settingsSectionPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get settingsSectionPricing;

  /// No description provided for @settingsSectionReceipts.
  ///
  /// In en, this message translates to:
  /// **'Receipt & invoice'**
  String get settingsSectionReceipts;

  /// No description provided for @settingsSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsSectionNotifications;

  /// No description provided for @settingsSectionStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff & permissions'**
  String get settingsSectionStaff;

  /// No description provided for @settingsSectionSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSectionSecurity;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsHeroEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsHeroEdit;

  /// No description provided for @settingsGeneralSummary.
  ///
  /// In en, this message translates to:
  /// **'Name, logo, contact, currency, and timezone'**
  String get settingsGeneralSummary;

  /// No description provided for @settingsGeneralOpen.
  ///
  /// In en, this message translates to:
  /// **'Open general settings'**
  String get settingsGeneralOpen;

  /// No description provided for @settingsLanguageRegionSummary.
  ///
  /// In en, this message translates to:
  /// **'Language, region, and formats'**
  String get settingsLanguageRegionSummary;

  /// No description provided for @settingsLanguagePick.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguagePick;

  /// No description provided for @settingsRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get settingsRegion;

  /// No description provided for @settingsDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get settingsDateFormat;

  /// No description provided for @settingsNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get settingsNumberFormat;

  /// No description provided for @settingsPricingSummary.
  ///
  /// In en, this message translates to:
  /// **'Margins, tax, decimals, and discounts'**
  String get settingsPricingSummary;

  /// No description provided for @settingsPricingOpen.
  ///
  /// In en, this message translates to:
  /// **'Open pricing settings'**
  String get settingsPricingOpen;

  /// No description provided for @settingsReceiptSummary.
  ///
  /// In en, this message translates to:
  /// **'Footer, print options, and barcode strip'**
  String get settingsReceiptSummary;

  /// No description provided for @settingsReceiptOpen.
  ///
  /// In en, this message translates to:
  /// **'Open receipt settings'**
  String get settingsReceiptOpen;

  /// No description provided for @settingsNotificationSummary.
  ///
  /// In en, this message translates to:
  /// **'Stock, expiry, debt, and alerts'**
  String get settingsNotificationSummary;

  /// No description provided for @settingsNotificationOpen.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get settingsNotificationOpen;

  /// No description provided for @settingsStaffSummary.
  ///
  /// In en, this message translates to:
  /// **'Roles, templates, and staff security'**
  String get settingsStaffSummary;

  /// No description provided for @settingsStaffOpen.
  ///
  /// In en, this message translates to:
  /// **'Manage staff'**
  String get settingsStaffOpen;

  /// No description provided for @settingsSecuritySummary.
  ///
  /// In en, this message translates to:
  /// **'Password, sessions, and device access'**
  String get settingsSecuritySummary;

  /// No description provided for @settingsAboutOpen.
  ///
  /// In en, this message translates to:
  /// **'Version, legal, and support'**
  String get settingsAboutOpen;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsThemeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeModeLight;

  /// No description provided for @settingsThemeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeModeDark;

  /// No description provided for @settingsThemeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsThemeModeSystem;

  /// No description provided for @settingsManageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get settingsManageSubscription;

  /// No description provided for @settingsTaxOpen.
  ///
  /// In en, this message translates to:
  /// **'Tax configuration'**
  String get settingsTaxOpen;

  /// No description provided for @settingsTaxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sales tax at checkout'**
  String get settingsTaxSubtitle;

  /// No description provided for @settingsInvoiceOpen.
  ///
  /// In en, this message translates to:
  /// **'Receipt & invoice template'**
  String get settingsInvoiceOpen;

  /// No description provided for @settingsSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get settingsSessionTitle;

  /// No description provided for @settingsSessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You are signed in on this device via Supabase Auth'**
  String get settingsSessionSubtitle;

  /// No description provided for @settingsSessionSnack.
  ///
  /// In en, this message translates to:
  /// **'Sign out below to end this session. Other devices use their own login.'**
  String get settingsSessionSnack;

  /// No description provided for @settingsSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOutTitle;

  /// No description provided for @settingsSignOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'End session on this device'**
  String get settingsSignOutSubtitle;

  /// No description provided for @settingsPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsPasswordTitle;

  /// No description provided for @settingsPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change password for this account'**
  String get settingsPasswordSubtitle;

  /// No description provided for @settingsOptionalPinTitle.
  ///
  /// In en, this message translates to:
  /// **'App lock PIN'**
  String get settingsOptionalPinTitle;

  /// No description provided for @settingsOptionalPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require a PIN to open this app on this device'**
  String get settingsOptionalPinSubtitle;

  /// No description provided for @appLockStatusOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get appLockStatusOn;

  /// No description provided for @appLockStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get appLockStatusOff;

  /// No description provided for @appLockEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get appLockEnterTitle;

  /// No description provided for @appLockEnterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock KPMS to continue'**
  String get appLockEnterSubtitle;

  /// No description provided for @appLockWrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get appLockWrong;

  /// No description provided for @appLockSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN'**
  String get appLockSetTitle;

  /// No description provided for @appLockSetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a 4 to 6 digit PIN'**
  String get appLockSetSubtitle;

  /// No description provided for @appLockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get appLockConfirmTitle;

  /// No description provided for @appLockMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get appLockMismatch;

  /// No description provided for @appLockChange.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get appLockChange;

  /// No description provided for @appLockRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get appLockRemove;

  /// No description provided for @appLockSetDone.
  ///
  /// In en, this message translates to:
  /// **'App lock PIN enabled'**
  String get appLockSetDone;

  /// No description provided for @appLockRemoved.
  ///
  /// In en, this message translates to:
  /// **'App lock PIN removed'**
  String get appLockRemoved;

  /// No description provided for @appLockManageTitle.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLockManageTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSomali.
  ///
  /// In en, this message translates to:
  /// **'Somali'**
  String get languageSomali;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageSheetTitle;

  /// No description provided for @languageSheetHint.
  ///
  /// In en, this message translates to:
  /// **'The interface updates immediately. Your choice is saved on this device and synced to the pharmacy account when possible.'**
  String get languageSheetHint;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutAppName.
  ///
  /// In en, this message translates to:
  /// **'KULMIS Pharmacy Management System'**
  String get aboutAppName;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersionLabel;

  /// No description provided for @aboutBuildLabel.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get aboutBuildLabel;

  /// No description provided for @aboutDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get aboutDeveloper;

  /// No description provided for @aboutDeveloperValue.
  ///
  /// In en, this message translates to:
  /// **'KULMIS'**
  String get aboutDeveloperValue;

  /// No description provided for @aboutTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get aboutTerms;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacy;

  /// No description provided for @aboutContact.
  ///
  /// In en, this message translates to:
  /// **'Contact & support'**
  String get aboutContact;

  /// No description provided for @aboutContactValue.
  ///
  /// In en, this message translates to:
  /// **'support@kulmis.example'**
  String get aboutContactValue;

  /// No description provided for @aboutTermsBody.
  ///
  /// In en, this message translates to:
  /// **'Use KPMS in accordance with your pharmacy license and local regulations. Features and availability may change with updates.'**
  String get aboutTermsBody;

  /// No description provided for @aboutPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Operational data is processed to run your pharmacy workspace. Review your organization’s data processing agreement for full details.'**
  String get aboutPrivacyBody;

  /// No description provided for @aboutCopyright.
  ///
  /// In en, this message translates to:
  /// **'© KULMIS. All rights reserved.'**
  String get aboutCopyright;

  /// No description provided for @sheetPharmacyProfile.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy profile'**
  String get sheetPharmacyProfile;

  /// No description provided for @fieldPharmacyName.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy name'**
  String get fieldPharmacyName;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get fieldPhone;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldLicense.
  ///
  /// In en, this message translates to:
  /// **'License number'**
  String get fieldLicense;

  /// No description provided for @fieldOwner.
  ///
  /// In en, this message translates to:
  /// **'Registered owner / superintendent'**
  String get fieldOwner;

  /// No description provided for @fieldCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency code'**
  String get fieldCurrency;

  /// No description provided for @fieldTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone (IANA)'**
  String get fieldTimezone;

  /// No description provided for @fieldLogoUrl.
  ///
  /// In en, this message translates to:
  /// **'Logo URL (optional)'**
  String get fieldLogoUrl;

  /// No description provided for @fieldTaxRate.
  ///
  /// In en, this message translates to:
  /// **'Tax rate (%)'**
  String get fieldTaxRate;

  /// No description provided for @salesTaxTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales tax'**
  String get salesTaxTitle;

  /// No description provided for @salesTaxDescription.
  ///
  /// In en, this message translates to:
  /// **'Applied to the taxable amount after discounts at checkout (exclusive).'**
  String get salesTaxDescription;

  /// No description provided for @receiptInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt & invoice'**
  String get receiptInvoiceTitle;

  /// No description provided for @receiptFooterLabel.
  ///
  /// In en, this message translates to:
  /// **'Footer note (optional)'**
  String get receiptFooterLabel;

  /// No description provided for @receiptFooterHint.
  ///
  /// In en, this message translates to:
  /// **'Regulatory text, thank-you line…'**
  String get receiptFooterHint;

  /// No description provided for @receiptShowBarcode.
  ///
  /// In en, this message translates to:
  /// **'Show barcode strip on receipt'**
  String get receiptShowBarcode;

  /// No description provided for @receiptShowBarcodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Decorative barcode block under totals'**
  String get receiptShowBarcodeSubtitle;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordNew.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get changePasswordNew;

  /// No description provided for @changePasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get changePasswordConfirm;

  /// No description provided for @validationPharmacyNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy name is required'**
  String get validationPharmacyNameRequired;

  /// No description provided for @validationTaxRateRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a tax rate between 0 and 100'**
  String get validationTaxRateRange;

  /// No description provided for @validationPasswordLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get validationPasswordLength;

  /// No description provided for @validationPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validationPasswordMismatch;

  /// No description provided for @validationPasswordSignupRules.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get validationPasswordSignupRules;

  /// No description provided for @authRecoveryVerifyLockedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {minutes} min.'**
  String authRecoveryVerifyLockedMinutes(int minutes);

  /// No description provided for @passwordStrengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Password strength'**
  String get passwordStrengthLabel;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get passwordStrengthFair;

  /// No description provided for @passwordStrengthGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get passwordStrengthGood;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrengthStrong;

  /// No description provided for @resetPasswordSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get resetPasswordSuccessTitle;

  /// No description provided for @authTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in a moment.'**
  String get authTooManyAttempts;

  /// No description provided for @validationMarginRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a margin between 0 and 99.99'**
  String get validationMarginRange;

  /// No description provided for @validationDecimalsRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 0 to 6'**
  String get validationDecimalsRange;

  /// No description provided for @snackPharmacySaved.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy profile saved'**
  String get snackPharmacySaved;

  /// No description provided for @snackTaxUpdated.
  ///
  /// In en, this message translates to:
  /// **'Tax rate updated'**
  String get snackTaxUpdated;

  /// No description provided for @snackInvoiceSaved.
  ///
  /// In en, this message translates to:
  /// **'Invoice settings saved'**
  String get snackInvoiceSaved;

  /// No description provided for @snackPasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get snackPasswordUpdated;

  /// No description provided for @snackLocaleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get snackLocaleUpdated;

  /// No description provided for @snackSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get snackSaveFailed;

  /// No description provided for @pricingSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get pricingSheetTitle;

  /// No description provided for @pricingProfitMargin.
  ///
  /// In en, this message translates to:
  /// **'Default profit margin (%)'**
  String get pricingProfitMargin;

  /// No description provided for @pricingProfitHint.
  ///
  /// In en, this message translates to:
  /// **'Used as a guide when pricing medicines'**
  String get pricingProfitHint;

  /// No description provided for @pricingDecimalPlaces.
  ///
  /// In en, this message translates to:
  /// **'Price decimal places'**
  String get pricingDecimalPlaces;

  /// No description provided for @pricingDiscountBehavior.
  ///
  /// In en, this message translates to:
  /// **'Discount behavior'**
  String get pricingDiscountBehavior;

  /// No description provided for @pricingDiscountPerLine.
  ///
  /// In en, this message translates to:
  /// **'Apply to line items'**
  String get pricingDiscountPerLine;

  /// No description provided for @pricingDiscountOnTotal.
  ///
  /// In en, this message translates to:
  /// **'Apply to receipt total'**
  String get pricingDiscountOnTotal;

  /// No description provided for @pricingTaxInclusive.
  ///
  /// In en, this message translates to:
  /// **'Tax-inclusive display'**
  String get pricingTaxInclusive;

  /// No description provided for @pricingTaxInclusiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show tax-included amounts where supported'**
  String get pricingTaxInclusiveSubtitle;

  /// No description provided for @notificationsLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock alerts'**
  String get notificationsLowStock;

  /// No description provided for @notificationsLowStockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Highlight when quantity is below threshold'**
  String get notificationsLowStockSubtitle;

  /// No description provided for @notificationsExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry alerts'**
  String get notificationsExpiry;

  /// No description provided for @notificationsExpirySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Surface batches nearing expiry'**
  String get notificationsExpirySubtitle;

  /// No description provided for @notificationsDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt reminders'**
  String get notificationsDebt;

  /// No description provided for @notificationsDebtSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customer balance nudges'**
  String get notificationsDebtSubtitle;

  /// No description provided for @notificationsSound.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get notificationsSound;

  /// No description provided for @notificationsVibrate.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get notificationsVibrate;

  /// No description provided for @receiptPaperSize.
  ///
  /// In en, this message translates to:
  /// **'Paper size'**
  String get receiptPaperSize;

  /// No description provided for @receiptPrintQuality.
  ///
  /// In en, this message translates to:
  /// **'Print quality'**
  String get receiptPrintQuality;

  /// No description provided for @printQualityDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get printQualityDraft;

  /// No description provided for @printQualityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get printQualityNormal;

  /// No description provided for @printQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get printQualityHigh;

  /// No description provided for @paperSizeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get paperSizeDefault;

  /// No description provided for @paperSizeThermal58.
  ///
  /// In en, this message translates to:
  /// **'Thermal 58 mm'**
  String get paperSizeThermal58;

  /// No description provided for @paperSizeThermal80.
  ///
  /// In en, this message translates to:
  /// **'Thermal 80 mm'**
  String get paperSizeThermal80;

  /// No description provided for @paperSizeA4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get paperSizeA4;

  /// No description provided for @regionUseDevice.
  ///
  /// In en, this message translates to:
  /// **'Match device'**
  String get regionUseDevice;

  /// No description provided for @regionSomalia.
  ///
  /// In en, this message translates to:
  /// **'Somalia'**
  String get regionSomalia;

  /// No description provided for @regionGeneric.
  ///
  /// In en, this message translates to:
  /// **'International'**
  String get regionGeneric;

  /// No description provided for @dateFormatSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get dateFormatSystem;

  /// No description provided for @dateFormatDdMmYyyy.
  ///
  /// In en, this message translates to:
  /// **'DD/MM/YYYY'**
  String get dateFormatDdMmYyyy;

  /// No description provided for @dateFormatMmDdYyyy.
  ///
  /// In en, this message translates to:
  /// **'MM/DD/YYYY'**
  String get dateFormatMmDdYyyy;

  /// No description provided for @dateFormatYyyyMmDd.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get dateFormatYyyyMmDd;

  /// No description provided for @numberFormatSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get numberFormatSystem;

  /// No description provided for @numberFormatWestern.
  ///
  /// In en, this message translates to:
  /// **'Western (0–9)'**
  String get numberFormatWestern;

  /// No description provided for @numberFormatArabicIndic.
  ///
  /// In en, this message translates to:
  /// **'Arabic-Indic digits'**
  String get numberFormatArabicIndic;

  /// No description provided for @staffTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission templates'**
  String get staffTemplatesTitle;

  /// No description provided for @staffTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preset bundles for cashier, pharmacist, and manager'**
  String get staffTemplatesSubtitle;

  /// No description provided for @staffTemplatesSnack.
  ///
  /// In en, this message translates to:
  /// **'Templates are applied when creating or editing staff in the Staff module.'**
  String get staffTemplatesSnack;

  /// No description provided for @staffSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff security rules'**
  String get staffSecurityTitle;

  /// No description provided for @staffSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require strong passwords and limit destructive actions to admins'**
  String get staffSecuritySubtitle;

  /// No description provided for @staffSecuritySnack.
  ///
  /// In en, this message translates to:
  /// **'Configure roles and route access from Staff. Sensitive actions stay with pharmacy admins.'**
  String get staffSecuritySnack;

  /// No description provided for @settingsReceiptExtrasOpen.
  ///
  /// In en, this message translates to:
  /// **'Print & paper'**
  String get settingsReceiptExtrasOpen;

  /// No description provided for @settingsReceiptExtrasSummary.
  ///
  /// In en, this message translates to:
  /// **'Paper size, print quality, and barcode strip'**
  String get settingsReceiptExtrasSummary;

  /// No description provided for @settingsTaxRateCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current rate: {rate}%'**
  String settingsTaxRateCurrent(String rate);

  /// No description provided for @settingsInvoicePreviewFooter.
  ///
  /// In en, this message translates to:
  /// **'{snippet} · barcode {state}'**
  String settingsInvoicePreviewFooter(String snippet, String state);

  /// No description provided for @settingsInvoicePreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Footer text · barcode strip'**
  String get settingsInvoicePreviewEmpty;

  /// No description provided for @settingsGeneralContactLine.
  ///
  /// In en, this message translates to:
  /// **'{phone} · {email}'**
  String settingsGeneralContactLine(String phone, String email);

  /// No description provided for @settingsGeneralCurrencyLine.
  ///
  /// In en, this message translates to:
  /// **'{currency} · {timezone}'**
  String settingsGeneralCurrencyLine(String currency, String timezone);

  /// No description provided for @featuresHubTitle.
  ///
  /// In en, this message translates to:
  /// **'All features'**
  String get featuresHubTitle;

  /// No description provided for @featuresHubSubtitlePharmacy.
  ///
  /// In en, this message translates to:
  /// **'Your pharmacy modules'**
  String get featuresHubSubtitlePharmacy;

  /// No description provided for @featuresHubSubtitlePlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform console'**
  String get featuresHubSubtitlePlatform;

  /// No description provided for @featuresClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get featuresClose;

  /// No description provided for @featuresPermissionsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load permissions.'**
  String get featuresPermissionsError;

  /// No description provided for @platformSearchModules.
  ///
  /// In en, this message translates to:
  /// **'Search platform'**
  String get platformSearchModules;

  /// No description provided for @platformSearchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get platformSearchNoMatches;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get validationEmailInvalid;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authWorkEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Work email'**
  String get authWorkEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authForgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPasswordLink;

  /// No description provided for @authSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInButton;

  /// No description provided for @authRegisterPharmacyLink.
  ///
  /// In en, this message translates to:
  /// **'Register a new pharmacy'**
  String get authRegisterPharmacyLink;

  /// No description provided for @authPharmacySignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy sign in'**
  String get authPharmacySignInTitle;

  /// No description provided for @authPharmacySignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your pharmacy workspace email and password.'**
  String get authPharmacySignInSubtitle;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account and preferences'**
  String get profileSubtitle;

  /// No description provided for @profileSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profileSectionPreferences;

  /// No description provided for @profileLanguageOpen.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get profileLanguageOpen;

  /// No description provided for @profileThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get profileThemeTitle;

  /// No description provided for @profileThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get profileThemeSystem;

  /// No description provided for @profileThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get profileThemeLight;

  /// No description provided for @profileThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get profileThemeDark;

  /// No description provided for @profilePharmacySettings.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy settings'**
  String get profilePharmacySettings;

  /// No description provided for @profilePharmacySettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pricing, receipts, staff, and operations'**
  String get profilePharmacySettingsSubtitle;

  /// No description provided for @profileSubscriptionOpen.
  ///
  /// In en, this message translates to:
  /// **'Subscription & billing'**
  String get profileSubscriptionOpen;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileChangePassword;

  /// No description provided for @profileAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get profileAccountLabel;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileLogout;

  /// No description provided for @registerPharmacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your pharmacy'**
  String get registerPharmacyTitle;

  /// No description provided for @registerPharmacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your workspace and owner account.'**
  String get registerPharmacySubtitle;

  /// No description provided for @registerSubmitCta.
  ///
  /// In en, this message translates to:
  /// **'Create pharmacy & sign in'**
  String get registerSubmitCta;

  /// No description provided for @registerLicenseHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional — add your license when you have it'**
  String get registerLicenseHelper;

  /// No description provided for @registerPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required.'**
  String get registerPhoneRequired;

  /// No description provided for @registerOwnerRequired.
  ///
  /// In en, this message translates to:
  /// **'Owner name is required.'**
  String get registerOwnerRequired;

  /// No description provided for @registerSessionMissing.
  ///
  /// In en, this message translates to:
  /// **'Session missing. Sign in instead.'**
  String get registerSessionMissing;

  /// No description provided for @registerDuplicateHelp.
  ///
  /// In en, this message translates to:
  /// **'This email already has an account. Sign in with the correct password or reset it.'**
  String get registerDuplicateHelp;

  /// No description provided for @registerVerifyEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email from the inbox link, then sign in or try again here.'**
  String get registerVerifyEmailFirst;

  /// No description provided for @registerGenericError.
  ///
  /// In en, this message translates to:
  /// **'Registration could not be completed.'**
  String get registerGenericError;

  /// No description provided for @registerFieldPharmacyName.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy name'**
  String get registerFieldPharmacyName;

  /// No description provided for @registerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy name is required.'**
  String get registerNameRequired;

  /// No description provided for @registerFieldOwnerName.
  ///
  /// In en, this message translates to:
  /// **'Owner full name'**
  String get registerFieldOwnerName;

  /// No description provided for @registerFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get registerFieldPhone;

  /// No description provided for @registerFieldAddressOptional.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get registerFieldAddressOptional;

  /// No description provided for @registerFieldLicenseOptional.
  ///
  /// In en, this message translates to:
  /// **'License number (optional)'**
  String get registerFieldLicenseOptional;

  /// No description provided for @registerLogoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional. Shown on invoices and receipts after your pharmacy is created.'**
  String get registerLogoSubtitle;

  /// No description provided for @registerLogoGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get registerLogoGallery;

  /// No description provided for @registerLogoCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get registerLogoCamera;

  /// No description provided for @registerLogoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove logo'**
  String get registerLogoRemove;

  /// No description provided for @registerLogoApplyFail.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy was created, but the logo could not be saved. Add it in Pharmacy settings.'**
  String get registerLogoApplyFail;

  /// No description provided for @registerLogoInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Please choose a PNG, JPG, or WEBP image.'**
  String get registerLogoInvalidFormat;

  /// No description provided for @registerLogoButton.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy logo'**
  String get registerLogoButton;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter and confirm a strong password for your account.'**
  String get resetPasswordSubtitle;

  /// No description provided for @resetPasswordSubmit.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get resetPasswordSubmit;

  /// No description provided for @resetPasswordDone.
  ///
  /// In en, this message translates to:
  /// **'Password updated. Sign in with your new password.'**
  String get resetPasswordDone;

  /// No description provided for @resetPasswordInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'No active reset session. Use Forgot password to request a code, or open the reset link from email on the web app.'**
  String get resetPasswordInvalidLink;

  /// No description provided for @resetPasswordBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get resetPasswordBackToSignIn;

  /// No description provided for @superAdminLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Operator sign in'**
  String get superAdminLoginTitle;

  /// No description provided for @superAdminLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Platform administration — not for pharmacy staff.'**
  String get superAdminLoginSubtitle;

  /// No description provided for @superAdminAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'This account is not authorized for operator access.'**
  String get superAdminAccessDenied;

  /// No description provided for @superAdminPharmacyPortalLink.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy app sign in'**
  String get superAdminPharmacyPortalLink;

  /// No description provided for @authVerifyEmailLink.
  ///
  /// In en, this message translates to:
  /// **'I need to verify my email'**
  String get authVerifyEmailLink;

  /// No description provided for @authSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed: {error}'**
  String authSignInFailed(String error);

  /// No description provided for @authCheckEmailConfirm.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm your account.'**
  String get authCheckEmailConfirm;

  /// No description provided for @authForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authForgotTitle;

  /// No description provided for @authForgotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We email you a 6-digit code from KPMS. Enter it here, then choose a new password — everything stays in this app.'**
  String get authForgotSubtitle;

  /// No description provided for @authForgotSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send verification code'**
  String get authForgotSendLink;

  /// No description provided for @authForgotResetSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent. Check your email and spam folder.'**
  String get authForgotResetSent;

  /// No description provided for @authForgotHaveResetLink.
  ///
  /// In en, this message translates to:
  /// **'I already have a code'**
  String get authForgotHaveResetLink;

  /// No description provided for @authRecoveryEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Open the KPMS password reset email and enter the 6-digit code shown there.'**
  String get authRecoveryEmailHint;

  /// No description provided for @authRecoveryOtpExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Code expires in {time}'**
  String authRecoveryOtpExpiresIn(String time);

  /// No description provided for @authRecoveryOtpExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Tap Resend to get a new one.'**
  String get authRecoveryOtpExpired;

  /// No description provided for @authRecoveryVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get authRecoveryVerifyTitle;

  /// No description provided for @authRecoveryCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get authRecoveryCodeLabel;

  /// No description provided for @authRecoveryVerifyCta.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get authRecoveryVerifyCta;

  /// No description provided for @authRecoveryResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authRecoveryResend;

  /// No description provided for @authRecoveryResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String authRecoveryResendIn(int seconds);

  /// No description provided for @authRecoveryResendAvailableIn.
  ///
  /// In en, this message translates to:
  /// **'Resend available in {seconds} seconds'**
  String authRecoveryResendAvailableIn(int seconds);

  /// No description provided for @authOtpPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste code'**
  String get authOtpPaste;

  /// No description provided for @passwordConfirmMatches.
  ///
  /// In en, this message translates to:
  /// **'Passwords match'**
  String get passwordConfirmMatches;

  /// No description provided for @passwordConfirmDoesNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match yet'**
  String get passwordConfirmDoesNotMatch;

  /// No description provided for @authRecoveryWaitSend.
  ///
  /// In en, this message translates to:
  /// **'Please wait before requesting another code.'**
  String get authRecoveryWaitSend;

  /// No description provided for @authRecoveryTooManyVerify.
  ///
  /// In en, this message translates to:
  /// **'Too many incorrect codes. Request a new code or try again later.'**
  String get authRecoveryTooManyVerify;

  /// No description provided for @authRecoveryEditEmail.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get authRecoveryEditEmail;

  /// No description provided for @authRecoveryCodeIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Enter the full verification code from your email.'**
  String get authRecoveryCodeIncomplete;

  /// No description provided for @authForgotSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send reset: {error}'**
  String authForgotSendFailed(String error);

  /// No description provided for @authVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get authVerifyTitle;

  /// No description provided for @authVerifyBodyGeneric.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to your inbox. Confirm it to activate your pharmacy account.'**
  String get authVerifyBodyGeneric;

  /// No description provided for @authVerifyBodyWithEmail.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email}. Confirm it to activate your account.'**
  String authVerifyBodyWithEmail(String email);

  /// No description provided for @authVerifyResend.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get authVerifyResend;

  /// No description provided for @authVerifyBackSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authVerifyBackSignIn;

  /// No description provided for @authVerifyMissingEmail.
  ///
  /// In en, this message translates to:
  /// **'Missing email. Return to sign in and try again.'**
  String get authVerifyMissingEmail;

  /// No description provided for @authVerifySent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent.'**
  String get authVerifySent;

  /// No description provided for @authVerifyResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Resend failed: {error}'**
  String authVerifyResendFailed(String error);

  /// No description provided for @onboardGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardGetStarted;

  /// No description provided for @onboardThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Theme: dark (tap to use system)'**
  String get onboardThemeDark;

  /// No description provided for @onboardThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Theme: light (tap to use dark)'**
  String get onboardThemeLight;

  /// No description provided for @onboardThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Theme: system (tap to use light)'**
  String get onboardThemeSystem;

  /// No description provided for @onboardWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {appName}'**
  String onboardWelcomeTitle(String appName);

  /// No description provided for @onboardWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Modern pharmacy operations — inventory, POS, and compliance in one place.'**
  String get onboardWelcomeSubtitle;

  /// No description provided for @onboardSellTitle.
  ///
  /// In en, this message translates to:
  /// **'Sell with confidence'**
  String get onboardSellTitle;

  /// No description provided for @onboardSellSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fast checkout, clear pricing, and structured payments for every counter.'**
  String get onboardSellSubtitle;

  /// No description provided for @onboardAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'See what matters'**
  String get onboardAnalyticsTitle;

  /// No description provided for @onboardAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics and exports help you track performance without guesswork.'**
  String get onboardAnalyticsSubtitle;

  /// No description provided for @onboardComfortTitle.
  ///
  /// In en, this message translates to:
  /// **'Comfort in any lighting'**
  String get onboardComfortTitle;

  /// No description provided for @onboardComfortSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch theme anytime — light, dark, or follow your system settings.'**
  String get onboardComfortSubtitle;

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// No description provided for @notFoundGoDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to dashboard'**
  String get notFoundGoDashboard;

  /// No description provided for @notFoundSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get notFoundSignIn;

  /// No description provided for @supabaseNotConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'Supabase not configured'**
  String get supabaseNotConfiguredTitle;

  /// No description provided for @supabaseNotConfiguredHint.
  ///
  /// In en, this message translates to:
  /// **'Add SUPABASE_URL and SUPABASE_ANON_KEY (public anon key only).'**
  String get supabaseNotConfiguredHint;

  /// No description provided for @supabaseConfigHelpMobile.
  ///
  /// In en, this message translates to:
  /// **'Debug Android/iOS: put `.env` next to `pubspec.yaml` — it is copied into `assets/env/generated_debug.env` during Debug builds. Then run `flutter run` again.\nRelease/APK: fill `assets/env/default.env` or use CI `--dart-define`.'**
  String get supabaseConfigHelpMobile;

  /// No description provided for @supabaseConfigHelpWeb.
  ///
  /// In en, this message translates to:
  /// **'Web: run `dart run tool/kpms_sync_root_env.dart` once, then `flutter run -d chrome`. Or use `--dart-define-from-file=.env`.'**
  String get supabaseConfigHelpWeb;

  /// No description provided for @supabaseConfigHelpDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop: copy `.env.example` → `.env` in the project root, then `flutter run`. Release builds use bundled `assets/env/default.env` or CI `--dart-define`.'**
  String get supabaseConfigHelpDesktop;

  /// No description provided for @supabaseConfigConsoleHint.
  ///
  /// In en, this message translates to:
  /// **'Console: look for `[kpms]` lines.'**
  String get supabaseConfigConsoleHint;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardSubtitleOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get dashboardSubtitleOverview;

  /// No description provided for @dashSectionSalesProfit.
  ///
  /// In en, this message translates to:
  /// **'Sales & profit'**
  String get dashSectionSalesProfit;

  /// No description provided for @dashSectionSalesProfitHint.
  ///
  /// In en, this message translates to:
  /// **'Live session analytics'**
  String get dashSectionSalesProfitHint;

  /// No description provided for @dashEmptySalesAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'No sales analytics yet'**
  String get dashEmptySalesAnalyticsTitle;

  /// No description provided for @dashEmptySalesAnalyticsMessage.
  ///
  /// In en, this message translates to:
  /// **'Record sales in POS to see trends and top-selling lines here.'**
  String get dashEmptySalesAnalyticsMessage;

  /// No description provided for @dashOpenPos.
  ///
  /// In en, this message translates to:
  /// **'Open POS'**
  String get dashOpenPos;

  /// No description provided for @dashRevenueHiddenRole.
  ///
  /// In en, this message translates to:
  /// **'Revenue trend is hidden for your role.'**
  String get dashRevenueHiddenRole;

  /// No description provided for @dashRevenueTrendPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Daily revenue trend appears when a time series is available.'**
  String get dashRevenueTrendPlaceholder;

  /// No description provided for @dashDailySales.
  ///
  /// In en, this message translates to:
  /// **'Daily sales'**
  String get dashDailySales;

  /// No description provided for @dashRevenuePulse.
  ///
  /// In en, this message translates to:
  /// **'Revenue pulse'**
  String get dashRevenuePulse;

  /// No description provided for @dashTopSellingPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Top-selling quantities appear after checkout.'**
  String get dashTopSellingPlaceholder;

  /// No description provided for @dashMonthlyTrendHidden.
  ///
  /// In en, this message translates to:
  /// **'Monthly trend is hidden for your role.'**
  String get dashMonthlyTrendHidden;

  /// No description provided for @dashMonthlySeriesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Monthly series appears as you record more checkout days.'**
  String get dashMonthlySeriesPlaceholder;

  /// No description provided for @dashMonthlySales.
  ///
  /// In en, this message translates to:
  /// **'Monthly sales'**
  String get dashMonthlySales;

  /// No description provided for @dashMonthlyTrajectory.
  ///
  /// In en, this message translates to:
  /// **'Trajectory'**
  String get dashMonthlyTrajectory;

  /// No description provided for @dashSectionInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory insights'**
  String get dashSectionInventory;

  /// No description provided for @dashSectionInventoryHint.
  ///
  /// In en, this message translates to:
  /// **'Stock, expiry, velocity'**
  String get dashSectionInventoryHint;

  /// No description provided for @dashSectionRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get dashSectionRecentActivity;

  /// No description provided for @dashSectionRecentActivityHint.
  ///
  /// In en, this message translates to:
  /// **'Sales, purchases, payments'**
  String get dashSectionRecentActivityHint;

  /// No description provided for @dashEmptyRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get dashEmptyRecentTitle;

  /// No description provided for @dashEmptyRecentMessage.
  ///
  /// In en, this message translates to:
  /// **'Sales, purchases, and supplier payments will appear here as you use the system.'**
  String get dashEmptyRecentMessage;

  /// No description provided for @dashStartSale.
  ///
  /// In en, this message translates to:
  /// **'Start sale'**
  String get dashStartSale;

  /// No description provided for @dashKpiTotalSales.
  ///
  /// In en, this message translates to:
  /// **'Total sales'**
  String get dashKpiTotalSales;

  /// No description provided for @dashKpiThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get dashKpiThisMonth;

  /// No description provided for @dashKpiCustomerCredits.
  ///
  /// In en, this message translates to:
  /// **'Customer credits'**
  String get dashKpiCustomerCredits;

  /// No description provided for @dashKpiOpenAr.
  ///
  /// In en, this message translates to:
  /// **'Open AR'**
  String get dashKpiOpenAr;

  /// No description provided for @dashKpiSupplierDebts.
  ///
  /// In en, this message translates to:
  /// **'Supplier debts'**
  String get dashKpiSupplierDebts;

  /// No description provided for @dashKpiOpenAp.
  ///
  /// In en, this message translates to:
  /// **'Open AP'**
  String get dashKpiOpenAp;

  /// No description provided for @dashKpiTotalMedicines.
  ///
  /// In en, this message translates to:
  /// **'Total medicines'**
  String get dashKpiTotalMedicines;

  /// No description provided for @dashKpiCatalogSkus.
  ///
  /// In en, this message translates to:
  /// **'Catalog SKUs'**
  String get dashKpiCatalogSkus;

  /// No description provided for @dashKpiLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get dashKpiLowStock;

  /// No description provided for @dashKpiBelowMinimum.
  ///
  /// In en, this message translates to:
  /// **'Below minimum'**
  String get dashKpiBelowMinimum;

  /// No description provided for @dashKpiExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get dashKpiExpiringSoon;

  /// No description provided for @dashKpiWithin90Days.
  ///
  /// In en, this message translates to:
  /// **'Within 90 days'**
  String get dashKpiWithin90Days;

  /// No description provided for @dashProfitTrend.
  ///
  /// In en, this message translates to:
  /// **'Profit trend'**
  String get dashProfitTrend;

  /// No description provided for @dashProfitMtdSession.
  ///
  /// In en, this message translates to:
  /// **'Month to date (session)'**
  String get dashProfitMtdSession;

  /// No description provided for @dashHiddenForRole.
  ///
  /// In en, this message translates to:
  /// **'Hidden for your role.'**
  String get dashHiddenForRole;

  /// No description provided for @dashProfitHintBody.
  ///
  /// In en, this message translates to:
  /// **'Profit updates as checkout lines post margin from POS. Export reports for accounting reconciliation.'**
  String get dashProfitHintBody;

  /// No description provided for @dashInsightLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get dashInsightLowStock;

  /// No description provided for @dashInsightLowStockAllOk.
  ///
  /// In en, this message translates to:
  /// **'All SKUs above minimum.'**
  String get dashInsightLowStockAllOk;

  /// No description provided for @dashInsightExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get dashInsightExpiringSoon;

  /// No description provided for @dashInsightExpiringSkuCount.
  ///
  /// In en, this message translates to:
  /// **'{count} SKU within 90 days.'**
  String dashInsightExpiringSkuCount(String count);

  /// No description provided for @dashInsightExpiringNone.
  ///
  /// In en, this message translates to:
  /// **'No batches in the 90-day window.'**
  String get dashInsightExpiringNone;

  /// No description provided for @dashInsightFastSelling.
  ///
  /// In en, this message translates to:
  /// **'Fast selling'**
  String get dashInsightFastSelling;

  /// No description provided for @dashInsightVelocityPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Record sales to populate velocity.'**
  String get dashInsightVelocityPlaceholder;

  /// No description provided for @dashRecentSaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Sale {invoice}'**
  String dashRecentSaleTitle(String invoice);

  /// No description provided for @dashRecentSaleSubtitleWithAmount.
  ///
  /// In en, this message translates to:
  /// **'POS · {amount} · {method}'**
  String dashRecentSaleSubtitleWithAmount(String amount, String method);

  /// No description provided for @dashRecentSaleSubtitleNoAmount.
  ///
  /// In en, this message translates to:
  /// **'POS · {method}'**
  String dashRecentSaleSubtitleNoAmount(String method);

  /// No description provided for @dashRecentPurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase {invoice}'**
  String dashRecentPurchaseTitle(String invoice);

  /// No description provided for @dashRecentPurchaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Purchases · {supplier}'**
  String dashRecentPurchaseSubtitle(String supplier);

  /// No description provided for @dashRecentSupplierPayment.
  ///
  /// In en, this message translates to:
  /// **'Supplier payment'**
  String get dashRecentSupplierPayment;

  /// No description provided for @dashRecentSupplierPaymentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{supplier} · {amount}'**
  String dashRecentSupplierPaymentSubtitle(String supplier, String amount);

  /// No description provided for @dashSupplierFallback.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get dashSupplierFallback;

  /// No description provided for @dashStaffPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff & permissions'**
  String get dashStaffPermissionsTitle;

  /// No description provided for @dashStaffPermissionsHint.
  ///
  /// In en, this message translates to:
  /// **'Invites, roles, and access trails stay centralized in Staff.'**
  String get dashStaffPermissionsHint;

  /// No description provided for @dashLowStockBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Low stock alert · 1 SKU} other{Low stock alert · {count} SKUs}}'**
  String dashLowStockBanner(num count);

  /// No description provided for @dashSegmentDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dashSegmentDay;

  /// No description provided for @dashSegmentWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get dashSegmentWeek;

  /// No description provided for @dashSegmentMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get dashSegmentMonth;

  /// No description provided for @dashInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get dashInsightsTitle;

  /// No description provided for @dashMiniRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get dashMiniRevenue;

  /// No description provided for @dashMiniProfitMo.
  ///
  /// In en, this message translates to:
  /// **'Profit (mo)'**
  String get dashMiniProfitMo;

  /// No description provided for @dashMiniTopSku.
  ///
  /// In en, this message translates to:
  /// **'Top SKU'**
  String get dashMiniTopSku;

  /// No description provided for @dashInsightCaptionDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily sales pulse'**
  String get dashInsightCaptionDaily;

  /// No description provided for @dashInsightCaptionWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly rhythm'**
  String get dashInsightCaptionWeekly;

  /// No description provided for @dashInsightCaptionMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly trajectory'**
  String get dashInsightCaptionMonthly;

  /// No description provided for @dashChartsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Charts populate when recorded sales exist for this period.'**
  String get dashChartsEmptyHint;

  /// No description provided for @dashFinancialChartHiddenRole.
  ///
  /// In en, this message translates to:
  /// **'Financial chart hidden for your role.'**
  String get dashFinancialChartHiddenRole;

  /// No description provided for @dashTopSellersTitle.
  ///
  /// In en, this message translates to:
  /// **'Top sellers'**
  String get dashTopSellersTitle;

  /// No description provided for @dashUnitsSoldSession.
  ///
  /// In en, this message translates to:
  /// **'Units sold (session)'**
  String get dashUnitsSoldSession;

  /// No description provided for @dashLowStockListTitle.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get dashLowStockListTitle;

  /// No description provided for @dashLowStockListAllOk.
  ///
  /// In en, this message translates to:
  /// **'All SKUs above minimum'**
  String get dashLowStockListAllOk;

  /// No description provided for @dashSalesTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales trend'**
  String get dashSalesTrendTitle;

  /// No description provided for @dashChartRecentPoints.
  ///
  /// In en, this message translates to:
  /// **'Recent points ({count})'**
  String dashChartRecentPoints(String count);

  /// No description provided for @dashChartTrendPoints.
  ///
  /// In en, this message translates to:
  /// **'Trend ({count} points)'**
  String dashChartTrendPoints(String count);

  /// No description provided for @dashReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get dashReview;

  /// No description provided for @dashTopSellingLine.
  ///
  /// In en, this message translates to:
  /// **'{name} · {units} u'**
  String dashTopSellingLine(String name, String units);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'so'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'so':
      return AppLocalizationsSo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
