# SMA Flutter Frontend

Responsive Flutter web frontend for the SMA Ghana school management platform.

## API Target

The frontend reads its backend URL from `SMA_API_BASE_URL`.

Default local backend:

```bash
http://localhost:8080/Narellallc/sma-v1/1.0.0
```

Production backend:

```bash
https://api.airghana.org/Narellallc/sma-v1/1.0.0
```

## Run Locally

The complete assessment, evaluation, report, correction, and term-closing workflow is documented in [Term Evaluations and Report Cards](docs/TERM_EVALUATIONS_AND_REPORT_CARDS_TRAINING_MANUAL.md).

### Recommended: one port

Build the Flutter web app and let Spring Boot serve both the interface and the
API from one address:

```bash
./tool/run_single_port.sh
```

Open:

```text
http://localhost:3000
```

Only port `3000` is exposed. To use another port:

```bash
PORT=4173 ./tool/run_single_port.sh
```

If the backend repository is not beside `SMA-Fontend`, set its location:

```bash
SMA_BACKEND_DIR=/path/to/spring-server-generated ./tool/run_single_port.sh
```

### Separate frontend and backend ports

Use the default localhost backend:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 4173
```

Point to a different local backend:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 4173 \
  --dart-define=SMA_API_BASE_URL=http://localhost:8080/Narellallc/sma-v1/1.0.0
```

Run from a phone on the same Wi-Fi by replacing `localhost` with your Mac IP:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 4173 \
  --dart-define=SMA_API_BASE_URL=http://YOUR_MAC_IP:8080/Narellallc/sma-v1/1.0.0
```

## Run Against Production

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 4173 \
  --dart-define=SMA_API_BASE_URL=https://api.airghana.org/Narellallc/sma-v1/1.0.0
```

For production web builds, pass the same define to `flutter build web`.
