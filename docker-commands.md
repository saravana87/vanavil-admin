# Docker Commands

Final production domains:

- Admin web: `https://vanavil.digitalgrub.in`
- Child web: `https://vanavil.digitalgrub.in/child_login/`
- API: `https://vanavilapi.digitalgrub.in`

Assumption: run these commands from the repository root on the server.

Note: this file documents the manual server deployment flow. The root `docker-compose.yml`
is still useful for local or simple container runs, but it exposes the API on `8000`.
The production server commands below expose the API on `8004` and expect Apache to
reverse proxy to that port.

## 1. Pull Latest Code

```bash
cd /vanavi/vanavil-admin
git pull origin main
```

## 1.5. Deploy Firebase Changes When Needed

Docker only updates the containers on the EC2 server. If you changed Firestore rules
or indexes, deploy those separately from a machine that already has Firebase CLI access
to the VANAVIL project.

```bash
cd /path/to/your/local/vanavil/repo

firebase deploy --only firestore:rules --project vanavil-2c565
firebase deploy --only firestore:indexes --project vanavil-2c565
```

Run this step only when files under `firebase/` changed.

## 2. Build And Run API

Update `services/s3_signer_api/.env` on the server to include:

```dotenv
S3_API_ALLOWED_ORIGINS=https://vanavil.digitalgrub.in
S3_API_ALLOWED_ORIGIN_REGEX=
```

Build and run:

```bash
cd /vanavi/vanavil-admin

FIREBASE_JSON="/vanavi/vanavil-admin/services/s3_signer_api/vanavil-2c565-firebase-adminsdk-fbsvc-9773c8b670.json"

docker build -t vanavil-s3-api:latest ./services/s3_signer_api

docker rm -f vanavil-s3-api || true

docker run -d \
  --name vanavil-s3-api \
  --restart unless-stopped \
  --env-file /vanavi/vanavil-admin/services/s3_signer_api/.env \
  -e FIREBASE_SERVICE_ACCOUNT_PATH=/run/secrets/firebase-service-account.json \
  -p 8004:8000 \
  -v "$FIREBASE_JSON:/run/secrets/firebase-service-account.json:ro" \
  vanavil-s3-api:latest
```

## 3. Build And Run Admin Web

Build and run:

```bash
cd /vanavi/vanavil-admin

docker build \
  -f apps/admin_web/Dockerfile \
  --build-arg VANAVIL_S3_API_BASE_URL=https://vanavilapi.digitalgrub.in \
  -t vanavil-admin-web:latest .

docker rm -f vanavil-admin-web || true

docker run -d \
  --name vanavil-admin-web \
  --restart unless-stopped \
  -p 8080:80 \
  vanavil-admin-web:latest
```

## 4. Quick Checks

```bash
docker ps
curl http://127.0.0.1:8004/docs
curl http://127.0.0.1:8080
curl http://127.0.0.1:8080/health
docker logs --tail 100 vanavil-s3-api
docker logs --tail 100 vanavil-admin-web
```

## 5. Build And Run Child Web

Build and run:

```bash
cd /vanavi/vanavil-admin

docker build \
  -f apps/child_app/Dockerfile \
  --build-arg VANAVIL_API_BASE_URL=https://vanavilapi.digitalgrub.in \
  --build-arg VANAVIL_WEB_BASE_HREF=/child_login/ \
  -t vanavil-child-web:latest .

docker rm -f vanavil-child-web || true

docker run -d \
  --name vanavil-child-web \
  --restart unless-stopped \
  -p 8081:80 \
  vanavil-child-web:latest
```

Quick checks:

```bash
curl http://127.0.0.1:8081/
curl http://127.0.0.1:8081/child_login/
curl http://127.0.0.1:8081/health
docker logs --tail 100 vanavil-child-web
```

## 6. Apache Routing

Expected Apache target mapping:

- `vanavil.digitalgrub.in` -> `http://127.0.0.1:8080`
- `vanavilapi.digitalgrub.in` -> `http://127.0.0.1:8004`
- `vanavil.digitalgrub.in/child_login/` -> `http://127.0.0.1:8081/`

## 7. Rebuild Only Admin Web

Use this when only admin web code changed:

```bash
cd /vanavi/vanavil-admin

docker build \
  -f apps/admin_web/Dockerfile \
  --build-arg VANAVIL_S3_API_BASE_URL=https://vanavilapi.digitalgrub.in \
  -t vanavil-admin-web:latest .

docker rm -f vanavil-admin-web || true

docker run -d \
  --name vanavil-admin-web \
  --restart unless-stopped \
  -p 8080:80 \
  vanavil-admin-web:latest
```

## 8. Rebuild Only Child Web

Use this when only child web code changed:

```bash
cd /vanavi/vanavil-admin

docker build \
  -f apps/child_app/Dockerfile \
  --build-arg VANAVIL_API_BASE_URL=https://vanavilapi.digitalgrub.in \
  --build-arg VANAVIL_WEB_BASE_HREF=/child_login/ \
  -t vanavil-child-web:latest .

docker rm -f vanavil-child-web || true

docker run -d \
  --name vanavil-child-web \
  --restart unless-stopped \
  -p 8081:80 \
  vanavil-child-web:latest
```

## 9. Recreate Only API

Use this when only `.env` changed:

```bash
cd /vanavi/vanavil-admin

FIREBASE_JSON="/vanavi/vanavil-admin/services/s3_signer_api/vanavil-2c565-firebase-adminsdk-fbsvc-9773c8b670.json"

docker rm -f vanavil-s3-api || true

docker run -d \
  --name vanavil-s3-api \
  --restart unless-stopped \
  --env-file /vanavi/vanavil-admin/services/s3_signer_api/.env \
  -e FIREBASE_SERVICE_ACCOUNT_PATH=/run/secrets/firebase-service-account.json \
  -p 8004:8000 \
  -v "$FIREBASE_JSON:/run/secrets/firebase-service-account.json:ro" \
  vanavil-s3-api:latest
```