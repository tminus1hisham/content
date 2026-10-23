# Content

A Kenya-first, adults-only creator platform. It ships as a Flutter app for Android, iOS and web, plus a staff admin web app. The product spec is [IT.md](IT.md).

## Run it

```sh
flutter pub get
flutter run                                  # fan / creator app
flutter run -d chrome -t lib/main_admin.dart # staff admin app
flutter test                                 # 92 tests
```

Until the Spring Boot API is ready, the app runs against an **in-app fake backend** (`lib/features/*/fake_*.dart`). It implements every endpoint the app calls. Demo accounts (password `password123`, every OTP or MFA code `123456`):

| Account | What it is |
| --- | --- |
| `fan@demo.ke` | Fan with a chat and a paid attachment waiting |
| `creator@demo.ke` | Approved creator (Amani) with earnings and a payout request |
| `new@demo.ke` | Creator who hasn't started onboarding |
| `pending@demo.ke` | Creator waiting for staff review |
| `admin@staff.ke` | Staff: super admin |
| `mod@staff.ke` | Staff: moderator |
| `finance@staff.ke`, `finance2@staff.ke` | Staff: finance. You need both to send a payout (dual control) |

In checkout, M-Pesa numbers ending in `000` fail and numbers ending in `999` are cancelled. Every other number succeeds.

## Connect the real services

| Setting | What it does |
| --- | --- |
| `--dart-define=API_BASE_URL=https://api.example.com` | Uses the Spring Boot API and turns the fake backend off |
| `--dart-define=LIVEKIT_URL=wss://…` and `--dart-define=LIVEKIT_DEV_TOKEN=…` | Real video for livestreams while the API isn't issuing tokens yet |

[docs/api-additions.md](docs/api-additions.md) lists every request and response shape the app relies on, including the endpoints IT.md §9 doesn't cover (livestreaming, staff login, sessions and so on). Hand it to the API team.

## Where things are

- `lib/app/`: router, theme (light, dark or system, plus accent colour)
- `lib/core/`: API client (token refresh), fake backend, KES formatting
- `lib/features/disguise/`: app icon disguise (Weather, Notes, Calendar, Calculator), working decoy apps, PIN lock
- `lib/features/auth`, `onboarding`, `content`, `commerce`, `messages`, `live`, `settings`, `admin`: one folder per area

## Distribution

Google Play and the App Store don't allow sexual content:
- **Android:** ship as a direct APK download.
- **Web:** works as is.
- **iOS:** limited to Ad Hoc or enterprise distribution.

Payment providers (Safaricom Daraja, card processors) must approve the business before production. See IT.md §16 Phase 0.
