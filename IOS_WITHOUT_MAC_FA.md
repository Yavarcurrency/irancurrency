# ساخت و تست iOS بدون داشتن Mac

پروژه پوشه کامل `ios/` را دارد و برای Flutter/iOS آماده شده است. Xcode روی iPhone یا Windows نصب نمی‌شود؛ برای build نهایی iOS باید یک محیط macOS/Xcode در جایی وجود داشته باشد.

## راه پیشنهادی برای شما: Cloud build + TestFlight
1. Apple ID داشته باشید و برای تست روی iPhone از طریق TestFlight، حساب Apple Developer فعال کنید.
2. پروژه را روی GitHub/GitLab قرار دهید.
3. پروژه را به Codemagic متصل کنید. فایل `codemagic.yaml` نمونه داخل پروژه قرار داده شده است.
4. در Codemagic، App Store Connect integration و Code Signing را تنظیم کنید.
5. متغیر `API_BASE_URL` از قبل روی `https://irancurrency.eu.cc` تنظیم شده است.
6. Build را اجرا کنید؛ خروجی IPA ساخته می‌شود و می‌توان آن را به TestFlight ارسال کرد.
7. روی iPhone برنامه TestFlight را از App Store نصب کنید و نسخه تست را از آنجا نصب کنید.

## راه دوم
یک Mac ابری یا Mac اجاره‌ای بگیرید، Flutter و Xcode را نصب کنید و همین پروژه را با `flutter build ipa --release` بسازید.

## نکته مهم
برای iOS واقعی، API باید HTTPS معتبر داشته باشد. در نسخه production از HTTP خام استفاده نکنید.
