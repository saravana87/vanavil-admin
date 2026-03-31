FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /repo

COPY packages/vanavil_core ./packages/vanavil_core
COPY packages/vanavil_firebase ./packages/vanavil_firebase
COPY packages/vanavil_ui ./packages/vanavil_ui
COPY apps/child_app/pubspec.yaml ./apps/child_app/pubspec.yaml

WORKDIR /repo/apps/child_app
RUN flutter pub get

COPY apps/child_app ./

ARG VANAVIL_API_BASE_URL
ARG VANAVIL_WEB_BASE_HREF=/child_login/
RUN flutter build web --release --base-href ${VANAVIL_WEB_BASE_HREF} --dart-define=VANAVIL_API_BASE_URL=${VANAVIL_API_BASE_URL}

FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1

ARG VANAVIL_WEB_BASE_HREF=/child_login/
ENV VANAVIL_WEB_BASE_HREF=${VANAVIL_WEB_BASE_HREF}

WORKDIR /app

COPY apps/child_app/server.py ./server.py
COPY --from=build /repo/apps/child_app/build/web ./public

EXPOSE 80

CMD ["sh", "-c", "python server.py --directory /app/public --port 80 --base-path \"$VANAVIL_WEB_BASE_HREF\""]
