# ─── قواعد ProGuard ─────────────────────────────────────────────
# برای vosk_flutter (تشخیص گفتار آفلاین) — JNA بومی
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }
# R8 در حالت release برای JNA به کلاس‌های دسکتاپ java.awt ارجاع می‌دهد که روی اندروید نیست
# این‌ها فقط برای AWT روی دسکتاپ هستند و روی اندروید استفاده نمی‌شوند — هشدار را خاموش کن
-dontwarn java.awt.**
-dontwarn com.sun.jna.**
-dontwarn com.sun.jna.Native$AWT
