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
