FROM dart:stable as build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .

RUN dart compile exe bin/server.dart -o bin/server

# running the thing
FROM debian:bullseye-slim
WORKDIR /app
COPY --from=build /app/bin/server /app/server

EXPOSE 8080

CMD ["./server"]