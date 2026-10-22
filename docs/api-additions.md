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

## Creator onboarding details the app relies on (§9.3–9.5, §9.10)

| Endpoint | Request | Response |
| --- | --- | --- |
| `GET /creators/me/onboarding` | — | `{status, steps: {contact, identity: not_started\|pending\|verified\|failed, profile, contract, payout}, readyToSubmit}`. `status` uses the FR-CRT-002 values |
| `POST /creators/me/submit-review` | — | `200` with the new onboarding body. `400 ONBOARDING_INCOMPLETE` |
| `POST /verification/sessions` | — | `201 {sessionId, status, providerUrl?}`. The app will open `providerUrl` once a provider is chosen |
| `GET /verification/status` | — | `{status}` |
| `GET` / `PATCH /creators/me` | `{displayName, handle, bio, categories[], language, location, discoverable}` | The profile. `GET` returns `404` before the first save. `PATCH` can return `400 INVALID_HANDLE` (must match `^[a-z0-9_]{3,20}$`) or `409 HANDLE_TAKEN` |
| `GET /contracts/offers` | — | `[{id, title, version, commissionPercent}]`. Empty once signed |
| `GET /contracts/offers/{id}` | — | `{id, title, version, commissionPercent, documentHash, sections: [{heading, body}]}`. `documentHash` is a SHA-256 of the exact text shown |
| `POST /contracts/offers/{id}/sign` | `{version, documentHash, signatureName, consentToElectronicSignature: true}` | `201 {id, version, documentHash, signedAt, signatureName}`. `409 VERSION_MISMATCH` if the version or hash isn't the current one. `400 SIGNATURE_INVALID` |
| `POST /creators/me/payout-methods` | `{type: "mpesa", phone: "+2547…", accountName}` | `201 {id, type, phoneMasked, accountName, verified: false}`. Sends an SMS code. Replacing a destination resets `verified` |
| `POST /creators/me/payout-methods/{id}/verify` | `{code}` | The method with `verified: true`. `400 INVALID_CODE` |
