FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart compile exe bin/server.dart -o /app/edge_ai_assistant

FROM dart:stable
WORKDIR /app
COPY --from=build /app/edge_ai_assistant /app/edge_ai_assistant
ENV PORT=8080
EXPOSE 8080
CMD ["/app/edge_ai_assistant"]
