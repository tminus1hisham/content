# Raha UI revamp: "Velvet night"

## Context
Raha (Flutter 3.41, Riverpod, go_router, fake backend, 22 widget tests) is a creator-support app for 18+ fans in Kenya. The user says it "looks too simple, like a beginner", and wants it premium and alluring, using the Emil Kowalski design-engineering principles and the UI skills.

Why it reads as beginner:
- **No motion.** The 13.7k lines contain one animated widget, no Hero, no press feedback and no haptics.
- **No identity.** Theme colours come from `ColorScheme.fromSeed(Rose)`, which looks like generic Material 3. The brand itself (sunset orange → coral → pink on cream, used in the uncommitted splash) appears nowhere else.
- **No imagery.** Creators are a letter in a `CircleAvatar` (7 places), and the app has 58 stock `ListTile`s.
- **Weak states.** Loading is a bare spinner (12 places), and empty and error states are bare `Center(Text)` (14 places).
- **Stock chrome.** The `NavigationBar` and app bars are unstyled.

User decisions:
1. Commit the pending Raha rebrand on develop first, then branch `ui-revamp`.
2. **Velvet night, dark-first.** The look is designed in dark first, with warm cream as the light mode. The default `ThemeMode.system` stays, because `theme_controller_test` asserts it.
3. **Generated creator identity.** Each creator gets a deterministic gradient avatar and banner derived from their id. There is no API change.

## Phase 0: Setup
- `git add -A && git commit -m "chore: Raha rebrand (icons, splash, covers, demo posts)"` on develop.
- `git checkout -b ui-revamp`.
- Write `REVAMP_PLAN.md` at the repo root, a copy of this plan with a status column.

## Design direction
- **Concept:** a private, cinematic room after dark. Deep plum-black surfaces, the sunset gradient used only as light (glows, rings, primary CTAs), image-led cards, and quiet, confident motion.
- **Dark palette:**

  | Role | Value |
  | --- | --- |
  | surface | `#0E0A0D` |
  | containerLow | `#16101A` |
  | container | `#1D1521` |
  | containerHigh | `#261C2A` |
  | onSurface | `#F7EEF1` |
  | onSurfaceVariant | `#B4A3AC` |
  | outlineVariant | white at 8% |

  - The brand gradient is `#FF9A43 → #EC6A72 → #FF65A1`.
- **Light palette:**

  | Role | Value |
  | --- | --- |
  | surface | cream `#FFFCF5` |
  | onSurface | ink `#392B32` |
  | onSurfaceVariant | `#796972` |

  - The surface containers are warm tints.
- **Accent:** `accents[0]` becomes `('Sunset', Color(0xFFEC6A72))`. The index stays 0, so persisted choices still work. The other accents still recolour `primary`, while the surfaces stay brand-fixed.
- **Type:** Manrope stays.
  - Display and headline get tighter tracking (−1.0 / −0.5).
  - Money and counts use tabular figures.
  - Follower counts are compact ("12.4k") via `intl` `NumberFormat.compact`.
- **Shape and depth:**
  - Radii: cards 20, controls 14, sheets 28.
  - Depth comes from layered surface tones plus a hairline border at 6–8%, not drop shadows (shadows don't read on black).
- **Motion (Emil):**
  - Curves: `easeOut = Cubic(0.23,1,0.32,1)`, `easeInOut = Cubic(0.77,0,0.175,1)`, `drawer = Cubic(0.32,0.72,0,1)`.
  - Durations: press 140ms, small 200ms, sheet/page 300ms.
  - Pressables scale to 0.97.
  - Entrances fade + 8px rise, staggered 40ms and capped at 8 items.
  - No animation on repeated, high-frequency actions (typing, tab re-taps).
  - Everything goes to `Duration.zero` under `MediaQuery.disableAnimationsOf`.
- **NOT doing:**
  - Generic purple gradients.
  - Glassmorphism on everything (blur only on the tab bar and floating CTAs).
  - Bouncy springs on serious money screens.
  - Restyling the **decoy apps** (calculator, notes, weather, calendar must keep looking stock: that is their safety purpose).
  - Restyling the **staff admin app** (internal tool, out of scope).

## Foundations (land before any page)
- **`lib/app/theme.dart`**
  - A hand-built `ColorScheme` per brightness: `fromSeed(accent)` for the tonal roles, then `copyWith` for the brand surfaces and on-colours above.
  - New `NavigationBarThemeData`: 68 tall, stadium indicator, only the selected label shown, w600 labels.
  - `pageTransitionsTheme`: `FadeForwardsPageTransitionsBuilder` on Android, `CupertinoPageTransitionsBuilder` on iOS (keeps swipe-back).
  - Chip, segmented, search-bar, list-tile and card themes on the new tokens.
  - `cardRadius` goes to 20.
- **`lib/app/motion.dart`** (new, about 15 lines): the curves and durations above, plus `Duration motion(BuildContext, Duration d)`, which returns zero under reduce-motion.
- **`lib/app/ui.dart`** (new, one file of primitives, all built on the Flutter SDK, no new dependencies):
  - `Pressable`: a scale-0.97 press with a 140ms `easeOut` and an optional `HapticFeedback.selectionClick`.
  - `GlowBackground`: the two radial sunset glows from `SplashScreen`. The splash is refactored to use it.
  - `CreatorAvatar(id, name, size, {ring})`: a gradient picked from the id hash over 6 brand-family hue pairs, with the initial. The optional sunset-gradient ring marks subscribed or live creators. It replaces all 7 `CircleAvatar` uses.
  - `CreatorBanner(id)`: a mesh of 2–3 radial gradients from the same hash.
  - `Skeleton` / `SkeletonList`: a shimmer that only runs while mounted (that is, while loading). Test latency is zero, so `pumpAndSettle` is unaffected.
  - `StateView(icon, title, message, action?)`: the shared empty and error look.
  - `Entrance(index, child)`: the staggered fade and rise. It runs once per mount.
  - `BrandButton`: a sunset-gradient primary CTA, used only for the money and hero actions (Subscribe, Unlock, Create account, Go live, Pay).
- **`asyncBody`** (in `discover_screens.dart`, used across features): add an optional `loading:` builder, defaulting to `SkeletonList`. Errors render a `StateView` with "Try again". The signature stays backward compatible.
- **Shell** (`lib/app/router.dart` `_Shell`):
  - `extendBody: true`, with `NavigationBar` wrapped in `ClipRect` + `BackdropFilter(blur 24)` over a surface at 72%.
  - Add `selectedIcon` (filled variants) to `_Tab`.
  - `HapticFeedback.selectionClick` on tab change.
  - The widget type stays `NavigationBar`, because 4 tests use `find.byType(NavigationBar)`.

## Pilot: `lib/features/content/discover_screens.dart` + `LockedMedia` in `media_view.dart`
Discover exercises a header, search, filters, a list, all states, navigation and a CTA.
- **Discover**
  - `CustomScrollView` with a large title "Discover", a one-line subtitle, `GlowBackground` behind the header, a pill `SearchBar` (keep `ValueKey('discover-search')`), and animated category pills.
  - Creators render as image-led cards: a 112px `CreatorBanner`, an overlapping `CreatorAvatar` (Hero tag `avatar-<id>`), name + verified, categories, compact followers, and a following heart.
  - Cards use `Pressable` + `Entrance` stagger, and a skeleton while loading.
- **Following**
  - The same cards.
  - `StateView` for empty: "Follow creators to see them here" (same text).
- **CreatorPage**
  - A stretch `SliverAppBar` with banner and glow, and a Hero avatar with a gradient ring when subscribed.
  - A stats row (followers, posts).
  - Follow ↔ Following morphs through `AnimatedSwitcher`, a 200ms fade + scale 0.96.
  - Subscribe uses `BrandButton`.
  - The posts grid gets radius 20 and press scale.
  - Keys `follow`, `subscribe`, `message-creator` and the report menu are unchanged.
- **PostTile / LockedMedia**
  - A glass lock pill (blurred chip with icon + price) instead of plain centred text.
  - Same cover logic, never the real media (FR-DIS-003).
- **PostDetail**
  - The creator row uses `CreatorAvatar`.
  - The bottom unlock area becomes a blurred floating panel with `BrandButton`.
  - Key `unlock` and all copy are unchanged.

**Then stop for the checkpoint**:
- Show screenshots of Discover, Creator and Post detail in dark and light, at 390px and 1280px.
- Ask once: approve and commit per page, approve and leave uncommitted, adjust, or stop.

## Rollout (after approval, one commit per row)

| # | Area | File(s) | Key changes | Status |
|---|------|---------|-------------|--------|
| 1 | Profile + settings | `profile/profile_screen.dart`, `settings/*.dart` | Avatar header with glow, grouped cards on new surfaces, accent picker with gradient swatches | ☑ |
| 2 | Inbox + chat | `messages/messages_screens.dart` | `CreatorAvatar` rows, unread dot, bubbles on brand tones, composer pill with blur | ☑ |
| 3 | Live | `live/live_screens.dart` | Live cards with a gradient ring; the "LIVE" badge pulses for at most 3 cycles (no endless animation, because of `pumpAndSettle`); room chat overlay with blur | ☑ |
| 4 | Commerce | `commerce/commerce_screens.dart` | Checkout summary card, `BrandButton` Pay, M-Pesa status steps animated, earnings figures tabular | ☑ |
| 5 | Creator home + studio | `content/studio_screens.dart`, `app/schedule_picker.dart` | Stat cards, post grid, composer access selector as pills | ☑ |
| 6 | Onboarding | `onboarding/onboarding_screens.dart` | Step progress with gradient track, cards per step | ☑ |
| 7 | Auth | `auth/auth_screens.dart`, `app/birth_date_picker.dart` | Welcome on `GlowBackground` + hero logo, `BrandButton`, OTP cells | ☑ |
| 8 | Lock | `disguise/lock_gate.dart`, `disguise/pin_pad.dart` | PIN dots and keys with `Pressable` + haptics (only when no disguise is active) | ☑ |

Each row:
- Behaviour stays identical: handlers, API calls, routes, keys and copy.
- Repeated patterns come from `ui.dart`, never one-offs.

Execution:
- Foundations + pilot are done in this session.
- Rollout rows are independent files, so each goes to a `delegate:builder` in its own worktree branched from `ui-revamp`, at most 4 at once. Each builder runs `flutter analyze` + its feature's test file.
- A `delegate:runner` runs the full `flutter test` once per merge.
- One `delegate:reviewer` pass at the end.

## Constraints
- No new dependencies (Flutter SDK only: `BackdropFilter`, `Hero`, `AnimatedSwitcher`, `HapticFeedback`, `intl` already present).
- Keep every `ValueKey`, every user-facing string, and the widget types that tests find by type: `NavigationBar`, `MediaView`, `LockedMedia`, `TextField`, `ListView`, `PopupMenuButton<String>`, `LinearProgressIndicator` (splash), `Image`, `Opacity`.
- No endless animation on any screen that stays visible.
- Locked media never shows or blurs real content.
- The decoys and the admin app are untouched.

## Verification
- **Static:** `flutter analyze` is clean after foundations, after the pilot, and per rollout row.
- **Tests:** after foundations and after the pilot, run `flutter test`, which must be fully green (22 test files). Run the feature's own test file per row, and the full suite once per merge.
- **Visual:**
  - `flutter run -d chrome --web-port 5000`, then screenshots via the `chrome-browser` skill at 390×844 and 1280×800, in dark and light. The Playwright MCP failed to connect this session.
  - Check the loading skeleton (set `fakeLatency` to 1.5s locally, not committed), the empty state (search "zzz"), and errors.
  - Keyboard focus order on web.
- **Reduce motion:** check one run with `MediaQuery(disableAnimations: true)` (accessibility setting) so entrances are instant.
- **Final:** grep for leftover `CircleAvatar(`, `CircularProgressIndicator()` in feature screens, and hardcoded `Color(0x` outside `theme.dart`/decoys. Write the report, and offer a PR to develop (no merge).

## Status
- [x] Phase 0: rebrand committed on develop (`b6dd3cf`), branch `ui-revamp`
- [x] Foundations: `theme.dart`, `motion.dart`, `ui.dart`, shell
- [x] Pilot: Discover, Following, Creator page, Post detail, LockedMedia. `flutter analyze` clean, 104/104 tests, screenshots at 390 (dark/light) and 1280
- [x] Checkpoint approval (approve, commit per page)
- [x] Rows 1–4 merged (profile/settings, inbox/chat, live, commerce): analyze clean, 104/104 on the merged branch
- [x] Rows 5–8 merged (studio, onboarding, auth, lock); `_edgeToEdge` removed, every tab scrolls under the frosted bar
- [x] Consistency sweep: `secondaryContainer` neutral accent tint (tonal buttons, icon tiles), flat snackbars, `tabAppBar` large titles on Following / Live now / Go live / Messages, header-led creator Home

## Learned in the pilot (apply to every row)
- **Tab screens and the frosted bar.** The shell uses `extendBody`, so a tab screen must add `MediaQuery.paddingOf(context).bottom` to its scroll padding. Until it does, list its path outside `_edgeToEdge` in `router.dart` (it gets a `SafeArea`). Add each revamped tab path to `_edgeToEdge`, and delete the set once all are in.
- **Tests find on-screen widgets only, on 800×600.**
  - Taller layouts must still show the tested item on screen.
  - Use two columns at ≥720px, single-row actions at ≥560px, and compact rows above 1.4× text scale (the `CreatorCard` pattern).
- **`AnimatedSwitcher` centres its child.** Pass a `StackFit.passthrough` `layoutBuilder` when the child should fill its slot.
- **No explicit `AppBarTheme.backgroundColor`.** It shifted onboarding layout by 6px under a snackbar; M3's default is already `surface`.
- **CTAs:**
  - Gradient CTAs are `FilledButton(style: brandButtonStyle(context))`, never a wrapper widget (tests read `widget<FilledButton>`).
  - CTA text is `brandInk`: white fails contrast on the orange stop.
- **Hero tags.** Discover and Following both stay mounted, so hero tags are prefixed per list, and the tag travels as go_router `extra`.
- **Screenshot harness.** A throwaway widget test (fonts loaded, images precached, layer `toImage`) lives in the session scratchpad. It is not in the repo.

## Found, not fixed
- A payment that ends `reversed` stops polling but has no view of its own, so checkout keeps showing the "Check your phone" waiting state with an endless progress bar (`commerce_screens.dart`). Fixing it needs new copy.
- `PostTile` puts its InkWell above the media, so tests tapping the "Unlock for …" label log "would not hit test" warnings (they still pass). A fix (InkWell wrapping the media) is parked as a patch pending the user's go-ahead.
