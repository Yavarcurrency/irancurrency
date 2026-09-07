# تغییرات v17
- نام داخلی Flutter: `irancurrency` (حذف نام قدیمی `currency_market_v12` از pubspec و import تست)
- نام نمایشی Android/iOS: `Irancurrency`
- iOS Bundle ID: `com.currencyhub.app`
- iOS test bundle: `com.currencyhub.app.RunnerTests`
- نسخه: `0.17.0+17`
- Backend پیش‌فرض: `https://irancurrency.eu.cc`
- اضافه‌شدن workflow تست کامپایل iOS بدون signing در Codemagic
- اضافه‌شدن قالب جدا برای build امضاشده و TestFlight
- حذف پوشه legacy `android_old` و cache/generated files از بسته Release

نکته: Android applicationId فعلی عمداً تغییر نکرده تا APK جدید همچنان همان اپ تست‌شده Android تلقی شود. تغییر Android applicationId را بهتر است فقط زمانی انجام دهیم که هویت انتشار Play Store نهایی شد.
