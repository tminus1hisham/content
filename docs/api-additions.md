# API additions for the Spring Boot team

Endpoints the Flutter app calls that are **not** in IT.md §9. Base path `/api/v1`.
Errors use `{"code": "...", "message": "..."}`. The in-app fake backend
(`lib/features/*/fake_*.dart`) implements each route and is the reference behaviour.

## Auth details the app relies on (§9.2)

| Endpoint | Request | Success | Errors the app handles |
| --- | --- | --- | --- |
| `POST /auth/register` | `{identifier, password, country, acceptedTerms}`. `identifier` is a lower-cased email or E.164 phone (`+2547…`) | `201 {verificationId}`. Same response when the identifier is already taken | — |
| `POST /auth/verify-contact` | `{verificationId, code}` | `200 {verified: true}` | `400 INVALID_CODE`, `410 VERIFICATION_EXPIRED`, `429 RATE_LIMITED` |
| `POST /auth/resend-verification` | `{verificationId}` | `202` | `429 RATE_LIMITED` |
| `POST /auth/login` | `{identifier, password}` | `200 {accessToken, refreshToken, user}` | `401 INVALID_CREDENTIALS`, `403 CONTACT_NOT_VERIFIED` with a fresh `verificationId` |
| `POST /auth/refresh` | `{refreshToken}` | `200 {accessToken, refreshToken, user}`. Rotates the refresh token | `401` means the session is over and the app signs out |
| `POST /auth/logout` | `{refreshToken}` | `204` | — |

Any other endpoint returning `401` makes the app call `/auth/refresh` once and retry the request.

## New

| Method | Endpoint | Purpose |
| --- | --- | --- |
| GET | `/users/me` | Current account: `{id, identifier, roles: ["fan"\|"creator"], verified}`. Used to restore a session at startup |
| PUT | `/users/me/roles` | `{roles: [...]}` sets the account's roles (IT.md screen A4). `400 INVALID_ROLES`. Adding `creator` only **starts** onboarding and must not allow monetising (FR-AUTH-003) |
