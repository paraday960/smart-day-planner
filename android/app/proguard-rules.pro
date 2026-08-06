# ─── قواعد ProGuard ─────────────────────────────────────────────
# برای vosk_flutter (تشخیص گفتار آفلاین) — JNA بومی
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }
