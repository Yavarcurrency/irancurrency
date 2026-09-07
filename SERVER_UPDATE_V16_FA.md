# به‌روزرسانی سرور به v16

این نسخه خطای mojibake/UTF-8 فارسی موجود در دیتابیس را هنگام شروع Backend به‌صورت خودکار ترمیم می‌کند و داده‌های فعلی را حذف نمی‌کند.

روی ویندوز فقط پوشه `backend` نسخه v16 را روی سرور در `/opt/irancurrency/backend` جایگزین کنید، اما فایل `.env` فعلی سرور را نگه دارید.

سپس روی Ubuntu:

```bash
cd /opt/irancurrency/backend
sudo docker-compose down
sudo docker-compose up -d --build
sudo docker-compose ps
curl http://127.0.0.1:8080/health
```

بعد از بالا آمدن سرویس، این آدرس را تست کنید:

`https://irancurrency.eu.cc/api/v1/state`

فارسی‌ها و پرچم‌ها باید صحیح نمایش داده شوند.
