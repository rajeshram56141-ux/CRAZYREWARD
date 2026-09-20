# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Proguard rules for Cloud Firestore
-keep class com.google.firebase.firestore.** { *; }

# Proguard rules for Firebase Auth
-keep class com.google.firebase.auth.** { *; }

# OneSignal
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# Google Sign In
-keep class com.google.android.gms.auth.api.signin.** { *; }
-dontwarn com.google.android.gms.auth.api.signin.**

# OkHttp/Retrofit/Dio
-keepattributes Signature, InnerClasses, AnnotationDefault
-keep class sun.misc.Unsafe { *; }
-dontwarn java.lang.SafeVarargs
-dontwarn javax.annotation.**
-dontwarn okio.**

# JNI
-keep class com.sudeep.flutter_essential.** { *; }

# Play Core (Missing classes fix)
-dontwarn com.google.android.play.core.**
