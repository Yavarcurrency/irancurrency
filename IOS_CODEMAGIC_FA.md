# Irancurrency v17 — راهنمای iOS بدون Mac

## هویت نسخه iOS
- Display Name: `Irancurrency`
- Flutter package name: `irancurrency`
- iOS Bundle ID: `com.currencyhub.app`
- Backend: `https://irancurrency.eu.cc`
- Version: `0.17.0 (17)`

> Bundle ID از نام نمایشی مستقل است. تغییر نام نمایشی برنامه در آینده لزوماً نیاز به تغییر Bundle ID ندارد.

## مرحله 1 — تست کامپایل iOS بدون Apple Developer
1. پروژه را در یک Git repository خصوصی قرار دهید و به GitHub/GitLab/Bitbucket push کنید.
2. در Codemagic یک Application جدید بسازید و repository را متصل کنید.
3. Codemagic باید فایل `codemagic.yaml` ریشه پروژه را پیدا کند.
4. workflow با نام `Irancurrency iOS - Unsigned Compile Check` را اجرا کنید.
5. این workflow روی macOS، `flutter pub get`، `flutter analyze`، `pod install` و سپس `flutter build ios --release --no-codesign` را اجرا می‌کند.
6. موفق‌شدن این مرحله یعنی سورس iOS روی Xcode/macOS کامپایل می‌شود. خروجی unsigned برای نصب عادی روی iPhone نیست.

## مرحله 2 — نصب واقعی روی iPhone از TestFlight
این مرحله نیاز به عضویت فعال Apple Developer Program و App Store Connect دارد.

1. در Apple Developer / App Store Connect یک App ID / App Record با Bundle ID دقیق `com.currencyhub.app` بسازید.
2. در App Store Connect یک API Key مناسب Codemagic بسازید و Key ID، Issuer ID و فایل `.p8` را نگه دارید.
3. integration مربوط به App Store Connect را در Codemagic تنظیم کنید.
4. code signing (Apple Distribution certificate + provisioning profile) را برای `com.currencyhub.app` در Codemagic آماده کنید.
5. فایل `codemagic.testflight.template.yaml` را باز کنید، مقدار `YOUR_CODEMAGIC_APP_STORE_CONNECT_INTEGRATION` را با نام integration خود عوض کنید و workflow آن را به `codemagic.yaml` اضافه کنید.
6. workflow `Irancurrency iOS - TestFlight` را اجرا کنید. خروجی signed IPA ساخته و برای TestFlight ارسال می‌شود.
7. پس از پردازش build در App Store Connect، تستر را در TestFlight اضافه کنید و اپ را از برنامه TestFlight روی iPhone نصب کنید.

## نکات مهم
- `https://irancurrency.eu.cc` همان Backend مشترک Android و iOS است؛ Backend جدا لازم نیست.
- فایل `.p8`، certificateها، private keyها یا رمزها را داخل Git قرار ندهید.
- `codemagic.yaml` فعلی عمداً فقط workflow بدون signing دارد تا قبل از اتصال حساب Apple بدون خطای credential اجرا شود.
- برای TestFlight از distribution type برابر `app_store` استفاده می‌شود.
- اولین build امضاشده ممکن است نیاز داشته باشد App Record از قبل در App Store Connect ایجاد شده باشد.
