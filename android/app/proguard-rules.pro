# Flutter Wrapper ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Supabase / Dart JNI reflection rules
-dontwarn okio.**
-dontwarn java.awt.**
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Anti-tampering / Obfuscation baseline
-repackageclasses
-allowaccessmodification
