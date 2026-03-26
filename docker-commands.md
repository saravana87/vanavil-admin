# Docker Commands

Final production domains:

- Admin web: `https://vanavil.digitalgrub.in`
- API: `https://vanavilapi.digitalgrub.in`

Assumption: the server checkout already exists at `/vanavi/vanavil-admin` and this repository already includes [docker-compose.yml](docker-compose.yml).

## 1. Pull Latest Code

```bash
cd /vanavi/vanavil-admin
git pull origin main
```

## 2. Check Required Files

Make sure these files already exist on the server before starting containers:

- `services/s3_signer_api/.env`
- `services/s3_signer_api/vanavil-2c565-firebase-adminsdk-fbsvc-9773c8b670.json`

Update `services/s3_signer_api/.env` to include:

```dotenv
S3_API_ALLOWED_ORIGINS=https://vanavil.digitalgrub.in
S3_API_ALLOWED_ORIGIN_REGEX=
```

## 3. Start With Docker Compose

The repository already has a compose file that starts both services together.

```bash
cd /vanavi/vanavil-admin

export VANAVIL_S3_API_BASE_URL=https://vanavilapi.digitalgrub.in
docker compose up --build -d
```

## 4. Quick Checks

```bash
cd /vanavi/vanavil-admin

docker compose ps
curl http://127.0.0.1:8000/docs
curl http://127.0.0.1:8080
docker compose logs --tail 100 s3_signer_api
docker compose logs --tail 100 admin_web
```

## 5. Apache Routing

Expected Apache target mapping:

- `vanavil.digitalgrub.in` -> `http://127.0.0.1:8080`
- `vanavilapi.digitalgrub.in` -> `http://127.0.0.1:8000`

## 6. Rebuild After Code Changes

Use this after `git pull` when application code changed:

```bash
cd /vanavi/vanavil-admin

export VANAVIL_S3_API_BASE_URL=https://vanavilapi.digitalgrub.in
docker compose up --build -d
```

## 7. Restart Without Rebuild

Use this when only runtime state changed and the images do not need to be rebuilt:

```bash
cd /vanavi/vanavil-admin
docker compose restart
```

## 8. Stop Everything

```bash
cd /vanavi/vanavil-admin
docker compose down
```