#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${SMA_BACKEND_DIR:-$(cd "$APP_DIR/../.." && pwd)/spring-server-generated}"
PORT="${PORT:-3000}"

if [[ ! -f "$BACKEND_DIR/pom.xml" ]]; then
  echo "Backend not found at: $BACKEND_DIR" >&2
  echo "Set SMA_BACKEND_DIR to the Spring Boot project directory." >&2
  exit 1
fi

echo "Building the web application..."
(
  cd "$APP_DIR"
  flutter build web \
    --base-href=/ \
    --dart-define=SMA_API_BASE_URL=
)

export SMA_WEB_STATIC_LOCATION="file:$APP_DIR/build/web/"

echo "Starting the complete application at http://localhost:$PORT"
echo "Press Ctrl+C to stop it."
(
  cd "$BACKEND_DIR"
  mvn spring-boot:run -Dspring-boot.run.profiles=single-port
)
