FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .

RUN dart compile exe bin/server.dart -o bin/server

FROM debian:bullseye-slim
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/bin/server /app/server

EXPOSE 8080
ENV ADDRESS=0.0.0.0
ENV PORT=8080
VOLUME ["/app/uploads"]
CMD ["./server"]
