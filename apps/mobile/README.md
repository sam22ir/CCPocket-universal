# CCPocket Mobile

Flutter client for `CCPocket Universal`.

## Run

```bash
flutter pub get
flutter run
```

The app expects the local bridge server in `packages/bridge` to be running on `ws://localhost:8765` unless you change the bridge URL in app settings.

## Checks

```bash
flutter analyze --no-pub
```

For project-level setup and bridge configuration, use the root `README.md`.
