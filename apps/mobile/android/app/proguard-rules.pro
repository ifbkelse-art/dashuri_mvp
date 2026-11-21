# Flutter and plugin rules are supplied by their AARs. Extra keeps for SDKs
# that use reflection.
-keep class com.cashfree.** { *; }
-dontwarn com.cashfree.**
-keep class io.getstream.** { *; }
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-keep class com.google.android.play.core.integrity.** { *; }
-dontwarn com.google.android.play.core.**
