این پروژه Flutter تستی مطابق منطق نسخه HTML v12 است.

برای ساخت APK روی ویندوز:
1) ZIP را Extract کن.
2) داخل پوشه پروژه PowerShell یا CMD باز کن.
3) اجرا کن:

flutter create .
flutter pub get
flutter run

برای APK:
flutter build apk --release

خروجی:
build\app\outputs\flutter-apk\app-release.apk

این نسخه فعلاً با داده محلی تستی کار می‌کند؛ بعد از تأیید روی گوشی، Backend واقعی وصل می‌شود.
