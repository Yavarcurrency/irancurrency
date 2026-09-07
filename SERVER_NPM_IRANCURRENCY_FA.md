# تنظیم نهایی سرور IranCurrency

دامنه عمومی پروژه: `irancurrency.eu.cc`

Public IP: `91.91.186.199`

Ubuntu Backend: `192.168.220.133`

## مسیر درخواست

Android / iOS -> HTTPS 443 -> Nginx Proxy Manager -> HTTP 80 -> Ubuntu Nginx -> 127.0.0.1:8080 -> FastAPI

## Nginx Proxy Manager

Proxy Host جدید:

- Domain Names: `irancurrency.eu.cc`
- Scheme: `http`
- Forward Hostname / IP: `192.168.220.133`
- Forward Port: `80`
- Block Common Exploits: ON
- Websockets Support: OFF (فعلاً لازم نیست)

بخش SSL:

- Request a new SSL Certificate
- Force SSL: ON
- HTTP/2 Support: ON

بعد از فعال شدن SSL باید این آدرس از اینترنت موبایل جواب بدهد:

`https://irancurrency.eu.cc/health`

## Ubuntu Nginx

فایل `backend/nginx.example.conf` از قبل با همین دامنه تنظیم شده است.

Backend Docker فقط روی `127.0.0.1:8080` در دسترس است و مستقیماً به شبکه بیرونی منتشر نمی‌شود.

## Build Android

آدرس API داخل پروژه به صورت پیش‌فرض `https://irancurrency.eu.cc` است. بنابراین Build معمولی کافی است:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

در صورت نیاز هنوز می‌توان آدرس را موقتاً Override کرد:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://example.com
```

## iOS / Codemagic

`codemagic.yaml` نیز از قبل همین دامنه را برای API استفاده می‌کند.
