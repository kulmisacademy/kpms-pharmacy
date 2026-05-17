# KPMS — keep rules when minification is enabled (R8 / ProGuard).
# Release currently sets isMinifyEnabled=false; these rules apply if you turn it on.

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keepnames class kotlin.** { *; }
-keep class kotlin.Metadata { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Gson / JSON / reflection used by plugins
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Sentry (stack traces / release breadcrumbs when R8 is enabled)
-keepattributes LineNumberTable,SourceFile
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**
