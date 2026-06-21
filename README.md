# Digital Mitro — Flutter Mobile App

Flutter client for the Digital Mitro CRM, talking to the same backend
that powers CRMAdmin / CRMEmployees / CRMClient on the web.

Built against **Flutter 3.41.6**.

## 1. Setup

```bash
flutter pub get
```

### Configure the backend URL

Open `lib/core/constants/api_constants.dart` and set:

```dart
static const String baseUrl = 'https://your-backend-domain.com';
```

- Android emulator talking to a backend running on your own machine: use `http://10.0.2.2:5000`
- iOS simulator talking to your own machine: use `http://localhost:5000`
- Real device / production: your actual deployed backend URL

### Run

```bash
flutter run
```

## 2. What's built (Phase 1)

Fully wired to your real backend — no mock data:

- **Splash → Login → Home shell** — unified login via `POST /mobile/login`
  (the "Login As" tabs are a visual hint only; the server auto-detects
  Employee/Admin/SuperAdmin/Client from the email, same as the actual
  account lookup logic)
- **Home** — greeting, clock in/out card, 4 stat cards, recent activity —
  all from `GET /mobile/dashboard`
- **Tasks** — search, All/Today/Pending/Done filters, checkbox to
  toggle complete, priority + due chips — from `GET /channels/tasks/all`
  and `PATCH /channels/:channelId/tasks/:taskId`
- **Attendance** — hero card, clock in/out, "Work in progress" state,
  history list with Leave/Week-Off/Absent colour coding — from
  `GET /attendance/user` and `POST /attendance/punch-in` / `punch-out`
- **Notifications** — list + clear all — from `/notification/*`
- **Chat (list only)** — Channels tab + DMs tab with unread badges and
  last-message previews — from `GET /mobile/channels` and `GET /mobile/dms`
- **Drawer** — role-adaptive: SuperAdmin/Admin see items gated by their
  actual `permissions` object (same system as the web sidebar); Employee
  and Client see trimmed sets

Session persistence (secure storage), pull-to-refresh, and consistent
loading/empty/error states are wired throughout.

## 3. What's next (Phase 2 — not yet built)

- Full chat **messaging** screens (bubbles, send, attachments, replies,
  pin, sockets for real-time updates) — list screens above are ready to
  link into this once built
- Remaining drawer destinations: Notes, Callbacks, Transfers, Sales,
  Activity, Concern, Salary, Manage Admins, Settings (currently show a
  "coming soon" snackbar placeholder)
- Push notifications **inside** the app (backend FCM sending is already
  built — see `CRMBackend/utils/pushNotification.js` — the app just
  needs `firebase_messaging` wired up once you've set up a Firebase
  project; `lib/services/auth_service.dart` already has a
  `registerFcmToken()` method ready to call)
- Google / Microsoft SSO (buttons are present but currently just show a
  "coming soon" message)

## 4. Project structure

```
lib/
  core/           # theme, constants, network client, secure storage
  models/         # plain Dart classes mirroring backend response shapes
  services/       # one class per backend resource (AuthService, TaskService, ...)
  providers/      # Provider-based app state (AuthProvider, NavProvider)
  screens/        # one folder per screen/feature
  widgets/        # shared reusable widgets (avatar, chips, badges, states)
```

State management: **Provider**. Networking: **Dio**, with a single
shared `ApiClient` that auto-attaches the JWT and converts every
failure into a friendly `ApiException`.
