# Docker And Apache Commands

Assumption: run these commands from the repository root on the server.

## 1. Build S3 Signer API

```bash
docker build -t vanavil-s3-api ./services/s3_signer_api
```

## 2. Run S3 Signer API On Port 8004

```bash
docker rm -f vanavil-s3-api || true

FIREBASE_JSON="/vanavi/vanavil-admin/services/s3_signer_api/vanavil-2c565-firebase-adminsdk-fbsvc-9773c8b670.json"
ls -l "$FIREBASE_JSON"

docker run -d \
  --name vanavil-s3-api \
  --restart unless-stopped \
  -p 8004:8000 \
  --env-file ./services/s3_signer_api/.env \
  -v "$FIREBASE_JSON:/run/secrets/firebase-service-account.json:ro" \
  -e FIREBASE_SERVICE_ACCOUNT_PATH=/run/secrets/firebase-service-account.json \
  vanavil-s3-api
```

Host JSON file path:

```bash
/vanavi/vanavil-admin/services/s3_signer_api/vanavil-2c565-firebase-adminsdk-fbsvc-9773c8b670.json
```

Container JSON file path used by the app:

```bash
/run/secrets/firebase-service-account.json
```

## 3. Test S3 Signer API

```bash
docker ps
curl http://127.0.0.1:8004/docs
docker logs -f vanavil-s3-api
```

## 4. Update S3 API Env For Domain

Update `services/s3_signer_api/.env` on the server to include:

```dotenv
S3_API_ALLOWED_ORIGINS=https://vanavil.digitalgrub.in
S3_API_ALLOWED_ORIGIN_REGEX=
```

After changing `.env`, recreate the container:

```bash
docker rm -f vanavil-s3-api

FIREBASE_JSON="/vanavi/vanavil-admin/services/s3_signer_api/vanavil-2c565-firebase-adminsdk-fbsvc-9773c8b670.json"
ls -l "$FIREBASE_JSON"

docker run -d \
  --name vanavil-s3-api \
  --restart unless-stopped \
  -p 8004:8000 \
  --env-file ./services/s3_signer_api/.env \
  -v "$FIREBASE_JSON:/run/secrets/firebase-service-account.json:ro" \
  -e FIREBASE_SERVICE_ACCOUNT_PATH=/run/secrets/firebase-service-account.json \
  vanavil-s3-api
```

## 5. Build Admin Web With Production API URL

```bash
docker build \
  -t vanavil-admin-web \
  -f apps/admin_web/Dockerfile \
  --build-arg VANAVIL_S3_API_BASE_URL=https://vanavil.digitalgrub.in/api \
  .
```

## 6. Run Admin Web On Port 8080

```bash
docker rm -f vanavil-admin-web || true

docker run -d \
  --name vanavil-admin-web \
  --restart unless-stopped \
  -p 8080:80 \
  vanavil-admin-web
```

## 7. Test Admin Web

```bash
docker ps
curl http://127.0.0.1:8080
docker logs -f vanavil-admin-web
```

## 8. Apache Config For Domain

Create the Apache vhost file:

```bash
sudo tee /etc/httpd/conf.d/vanavil.conf > /dev/null <<'EOF'
<VirtualHost *:80>
    ServerName vanavil.digitalgrub.in

    ProxyPreserveHost On
    ProxyRequests Off

    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Port "80"

    ProxyPass /api/ http://127.0.0.1:8004/
    ProxyPassReverse /api/ http://127.0.0.1:8004/

    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/

    ErrorLog /var/log/httpd/vanavil-error.log
    CustomLog /var/log/httpd/vanavil-access.log combined
</VirtualHost>
EOF
```

Validate and restart Apache:

```bash
sudo apachectl configtest
sudo systemctl restart httpd
```

## 9. HTTPS Apache Config

If SSL is configured, use this structure for the HTTPS vhost:

```apache
<VirtualHost *:443>
    ServerName vanavil.digitalgrub.in

    SSLEngine on

    ProxyPreserveHost On
    ProxyRequests Off

    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"

    ProxyPass /api/ http://127.0.0.1:8004/
    ProxyPassReverse /api/ http://127.0.0.1:8004/

    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/

    ErrorLog /var/log/httpd/vanavil-error.log
    CustomLog /var/log/httpd/vanavil-access.log combined
</VirtualHost>
```

## 10. End-To-End Checks

```bash
curl http://127.0.0.1:8004/docs
curl http://127.0.0.1:8080
curl -I http://vanavil.digitalgrub.in
curl -I http://vanavil.digitalgrub.in/api/docs
```

If HTTPS is enabled:

```bash
curl -I https://vanavil.digitalgrub.in
curl -I https://vanavil.digitalgrub.in/api/docs
```

## 11. Rebuild Only Admin Web After API Path Change

If the public API URL changes, rebuild only the admin web image:

```bash
docker rm -f vanavil-admin-web

docker build \
  -t vanavil-admin-web \
  -f apps/admin_web/Dockerfile \
  --build-arg VANAVIL_S3_API_BASE_URL=https://vanavil.digitalgrub.in/api \
  .

docker run -d \
  --name vanavil-admin-web \
  --restart unless-stopped \
  -p 8080:80 \
  vanavil-admin-web
```

## 12. Recreate Only S3 API After Env Change

If only `.env` changes, do not rebuild the image. Recreate the container:

```bash
docker rm -f vanavil-s3-api

FIREBASE_JSON="/vanavi/vanavil-admin/services/s3_signer_api/vanavil-2c565-firebase-adminsdk-fbsvc-9773c8b670.json"
ls -l "$FIREBASE_JSON"

docker run -d \
  --name vanavil-s3-api \
  --restart unless-stopped \
  -p 8004:8000 \
  --env-file ./services/s3_signer_api/.env \
  -v "$FIREBASE_JSON:/run/secrets/firebase-service-account.json:ro" \
  -e FIREBASE_SERVICE_ACCOUNT_PATH=/run/secrets/firebase-service-account.json \
  vanavil-s3-api
```