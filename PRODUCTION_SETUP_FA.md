# راه‌اندازی نسخه Production نرم‌افزار نرخ ارز

## 1) Backend روی سرور
روی یک VPS لینوکس با Docker:

```bash
cd backend
cp .env.example .env
nano .env
# ADMIN_PASSWORD و JWT_SECRET را تغییر دهید
docker compose up -d --build
curl http://127.0.0.1:8080/health
```

سپس دامنه `irancurrency.eu.cc` را با Nginx یا Caddy و گواهی SSL به `127.0.0.1:8080` وصل کنید.

## 2) ساخت Android متصل به سرور
در Windows داخل پوشه پروژه:

```cmd
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://irancurrency.eu.cc
```

خروجی: `build\app\outputs\flutter-apk\app-release.apk`

## 3) رفتار برنامه
- اپ بدون ورود، نرخ مشتری را از سرور می‌گیرد.
- ورود همکار، کد را روی سرور بررسی می‌کند و نرخ‌های همکار را می‌گیرد.
- ورود به پنل مدیریت، رمز مدیریت سرور می‌خواهد.
- ثبت نرخ‌ها و تغییرات اصلی پنل روی سرور ذخیره می‌شوند.
- اگر سرور موقتاً قطع باشد، برنامه با اطلاعات داخلی اولیه باز می‌شود و وضعیت آفلاین را نمایش می‌دهد.
- Theme و رنگ انتخابی روی خود گوشی ذخیره می‌شوند.

## 4) امنیت قبل از انتشار
- `ADMIN_PASSWORD` قوی انتخاب شود.
- `JWT_SECRET` حداقل 32 کاراکتر تصادفی باشد.
- بک‌اند فقط پشت HTTPS عمومی شود.
- پورت 8080 مستقیماً روی اینترنت باز نشود؛ Docker Compose فعلی آن را فقط روی 127.0.0.1 bind می‌کند.
- از `backend/data/app.db` بکاپ روزانه بگیرید.
