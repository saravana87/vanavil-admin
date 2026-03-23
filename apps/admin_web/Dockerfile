FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /repo

COPY packages/vanavil_core ./packages/vanavil_core
COPY packages/vanavil_firebase ./packages/vanavil_firebase
COPY packages/vanavil_ui ./packages/vanavil_ui
COPY apps/admin_web/pubspec.yaml ./apps/admin_web/pubspec.yaml

WORKDIR /repo/apps/admin_web
RUN flutter pub get

COPY apps/admin_web ./

ARG VANAVIL_S3_API_BASE_URL
RUN flutter build web --release --dart-define=VANAVIL_S3_API_BASE_URL=${VANAVIL_S3_API_BASE_URL}

FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1

WORKDIR /app

COPY apps/admin_web/server.py ./server.py
COPY --from=build /repo/apps/admin_web/build/web ./public

EXPOSE 80

CMD ["python", "server.py", "--directory", "/app/public", "--port", "80"]