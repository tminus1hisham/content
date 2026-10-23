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

## Messaging and reports (§9.11–9.12)

| Endpoint | Request | Response and errors |
| --- | --- | --- |
| `GET /conversations` | — | `[{id, other: {id, displayName, handle?}, blocked, lastMessage}]`. A fan's email or phone is **never** included in `other` |
| `POST /conversations` | `{userId}` | `{id, other}`. Returns the existing conversation if there is one. `403 NOT_ALLOWED` for fan-to-fan, `403 BLOCKED` |
| `GET /conversations/{id}/messages` | — | `{other, blocked, blockedByMe, messages: [{id, senderId, text, createdAt, attachment?: {mediaId, priceCents, locked}}]}`. **`mediaId` is null while `locked`** |
| `POST /conversations/{id}/messages` | `{text, attachment?: {mediaId, priceCents}}` | `201` with the message. Errors: `403 BLOCKED`, `400 EMPTY_MESSAGE`, `400 TOO_LONG` (over 2000 characters). Attachments add `403 CREATOR_NOT_APPROVED`, `400 MEDIA_REQUIRED` and `400 PRICE_OUT_OF_RANGE` |
| Buying an attachment | — | Use `POST /orders` with `{type: "message", itemId: <messageId>}`, then the normal checkout. The app does not use `POST /messages/{id}/unlock` |
| `POST`/`DELETE /users/{id}/block` | — | `204` |
| `POST /reports` | `{targetType: user\|post\|message, targetId, reason: minor\|non_consensual\|harassment\|impersonation\|scam\|other, details}` | `201 {caseId, priority: urgent\|normal, status}`. `minor` and `non_consensual` are **urgent** (FR-SAF-003) |

The app polls the open thread every 5 s. Tell us if you add a realtime transport (WebSocket or SSE).

## Livestreaming (new; not in IT.md §9)

The app uses **LiveKit** for video. The Spring API issues LiveKit access tokens (using the LiveKit server SDK) and is the only place access is decided.

| Method | Endpoint | Purpose |
| --- | --- | --- |
| GET | `/live/now` | Live sessions: `[{id, creator, title, access: free\|subscribers\|ticketed, priceCents, record, status, startedAt, slowModeSeconds, hasAccess, removed}]` |
| GET | `/live/sessions/{id}` | One session, same shape |
| POST | `/live/sessions` | Start a stream. Body `{title, access, priceCents?, record, safetyConfirmed: true}`. Errors: `403 CREATOR_NOT_APPROVED`, `400 TITLE_REQUIRED`, `400 PRICE_OUT_OF_RANGE`, `400 SAFETY_CHECK_REQUIRED` |
| POST | `/live/sessions/{id}/token` | `{url, token, room, identity, name, canPublish}`. `canPublish` is true only for the creator. Errors: `403 LIVE_ACCESS_DENIED` (no ticket or subscription), `403 REMOVED_FROM_LIVE`, `410 LIVE_ENDED` |
| POST | `/live/sessions/{id}/end` | Creator only. Returns `{durationSeconds, tipsCents, ticketsSold, ticketRevenueCents}` and closes the LiveKit room |
| POST | `/live/sessions/{id}/moderation` | Creator only. `{action: mute\|unmute\|remove\|slow_mode, identity?, seconds?}`. Also update the participant's LiveKit permissions (mute → `canPublishData: false`, remove → `RemoveParticipant`) |

Tickets and tips are bought through `POST /orders`:
- **Ticket:** `{type: "ticket", itemId: <sessionId>}`.
- **Tip:** `{type: "tip", itemId: <sessionId>, amountCents}`, where the fan chooses the amount (KSh 10 to 50,000).

When a tip payment succeeds, **the server** sends a LiveKit data message on topic `tip` with `{name, amountCents}`. The app only believes tip, slow-mode and moderation messages that come from the server, and pin messages that come from the creator's identity. Data topics are `chat` `{text}`, `pin` `{text}`, `tip` and `moderation` `{slowModeSeconds?, muted?, removed?}`.

Without `--dart-define=LIVEKIT_URL=…` the app runs the room in demo mode, with no real video and chat that stays on the device.

## Staff (admin) API (§9.13 plus additions)

The admin web app is `lib/main_admin.dart`. Staff are a separate account type, and every route checks **one granular permission** from IT.md §7.3:

`creator.verification.review`, `moderation.case.read`, `moderation.case.resolve`, `finance.payout.approve`, `finance.payout.initiate`, `contracts.template.manage`, `admin.config.manage`, `admin.roles.manage`, `audit.sensitive_access.read`.

A missing permission returns `403 FORBIDDEN`. Every write is recorded in the audit log.

| Method | Endpoint | Notes |
| --- | --- | --- |
| POST | `/admin/auth/login` | **New.** Body `{email, password, mfaCode}`. Returns `{accessToken, refreshToken, staff: {id, email, name, role, permissions[], mfaEnabled}}`. Errors: `401 INVALID_CREDENTIALS`, `MFA_REQUIRED`, `MFA_INVALID`. The app signs out after 15 minutes idle |
| GET | `/admin/me` | **New.** The signed-in staff member |
| GET | `/admin/dashboard` | `{pendingCreators, openReports, urgentReports, payoutsToReview, reconciliationExceptions}` |
| GET | `/admin/creators?status=under_review` | **New.** `[{userId, displayName, handle, status, identity, contract: {version, signedAt}, payoutVerified, categories}]`. Shows outcomes only, never identity documents |
| POST | `/admin/creators/{id}/review` | **New** (instead of `/admin/verification/{id}/review`). Body `{decision: approve\|request_info\|reject\|suspend, reason}`. Every decision except `approve` needs a reason (`400 REASON_REQUIRED`) |
| GET | `/admin/moderation/cases` | Urgent cases first. `reporterId` is withheld |
| POST | `/admin/moderation/cases/{id}/actions` | Body `{action: dismiss\|restrict_content\|suspend_user, reasonCode}` |
| GET | `/admin/payouts?status=` | Payout JSON plus `creatorId`, `approvedBy`, `rejectReason` |
| POST | `/admin/payouts/{id}/approve` | `requested` → `approved` |
| POST | `/admin/payouts/{id}/submit` | `approved` → sent to M-Pesa. **Dual control:** the approver gets `409 DUAL_CONTROL_REQUIRED` |
| POST | `/admin/payouts/{id}/reject` | Body `{reason}`. The reserved amount goes back to available |
| GET | `/admin/contracts/templates` | `[{id, title, versions: [{version, status, commissionPercent, effectiveFrom, signedCount}]}]` |
| GET | `/admin/configuration` | `{commissionPercent, minPriceCents, maxPriceCents, payoutMinimumCents, currencies, countries}` |
| PATCH | `/admin/configuration/commissionPercent` | Body `{value: 0..50}`. Applies to **new** transactions only (FR-PRC-005). Logged as `before -> after` |
| GET | `/admin/audit-events` | `[{at, staff, action, target, detail}]` |
| GET | `/admin/staff` | Staff with role, permissions and MFA status |
