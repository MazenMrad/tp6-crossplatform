# tp6 — Waiting Room Queue

Resilient single-room waiting queue built with Flutter and Supabase (Workshop 6).

All clients register in one shared queue. Geolocation is optional and informational —
it never decides queue assignment, and a user is never blocked from registering
because GPS is unavailable or permission was denied.

## Features

- Optional geolocation capture (lat, lng, accuracy) during registration
- Connectivity monitoring that distinguishes device network from backend availability
- Offline registration persisted locally in SQLite
- Automatic synchronization of pending/failed registrations with deduplication
- Loading, empty, error and offline UI states
- Pagination with deduplication and Supabase Realtime insert reconciliation
- Unit, provider and widget tests (mocktail)

## Architecture

```
lib/
├── main.dart                  Supabase initialization + provider wiring
├── models/                    Client, SyncStatus, AppConnectivity, QueueState
├── providers/                 QueueProvider, ConnectivityProvider
├── services/                  GeolocationService, ConnectivityService, SyncService
├── repositories/              QueueRepository (+ Supabase remote data source)
├── storage/                   LocalQueueStorage (SQLite)
├── screens/                   QueueScreen
└── widgets/                   ClientCard, OfflineBanner, LoadingWidget, QueueEmptyWidget
```

## Configuration

The app reads its Supabase credentials from `--dart-define`:

```powershell
flutter run --dart-define=SUPABASE_URL=https://qrvpcueshhmofherertv.supabase.co `
            --dart-define=SUPABASE_ANON_KEY=sb_publishable_CJPh-Gp0-F3Fc7RKiEKbWQ_-drQQvYn
```

VS Code: use the preconfigured `tp6 (Android)` / `tp6 (Windows)` launch profiles
in `.vscode/launch.json`.

## Supabase setup

Apply the SQL in `supabase/migrations/` via the Supabase SQL editor:

1. `0001_add_location_columns.sql` — adds optional location columns plus
   latitude/longitude check constraints to `public.clients`.
2. `0002_register_queue_client_function.sql` — creates the
   `register_queue_client` RPC used by the sync engine. It inserts with
   `ON CONFLICT (id) DO UPDATE` so retried registrations never create duplicates.

## Running the tests

```powershell
flutter analyze
flutter test
```
