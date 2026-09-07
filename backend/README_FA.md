# بک‌اند نرم‌افزار نرخ ارز

این سرویس یک API واقعی FastAPI با ذخیره دائمی SQLite است. برای شروع روی سرور لینوکس Docker و Docker Compose کافی است.

1. `.env.example` را به `.env` کپی کنید و `ADMIN_PASSWORD` و `JWT_SECRET` را حتماً عوض کنید.
2. اجرا: `docker compose up -d --build`
3. تست داخلی سرور: `curl http://127.0.0.1:8080/health`
4. برای استفاده واقعی، دامنه `irancurrency.eu.cc` را با Nginx/Caddy و HTTPS به `127.0.0.1:8080` reverse-proxy کنید.

API اصلی:
- `GET /health`
- `GET /api/v1/state` نرخ مشتری بدون توکن
- `POST /api/v1/partner/login` ورود همکار
- `POST /api/v1/admin/login` ورود مدیر
- `PUT /api/v1/admin/state` ذخیره کامل تنظیمات و نرخ‌ها با توکن مدیر

دیتابیس در `backend/data/app.db` ذخیره می‌شود؛ برای بکاپ همین فایل را کپی کنید.
