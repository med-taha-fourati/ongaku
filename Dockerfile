FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG BACKEND_URL

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build apk --release --dart-define=BACKEND_URL=$BACKEND_URL

FROM alpine:latest
COPY --from=build /app/build/app/outputs/flutter-apk/app-release.apk /output/app-release.apk