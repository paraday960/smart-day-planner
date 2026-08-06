# فرمان صوتی فارسی

این نسخه یک دکمه Push-to-Talk دارد: کاربر دکمه میکروفون را نگه می‌دارد، فارسی حرف می‌زند و وقتی رها می‌کند فرمان اجرا می‌شود.

## فرمان‌های پشتیبانی‌شده

### مدیریت کارها
- «کار جدید تماس با مشتری اضافه کن»
- «کار جدید طراحی سایت مشتری برای فردا اضافه کن»
- «کار پروژه فروش کامل شد»
- «برنامه امروزمو بچین»
- «الان چی کار کنم؟»

### حسابداری
- «درآمد سه میلیون تومان ثبت کن»
- «درآمد ۳۰۰۰۰۰۰ ثبت کن»
- «هزینه دویست هزار تومان ثبت کن»
- «وضع مالی امروز چطوره؟»

## نکته مهم درباره آفلاین بودن
در کد فعلی از پکیج `speech_to_text` استفاده شده و گزینه `onDevice: false` فعال است؛ یعنی اپ می‌تواند از سرویس رایگان تشخیص گفتار خود گوشی استفاده کند. این حالت ممکن است برای دقت بهتر فارسی از اینترنت استفاده کند، اما API پولی لازم ندارد. اگر آفلاین کامل خواستی، مقدار را `true` کن یا Vosk/Whisper.cpp اضافه کن.

اگر آفلاین ۱۰۰٪ تضمینی می‌خواهی، مسیر حرفه‌ای‌تر این است:
1. استفاده از Vosk یا Whisper.cpp روی موبایل
2. اضافه کردن مدل فارسی آفلاین به assets یا دانلود یک‌بارمصرف
3. تبدیل صدا به متن با مدل محلی
4. ارسال متن خروجی به `VoiceCommandProcessor`

## Permission لازم بعد از ساخت پروژه Flutter
بعد از اجرای:
```bash
flutter create --platforms=android,ios .
```
این موارد را اضافه کن.

### Android
در فایل `android/app/src/main/AndroidManifest.xml` قبل از تگ `<application>`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<queries>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```

اگر فقط آفلاین کامل می‌خواهی و از سرویس آنلاین استفاده نمی‌کنی، permission اینترنت را می‌توانی حذف کنی. بعضی Speech Service های اندروید برای تشخیص اولیه به آن نیاز دارند.

### iOS
در فایل `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>برای دریافت فرمان صوتی فارسی به میکروفون نیاز داریم.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>برای تبدیل گفتار فارسی به متن و اجرای فرمان‌ها استفاده می‌شود.</string>
```

## فایل‌های مربوطه
- `lib/services/voice_command_processor.dart` — تبدیل متن فارسی به فرمان اجرایی
- `lib/screens/home_screen.dart` — UI دکمه نگه‌داشتنی میکروفون
- `pubspec.yaml` — dependency مربوط به `speech_to_text`
