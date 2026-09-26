# =========================================================================
# DANGEROUSTNERDY 5E TOOLKIT - PROGUARD / R8 SHRANK & OBFUSCATION RULES
# =========================================================================

# 1. Preserve Flutter Engine & Plugin Interfaces
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# 2. Preserve Native Method Names for JNI Calls
-keepclasseswithmembernames class * {
    native <methods>;
}

# 3. Preserve Custom Data Models from Reflection Stripping
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# 4. Firebase Core & Cloud Firestore Protection
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn com.google.firebase.**
-dontwarn com.google.firestore.**
-dontwarn javax.annotation.**

# 5. Prevent Obfuscation of Generated Firebase Components
-keep class com.google.firebase.** { *; }
-keep class com.google.firestore.** { *; }
