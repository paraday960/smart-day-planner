# راهنمای ساخت فایل نصب APK - دستیار روزانه هوشمند

## روش ۱: دانلود خودکار از گیت‌هاب (ساده‌ترین - همین الان در حال ساخت)

هر بار که به `main` پوش می‌کنی، گیت‌هاب خودکار APK دیباگ می‌سازد:

1. برو به: https://github.com/paraday960/smart-day-planner/actions
2. آخرین Run با نام `Flutter CI` را باز کن
3. پایین صفحه بخش `Artifacts` → فایل `debug-apk` را دانلود کن
4. روی گوشی نصب کن (Allow unknown sources)

> همین الان یک Build جدید (ID: 31127701666) در حال اجراست — ۵-۸ دقیقه دیگر آماده می‌شود.

## روش ۲: ساخت روی کامپیوتر خودت (برای انتشار در کافه‌بازار/مایکت)

### پیش‌نیاز
```bash
flutter --version  # باید 3.22+
java -version      # 17
```

### ساخت APK دیباگ (برای تست)
```bash
cd smart-day-planner
flutter pub get
bash scripts/build_android_debug.sh
# خروجی: build/app/outputs/flutter-apk/app-debug.apk
```

### ساخت APK انتشار (برای کافه‌بازار)
```bash
# 1. ساخت keystore (فقط بار اول)
keytool -genkey -v -keystore ~/smart-day-planner.jks -keyalg RSA -keysize 2048 -validity 10000 -alias smartday

# 2. ساخت فایل android/key.properties
cat > android/key.properties << 'KEY'
storePassword=رمز_خودت
keyPassword=رمز_خودت
keyAlias=smartday
storeFile=/home/شما/smart-day-planner.jks
KEY

# 3. بیلد انتشار
flutter build apk --release
flutter build appbundle --release  # برای گوگل پلی/کافه‌بازار (AAB)

# خروجی:
# build/app/outputs/flutter-apk/app-release.apk
# build/app/outputs/bundle/release/app-release.aab
```

### ساخت با مدل ۳D و LLM
```bash
# با مدل سه‌بعدی (همین الان داخل assets هست)
flutter build apk --release

# با هوش LLM محلی (اختیاری، 470MB)
bash scripts/download_llm_model.sh
flutter build apk --release --dart-define=ENABLE_LOCAL_LLM=true
```

## انتشار در کافه‌بازار / مایکت

1. فایل `app-release.aab` یا `app-release.apk` را آپلود کن
2. از `release/store_listing_fa.md` عنوان و توضیحات را کپی کن
3. از `release/privacy_policy_fa.md` حریم خصوصی را بذار
4. آیکون: `assets/icon.png` (یا بساز با `flutter_launcher_icons`)
5. اسکرین‌شات: از `release/qa_matrix.md` تست کن و عکس بگیر

## نسخه فعلی
- version: 0.2.5+8
- برای انتشار نسخه جدید: `bash scripts/bump_version.sh patch` (یا minor/major)

## مشکل خوردی؟
```bash
flutter clean
flutter pub get
flutter analyze
```
و لاگ را بفرست.
