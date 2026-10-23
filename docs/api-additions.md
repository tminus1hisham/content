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

## Content and discovery (§9.6–9.7)

Upload:
1. `POST /media/upload-sessions {kind: image|video, mimeType, size}` returns `201 {id, uploadUrl}`.
2. The app sends `PUT` with the raw bytes to `uploadUrl`, with **no** Authorization header.
3. `POST /media/upload-sessions/{id}/complete` returns `{mediaId, status}`, or `409 UPLOAD_INCOMPLETE`.

The app does one PUT per file today. Tell us which resumable protocol you choose (tus or S3 multipart) and the app will switch to it.

**Post JSON** (every post endpoint returns this shape):

```json
{
  "id": "…",
  "creator": {"id": "…", "handle": "…", "displayName": "…"},
  "caption": "…",
  "access": "free|followers|subscribers|paid",
  "priceCents": 15000,
  "status": "draft|scheduled|published|archived",
  "locked": true,
  "media": [{"id": "…", "kind": "image|video"}],
  "createdAt": "…",
  "publishAt": "…",
  "views": 12
}
```

`publishAt` is optional. `views` is only included for the owner. `locked` is computed **per viewer** on the server.

| Endpoint | Notes |
| --- | --- |
| `POST /posts` | Body `{caption, mediaIds[], access, priceCents?, publish, consent, publishAt?}`. Errors: `400 MEDIA_REQUIRED` (or media owned by someone else). `403 CREATOR_NOT_APPROVED` for `paid`/`subscribers` before approval. `400 PRICE_OUT_OF_RANGE` (KSh 10 to 50,000, in cents). `400 CONSENT_REQUIRED` when publishing without `consent: true` |
| `GET /creators/me/posts?status=` | **New.** The owner's posts, without removed ones |
| `GET /creators/me/analytics` | `{followers, subscribers, posts, views}` |
| `GET /creators/{handle}` | `{id, handle, displayName, bio, categories, location, verified, followers, isFollowing, isSubscribed}`. The handle `me` is reserved |
| `GET /creators/{id}/posts` | Published posts, with `locked` set for each viewer |
| `GET /media/{id}/access` | `200 {url, kind, expiresAt}` (a short-lived URL) or `403 CONTENT_ACCESS_DENIED`. The app never asks for this on a locked post |
| `DELETE /posts/{id}` | Soft delete, so purchases stay traceable |
| `POST`/`DELETE /creators/{id}/follow` | Return the creator JSON |
| `GET /discovery/creators?q=&category=` | Approved, discoverable creators |

## Checkout, subscriptions, earnings and payouts (§9.8–9.10, §10)

Every amount is an integer in cents, in KES. The app only **displays** amounts. The server prices orders and computes commission, net amounts and balances.

| Endpoint | Request | Response and errors |
| --- | --- | --- |
| `POST /orders` | `{type: post\|subscription, itemId, idempotencyKey}`. For a subscription, `itemId` is the creator id. Any client-sent amount is ignored | `201 {id, type, itemId, creatorId, description, currency, amountCents, feesCents, totalCents, recurring, status, createdAt}`. A repeated key returns `200` with the same order. `400 NOT_PURCHASABLE` |
| `POST /orders/{id}/checkout` | `{method: "mpesa", phone: "+2547…", idempotencyKey}` | `201 {id, orderId, status: "processing", method}`. Sends the STK push. `409 ALREADY_PAID`, `400 INVALID_PHONE` |
| `GET /payments/{id}` | — | `{id, orderId, status, method, failureReason?}`. `status` uses the §10.3 states. The app polls every 2 s for about 90 s |
| `POST /payments/provider-webhooks/{provider}` | Provider payload | Must be verified and idempotent. One entitlement and one balanced set of ledger entries per payment |
| `GET /creators/{id}/subscription-tiers` | — | `[{id, name, priceCents, currency, interval, benefits[]}]` |
| `GET /fans/me/purchases` | — | Orders that are paid or being refunded, as order JSON |
| `POST /orders/{id}/refund-requests` | `{reason}` | `201 {id, status}`. `409 NOT_REFUNDABLE` |
| `GET /fans/me/subscriptions` | — | `[{id, creator, priceCents, currency, status: active\|cancelled\|expired, renewsAt?, endsAt, benefits[]}]` |
| `POST /subscriptions/{id}/cancel` | — | Stops renewal. Access continues until `endsAt` |
| `GET /creators/me/earnings` | — | `{currency, pendingCents, availableCents, reservedCents, paidOutCents, adjustmentsCents, commissionPercent, payoutMinimumCents, payoutMaximumCents}` |
| `GET /creators/me/transactions` | — | `[{id, type: sale\|subscription\|payout\|refund, description, currency, grossCents, commissionCents, feesCents, netCents, status, contractRef, createdAt}]` |
| `POST /creators/me/payout-requests` | `{amountCents, payoutMethodId, idempotencyKey}` | `201 {id, amountCents, currency, destination, status, createdAt}`. Moves the amount from available to reserved. Errors: `400 AMOUNT_OUT_OF_RANGE`, `400 INSUFFICIENT_BALANCE`, `400 DESTINATION_NOT_VERIFIED`, `403 CREATOR_NOT_APPROVED` |

Subscriptions are started through `POST /orders` with `type: subscription`, not through `POST /subscriptions`, so every payment goes through the same order, payment and ledger path.
