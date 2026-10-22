# Product blueprint: A better OnlyFans-style creator platform for Kenya and beyond

The opportunity is to build more than an adult-content subscription website. You can build a creator monetization platform where creators control their content and prices, fans can pay for exactly what they want, live experiences generate revenue in real time, and the platform manages contracts, payouts, safety, and compliance.

I'll design this around three connected experiences:

- Creator app: Mobile-first tools for uploading content, managing fans, going live, tracking income, and handling contracts.
- Fan experience: A discreet, mobile-friendly app and web platform for discovering creators, subscribing, purchasing individual content, tipping, messaging, and joining livestreams.
- Admin platform: A powerful operations dashboard for identity verification, moderation, creator agreements, commissions, payments, disputes, and financial reporting.

The initial market assumption is Kenya, with KES pricing and mobile-money support, while keeping the architecture ready for international expansion.

## 1. Product vision and differentiators

[Creator Support Platform: app concept by Ronas IT | Software Development Company on Dribbble](https://images.openai.com/static-rsc-4/NBEWJCBMJWbzaAhEuhD3VL_CY-1Nk51eCEVf_u8_pLT_ET-S3G5AyFcar6__BsfQQTWQO3ugcmG1pU1GbHgNJ-B-hPJf9vr41qM0GWXVmfyEN6MU1rhrTL1Dqy5AFBGsIhpMN7x_VX24MeIWqwJhEXIqLIIJ-G0c2XOk0aPqOLs?purpose=inline)

01\. Pay for anything

Creators can sell a single photo, a video, a content bundle, a private message, a livestream ticket, or a recurring subscription. A fan should not have to subscribe to unlock one item.

[Parler for Creators: Monetize Your Content with Play & Shop](https://images.openai.com/static-rsc-4/lfnd4glbQJELQCal2RCUqHiOzkbzBL0JLsRCbblhyaPQI_IrLgCr4uLepcyIvtGHNCggRD7VMPUmeKg-1v9AR0Ah1ygqeEF23NL6VFzDLl0VYrbSgHAqB8td8CC3-jDWF1Ql8HZnT1aRrEJcqASA3rMISIOdaYPrgiPQFQYK0Wo?purpose=inline)

02\. Creator-first economics

Transparent commission rates, real-time sales analytics, scheduled payouts, audience insights, and a clear earnings ledger. Creators should always know what they earned and why.

[OnlyFans Clone App Development | Xpertz](https://images.openai.com/static-rsc-4/vsCi4nrdshnrta8Wz5h7G1zxXQc20lcn3w1j_OvMvekDIByjceZ474Y0o3F4GOYfSfjBbHcP8OWx-jUl8RRa9BEKm5n0tQhCIZsX-ujmtBKCfRHEXklIj_igoFUnTtm3P5s9rhR3W6VyNIGcFYEvx8Q1dwtg2sOnPKMH-fRInJw?purpose=inline)

03\. Live experiences that monetize

Ticketed streams, virtual gifts, paid Q&A sessions, tips, subscriber-only rooms, and optional paid replays.

[PayFlow — Fintech Wallet App UI | Dark Mode by Wilson Kinyua on Dribbble](https://images.openai.com/static-rsc-4/LFz0jJnfeWDUmNZHr3bT2Y2JMQ39r653KV_CIWZSVyTZic1Wh-L4Ru2EQu5rJbl7i1uHIelAps2lzBcLoZ_5JMz8Eob-4Y17BVUiiE95JOGO7gQO3dLhTlDCM7O19IonW9rhnjAvBQ5m4gwNJTicpLihir985BHpxfTDbz_bHEU?purpose=inline)

04\. Local payments that actually work

KES-denominated prices, M-Pesa integration where supported, card payments, a creator earnings wallet, and clear payout status tracking.

Core product principle: make purchasing frictionless for fans without making creator verification, payment security, or content protection optional.

This blueprint assumes an adults-only platform, with effective age and identity verification, consent documentation, and controls designed to prevent exploitation and unauthorized content distribution.

## 2. The complete platform ecosystem

## Central platform backend

Identity · Payments · Content · Contracts · Safety · Analytics

Creator mobile app

Upload, go live, chat, earnings, verification and contracts.

Fan mobile app

Discover, purchase, subscribe, message and watch.

Creator web portal

Advanced studio, scheduling, analytics and business management.

Fan web portal

Full discovery, purchases, viewing and account management.

Admin & trust operations

A separate, permission-controlled interface for operations, finance, moderation, support, legal and system configuration.

I would make the backend shared across all interfaces. A purchase on the web must unlock the same content in the mobile app; a signed contract must update the creator's status everywhere; and a refund must update the fan's transaction, creator earnings, and admin ledger together.

### Recommended navigation

| Creator mobile           | Fan mobile         |
| ------------------------ | ------------------ |
| Home / dashboard         | Discover           |
| Content studio           | Following          |
| Go live                  | Live now           |
| Messages                 | Inbox              |
| Earnings / wallet        | My library         |
| Audience / subscribers   | Subscriptions      |
| Contracts / verification | Wallet / purchases |
| Profile / settings       | Profile / settings |

The web portals should share these core sections, with more space for bulk uploads, analytics, scheduling, and account management.

## 3. Creator journey: from signup to first payout

Step 1 — Create an account

Sign up with email or phone, verify OTP, create a username, set a password or passkey, and enable two-factor authentication. A creator can save progress and resume onboarding later.

Step 2 — Verify age and identity

Confirm the creator is an adult using an appropriate identity and age-assurance process. Verify identity, liveness where appropriate, payout ownership and any required documentation for people appearing in content.

Step 3 — Review and sign the creator agreement

Present the platform commission, payout terms, content ownership, permitted uses, termination rules, dispute process and other material terms. The creator reviews the full agreement, signs electronically, and downloads a copy.

Step 4 — Set up the creator profile

Add display name, handle, bio, profile photo, banner, content categories, language, location visibility and discovery preferences. Offer public, subscriber-only and private profile elements.

Step 5 — Configure payouts

Add an eligible payout method, verify ownership, review the withdrawal minimum and schedule, and complete any required tax or business information.

Step 6 — Admin approval and launch

The admin checks verification, agreement status, payout setup and required compliance items. The creator gets a clear status: Incomplete, Under review, Action required, Approved or Rejected with an appeal route.

### The creator dashboard

CREATOR STUDIO

## Good morning, Creator

Available earnings

# KSh 12,450

Illustrative balance

Active fans

# 384

Illustrative count

### Quick actions

Upload

Go live

Schedule

### Recent activity

Individual content sale

Paid unlock · Illustrative transaction

\+ KSh 250

Fan tip

Live session · Illustrative transaction

\+ KSh 100

The numbers above are mock data for the proposed interface, not live earnings.

## 4. Content studio: selling anything at any price

This is one of the most important differentiators. Do not force creators into one pricing model.

[DTFansOnly – Paid Content Creators Flutter App – Android – iOS – admin panel – patreon – onlyfans | DivineTechs](https://images.openai.com/static-rsc-4/DvJm7rfPJ-4_icoaTJMhLr0GWuFy5qMRY58mQHZ83DoH1tvqQgX9LLsggnCdbAa464UYfXEglVS5QYAP0JhWMUEVSuxl2JQz3I6JenET18RQsTM4TWoHdR-66BO38rPacBFi96gwsdauthGH3fK1IlUM1lBjJnYlU6Y1bUm_hAA?purpose=inline)

Photo and image posts

Upload one image or a gallery. Choose free, followers-only, subscriber-only or pay-per-item access. For example, a creator can charge KSh 10 for a single photo and KSh 500 for a premium gallery.

[Video Editing Dashboard by Afterglow on Dribbble](https://images.openai.com/static-rsc-4/Q8dfPttvy7dHrCj_x_W_FK2Fcivr9KGcqAzyIAPPfNl1ugSUVANRQFJD9_nwMzrnbKRQZQZOQ7Y_h1MSQHse8B4oHSdbuPHBT4PdyO2lH3HMPRvXgnBHxJ4A1DLyv68s9_CrOphKP5JxC4iz1aCVW-9xchq6JGfmj_I_5b7jPSQ?purpose=inline)

Video posts

Upload long-form or short-form video, set a price, add a teaser and caption, select the audience, schedule publication and optionally sell access to a downloadable file where permitted.

[Live Streaming Platform by Seven Metrics on Dribbble](https://images.openai.com/static-rsc-4/yiOj1g5M7azC_fRDaYXfos7Ohm0umtkusmZlVkdIMx2MYSgsukAGl5Ujlqlwl6wMN4eD-u-7d8gP4JCCTTi9BSbgfYxrH_vFkd4P5vWh_COxaoZZ11NLMu6cfm_9QZsRXH_b6kEVaf89CCe3vsCdw8MPCetsqXtjTrm2ngr1q2I?purpose=inline)

Livestream studio

Start a free stream, subscriber-only stream, ticketed event or private session. Enable tips, paid questions, moderation, viewer limits, stream recording and paid replays.

[Locked messages – Fourthwall](https://images.openai.com/static-rsc-4/9tPvusNDvI7MdMEWkE9Gz8JFb7nlPw8gJTmXtStRGgBzGAe15wSP41J-Xp3MqvR4sHq5luZxg-3qaPcbsyVWhGWaCwC60KiGkBwbqOozbQrsvqbem6bUw9WMab3gY9Q8nc8F4Sah2UGbei9HyeLUqECkRwuY9ty1vGoQLrLAl9E?purpose=inline)

Paid messages and custom requests

Let creators charge to unlock a media attachment, set prices for custom work, define delivery deadlines and accept or decline requests before payment is finalized.

### The publish workflow

1. Choose media: Select photos, videos or an upcoming live event. Support multiple uploads and resumable uploads on unreliable connections.
2. Prepare content: Add caption, thumbnail, teaser, tags and optional content warnings.
3. Set access: Public preview, followers, subscribers, paid unlock or a custom audience.
4. Set price: Enter any permitted amount in KSh, subject to configurable minimums, maximums, payment costs and provider constraints.
5. Choose timing: Publish now, schedule for later, or save as a draft.
6. Review: Scan uploads for policy violations, check consent documentation where required, and route flagged content to human moderation.
7. Publish and measure: Show the post's views, unlocks, conversion rate, revenue and refund or chargeback status.

### Example: a KSh 10 photo sale

[076 Tulum - Putri Cinta](https://images.openai.com/static-rsc-4/xLfirWtnJ-ZAEOb5X7nOTIGvAnf5_ajbeKX9kL6pHrbZSixEO6NkoqwI3L_NH6jzPvp5ifnnOER7MJjW3JeeMGoiNs-7iQ0SB_HuxoDt3RWT9FWRhEbTFoGKAt4yxTrmRM5TdS9RE_nxaiigGkDZMnpEJrj3anRYiu5W2s2ticc?purpose=inline)

Premium photo #104

One-time purchase · Personal access

# KSh 10

Example price

### Illustrative revenue split

Fan pays

### KSh 10.00

Platform fee at 20%

− KSh 2.00

Creator share before other deductions

### KSh 8.00

Illustration only. Actual net earnings depend on the contract, payment-processing fees, applicable taxes, refunds and other disclosed deductions. The checkout must make any applicable buyer fees clear before payment.

A critical implementation detail: do not treat every KSh 10 sale as economically identical to a KSh 1,000 sale. Payment providers may have fixed transaction costs, and fees may make microtransactions unprofitable. Offer configurable minimum prices, prepaid fan balances or bundled purchases where legally and commercially appropriate.

## 5. Fan journey: discovery to purchase

The fan experience should be easy to understand, discreet, and built around content rather than confusing subscription requirements.

1\. Discover

Browse creator profiles, free previews, trending posts, categories, verified creators and live events. Provide an adults-only entry gate and do not expose explicit previews before the required checks.

2\. View a creator profile

Show the creator's bio, verification badge, public content, membership options, individual item prices, livestream schedule and a clear explanation of what each purchase unlocks.

3\. Choose how to pay

The fan can follow for free, buy one photo, unlock one video, purchase a bundle, subscribe monthly, buy a live ticket or tip. Each option is independent unless the creator explicitly configures otherwise.

4\. Checkout

Display the item, total amount, currency, recurring-payment status, refund terms and selected payment method. Complete payment through a supported provider and confirm the result server-side.

5\. Unlock and consume

Unlock the purchased item immediately after verified payment. Grant the correct access rights on web and mobile, and show the purchase in the fan's library.

6\. Return and retain

Offer new-post notifications, saved creators, wishlists, creator announcements, membership renewal reminders and easy cancellation.

### Fan features that build trust

- A searchable purchase history and receipts.
- A library of purchased content, with clear access and expiry rules.
- Transparent recurring billing and one-tap subscription cancellation.
- Optional private usernames and discreet notifications.
- A spending dashboard and optional monthly spending limits.
- A report, block and mute control available on every creator profile, post, message and live room.
- Clear refund, dispute and chargeback status.
- An account deletion and personal-data request workflow.

## 6. Livestreams: build an entire revenue engine

Livestreaming should be a first-class product rather than a camera button bolted onto the app.

[Shoutcast Audio & Video Stream Servers | AutoDJ, Restream | 7 Days Trial](https://images.openai.com/static-rsc-4/F_EH1NrLHSheDPgJ1lrTZ889jCL3bAGUxdQnWd_n91frqwrHfQauKaqB_JeFJ3uYsrh61gI50lCp31Z8AGZ-x5J3lw8ouPT8O7cIVdAonJlvbNd0ZmRoFRrRuDFoWXpymnGNMi_Xbd4UbDg40ht-ylgMKi1HyftkOeCq0dAJpLA?purpose=inline)

[shoutcastnet.com](https://www.shoutcastnet.com/?utm_source=chatgpt.com)

## Creator live control room

Ticketed access

Sell admission at a creator-defined price.

Tips and gifts

One-time tips or virtual gifts with transparent values.

Paid questions

Charge for priority questions or responses.

Replay sales

Sell a recorded session to eligible viewers.

### Creator live flow

1. Creator checks camera, microphone, network quality and stream settings.
2. Chooses free, subscriber-only, ticketed or private access.
3. Sets the price, title, audience rules and optional recording policy.
4. Goes through any required live eligibility and safety checks.
5. Starts streaming; the backend creates a live session and issues viewing permissions.
6. Viewers join, chat and purchase allowed interactions.
7. Moderators can remove viewers, mute chat, pause the session or end the stream.
8. At the end, finalize the session ledger, process eligible earnings and publish a replay only if configured and permitted.

Important live features: low-latency streaming, adaptive video quality, connection recovery, slow mode, chat filters, moderator roles, participant blocking, emergency stream termination and safeguards against unauthorized recordings.

For private two-person sessions, add a booking calendar, upfront payment, clear session duration, cancellation rules, a creator-controlled acceptance process and no-show handling.

## 7. Messaging, subscriptions and fan relationships

These features help creators earn recurring revenue without relying on explicit content sales alone.

| Feature                | How it works                                                                                      |
| ---------------------- | ------------------------------------------------------------------------------------------------- |
| Free follow            | Fans receive permitted public updates without paying.                                             |
| Monthly membership     | Creator sets a recurring price and defines member benefits.                                       |
| Multiple tiers         | For example, Basic, Premium and VIP with different access rights.                                 |
| Paid direct messages   | Creator can sell an individual message or locked attachment.                                      |
| Custom requests        | Fan submits a request, creator accepts terms, and payment is collected according to the workflow. |
| Fan tips               | Fans send voluntary payments with clear confirmation.                                             |
| Broadcast messages     | Creators announce new content or upcoming streams to eligible recipients.                         |
| Bundles                | Combine multiple posts or access periods at one disclosed price.                                  |
| Gift memberships       | One fan can purchase a defined subscription period for another eligible fan.                      |
| Creator collaborations | Verified creators can co-host approved content and explicitly agree how earnings are divided.     |

For paid messaging, build in anti-spam limits, consent-based messaging controls, request expiration and refund handling. Creators should be able to prevent messages from specific users without losing their existing financial records.

## 8. Digital contracts between creators and the platform

This needs to be a complete contract-management system, not simply a checkbox during signup.

### The contract lifecycle

### 01

Draft

Admin creates a contract template and defines commercial terms.

### 02

Offer

Creator receives the agreement and a plain-language fee summary.

### 03

Review

Creator can read, download, ask questions and decline without signing.

### 04

Sign

Both parties sign electronically with identity, timestamp and document-version evidence.

### 05

Activate

The platform activates the agreed commission and payout rules.

### 06

Amend or terminate

Changes require the appropriate consent, notice and version history.

### Clauses the agreement should cover

- Parties, verified identity and eligibility.
- Platform services and permitted use of the service.
- Commission percentage, fee calculation and any taxes or payment charges.
- Payout thresholds, payout schedules, reserves and adjustments.
- Creator ownership of content and the limited license needed to host, process, display and distribute it as instructed.
- Content standards, consent, identity verification and prohibited material.
- Confidentiality, privacy and security responsibilities.
- Refunds, disputes, fraud, chargebacks and negative balances.
- Termination, suspension, account closure and continued access to financial records.
- How changes to fees are notified, accepted and made effective.
- Dispute resolution, governing law and contact information.
- An explicit statement that the platform does not acquire ownership of a creator's content merely because the creator uploads it.

### Commission configuration

Admin should be able to configure contract terms per creator or approved creator cohort.

| Example plan     | Platform commission | Creator share before other deductions |
| ---------------- | ------------------- | ------------------------------------- |
| Standard         | 20%                 | 80%                                   |
| Founding creator | 15%                 | 85%                                   |
| Premium services | 25%                 | 75%                                   |

These are proposed examples, not market benchmarks or final pricing. The system should support different terms, but every active contract must define exactly which rate applies to which revenue type and when it takes effect.

### What makes a digital signature reliable?

Store the exact signed document, immutable document version, signatory identity evidence, consent to electronic signing, timestamp, document hash, audit events and a downloadable copy for each party. Apply the applicable Kenyan electronic-transactions and contract rules with legal review; a click-to-sign flow should not be assumed to satisfy every legal requirement in every situation.

A signed contract must remain available to both parties after termination, subject to lawful retention and privacy requirements.

## 9. Admin dashboard: the business control center

The admin portal is what allows this platform to operate reliably at scale. It needs dedicated areas for operations, finance, legal, safety, support and engineering.

ADMINISTRATION

# Platform overview

Illustrative data

Gross transaction volume

# KSh 4.8M

Example reporting period

Active creators

# 1,240

Example count

Pending verification

# 36

Example queue

Pending payouts

# KSh 286K

Example queue value

### Admin navigation

Users & creators

Profiles, verification, account status and appeals

Contracts

Templates, signatures, revisions and commission terms

Payments & finance

Transactions, reconciliation, refunds and payouts

Trust & moderation

Reports, flagged content, consent records and urgent escalations

Customer support

Tickets, disputes, complaints and account recovery

Analytics & growth

Sales, retention, creator performance and acquisition

Platform settings

Fees, price limits, permissions, integrations and feature flags

### Admin permissions

Do not give every employee unrestricted access.

| Role                | Main permissions                                                |
| ------------------- | --------------------------------------------------------------- |
| Super admin         | Platform configuration and access management                    |
| Creator onboarding  | Identity verification and creator approvals                     |
| Trust and safety    | Reports, moderation, restrictions and appeals                   |
| Finance             | Reconciliation, commission reports, refunds and payout approval |
| Legal and contracts | Agreement templates, signed contracts and legal requests        |
| Customer support    | Support tickets and limited account troubleshooting             |
| Analyst             | Aggregated metrics and appropriately restricted reports         |

Sensitive actions—such as modifying commission rates, releasing large payouts, exporting identity records or changing administrator permissions—should require extra authorization and an audit trail. Admins should not be able to browse private creator media without an authorized, logged reason.

## 10. Payments, wallet and creator earnings

For Kenya, I'd prioritize M-Pesa alongside card payments and other approved payment providers. Safaricom's [Daraja developer platform](https://developer.safaricom.co.ke/?utm_source=chatgpt.com) provides APIs for M-Pesa payment collection and disbursements, including STK Push and business-to-customer payments. Production access and onboarding requirements must be confirmed with the provider.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://developer.safaricom.co.ke\&sz=32)

Safaricom

+2



### Payment flow

1\. Fan initiates checkout

Order, price, fees and access rights are recorded.

2\. Payment provider processes payment

M-Pesa prompt, card checkout or another supported method.

3\. Backend verifies the result

Validate the provider's callback, transaction identity, amount and status.

4\. Ledger records the transaction

Allocate platform commission, creator earnings, payment fees and any reserves.

5\. Fan access is granted

The purchased content or service becomes accessible on all authorized devices.

Never unlock paid content simply because the mobile app says payment succeeded. Provider callbacks can be delayed or repeated, and transaction status may need reconciliation. Access should be granted only after the backend verifies payment.

### Wallet requirements

The creator wallet should distinguish:

- Pending: Earnings awaiting payment settlement, risk checks or the applicable hold period.
- Available: Funds eligible for payout.
- Reserved: Funds held against an explicitly defined risk, refund or dispute policy.
- Paid out: Funds successfully disbursed and reconciled.
- Adjusted: Refunds, chargebacks, corrections or other documented adjustments.

Use an append-only financial ledger rather than directly editing a balance field. Each transaction needs an identifier, currency, source, creator, applicable contract, fee breakdown, settlement status and audit history.

Also build automated reconciliation against provider reports, duplicate-payment prevention, idempotent callbacks, payout approval rules, refund tracking and a failed-payment recovery workflow.

Important distinction: an in-app wallet is not automatically a regulated stored-value product. Decide whether fans can preload balances, transfer funds or hold money, and obtain legal and payment-provider guidance before enabling these features.

## 11. Trust, safety, privacy and content protection

For an adults-only platform, trust and safety must be part of the core product architecture—not something added after launch.

### Essential safeguards

Adult and identity verification

Verify creator age and identity before monetization, apply suitable age-assurance controls to viewers, and prevent underage users from accessing adult services. Establish a process for verifying every person depicted in content where required.

Consent and rights management

Maintain appropriate records of consent, releases, content rights and authorized uses. Provide a fast process for reporting non-consensual imagery, impersonation, coercion and unauthorized distribution.

Content security

Store media in private object storage, use short-lived signed viewing URLs, enforce server-side access permissions and use watermarking where appropriate. Avoid exposing permanent raw media links.

Moderation and incident response

Scan uploads, review reports, prioritize urgent safety incidents, preserve relevant evidence securely and support appeals. Detection tools should be combined with trained human review.

Privacy by default

Separate identity documents from public profiles, restrict staff access, encrypt sensitive information, minimize data collection and implement retention and deletion policies.

### Kenya-specific compliance work

Before launch, obtain Kenyan legal advice on the proposed business model, content rules, age assurance, electronic contracting, payment arrangements, consumer protection, tax, and the applicable communications and criminal laws.

The [Office of the Data Protection Commissioner](https://www.odpc.go.ke/data-protection-laws-kenya/?utm_source=chatgpt.com) publishes Kenya's Data Protection Act, 2019 and associated regulations. Determine whether the platform must register as a data controller or processor, complete a data-protection impact assessment, and implement appropriate security, breach-response and data-subject request procedures.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://www.odpc.go.ke\&sz=32)

Data Protection Office

+3



Additional launch requirements:

- Establish explicit prohibited-content rules, including a strict prohibition on sexual content involving minors.
- Define a process for responding to lawful requests and urgent reports.
- Assess cross-border hosting, international transfers and vendor access to personal information.
- Verify that payment providers and hosting vendors permit the proposed business model in writing.
- Review app-store and payment-network restrictions before committing to native-app distribution.
- Obtain appropriate insurance and a documented incident-response plan where commercially available.

Privacy is particularly important for both creators and fans. Do not expose legal names, phone numbers, identity documents or payment details on public profiles. Avoid promising complete anonymity: identity verification, payment processing and lawful compliance can require personal information.

## 12. Features that could make it better than OnlyFans

I'd prioritize differentiation through better economics, creator independence, usability and trust—not just by adding more buttons.

[Anvil Creators | Creator Monetization Partners for Influencers](https://images.openai.com/static-rsc-4/_wX1vwRY6tblwKdDKBUjxNONGmyz2u5UP8KuRk_Ws0QKMujllzsNres8BiaDc0djlQBTiU-dNwTmHKnS1-M1xB0S6dX6f3ycym3rqQ6N0X2N64aMBjv5EasMdeONqXnfR_iQ6CMHtx0cVWfyzk8Ldooy6XI1BXsTYs1IWT3Rbw0?purpose=inline)

1\. Smart creator analytics

Show earnings per content type, repeat-purchase rate, subscription churn, conversion from free previews and customer lifetime value. Let creators export their own data.

[Creator Super App: POP.STORE for More Subscribers & Cash](https://images.openai.com/static-rsc-4/hBznzIGFTB70aBnYrfkSrOPDHIVrt_vE-oRN_wqk_6-x4a5fZ0cfVwDmYGg32IZgniqRSnrXTCBXuaCzPNxxe0Wt-5nNDSn3y-ps6VOZWSCPWEbV8OEezdZSdblYzvy25Cwx70_5S1dr1cN3m6KFd2v0yorvZSsKQruTuaG2A2A?purpose=inline)

2\. Creator-owned storefronts

Give each creator a customizable mini-site, branded landing page, product catalog, shareable links and portable audience exports where permitted. This reduces dependence on the platform's recommendation algorithm.

[GWOP – For creators](https://images.openai.com/static-rsc-4/tXGkZRQ4Xx271yvUGmHxl85AS5-W-XshwecJ-NSuRFoNfLsv2sv0hxwfUY9Z2_WwYvcSb9Cxs-xFy2Xyx7OcQU10CwVNjmcwi4BEwdQcNnMh5hrIuA173wuLBvwZBJuezlyqGmvXWt-7F3scYXWbQKKJRyNyVnEMt_XQiCjI2Pk?purpose=inline)

3\. Transparent earnings and fees

Show the exact net amount from every sale, explain every deduction and give creators a searchable transaction ledger. Make payout timing predictable.

[Content Schedule Planner - Best Featured Genesis App by @pearlchal | Taskade](https://images.openai.com/static-rsc-4/Uh92VPDB28ggTbarPcfrMuh-icOEWyzdw8id_g5CUM2x9RTzw3_MY3o2QYWEKqtZrS1Z2BIGekVURXkJ6wp7rrm1MSMwxVqI6MHkZH3AwWibfmUtEx49RLOWjyXA98_7wAiuOL12Ae6VFLYjPqlhFYzlD5BqhHkXRcrAae-Q50Q?purpose=inline)

4\. Collaboration marketplace

Let creators find verified collaborators, negotiate revenue shares, document consent and agree to content rights before production. Attribute sales correctly and distribute earnings according to the signed agreement.

[Komunita - Platforma pro tvůrce a jejich komunity](https://images.openai.com/static-rsc-4/w7ln5N0itnC6a_plkqlhu_tyIHUuxl8HPsEPRifCaDQTgFzracqB7DB7kullAhW5hrxYpAwKuIu_4i68N0Uc3dLHgoEBcAKCLj3Inugb0dFiui4irwVyH3BKDeh-aif94kCP1IwPzcp3TNt8fHuV0o-BaElqr1zghb9brWFbrrk?purpose=inline)

5\. Community and experiences

Add private communities, polls, scheduled sessions, creator AMAs, virtual events and membership perks. Give creators revenue options beyond individual content sales.

[Watermarking in V4 | Frame.io V4 Knowledge Center](https://images.openai.com/static-rsc-4/tCq60j2B0UUMj6VJpiKJbC62cnmQPyIoOIYPep7lor20sXzFXzXbPDV-arjT4tlShzgP9BObJXlatUn_C-3SFn8rScCGaPGHJto15NtoI4c44ipqEwMSPLeVjBpch10EQAL7T4TJ-nz_2tdniBnBOlK3OmYfoqTbzPQGMVxWtAc?purpose=inline)

6\. Better content protection

Use per-user watermarking, suspicious-access alerts, leaked-content reporting and rapid takedown workflows. Explain honestly that screenshots and external recording cannot be prevented perfectly.

Other valuable features for later releases include:

- AI-assisted captions, translations and metadata suggestions, with creator approval before publishing.
- Smart scheduling based on each creator's own engagement history.
- Discount codes, limited-time offers and bundles.
- Referral programs with fraud controls.
- Subscription pause options and win-back offers.
- Creator-defined regional pricing, subject to provider and tax constraints.
- Accessibility features, multiple languages and low-bandwidth media delivery.
- Creator business tools for invoices, earnings statements and tax exports.
- A portable fan relationship system that does not expose personal contact details.
- Optional creator teams with scoped permissions and revenue allocation.

Avoid launching AI-generated intimate media, synthetic likeness tools or automated personalized messaging without dedicated consent, impersonation, disclosure and safety controls.

## 13. Technical architecture

For the first version, I recommend a modular monolith with separate background workers, rather than immediately splitting the entire product into dozens of microservices. This keeps development and operations manageable while preserving clear module boundaries.

Client applications

Creator mobile · Fan mobile · Creator web · Fan web · Admin web

API gateway and identity

Authentication · Authorization · Rate limiting · Audit events

Application modules

Users & contracts

Content & access

Payments & ledger

Messaging & live

Moderation & reports

Analytics & notifications

Infrastructure and integrations

PostgreSQL · Private object storage · CDN · Queue · Redis · Payment providers · Streaming service

### Proposed technology stack

| Layer                       | Recommendation                                                                |
| --------------------------- | ----------------------------------------------------------------------------- |
| Web applications            | Next.js and TypeScript                                                        |
| Mobile apps                 | React Native with TypeScript                                                  |
| Backend                     | NestJS with TypeScript, or an equivalent mature backend framework             |
| Main database               | PostgreSQL                                                                    |
| Cache and short-lived state | Redis                                                                         |
| Background jobs             | A durable queue backed by Redis or a managed queue service                    |
| Media storage               | Private S3-compatible object storage                                          |
| Media delivery              | CDN with access-controlled, short-lived URLs                                  |
| Video processing            | Managed transcoding initially; asynchronous workers where appropriate         |
| Livestreaming               | Managed streaming infrastructure supporting adaptive bitrate and low latency  |
| Search                      | PostgreSQL initially, with a dedicated search engine as scale requires        |
| Monitoring                  | Centralized logs, metrics, error tracking and security alerts                 |
| Contracts                   | Versioned document storage, electronic-signature integration and audit events |

### Core data entities

Design the database around the actual business rules from the start:

- `users`, `creator_profiles`, `fan_profiles`, `identity_verifications`
- `creator_contracts`, `contract_versions`, `contract_signatures`, `commission_rules`
- `media_assets`, `posts`, `content_access_rules`, `content_rights`
- `subscriptions`, `orders`, `order_items`, `payment_attempts`
- `ledger_entries`, `payouts`, `refunds`, `chargebacks`
- `conversations`, `messages`, `live_sessions`, `live_tickets`, `tips`
- `reports`, `moderation_cases`, `consent_records`, `audit_events`

Use explicit state machines for verification, contracts, payments, refunds, payouts and moderation cases. For example, a payout should move through states such as `requested`, `under_review`, `approved`, `processing`, `paid`, `failed` or `cancelled`—with controlled transitions and a full audit history.

### Critical engineering requirements

1. Enforce authorization on the server for every paid asset and private conversation.
2. Use signed, versioned contracts and retain evidence of the exact agreement accepted.
3. Make payment processing idempotent and reconcile provider callbacks with actual transactions.
4. Keep identity documents and other sensitive records isolated from ordinary application data.
5. Use resumable uploads, media transcoding, background moderation jobs and CDN delivery.
6. Build account recovery, rate limiting, anti-bot controls, abuse detection and secure administrator authentication.
7. Test database backups, restoration, incident response and payout reconciliation before launch.
8. Design the mobile apps to work well on slower connections and lower-cost Android devices.

## 14. Recommended launch roadmap

Do not try to build every feature in the first release. The goal should be to launch a complete, trustworthy commercial loop: verify a creator, sign the agreement, publish content, accept payment, unlock access, calculate earnings and pay the creator.

Phase 0

Foundation

Product and compliance definition

Confirm business and legal feasibility, payment-provider approval, contract terms, age-assurance processes, content policies, user journeys and technical architecture.

Exit criterion: approved specifications, legal review and a viable payment path.

Phase 1

MVP

Core marketplace

Responsive web apps, creator onboarding, digital contracts, individual photo and video sales, subscriptions, M-Pesa/card integration where approved, creator ledger, payouts, fan library and admin moderation.

Exit criterion: successful end-to-end purchases, refunds, reconciliation and creator payouts.

Phase 2

Mobile

Creator and fan mobile apps

Uploads, purchases, messaging, push notifications, wallet history, security settings and cross-device entitlements.

Exit criterion: web and mobile share the same account, payment and access records.

Phase 3

Live

Livestreaming and paid interactions

Ticketing, tips, moderation, paid questions, recording controls and replay sales.

Exit criterion: reliable sessions, accurate live revenue accounting and working safety controls.

Phase 4

Growth

Differentiation and expansion

Creator storefronts, advanced analytics, collaborations, referrals, bundles, international currencies and localized payments.

Exit criterion: measurable creator retention, sustainable unit economics and reliable operations.

The duration of each phase will depend on team size, payment-provider approval, compliance work, livestreaming requirements and the level of polish expected.

## 15. Business model and unit economics

A sensible initial model is commission on creator transactions, with optional paid business tools later.

Potential revenue streams:

- Commission on subscriptions and individual content sales.
- Commission on paid livestreams, tips and custom requests, subject to clear contractual terms.
- Optional creator analytics, storefront customization or business-management subscriptions.
- Carefully disclosed promotional placement for eligible creators.
- Business tools for creator teams and agencies.

I would avoid charging creators substantial upfront fees before the platform demonstrates that it can reliably generate sales.

Track these metrics from day one:

| Metric                      | Why it matters                                                     |
| --------------------------- | ------------------------------------------------------------------ |
| Creator activation rate     | Are new creators successfully reaching their first published post? |
| Time to first sale          | How quickly can creators start earning?                            |
| Fan conversion rate         | Are visitors becoming paying customers?                            |
| Repeat purchase rate        | Do fans return and buy again?                                      |
| Creator earnings retention  | Are creators continuing to earn and stay active?                   |
| Subscription churn          | Are recurring members cancelling?                                  |
| Payment success rate        | Are checkout failures hurting revenue?                             |
| Refund and chargeback rate  | Are payments and customer expectations healthy?                    |
| Net revenue per transaction | Is each sale profitable after payment and operating costs?         |
| Payout success rate         | Are creators receiving their money on time?                        |
| Safety response time        | Are reports being addressed promptly?                              |

## 16. Final product decisions

These are the initial defaults I recommend. You can change them before the product requirements and database are finalized.

## Configure your launch blueprint

Choose your preferences to generate a tailored starting specification.

1\. Platform launch

Web first, mobile apps later

Web and mobile apps together

Mobile first, web alongside shortly after

2\. Initial platform commission

10% — aggressive creator acquisition

15% — creator-friendly

20% — balanced starting assumption

25% — higher revenue per sale

3\. Payment methods

M-Pesa first

M-Pesa and cards

M-Pesa, cards and additional international methods

4\. Livestreaming strategy

Include basic livestreaming in the first release

Launch livestreaming after core sales work

5\. Content pricing

Creator-defined flexible pricing, with configurable limits

Minimum price per transaction and optional bundles

Flexible prices plus prepaid fan balance, subject to legal and provider approval

Generate my detailed product specification

My recommendation is to build the core transaction and trust systems first, then add mobile distribution and livestreaming as the provider, compliance and operational requirements become clear. The most important competitive advantage will be a platform where creators can sell anything at a transparent price, get paid reliably, retain control of their content and trust the company operating the service.



I’ll structure this as a product and engineering specification that a product manager, UI/UX designer, backend engineer, mobile developer, and QA team can work from.

The baseline is a Kenya-first, adults-only creator platform with web and mobile launching together, a 20% platform commission, M-Pesa and international payment methods where approved, creator-defined pricing, and livestreaming in Phase 2.

The most important architectural decision is that payments, contracts, content permissions, and creator earnings must be managed by one authoritative backend. The web and mobile apps are different interfaces to the same system.

# PRODUCT REQUIREMENTS DOCUMENT

## Adult Creator Monetization Platform — Kenya-First

**Document status:** Draft v1.0\
**Product type:** Adults-only creator commerce and subscription platform\
**Initial market:** Kenya, with international expansion planned\
**Platforms:** Creator mobile app, fan mobile app, creator web, fan web, admin web\
**Initial commission:** 20% of eligible creator transaction revenue\
**Payment strategy:** M-Pesa, cards, and approved international payment methods\
**Livestreaming:** Phase 2\
**Pricing model:** Creator-defined pricing within configurable platform and payment-provider limits

---

# 1. Executive Summary

## 1.1 Product vision

Build a secure creator monetization platform that enables verified adult creators to sell digital content and experiences directly to consenting adult customers.

The platform will support individual photo and video purchases, subscriptions, paid messages, tips, content bundles, private sessions, and livestreaming.

Unlike a subscription-only marketplace, creators should be able to monetize individual items independently. A creator may offer a free post, sell a photo for KSh 10, charge KSh 500 for a video, and offer a recurring membership without requiring every customer to subscribe.

The platform must combine a simple consumer experience with robust financial accounting, creator agreements, privacy controls, content protection, identity verification, and moderation.

## 1.2 Business objectives

1. Enable creators to complete onboarding and publish their first eligible product.
2. Convert adult visitors into paying customers through transparent pricing and frictionless checkout.
3. Support recurring and one-time revenue without forcing one monetization model.
4. Provide predictable, auditable creator earnings and payouts.
5. Establish a trustworthy operating environment with enforceable content and consent policies.
6. Support Kenyan payment methods while designing for international customers and creators.
7. Build a scalable architecture without unnecessary early infrastructure complexity.

## 1.3 Success criteria

The following are proposed initial targets, not existing performance figures.

| Metric                                             | Initial target                                                            |
| -------------------------------------------------- | ------------------------------------------------------------------------- |
| Creator onboarding completion                      | At least 70% of eligible applicants                                       |
| Time from approved onboarding to first publication | Under 30 minutes                                                          |
| Successful checkout rate                           | At least 90% of valid payment attempts, measured by method                |
| Payment-to-access delay                            | Under 5 seconds at p95 after verified confirmation                        |
| Successful eligible payouts                        | At least 98% within the promised payout window                            |
| Platform availability                              | 99.9% monthly target after stabilization                                  |
| Critical security issues at launch                 | Zero unresolved                                                           |
| Unresolved urgent safety incidents                 | Zero beyond the defined response SLA                                      |
| Financial reconciliation                           | 100% of settled transactions reconciled or assigned an explicit exception |

Targets must be reviewed during pilot testing and adjusted using actual data.

## 1.4 Product principles

- Adults only.
- Explicit consent and verifiable content rights.
- Creator ownership of their content, subject to a limited platform license.
- Transparent fees and recurring billing.
- No access to paid content without verified authorization.
- No payout without financial ledger validation.
- Privacy by default.
- Human review and appeals for consequential moderation decisions.
- Consistent entitlements across web and mobile.
- Accessibility and low-bandwidth support.

---

# 2. Scope

## 2.1 MVP scope: Phase 1

The first production release must include:

- Adult fan and creator account registration.
- Age and identity verification workflows.
- Creator onboarding and payout verification.
- Versioned digital creator agreements and electronic signatures.
- Creator profile management.
- Photo and video uploads.
- Free posts and paid individual items.
- Creator-defined prices within configured limits.
- Subscription memberships.
- Fan discovery and creator following.
- Checkout and payment confirmation.
- M-Pesa and card payments through approved providers.
- Content access enforcement.
- Creator earnings ledger.
- Refunds and chargeback handling.
- Creator payout requests and reconciliation.
- Basic messaging, with configurable paid attachments if included in the launch scope.
- Reporting, blocking, moderation, and appeals.
- Admin dashboard and role-based permissions.
- Audit logs and operational monitoring.
- Privacy requests, account deletion workflows, and policy disclosures.

## 2.2 Phase 2 scope

- Livestreaming.
- Ticketed streams.
- Virtual gifts and tips during streams.
- Paid questions and priority interactions.
- Paid replays.
- Private video sessions and booking.
- Advanced creator analytics.
- Content bundles and promotions.
- Creator collaborations and revenue splits.
- Referral and affiliate programs.
- Advanced anti-fraud scoring.
- Creator storefront customization.
- Additional international payment methods and currencies.

## 2.3 Explicitly out of scope for MVP

- A platform-issued cryptocurrency.
- Unrestricted user-to-user cash transfers.
- A general-purpose stored-value wallet before regulatory assessment.
- Automatic global availability in every country.
- Guaranteed prevention of screenshots or external recordings.
- Unreviewed synthetic intimate media or impersonation tools.
- Public distribution of identity documents or sensitive verification data.
- Unrestricted adult-content uploads without moderation and consent controls.

## 2.4 Release acceptance principle

A feature is not complete merely because its primary screen works.

A financial feature is complete only when it includes state transitions, authorization, audit events, failure handling, reconciliation, and tests. A content feature is complete only when upload, moderation, access enforcement, reporting, removal, and deletion behavior are defined.

---

# 3. User Types and Personas

## 3.1 Creator

An adult who publishes eligible content and earns revenue.

Needs:

- Fast registration and verification.
- Control over pricing and access.
- Easy uploads and content scheduling.
- Transparent earnings.
- Reliable payouts.
- Control over who can message or access content.
- Access to contracts and financial statements.

## 3.2 Fan

An eligible adult who discovers creators and purchases content or experiences.

Needs:

- Simple discovery.
- Clear prices and purchase conditions.
- Secure checkout.
- Immediate access after verified payment.
- A personal purchase library.
- Subscription management and cancellation.
- Privacy and discreet notifications.
- Clear refund and dispute procedures.

## 3.3 Moderator

An authorized staff member who reviews reports, flagged content, consent concerns, and account restrictions.

Needs:

- A prioritized case queue.
- Access only to relevant evidence.
- Standardized decisions and reason codes.
- Escalation procedures.
- Audit trails and appeals.

## 3.4 Finance operator

An authorized employee responsible for transaction reconciliation, refunds, and creator payouts.

Needs:

- Searchable financial records.
- Provider settlement comparisons.
- Pending payout queues.
- Approval controls.
- Exception reporting.
- Separation between initiating and approving sensitive actions.

## 3.5 Legal and compliance operator

Responsible for contract templates, legal requests, retention policies, compliance documentation, and sensitive escalations.

## 3.6 Super administrator

Responsible for platform configuration, access management, security controls, and system-level settings.

No administrator should automatically receive unrestricted access to every user's private content or identity documents.

---

# 4. Functional Requirements

Priority definitions:

- **P0:** Required before production launch.
- **P1:** Important shortly after launch.
- **P2:** Planned enhancement.

## 4.1 Identity and authentication

**FR-AUTH-001 — Registration (P0)**\
Users must be able to register using an approved email or phone-based flow.

**FR-AUTH-002 — Verification (P0)**\
Email or phone verification must be completed before sensitive account actions.

**FR-AUTH-003 — Adult eligibility (P0)**\
Adult creator monetization must require successful age and identity checks. Fans must pass the applicable age-assurance process before accessing restricted services.

**FR-AUTH-004 — Session management (P0)**\
Users must be able to view active sessions and revoke individual sessions.

**FR-AUTH-005 — Two-factor authentication (P0 for staff; recommended for creators)**\
Administrator accounts must require strong multi-factor authentication. Creator accounts should support it.

**FR-AUTH-006 — Recovery (P0)**\
Account recovery must verify ownership and prevent unauthorized changes to payout destinations.

**FR-AUTH-007 — Risk-based re-verification (P0)**\
Changes to legal identity, payout ownership, or high-risk account attributes may require renewed verification.

## 4.2 Creator onboarding

**FR-CRT-001 — Profile setup (P0)**\
Creators can configure display name, handle, biography, avatar, banner, language, categories, and privacy settings.

**FR-CRT-002 — Verification status (P0)**\
The system must show states such as `incomplete`, `submitted`, `under_review`, `action_required`, `approved`, `rejected`, `suspended`.

**FR-CRT-003 — Payout setup (P0)**\
Creators can register an eligible payout destination and complete ownership verification.

**FR-CRT-004 — Contract requirement (P0)**\
A creator cannot monetize until the required agreement is signed and active.

**FR-CRT-005 — Draft persistence (P0)**\
Onboarding progress must be saved securely so users can resume later.

**FR-CRT-006 — Appeals (P0)**\
Creators can appeal eligible verification or moderation decisions.

## 4.3 Digital contracts

**FR-CON-001 — Versioned templates (P0)**\
Authorized staff can create, review, publish, and retire contract templates.

**FR-CON-002 — Offer and acceptance (P0)**\
Creators can review the entire agreement and fee summary before signing.

**FR-CON-003 — Signature evidence (P0)**\
The system records document version, signer identity evidence, timestamp, signature event, consent to electronic signing, and document hash.

**FR-CON-004 — Immutable executed document (P0)**\
Once signed, the executed document cannot be silently edited or replaced.

**FR-CON-005 — Amendments (P0)**\
Material changes require a new version and the required notice and acceptance.

**FR-CON-006 — Contract enforcement (P0)**\
The commission rules applied to a transaction must be traceable to the active agreement and applicable transaction date.

**FR-CON-007 — Download and retention (P0)**\
Each party can download the executed agreement, subject to lawful retention and access rules.

## 4.4 Content management

**FR-CNT-001 — Media upload (P0)**\
Creators can upload supported image and video formats.

**FR-CNT-002 — Resumable uploads (P0)**\
Large uploads can resume after interrupted connections.

**FR-CNT-003 — Drafts (P0)**\
Creators can save unfinished content privately.

**FR-CNT-004 — Content access types (P0)**\
Supported access policies include:

- Public preview.
- Followers.
- Active subscribers.
- One-time purchase.
- Approved custom audience.
- Scheduled release.

**FR-CNT-005 — Flexible pricing (P0)**\
Creators can set a price within platform-configured limits and applicable provider constraints.

**FR-CNT-006 — Preview management (P0)**\
Creators can select a safe preview, thumbnail, caption, and tags.

**FR-CNT-007 — Content lifecycle (P0)**\
Content supports draft, processing, moderation pending, scheduled, published, restricted, removed, and deleted states.

**FR-CNT-008 — Rights and consent (P0)**\
Content involving other people requires the applicable consent, age, and rights evidence before publication.

**FR-CNT-009 — Secure delivery (P0)**\
Private assets must never be exposed through permanent public object-storage URLs.

**FR-CNT-010 — Removal workflow (P0)**\
Creators and authorized staff can initiate removal, with evidence retention and legal holds applied where required.

## 4.5 Pricing and monetization

**FR-PRC-001 — One-time purchases (P0)**\
A fan can buy an individual content item without subscribing.

**FR-PRC-002 — Subscriptions (P0)**\
Creators can configure a recurring membership price and define member benefits.

**FR-PRC-003 — Commission (P0)**\
The default platform commission is 20% of eligible creator transaction revenue, subject to the executed agreement.

**FR-PRC-004 — Fee transparency (P0)**\
Checkout and earnings statements show relevant platform, processing, tax, and other applicable deductions.

**FR-PRC-005 — Commission history (P0)**\
Changes to commission terms must not silently rewrite historical transactions.

**FR-PRC-006 — Refund adjustments (P0)**\
Refunds and chargebacks must update the ledger through compensating entries rather than deleting the original transaction.

**FR-PRC-007 — Discounts (P1)**\
Creators can offer time-limited discounts, coupon codes, and bundles.

## 4.6 Fan discovery

**FR-DIS-001 — Search (P0)**\
Fans can search eligible creator profiles by name, handle, and approved categories.

**FR-DIS-002 — Creator profile (P0)**\
Profiles display public information, prices, membership options, and available content previews.

**FR-DIS-003 — Restricted content protection (P0)**\
Explicit or restricted content must not be displayed to unauthorized users through previews, search snippets, notifications, or public APIs.

**FR-DIS-004 — Follow and unfollow (P0)**\
Fans can follow creators without purchasing.

**FR-DIS-005 — Recommendations (P1)**\
Recommendations must respect user restrictions, blocked accounts, eligibility, and moderation state.

## 4.7 Checkout and payments

**FR-PAY-001 — Payment intent (P0)**\
Every checkout creates a unique order and payment intent.

**FR-PAY-002 — Provider integration (P0)**\
The platform supports approved M-Pesa and card-processing integrations, with additional international methods enabled only after provider approval.

**FR-PAY-003 — Server-side verification (P0)**\
Content access is granted only after a verified provider event or authoritative status check.

**FR-PAY-004 — Idempotency (P0)**\
Duplicate requests and repeated callbacks must not create duplicate purchases or ledger entries.

**FR-PAY-005 — Currency support (P0)**\
Each transaction records its currency. FX conversion and displayed totals must be explicit when relevant.

**FR-PAY-006 — Failure handling (P0)**\
Pending, failed, expired, cancelled, reversed, and successful payments must be represented accurately.

**FR-PAY-007 — Reconciliation (P0)**\
Provider transactions must be reconciled against platform orders and settlement records.

**FR-PAY-008 — Refunds (P0)**\
Refund requests must follow published policies and provider capabilities.

## 4.8 Creator earnings and payouts

**FR-WAL-001 — Financial ledger (P0)**\
All financial movements must be represented through auditable ledger entries.

**FR-WAL-002 — Balance categories (P0)**\
The interface distinguishes pending, available, reserved, paid-out, and adjusted earnings.

**FR-WAL-003 — Payout request (P0)**\
Eligible creators can request payout to a verified destination.

**FR-WAL-004 — Payout controls (P0)**\
The system enforces eligibility, minimums, limits, risk holds, and required approvals.

**FR-WAL-005 — Payout reconciliation (P0)**\
A payout is marked paid only after provider confirmation and reconciliation.

**FR-WAL-006 — Statements (P0)**\
Creators can access transaction statements and payout histories.

## 4.9 Messaging and subscriptions

**FR-MSG-001 — Conversations (P0 or deferred to initial launch scope)**\
Eligible users can exchange permitted messages.

**FR-MSG-002 — Privacy controls (P0)**\
Users can block, mute, and report other users.

**FR-MSG-003 — Paid attachments (P1)**\
Creators can attach separately purchasable content to messages.

**FR-SUB-001 — Membership management (P0)**\
Fans can view current subscriptions, renewal dates, prices, and benefits.

**FR-SUB-002 — Cancellation (P0)**\
Fans can cancel renewal through a straightforward workflow.

**FR-SUB-003 — Access expiry (P0)**\
Subscription access ends according to the disclosed entitlement policy.

## 4.10 Trust, safety, and moderation

**FR-SAF-001 — Reports (P0)**\
Users can report profiles, media, messages, and other eligible activity.

**FR-SAF-002 — Case management (P0)**\
Reports become tracked cases with priority, status, assigned reviewer, evidence references, and decision history.

**FR-SAF-003 — Consent concerns (P0)**\
Reports of non-consensual imagery, coercion, impersonation, or rights violations receive a dedicated escalation path.

**FR-SAF-004 — Content restrictions (P0)**\
Flagged content can be restricted while awaiting review, according to risk and policy.

**FR-SAF-005 — Appeals (P0)**\
Users can appeal eligible decisions, with reviewer independence where practicable.

**FR-SAF-006 — Auditability (P0)**\
Staff access to sensitive records and moderation actions must be logged.

**FR-SAF-007 — Prohibited content (P0)**\
The service must prohibit sexual content involving minors, non-consensual sexual imagery, exploitative material, and other content prohibited by applicable law or platform policy.

## 4.11 Administration

**FR-ADM-001 — Role-based access (P0)**\
Admin functions require explicit permissions.

**FR-ADM-002 — Financial controls (P0)**\
High-risk refunds, payout releases, and commission changes may require dual approval.

**FR-ADM-003 — Operational queues (P0)**\
The dashboard provides verification, moderation, payout, dispute, and support queues.

**FR-ADM-004 — Audit log (P0)**\
Sensitive administrative changes are attributable to an authenticated staff account.

**FR-ADM-005 — Feature flags (P1)**\
Authorized staff can enable features by market, account cohort, or platform without deploying new code.

---

# 5. Screen-by-Screen User Flows

## 5.1 Shared account entry

### Screen A1: Welcome

Components:

- Product logo.
- Sign in.
- Create account.
- Age eligibility notice.
- Terms, privacy, and acceptable-use links.
- Market availability notice.

Actions:

- Continue to registration.
- Sign in.
- Open policy documents.

Acceptance criteria:

- The page does not expose restricted media.
- Age restrictions are clearly explained.
- The interface does not claim to guarantee anonymity.

### Screen A2: Account registration

Fields:

- Email or phone.
- Password or approved passwordless method.
- Country.
- Acceptance of applicable terms.

Actions:

- Create account.
- Verify contact details.
- Return to sign in.

Validation:

- Normalize and validate identifiers.
- Apply rate limits and bot protection.
- Do not disclose whether another user owns an email or phone number.

### Screen A3: Contact verification

Components:

- OTP entry.
- Resend timer.
- Change contact method.
- Help link.

States:

- Pending.
- Verified.
- Expired.
- Failed.
- Rate-limited.

### Screen A4: Account role selection

Options:

- Fan.
- Creator.
- Both roles, where permitted by the business rules.

Role selection must not bypass age checks or creator onboarding requirements.

---

## 5.2 Creator onboarding flow

### Screen C1: Creator eligibility

Display:

- Adult eligibility requirements.
- Countries supported.
- Identity and payout requirements.
- Content policy summary.
- Expected review process.

Actions:

- Begin verification.
- Save and exit.

### Screen C2: Age and identity verification

Components:

- Approved verification provider flow.
- Data-use notice.
- Verification status.
- Instructions for failed verification.

Requirements:

- Collect only necessary information.
- Prefer a qualified verification provider that returns verification outcomes rather than storing raw documents unnecessarily.
- Restrict raw identity evidence to specifically authorized staff.
- Never permit creator monetization before the required checks pass.

### Screen C3: Creator profile setup

Fields:

- Display name.
- Unique handle.
- Biography.
- Profile image.
- Banner.
- Categories.
- Language.
- Optional public location.
- Discovery preferences.

Actions:

- Save draft.
- Preview profile.
- Continue.

### Screen C4: Creator agreement

Sections:

- Commercial terms.
- Platform commission.
- Payment and payout terms.
- Content ownership and licensing.
- Content rules and consent.
- Refunds and chargebacks.
- Privacy and termination.
- Dispute resolution.

Actions:

- Read complete agreement.
- Download.
- Ask support.
- Accept and sign.
- Decline.

Signing must record the exact contract version.

### Screen C5: Payout setup

Fields depend on the approved payout provider:

- Payout method.
- Beneficiary details.
- Verified account or mobile-money destination.
- Required tax or business information.

Actions:

- Verify.
- Save.
- Replace destination.

Security:

- Payout destination changes may trigger re-authentication, notifications, and a risk-based hold.

### Screen C6: Onboarding status

Display:

- Contact verification.
- Age and identity verification.
- Profile completeness.
- Signed contract.
- Payout setup.
- Compliance review.

States:

- Incomplete.
- Submitted.
- Under review.
- Action required.
- Approved.
- Rejected.
- Suspended.

### Screen C7: Creator dashboard

Widgets:

- Available earnings.
- Pending earnings.
- Active subscribers.
- Content views.
- Recent purchases.
- Recent payouts.
- Verification or contract warnings.

Quick actions:

- Upload content.
- Create post.
- View messages.
- Manage memberships.
- Request payout.

### Screen C8: Content studio

Steps:

1. Select image or video.
2. Upload media.
3. Wait for processing.
4. Add caption and metadata.
5. Configure preview.
6. Select access policy.
7. Set price.
8. Choose publish time.
9. Review policy warnings.
10. Publish or save draft.

The studio must clearly show the final price, access rules, and current moderation status.

### Screen C9: Content management

Tabs:

- Drafts.
- Published.
- Scheduled.
- Restricted.
- Archived.

Actions:

- Edit eligible metadata.
- Change future pricing where permitted.
- Unpublish.
- View analytics.
- Report an issue.

Historical purchases must remain traceable if content is later removed or restricted.

### Screen C10: Earnings

Sections:

- Pending.
- Available.
- Reserved.
- Paid out.
- Adjustments.

Filters:

- Date range.
- Transaction type.
- Currency.
- Status.

Each transaction displays:

- Gross amount.
- Commission.
- Processing fees where applicable.
- Taxes or other disclosed deductions.
- Net amount.
- Contract/rate reference.
- Refund or chargeback status.

### Screen C11: Payout request

Display:

- Available balance.
- Eligible amount.
- Minimum and maximum.
- Destination.
- Fees and expected processing window.
- Any hold or eligibility warning.

Flow:

1. Enter amount.
2. Select verified destination.
3. Review terms.
4. Confirm with appropriate authentication.
5. Create payout request.
6. Show tracking status.

### Screen C12: Contracts and documents

Sections:

- Current agreement.
- Previous versions.
- Pending amendments.
- Downloadable signed documents.
- Signature evidence summary.
- Support and legal contact details.

### Screen C13: Creator settings

Sections:

- Account security.
- Public profile.
- Privacy.
- Notification preferences.
- Blocked users.
- Payout methods.
- Tax and compliance details.
- Account closure.

---

## 5.3 Fan journey

### Screen F1: Adult eligibility gate

- Explain the platform's age requirement.
- Run the required age-assurance process before restricted access.
- Avoid displaying explicit previews before eligibility is established.
- Provide a safe exit path.

### Screen F2: Fan registration

- Email or phone.
- Verification.
- Password or passkey.
- Country and currency preferences.
- Optional privacy settings.

### Screen F3: Discovery

Sections:

- Recommended creators.
- Followed creators.
- New content.
- Available live events, when enabled.
- Search and category filters.

All recommendations must respect blocks, account restrictions, and content eligibility.

### Screen F4: Creator profile

Display:

- Profile image and biography.
- Verification status where appropriate.
- Public posts and safe previews.
- Individual item prices.
- Membership tiers.
- Content categories.
- Live schedule when enabled.
- Follow and report controls.

### Screen F5: Content detail

Display:

- Safe preview.
- Creator identity.
- Price and currency.
- Exact access being purchased.
- Any applicable restrictions.
- Purchase button.

Do not expose the original media URL before authorization.

### Screen F6: Checkout

Steps:

1. Confirm item and price.
2. Display fees and total.
3. Identify recurring versus one-time payment.
4. Select an approved payment method.
5. Complete provider authorization.
6. Wait for verified result.
7. Show receipt and access status.

The checkout must not claim success based solely on a client-side callback or redirect.

### Screen F7: Purchase result

States:

- Success.
- Pending.
- Failed.
- Cancelled.
- Expired.
- Under review.

A pending payment must not unlock paid media unless the provider's documented payment model confirms the transaction is complete.

### Screen F8: Purchased library

Sections:

- Purchased items.
- Active subscriptions.
- Expired subscriptions.
- Receipts.
- Refund requests.

Content access follows the entitlement policy and any lawful restriction.

### Screen F9: Subscription management

Display:

- Creator.
- Current price.
- Renewal date.
- Benefits.
- Payment method where supported.
- Cancellation action.

Require clear confirmation of cancellation and show the effective end date.

### Screen F10: Messages

Components:

- Conversation list.
- Message thread.
- Report and block controls.
- Paid attachment preview.
- Purchase confirmation where applicable.

Never use unsolicited intimate messaging as an automatic growth tactic.

### Screen F11: Fan wallet and transactions

If a stored balance is not approved for launch, this screen is a transaction center rather than a deposit wallet.

Display:

- Purchases.
- Refunds.
- Receipts.
- Payment status.
- Spending summary.
- Optional spending controls.

### Screen F12: Privacy and account management

- Notification settings.
- Discreet notification options.
- Session management.
- Account deletion.
- Data-access requests.
- Privacy notices.
- Support and complaint channels.

---

## 5.4 Admin workflows

### Screen ADM1: Staff login

- MFA required.
- Session timeout.
- Risk-based authentication.
- Access denied unless the staff account is active.

### Screen ADM2: Operations dashboard

Queues:

- Pending creator verification.
- Content reports.
- Urgent safety cases.
- Payouts requiring review.
- Payment reconciliation exceptions.
- Refund disputes.
- Support requests.

### Screen ADM3: Creator review

Display:

- Verification outcome.
- Profile details.
- Agreement status.
- Payout setup status.
- Policy checklist.
- Review history.

Actions:

- Approve.
- Request more information.
- Reject with reason.
- Suspend under policy.
- Escalate.

### Screen ADM4: Contract management

- Draft templates.
- Version history.
- Commission terms.
- Effective dates.
- Required acceptance rules.
- Signature completion.
- Amendment status.

### Screen ADM5: Financial operations

- Search orders and payment attempts.
- Review provider events.
- Reconcile settlements.
- Initiate eligible refunds.
- Review payout exceptions.
- Approve or reject eligible payout requests.
- Export authorized financial reports.

### Screen ADM6: Moderation case

Display only evidence needed for the case.

Fields:

- Report type.
- Reporter and subject identifiers.
- Content references.
- Severity.
- Evidence references.
- Assigned reviewer.
- Decision and reason code.
- Appeal status.
- Audit history.

### Screen ADM7: Access and audit

- Staff accounts.
- Role assignments.
- MFA status.
- Sensitive-record access events.
- Configuration changes.
- Export history.
- Security alerts.

### Screen ADM8: Platform configuration

- Commission rules for future transactions.
- Permitted currencies.
- Pricing limits.
- Supported countries.
- Payment-provider status.
- Feature flags.
- Content policy versions.
- Retention configuration.

Sensitive configuration changes must be logged, validated, and approved according to risk.

---

# 6. User Stories and Acceptance Criteria

## 6.1 Creator stories

### US-C01: Register as a creator

As an eligible adult, I want to register as a creator so that I can monetize my content.

Acceptance criteria:

- Contact verification is required.
- Adult eligibility and identity verification are completed through an approved process.
- Failed checks do not enable monetization.
- The user can save progress and resume.
- Status changes are visible.

### US-C02: Sign a creator agreement

As a creator, I want to review and sign the platform agreement so that I understand the fees and obligations.

Acceptance criteria:

- Full agreement is accessible before signing.
- Commission terms are clearly summarized.
- The exact signed version is preserved.
- The creator receives a downloadable copy.
- Material changes follow the amendment workflow.

### US-C03: Sell an individual photo

As a creator, I want to set a price for an individual photo so that customers can purchase it without a subscription.

Acceptance criteria:

- Creator can choose an allowed price.
- Preview and full media are stored separately or protected separately.
- Purchase grants access only to the correct item.
- Repeated payment callbacks do not create multiple sales.
- Revenue is attributed to the applicable commission rule.

### US-C04: Sell a video

As a creator, I want to upload a video, add a teaser, and set its price.

Acceptance criteria:

- Upload can resume after interruption.
- Processing status is visible.
- Media is checked against policy.
- Unauthorized users cannot retrieve the original media.
- Creator can view sales and access metrics.

### US-C05: Request a payout

As a creator, I want to withdraw eligible earnings to my verified payout destination.

Acceptance criteria:

- Available balance is calculated from the ledger.
- Reserved and pending amounts cannot be withdrawn.
- Duplicate requests are prevented.
- Payout status is tracked.
- Failed payouts return to an appropriate ledger state after reconciliation.
- Every payout has an audit trail.

### US-C06: View earnings breakdown

As a creator, I want to see how much the platform deducts from each sale.

Acceptance criteria:

- Gross, commission, processing costs, applicable taxes, and net are distinguishable.
- The applied commission rate is traceable to the contract.
- Refunds appear as separate adjustments.
- Historical statements remain consistent.

## 6.2 Fan stories

### US-F01: Purchase a single item

As a fan, I want to buy one content item without subscribing.

Acceptance criteria:

- Price and access terms are visible before checkout.
- One-time and recurring charges are clearly distinguished.
- Access is granted only after verified payment.
- Receipt and purchase history are updated.
- A retry does not create a duplicate charge.

### US-F02: Manage a subscription

As a fan, I want to cancel recurring billing without unnecessary friction.

Acceptance criteria:

- Current renewal date and benefits are visible.
- Cancellation can be completed through the account.
- The effective cancellation date is displayed.
- Access expiry follows the disclosed policy.
- Cancellation is confirmed and logged.

### US-F03: Report content

As a fan, I want to report suspected abuse or non-consensual content.

Acceptance criteria:

- Reporting is available from relevant screens.
- The user can select a reason and add information.
- Urgent reports are prioritized.
- The reporter receives a case reference where appropriate.
- Reports are not visible to unauthorized users.

### US-F04: Control privacy

As a fan, I want discreet notifications and control over my sessions.

Acceptance criteria:

- Notification content can be minimized.
- Sessions can be revoked.
- Personal payment details are not exposed to creators.
- Account deletion and privacy request options are discoverable.

## 6.3 Finance stories

### US-FIN01: Reconcile payments

As a finance operator, I want to compare platform transactions with provider settlement records.

Acceptance criteria:

- Each provider transaction can be matched to an order or flagged as an exception.
- Unmatched records enter a queue.
- Duplicate events are detected.
- Reconciliation results are auditable.
- Settled totals can be exported by authorized users.

### US-FIN02: Approve a payout

As an authorized finance operator, I want to approve eligible payouts so that funds are disbursed under the platform's controls.

Acceptance criteria:

- Creator eligibility is checked at approval.
- Destination changes and risk flags are visible.
- Required second approval is enforced.
- Provider confirmation is required before marking paid.
- All decisions are recorded.

## 6.4 Moderator stories

### US-MOD01: Review a report

As a moderator, I want a prioritized case queue so that I can address safety concerns efficiently.

Acceptance criteria:

- Case severity and age are visible.
- Access to evidence is restricted and logged.
- Decision reason codes are mandatory.
- Urgent reports can be escalated.
- Appeal history is retained.

### US-MOD02: Restrict unsafe content

As an authorized moderator, I want to restrict flagged content while it is reviewed.

Acceptance criteria:

- Restriction is applied consistently across clients.
- Existing entitlements are handled according to policy.
- The decision is auditable.
- The affected user is notified where appropriate and safe.
- Appeals are supported.

---

# 7. Permission Model

## 7.1 Core principles

- Deny access by default.
- Enforce permissions on the backend, not just the interface.
- Separate content ownership from access entitlement.
- Separate creator verification from public verification badges.
- Apply least privilege to staff.
- Require extra approval for sensitive financial actions.
- Record sensitive access and administrative changes.

## 7.2 Roles

| Capability                      | Fan                  | Creator              | Support                      | Moderator            | Finance                         | Legal                            | Super admin                    |
| ------------------------------- | -------------------- | -------------------- | ---------------------------- | -------------------- | ------------------------------- | -------------------------------- | ------------------------------ |
| Browse eligible public profiles | Yes                  | Yes                  | Limited                      | Limited              | No                              | No                               | As needed                      |
| Purchase content                | Yes                  | Optional             | No                           | No                   | No                              | No                               | No                             |
| Publish content                 | No                   | Own account          | No                           | Restrict/remove only | No                              | No                               | Through controlled permissions |
| View own purchases              | Yes                  | If also a fan        | No                           | No                   | Authorized case context         | Authorized case context          | Audited exception              |
| View own earnings               | No                   | Yes                  | No                           | No                   | Authorized financial operations | Contract context only            | Audited exception              |
| Sign creator agreement          | No                   | Yes                  | No                           | No                   | No                              | No, unless party to an agreement | No                             |
| Review identity records         | Own status           | Own status           | Minimal status               | Only if required     | No by default                   | Only if required                 | Audited, limited               |
| Moderate content                | Report only          | Own eligible content | Escalate                     | Yes                  | No                              | Policy/legal hold actions        | Configured authority           |
| Initiate refunds                | Request              | No                   | Limited policy-based actions | No                   | Yes                             | No                               | Controlled override            |
| Approve payouts                 | No                   | Request own payout   | No                           | No                   | Authorized approval             | No                               | Dual-controlled override       |
| Edit contract templates         | No                   | No                   | No                           | No                   | No                              | Yes                              | Yes                            |
| Change commission configuration | No                   | No                   | No                           | No                   | No                              | Propose/review                   | Controlled approval            |
| Manage staff roles              | No                   | No                   | No                           | No                   | No                              | No                               | Yes                            |
| View audit logs                 | Own activity summary | Own activity summary | Limited                      | Relevant cases       | Financial logs                  | Contract/legal logs              | Authorized full scope          |

The table is a starting point. Actual permissions should be implemented as granular actions rather than a single broad role check.

## 7.3 Suggested permission names

Examples:

- `creator.profile.update`
- `creator.content.create`
- `creator.content.publish`
- `creator.earnings.read`
- `creator.payout.request`
- `fan.purchase.create`
- `fan.subscription.cancel`
- `moderation.case.read`
- `moderation.content.restrict`
- `moderation.case.resolve`
- `finance.payment.reconcile`
- `finance.refund.initiate`
- `finance.refund.approve`
- `finance.payout.initiate`
- `finance.payout.approve`
- `contracts.template.manage`
- `contracts.version.publish`
- `admin.roles.manage`
- `audit.sensitive_access.read`

Sensitive financial operations should support dual control, with distinct initiating and approving users.

---

# 8. Database Schema

## 8.1 Database conventions

Use PostgreSQL as the primary transactional database.

Conventions:

- Primary keys: UUID.
- Timestamps: UTC `timestamptz`.
- Monetary values: integer minor units where the currency supports them, with currency recorded explicitly.
- No floating-point arithmetic for financial calculations.
- Foreign keys and unique constraints for integrity.
- Soft deletion only where appropriate; legal deletion and retention rules must be defined.
- Sensitive identity data separated from ordinary profile data.
- Append-only financial ledger entries.
- Explicit state transitions for financial and moderation workflows.

## 8.2 Users and identity

### `users`

| Column           | Type                 | Notes                                                |
| ---------------- | -------------------- | ---------------------------------------------------- |
| id               | UUID PK              | Internal identifier                                  |
| email_normalized | TEXT nullable UNIQUE | Normalized email                                     |
| phone_e164       | TEXT nullable UNIQUE | Normalized phone                                     |
| password_hash    | TEXT nullable        | Never store plaintext passwords                      |
| account_status   | ENUM/TEXT            | pending, active, restricted, suspended, closed       |
| primary_role     | TEXT                 | Initial role hint; not the sole authorization source |
| country_code     | CHAR(2)              | Account market                                       |
| created_at       | TIMESTAMPTZ          | Creation time                                        |
| updated_at       | TIMESTAMPTZ          | Last update                                          |
| closed_at        | TIMESTAMPTZ nullable | Closure time                                         |

### `user_roles`

`id`, `user_id`, `role`, `granted_by`, `created_at`, `revoked_at`.

Purpose: support multiple roles without relying on one mutable role field.

### `auth_sessions`

`id`, `user_id`, `refresh_token_hash`, `device_label`, `created_at`, `last_seen_at`, `expires_at`, `revoked_at`.

Never store raw long-lived session secrets.

### `verification_cases`

`id`, `user_id`, `provider`, `verification_type`, `status`, `provider_reference`, `decision_reason_code`, `submitted_at`, `reviewed_at`, `reviewer_id`.

Do not place raw identity documents in this table.

### `restricted_identity_records`

`id`, `user_id`, `provider_reference`, `encrypted_evidence_reference`, `retention_category`, `access_classification`, `created_at`, `retention_until`.

Store only necessary data. Prefer provider-hosted document handling and verification tokens where feasible.

## 8.3 Creator profiles

### `creator_profiles`

`id`, `user_id UNIQUE`, `handle UNIQUE`, `display_name`, `bio`, `avatar_asset_id`, `banner_asset_id`, `profile_status`, `verification_status`, `discovery_enabled`, `created_at`, `updated_at`.

### `creator_payout_methods`

`id`, `creator_id`, `provider`, `method_type`, `encrypted_destination_reference`, `verification_status`, `created_at`, `revoked_at`.

Never store provider secrets or full payment credentials in ordinary application records.

## 8.4 Contracts

### `contract_templates`

`id`, `name`, `jurisdiction`, `status`, `created_by`, `created_at`.

### `contract_versions`

`id`, `template_id`, `version_number`, `document_storage_key`, `document_hash`, `terms_json`, `effective_from`, `published_at`, `created_by`.

### `creator_contracts`

`id`, `creator_id`, `contract_version_id`, `status`, `commission_rule_id`, `offered_at`, `accepted_at`, `terminated_at`.

### `contract_signatures`

`id`, `creator_contract_id`, `signer_user_id`, `document_hash`, `signature_provider`, `provider_signature_reference`, `signed_at`, `consent_evidence_reference`, `audit_event_id`.

Contract versions and executed documents must be immutable.

## 8.5 Commission configuration

### `commission_rules`

`id`, `name`, `platform_rate_bps`, `eligible_transaction_types`, `effective_from`, `effective_until`, `status`, `created_by`, `approved_by`.

Use basis points: 2,000 basis points represent a 20% rate.

The rule should define whether the rate applies before or after any specific deductions. This must be consistent with the executed contract.

Historical transactions should store a snapshot of the applied rate and calculation details.

## 8.6 Media and content

### `media_assets`

`id`, `owner_user_id`, `storage_key`, `media_type`, `mime_type`, `file_size_bytes`, `checksum`, `processing_status`, `moderation_status`, `duration_seconds`, `created_at`, `deleted_at`.

### `posts`

`id`, `creator_id`, `title`, `caption`, `post_status`, `access_type`, `price_amount_minor`, `currency`, `publish_at`, `published_at`, `created_at`, `updated_at`.

### `post_media`

`id`, `post_id`, `media_asset_id`, `display_order`, `is_preview`.

### `content_access_rules`

`id`, `post_id`, `access_type`, `required_subscription_tier_id`, `price_amount_minor`, `currency`, `valid_from`, `valid_until`.

Use one authoritative representation for the access policy. Avoid conflicting duplicate fields between the post and access-rule records.

### `content_rights_records`

`id`, `content_id`, `rights_type`, `consent_record_id`, `evidence_reference`, `status`, `reviewed_by`, `created_at`.

### `consent_records`

`id`, `content_id`, `participant_reference`, `consent_type`, `verification_status`, `evidence_reference`, `verified_at`, `retention_category`.

Access to consent evidence must be restricted. The schema should support lawful retention and deletion policies without placing sensitive documents in public-facing records.

## 8.7 Orders and payments

### `orders`

`id`, `buyer_user_id`, `creator_id`, `status`, `currency`, `subtotal_minor`, `fees_minor`, `tax_minor`, `total_minor`, `idempotency_key`, `created_at`.

### `order_items`

`id`, `order_id`, `item_type`, `item_reference_id`, `quantity`, `unit_amount_minor`, `currency`, `access_grant_reference`.

### `payment_attempts`

`id`, `order_id`, `provider`, `provider_payment_reference`, `status`, `amount_minor`, `currency`, `idempotency_key`, `initiated_at`, `confirmed_at`, `failure_code`.

### `provider_events`

`id`, `provider`, `provider_event_id`, `event_type`, `received_at`, `signature_verified`, `processing_status`, `payload_reference`.

Create a unique constraint on the provider and provider event identifier where available.

Avoid retaining unnecessary raw provider payloads containing personal or payment data.

## 8.8 Access entitlements

### `entitlements`

`id`, `user_id`, `resource_type`, `resource_id`, `source_type`, `source_id`, `status`, `valid_from`, `valid_until`, `created_at`, `revoked_at`.

Examples:

- One-time purchase.
- Active subscription.
- Approved ticket.
- Authorized private session.

Every protected-content request must check the current entitlement state and resource policy.

## 8.9 Subscriptions

### `subscriptions`

`id`, `fan_user_id`, `creator_id`, `tier_id`, `status`, `currency`, `price_minor`, `billing_interval`, `current_period_start`, `current_period_end`, `cancel_at_period_end`, `provider_subscription_reference`.

### `subscription_tiers`

`id`, `creator_id`, `name`, `description`, `price_minor`, `currency`, `billing_interval`, `status`.

Subscription changes must not rewrite historical billing periods.

## 8.10 Financial ledger

### `ledger_accounts`

`id`, `account_type`, `owner_reference`, `currency`, `status`.

### `ledger_transactions`

`id`, `transaction_type`, `source_type`, `source_id`, `status`, `currency`, `created_at`, `posted_at`, `reversal_of_transaction_id`.

### `ledger_entries`

`id`, `ledger_transaction_id`, `ledger_account_id`, `side`, `amount_minor`, `currency`, `created_at`.

Use double-entry accounting: every posted financial transaction must balance within each currency.

### `refunds`

`id`, `order_id`, `payment_attempt_id`, `amount_minor`, `currency`, `reason_code`, `status`, `initiated_by`, `approved_by`, `provider_reference`, `created_at`.

### `payouts`

`id`, `creator_id`, `payout_method_id`, `amount_minor`, `currency`, `status`, `requested_at`, `approved_at`, `submitted_at`, `settled_at`, `provider_reference`, `failure_reason_code`.

### `payout_approvals`

`id`, `payout_id`, `approver_user_id`, `decision`, `reason`, `created_at`.

Prevent the same person from both initiating and approving a payout where dual control is required.

### `settlement_records`

`id`, `provider`, `settlement_reference`, `currency`, `gross_minor`, `fee_minor`, `net_minor`, `settlement_date`, `reconciliation_status`.

### `reconciliation_exceptions`

`id`, `provider`, `external_reference`, `internal_reference`, `exception_type`, `status`, `assigned_to`, `resolution_notes`, `created_at`, `resolved_at`.

## 8.11 Messaging

### `conversations`

`id`, `conversation_type`, `created_at`, `status`.

### `conversation_participants`

`conversation_id`, `user_id`, `joined_at`, `left_at`, `participant_role`.

### `messages`

`id`, `conversation_id`, `sender_user_id`, `message_type`, `body_reference`, `created_at`, `deleted_at`.

### `message_attachments`

`id`, `message_id`, `media_asset_id`, `access_type`, `price_minor`, `currency`.

### `user_blocks`

`id`, `blocker_user_id`, `blocked_user_id`, `created_at`.

## 8.12 Moderation and audit

### `reports`

`id`, `reporter_user_id`, `subject_type`, `subject_id`, `reason_code`, `description_reference`, `priority`, `status`, `created_at`.

### `moderation_cases`

`id`, `report_id`, `assigned_to`, `case_status`, `decision`, `decision_reason_code`, `created_at`, `resolved_at`.

### `moderation_actions`

`id`, `case_id`, `actor_user_id`, `action_type`, `target_type`, `target_id`, `reason_code`, `created_at`.

### `appeals`

`id`, `case_id`, `appellant_user_id`, `reason_reference`, `status`, `reviewer_id`, `decision`, `created_at`, `resolved_at`.

### `audit_events`

`id`, `actor_user_id`, `action`, `target_type`, `target_id`, `request_id`, `ip_reference`, `created_at`, `metadata_reference`.

Audit records must be tamper-resistant, access-controlled, and retained according to a defined policy.

## 8.13 Important database constraints

- Unique normalized account identifiers where provided.
- Unique creator handles.
- Unique provider event IDs.
- Unique idempotency keys within the appropriate scope.
- Positive transaction amounts except where explicit ledger entry types support signed adjustments.
- Currency consistency within each balanced transaction.
- Foreign keys for all transactional relationships.
- No direct deletion of posted ledger entries.
- No contract activation without the required signed agreement.
- No creator monetization without required verification.
- No entitlement created from an unverified payment.
- No payout exceeding the eligible ledger-derived balance.
- No publication of restricted content without required moderation and rights checks.

---

# 9. API Design

## 9.1 API conventions

Base path: `/api/v1`

Use REST APIs for standard application operations and webhooks for provider events. Use a dedicated realtime transport for chat and livestream status when necessary.

Conventions:

- JSON requests and responses.
- Bearer access tokens or secure cookie-based sessions.
- Server-side authorization for every protected resource.
- Idempotency keys for checkout, refunds, and payouts where appropriate.
- Cursor pagination for large lists.
- Standardized error codes.
- Request IDs for support and audit correlation.
- Rate limiting.
- API versioning.
- OpenAPI specification and generated client types.

Example error:

`403 CONTENT_ACCESS_DENIED`

Do not expose private storage keys, internal identity details, or payment-provider secrets in responses.

## 9.2 Authentication APIs

| Method | Endpoint                       | Purpose                      |
| ------ | ------------------------------ | ---------------------------- |
| POST   | `/auth/register`               | Create account               |
| POST   | `/auth/login`                  | Authenticate                 |
| POST   | `/auth/logout`                 | End session                  |
| POST   | `/auth/refresh`                | Refresh session              |
| POST   | `/auth/verify-contact`         | Verify email or phone        |
| POST   | `/auth/resend-verification`    | Resend verification          |
| POST   | `/auth/password-reset/request` | Request password reset       |
| POST   | `/auth/password-reset/confirm` | Complete password reset      |
| GET    | `/auth/sessions`               | List current user's sessions |
| DELETE | `/auth/sessions/{id}`          | Revoke a session             |
| POST   | `/auth/mfa/enroll`             | Enroll MFA                   |
| POST   | `/auth/mfa/verify`             | Verify MFA                   |

## 9.3 Verification APIs

| Method | Endpoint                                       | Purpose                      |
| ------ | ---------------------------------------------- | ---------------------------- |
| POST   | `/verification/sessions`                       | Start verification           |
| GET    | `/verification/status`                         | Read own verification status |
| POST   | `/verification/provider-webhook`               | Receive provider events      |
| POST   | `/admin/verification/{id}/review`              | Authorized review            |
| POST   | `/admin/verification/{id}/request-information` | Request more information     |

Raw identity documents must not be exposed through ordinary user APIs.

## 9.4 Creator profile APIs

| Method | Endpoint                     | Purpose                      |
| ------ | ---------------------------- | ---------------------------- |
| GET    | `/creators/me`               | Read own creator profile     |
| PATCH  | `/creators/me`               | Update profile               |
| GET    | `/creators/{handle}`         | Read eligible public profile |
| POST   | `/creators/me/submit-review` | Submit onboarding            |
| GET    | `/creators/me/onboarding`    | Read onboarding status       |
| GET    | `/creators/me/analytics`     | Read authorized analytics    |
| GET    | `/creators/me/contracts`     | List own agreements          |

## 9.5 Contract APIs

| Method | Endpoint                                   | Purpose                           |
| ------ | ------------------------------------------ | --------------------------------- |
| GET    | `/contracts/offers`                        | Read current offers               |
| GET    | `/contracts/offers/{id}`                   | Read full offer                   |
| POST   | `/contracts/offers/{id}/sign`              | Sign eligible agreement           |
| POST   | `/contracts/offers/{id}/decline`           | Decline offer                     |
| GET    | `/contracts/{id}/document`                 | Download authorized document      |
| GET    | `/contracts/{id}/audit`                    | Read authorized signature history |
| GET    | `/admin/contracts/templates`               | List templates                    |
| POST   | `/admin/contracts/templates`               | Create template                   |
| POST   | `/admin/contracts/templates/{id}/versions` | Create a version                  |
| POST   | `/admin/contracts/versions/{id}/publish`   | Publish version                   |
| POST   | `/admin/contracts/{id}/amend`              | Create amendment                  |

Signature endpoints must validate the authenticated signer, offer status, document version, and any required signing intent.

## 9.6 Content APIs

| Method | Endpoint                               | Purpose                         |
| ------ | -------------------------------------- | ------------------------------- |
| POST   | `/media/upload-sessions`               | Create upload session           |
| POST   | `/media/upload-sessions/{id}/complete` | Complete upload                 |
| GET    | `/media/{id}/status`                   | Read processing status          |
| POST   | `/posts`                               | Create post                     |
| GET    | `/posts/{id}`                          | Read authorized post            |
| PATCH  | `/posts/{id}`                          | Edit own eligible post          |
| POST   | `/posts/{id}/publish`                  | Publish eligible post           |
| POST   | `/posts/{id}/unpublish`                | Unpublish                       |
| DELETE | `/posts/{id}`                          | Request deletion                |
| GET    | `/creators/{id}/posts`                 | List eligible posts             |
| GET    | `/media/{id}/access`                   | Resolve access for current user |

A media authorization response should return either a safe preview or a short-lived authorized delivery URL. It must never reveal the raw storage location to an unauthorized user.

## 9.7 Discovery APIs

| Method | Endpoint                | Purpose                        |
| ------ | ----------------------- | ------------------------------ |
| GET    | `/discovery/creators`   | Search eligible creators       |
| GET    | `/discovery/posts`      | Search eligible public content |
| GET    | `/discovery/categories` | List approved categories       |
| POST   | `/creators/{id}/follow` | Follow creator                 |
| DELETE | `/creators/{id}/follow` | Unfollow creator               |
| GET    | `/fans/me/following`    | List followed creators         |

## 9.8 Checkout and payment APIs

| Method | Endpoint                                 | Purpose                          |
| ------ | ---------------------------------------- | -------------------------------- |
| POST   | `/orders`                                | Create order                     |
| GET    | `/orders/{id}`                           | Read own order                   |
| POST   | `/orders/{id}/checkout`                  | Start checkout                   |
| GET    | `/payments/{id}`                         | Read own payment status          |
| POST   | `/payments/provider-webhooks/{provider}` | Receive verified provider events |
| GET    | `/fans/me/purchases`                     | List own purchases               |
| POST   | `/orders/{id}/refund-requests`           | Request refund                   |
| GET    | `/refunds/{id}`                          | Read refund status               |

Checkout requirements:

- Recalculate price on the server.
- Verify that the item is purchasable.
- Validate currency and provider compatibility.
- Apply the correct contract-specific commission.
- Record an idempotency key.
- Verify provider callbacks and reconcile status.
- Grant entitlement only when the transaction is eligible for access.
- Keep failed and pending transactions from being treated as successful purchases.

## 9.9 Subscription APIs

| Method | Endpoint                            | Purpose                     |
| ------ | ----------------------------------- | --------------------------- |
| GET    | `/creators/{id}/subscription-tiers` | List eligible tiers         |
| POST   | `/subscriptions`                    | Start subscription          |
| GET    | `/subscriptions/{id}`               | Read own subscription       |
| POST   | `/subscriptions/{id}/cancel`        | Cancel renewal              |
| POST   | `/subscriptions/{id}/change-tier`   | Change tier where supported |
| GET    | `/fans/me/subscriptions`            | List subscriptions          |

Recurring payment methods must be explicitly supported by the selected provider and disclosed to the fan.

## 9.10 Wallet and payout APIs

| Method | Endpoint                                  | Purpose                         |
| ------ | ----------------------------------------- | ------------------------------- |
| GET    | `/creators/me/earnings`                   | Read earnings summary           |
| GET    | `/creators/me/transactions`               | Read own transactions           |
| GET    | `/creators/me/payout-methods`             | List payout destinations        |
| POST   | `/creators/me/payout-methods`             | Add payout destination          |
| POST   | `/creators/me/payout-methods/{id}/verify` | Verify destination              |
| POST   | `/creators/me/payout-requests`            | Request payout                  |
| GET    | `/creators/me/payout-requests`            | List payout requests            |
| GET    | `/creators/me/statements`                 | Retrieve statements             |
| POST   | `/admin/payouts/{id}/approve`             | Approve payout                  |
| POST   | `/admin/payouts/{id}/reject`              | Reject payout with reason       |
| POST   | `/admin/payouts/{id}/submit`              | Submit approved payout          |
| POST   | `/admin/finance/reconcile`                | Start authorized reconciliation |

The client must never be allowed to set the creator's balance, net earnings, commission rate, or payout eligibility.

## 9.11 Messaging APIs

| Method | Endpoint                       | Purpose                       |
| ------ | ------------------------------ | ----------------------------- |
| GET    | `/conversations`               | List authorized conversations |
| POST   | `/conversations`               | Create conversation           |
| GET    | `/conversations/{id}/messages` | Read authorized messages      |
| POST   | `/conversations/{id}/messages` | Send message                  |
| POST   | `/messages/{id}/unlock`        | Purchase eligible attachment  |
| POST   | `/users/{id}/block`            | Block user                    |
| DELETE | `/users/{id}/block`            | Unblock user                  |

## 9.12 Moderation APIs

| Method | Endpoint                                | Purpose                    |
| ------ | --------------------------------------- | -------------------------- |
| POST   | `/reports`                              | Create report              |
| GET    | `/reports/{id}`                         | Read permitted case status |
| GET    | `/admin/moderation/cases`               | List authorized cases      |
| GET    | `/admin/moderation/cases/{id}`          | Read case                  |
| POST   | `/admin/moderation/cases/{id}/assign`   | Assign case                |
| POST   | `/admin/moderation/cases/{id}/actions`  | Record authorized action   |
| POST   | `/moderation/cases/{id}/appeals`        | Submit appeal              |
| POST   | `/admin/moderation/appeals/{id}/review` | Review appeal              |

## 9.13 Administrative APIs

- `GET /admin/dashboard`
- `GET /admin/users`
- `GET /admin/creators`
- `GET /admin/finance/transactions`
- `GET /admin/finance/reconciliation-exceptions`
- `GET /admin/audit-events`
- `GET /admin/roles`
- `POST /admin/roles/{id}/assign`
- `GET /admin/configuration`
- `PATCH /admin/configuration/{key}`

Every administrative endpoint requires explicit permission checks and audit logging.

---

# 10. Payment, Commission, Refund, and Payout Rules

## 10.1 Commission calculation

Default platform commission: 20% of eligible creator transaction revenue.

The exact base must be defined contractually. A proposed calculation for a transaction where commission applies to the pre-tax content amount is:

- Eligible transaction amount: KSh 1,000.
- Platform commission at 20%: KSh 200.
- Creator share before other deductions: KSh 800.

Payment processing charges, taxes, reserves, refunds, and chargebacks must be shown separately and allocated according to the creator agreement and applicable law.

Do not assume every payment method has the same processing costs.

For low-value items, the platform must account for fixed payment costs. A KSh 10 sale may have different unit economics from a KSh 1,000 sale. Configure minimum prices and consider prepaid balances or bundles only after reviewing payment-provider and regulatory requirements.

## 10.2 Double-entry accounting

Every posted transaction must balance.

Illustrative sale of KSh 1,000 before provider fees and taxes:

1. Record the payment asset or receivable.
2. Credit the creator payable for KSh 800.
3. Credit platform commission revenue for KSh 200.

When payment processing fees occur, record them separately and allocate them according to policy.

Use a clearing or receivable account where the payment provider settles at a different time than the customer authorization.

## 10.3 Payment states

Recommended states:

- `created`
- `requires_action`
- `processing`
- `succeeded`
- `failed`
- `cancelled`
- `expired`
- `reversed`
- `under_review`

Provider events must be authenticated and idempotently processed.

## 10.4 Refund workflow

1. Fan requests a refund or a qualifying event triggers a review.
2. System checks order, provider status, prior refunds, and applicable policy.
3. Refund is approved or rejected with a reason.
4. Provider refund is initiated.
5. The financial ledger records the adjustment.
6. Entitlement is updated according to the applicable policy.
7. Fan and creator receive appropriate status updates.
8. Reconciliation confirms the final result.

A refund must never erase the original purchase record.

## 10.5 Payout workflow

1. Creator requests an eligible amount.
2. Backend derives available earnings from the ledger.
3. Risk checks and destination verification run.
4. Required finance approvals are collected.
5. Payout is submitted to the provider.
6. Provider status is checked.
7. Settlement is reconciled.
8. Ledger and payout status are updated.
9. Creator receives a receipt or failure explanation.

Do not advertise instant payouts unless the provider, risk policy, and actual settlement process support them.

---

# 11. Security and Content Protection

## 11.1 Media security

- Use private object storage.
- Separate preview assets from original assets.
- Authorize every full-content request.
- Use short-lived signed URLs or authenticated streaming tokens.
- Avoid permanent public links to private media.
- Apply rate limits and abuse detection.
- Record suspicious access patterns.
- Support creator-specific and user-specific watermarking where appropriate.
- Restrict downloads unless explicitly permitted.

No technical control can guarantee that a recipient cannot screenshot or record content.

## 11.2 Authentication and authorization

- Strong password hashing.
- Secure session handling.
- MFA for staff.
- CSRF protection where cookie-based sessions are used.
- Rate limiting and bot detection.
- Secure account recovery.
- Server-side permission checks.
- Session revocation.
- Dependency and secret scanning.
- Security alerts for high-risk account changes.

## 11.3 Payment security

- Use tokenized provider integrations.
- Do not store card security codes.
- Minimize cardholder-data exposure.
- Confirm applicable PCI DSS obligations with the payment provider and a qualified assessor.
- Verify webhook signatures.
- Protect provider secrets.
- Enforce idempotency.
- Reconcile transactions and payouts.
- Detect suspicious purchasing and payout patterns.

## 11.4 Privacy

- Separate identity verification data from ordinary application data.
- Apply field-level encryption or provider-managed protected storage where appropriate.
- Restrict staff access to sensitive data.
- Define retention periods and deletion procedures.
- Support data-access and correction requests.
- Assess international data transfers.
- Maintain a breach-response process.
- Avoid collecting sensitive data that is not necessary.

---

# 12. Kenya and International Compliance Requirements

Legal review is a release dependency.

The platform must obtain advice on the business model and relevant laws before enabling production transactions or accepting adult content.

Areas requiring review:

1. Kenyan Data Protection Act, 2019 and associated regulations.
2. Registration obligations with the Office of the Data Protection Commissioner, where applicable.
3. Data protection impact assessment and processing of sensitive personal data.
4. Applicable Kenyan criminal and communications laws governing prohibited content.
5. Age assurance, identity verification, consent, and recordkeeping.
6. Electronic contracting and electronic signatures.
7. Payment services, stored-value products, and settlement arrangements.
8. Consumer protection, pricing transparency, subscriptions, and refunds.
9. Tax obligations for the platform and creators.
10. Cross-border data transfers and international payments.
11. Payment-provider and card-network adult-content restrictions.
12. App-store restrictions and distribution requirements.
13. Lawful requests, evidence preservation, and incident response.

A payment provider's technical API availability does not establish that it permits the business model. Obtain explicit provider approval before production use.

M-Pesa integration should use the appropriate approved Safaricom Daraja or commercial payment-provider route. International card processing should use a provider that expressly permits the platform's content category and supported jurisdictions.

The product must not launch in a country until eligibility, payment, privacy, content-policy, and legal requirements for that market are reviewed.

---

# 13. Technical Architecture and Infrastructure

## 13.1 Architecture

Start with a modular monolith and separate background workers.

Suggested modules:

- Identity and access.
- Creator onboarding.
- Contracts.
- Media and content.
- Discovery.
- Orders and payments.
- Financial ledger.
- Subscriptions.
- Messaging.
- Moderation.
- Notifications.
- Analytics.
- Administration.

The modules should have clear interfaces so that high-load functions, such as media processing and livestreaming, can be separated later.

## 13.2 Recommended stack

| Layer             | Technology                                             |
| ----------------- | ------------------------------------------------------ |
| Web               | Next.js, React, TypeScript                             |
| Mobile            | React Native, TypeScript                               |
| Backend           | NestJS or another mature typed backend framework       |
| Database          | PostgreSQL                                             |
| Cache             | Redis                                                  |
| Queue             | Managed durable queue or suitable queue infrastructure |
| Storage           | Private S3-compatible object storage                   |
| Media delivery    | CDN with authorization controls                        |
| Video processing  | Managed transcoding service initially                  |
| Livestreaming     | Managed streaming provider in Phase 2                  |
| API specification | OpenAPI                                                |
| Monitoring        | Centralized logs, metrics, tracing, error reporting    |
| Deployment        | Managed cloud services with infrastructure as code     |

## 13.3 Background jobs

Use asynchronous workers for:

- Media transcoding.
- Thumbnail generation.
- Upload validation.
- Moderation scans.
- Notifications.
- Provider event retries.
- Settlement reconciliation.
- Payout status checks.
- Analytics aggregation.
- Scheduled publishing.
- Data-retention jobs.

Jobs must be retryable and idempotent.

## 13.4 Environment strategy

Maintain separate:

- Local development.
- Automated testing.
- Staging.
- Production.

Production secrets and real payment credentials must never be used in local development or ordinary automated tests.

## 13.5 Disaster recovery

Define:

- Backup frequency.
- Recovery point objective.
- Recovery time objective.
- Backup encryption.
- Restoration tests.
- Provider outage procedures.
- Financial reconciliation recovery.
- Security incident procedures.

Test restoration before production launch.

---

# 14. Non-Functional Requirements

## Performance

- Standard API read requests: target p95 under 300 ms, excluding third-party provider latency.
- Standard application write requests: target p95 under 500 ms, excluding media uploads and external processing.
- Verified payment-to-entitlement update: target p95 under 5 seconds where provider callbacks arrive promptly.
- Support resumable uploads.
- Paginate large collections.
- Use CDN delivery for authorized media.

## Availability

- Target 99.9% monthly application availability after stabilization.
- Monitor dependencies separately.
- Gracefully handle provider outages.
- Never treat a payment timeout as proof of success or failure without status resolution.

## Accessibility

- Target WCAG 2.2 AA for applicable web interfaces.
- Support screen readers and keyboard navigation.
- Provide readable contrast and clear error states.
- Avoid relying solely on color to communicate status.

## Internationalization

- KES as the initial default.
- Store currency per transaction.
- Use locale-aware formatting.
- Support future language and currency expansion.
- Avoid assuming that all countries use the same payment, tax, or refund rules.

## Observability

Track:

- Request latency and error rates.
- Payment success and failure.
- Webhook delays and retries.
- Entitlement failures.
- Upload and transcoding failures.
- Payout exceptions.
- Reconciliation differences.
- Moderation queue age.
- Security events.

---

# 15. QA and Testing Strategy

## 15.1 Automated testing

### Unit tests

- Commission calculation.
- Price validation.
- Entitlement decisions.
- Subscription expiry.
- Refund accounting.
- Payout eligibility.
- Permission checks.
- Contract state transitions.

### Integration tests

- Payment-provider sandbox.
- Webhook authentication.
- Database transactions.
- Upload and media processing.
- Electronic-signature integration.
- Payout reconciliation.
- Notification delivery.

### End-to-end tests

1. Register a fan.
2. Complete required eligibility checks.
3. Register a creator.
4. Complete verification.
5. Sign the creator agreement.
6. Publish a paid item.
7. Complete a test payment.
8. Verify access.
9. Verify commission and ledger entries.
10. Request a payout.
11. Reconcile the payout.
12. Process a refund.
13. Verify access and financial adjustments.

### Security tests

- Attempt unauthorized access to paid media.
- Attempt access to another user's purchase history.
- Replay provider webhooks.
- Submit duplicate checkout requests.
- Change payout destinations without required verification.
- Attempt privilege escalation.
- Attempt unauthorized contract or commission changes.
- Test upload restrictions and abuse limits.

### Operational tests

- Provider outage.
- Delayed webhook.
- Duplicate webhook.
- Failed payout.
- Failed refund.
- Database restoration.
- Queue backlog.
- CDN authorization failure.
- High-volume upload.
- Urgent moderation escalation.

## 15.2 Launch blockers

Do not launch if any of these remain unresolved:

- Unverified payment can unlock paid content.
- Financial ledger can become inconsistent.
- Creator can monetize without required approval or signed agreement.
- Private content is publicly accessible.
- Sensitive identity data is available to unauthorized staff.
- Payouts can bypass required approval controls.
- Critical adult-safety or consent workflows are absent.
- Payment provider approval is missing.
- Critical security findings remain unresolved.

---

# 16. Development Milestones

The following is a planning estimate for a cross-functional team. It is not a guaranteed delivery schedule.

## Phase 0 — Discovery and feasibility

**Indicative duration:** 2–4 weeks.

Deliverables:

- Product scope.
- Screen inventory.
- User journeys.
- Technical architecture.
- Payment-provider feasibility.
- Compliance and legal review plan.
- Creator agreement draft.
- Content policy.
- Threat model.
- Initial backlog.

Exit criteria:

- Legal and commercial feasibility reviewed.
- Target payment route identified.
- Critical third-party dependencies understood.
- MVP requirements approved.

## Phase 1 — Design system and platform foundation

**Indicative duration:** 3–5 weeks.

Deliverables:

- Design system.
- Responsive web foundations.
- Mobile app shells.
- Authentication.
- Role and permission model.
- Database migrations.
- CI/CD.
- Logging and monitoring.
- Staging environment.

Exit criteria:

- Users can register and authenticate.
- Authorization is tested.
- Web and mobile use shared backend services.
- Environments and deployment process are operational.

## Phase 2 — Creator onboarding and contracts

**Indicative duration:** 3–5 weeks.

Deliverables:

- Verification-provider integration.
- Creator profile.
- Onboarding status.
- Payout setup.
- Contract templates.
- Electronic signatures.
- Contract versioning.
- Admin verification queues.

Exit criteria:

- A creator can complete the required onboarding.
- The exact executed contract is preserved.
- Unapproved creators cannot monetize.

## Phase 3 — Content studio and discovery

**Indicative duration:** 4–6 weeks.

Deliverables:

- Upload sessions.
- Media storage and processing.
- Creator content studio.
- Pricing and access rules.
- Public profile.
- Search and discovery.
- Content moderation pipeline.
- Protected media delivery.

Exit criteria:

- Creators can publish eligible free and paid items.
- Fans can discover public profiles.
- Unauthorized access to full content is blocked.
- Upload and moderation failures are recoverable.

## Phase 4 — Commerce and financial operations

**Indicative duration:** 4–7 weeks, partly parallelizable.

Deliverables:

- Orders.
- Checkout.
- Approved M-Pesa integration.
- Approved card integration.
- Payment webhooks.
- Entitlements.
- Commission calculation.
- Double-entry ledger.
- Refunds.
- Creator earnings.
- Payout processing.
- Settlement reconciliation.

Exit criteria:

- Complete sandbox purchase flow works.
- Duplicate callbacks cannot duplicate financial entries.
- Refund and payout accounting reconciles.
- Finance can investigate exceptions.

## Phase 5 — Mobile completion and launch readiness

**Indicative duration:** 4–6 weeks, overlapping earlier work.

Deliverables:

- Creator mobile flows.
- Fan mobile flows.
- Cross-platform entitlements.
- Push notifications.
- App security review.
- Accessibility review.
- Load testing.
- Incident-response runbooks.
- Production monitoring.
- Pilot support processes.

Exit criteria:

- Web and mobile share the same entitlements and financial state.
- Security and safety launch blockers are resolved.
- Production payment and support operations are ready.

## Phase 6 — Controlled pilot

**Indicative duration:** 2–4 weeks.

Deliverables:

- Limited creator cohort.
- Controlled fan onboarding.
- Production payment testing.
- Payout reconciliation.
- Support and moderation staffing.
- Bug triage.
- Unit economics review.

Exit criteria:

- Successful purchases and payouts.
- No unresolved critical security or financial defects.
- Operational capacity proven.
- Leadership approves broader rollout.

## Phase 7 — Livestreaming

**Indicative duration:** 4–8+ weeks after core commerce stabilization.

Deliverables:

- Streaming provider integration.
- Creator live studio.
- Viewer authorization.
- Ticketing.
- Tips.
- Chat moderation.
- Session accounting.
- Replay controls.
- Safety escalation.
- Network resilience testing.

Exit criteria:

- Only eligible viewers can join restricted streams.
- Live revenue reconciles.
- Moderators can intervene.
- Stream failure and refunds follow documented rules.

## Overall planning estimate

A production-oriented MVP with web and mobile, payment integration, contracts, moderation, and payout operations may require approximately 16–28 weeks or longer depending on team size, provider approvals, compliance work, and implementation complexity.

Livestreaming should be planned as a separate release rather than a launch dependency.

---

# 17. Team and Ownership

Suggested initial team:

| Role                     | Responsibility                                     |
| ------------------------ | -------------------------------------------------- |
| Product manager          | Requirements, prioritization, acceptance           |
| Product designer         | Research, design system, user flows                |
| Technical lead           | Architecture, technical quality, delivery          |
| Backend engineers        | APIs, payments, ledger, contracts                  |
| Web engineer             | Creator, fan, and admin portals                    |
| Mobile engineers         | Creator and fan applications                       |
| QA engineer              | Automated and manual testing                       |
| DevOps/security engineer | Infrastructure, monitoring, security               |
| Trust and safety lead    | Policies, moderation operations, incident response |
| Legal/compliance advisor | Contracts, privacy, payments, jurisdiction review  |
| Finance operations owner | Reconciliation, refunds, payout controls           |

Some roles may be combined in a small team, but payment integrity, security, and adult-content safety must have explicit ownership.

---

# 18. Risks and Mitigations

| Risk                                            | Mitigation                                                                               |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Payment provider refuses adult-content business | Obtain written approval before committing to production integration                      |
| App-store restrictions                          | Confirm distribution policies early and maintain a compliant web experience              |
| Creator identity fraud                          | Use approved verification providers and risk-based re-verification                       |
| Non-consensual content                          | Consent and rights controls, reporting, rapid escalation, and removal workflows          |
| Payment fraud                                   | Idempotency, risk checks, settlement reconciliation, payout holds                        |
| Content leaks                                   | Access-controlled delivery, watermarking, incident response, realistic protection claims |
| Microtransaction losses                         | Model provider fees and configure minimum prices or bundles                              |
| Contract disputes                               | Versioned agreements, clear terms, reliable signature evidence                           |
| Staff misuse of sensitive data                  | Least privilege, access logs, approval workflows                                         |
| Data breach                                     | Encryption, isolation, monitoring, retention limits, response plans                      |
| Regulatory changes                              | Market-by-market legal review and configurable eligibility                               |
| Creator dissatisfaction                         | Transparent fees, timely payouts, appeal processes, creator feedback                     |
| Operational overload                            | Controlled pilot, staffed safety queue, defined SLAs                                     |

---

# 19. Launch Checklist

## Product

- Registration and authentication work.
- Creator onboarding and profile work.
- Creator contracts are signed and retrievable.
- Uploads, processing, publishing, and access rules work.
- Fans can buy individual items.
- Subscription cancellation works.
- Web and mobile entitlements remain consistent.

## Payments

- Provider approval confirmed.
- Checkout totals are accurate.
- Webhooks are verified.
- Idempotency is tested.
- Financial ledger balances.
- Refunds and chargebacks are accounted for.
- Payouts are verified and reconciled.
- Finance has exception-handling procedures.

## Safety and privacy

- Adult eligibility and identity verification are operational.
- Consent and rights controls are active.
- Prohibited-content rules are published.
- Moderation queues are staffed.
- Urgent incident procedures are tested.
- Identity records are access-restricted.
- Account deletion and privacy requests are supported.
- Staff access is audited.

## Engineering

- Production monitoring is active.
- Backup restoration has been tested.
- Critical security issues are resolved.
- Load and failure testing is complete.
- Deployment rollback is tested.
- Support and incident runbooks are approved.

---

# 20. Final Product Recommendation

Build the product around five dependable capabilities:

1. **Creator onboarding and contracts:** Verify eligible creators, capture agreement evidence, and enforce the applicable commission terms.
2. **Flexible content commerce:** Allow individual purchases, subscriptions, bundles, and other approved monetization models.
3. **Reliable financial operations:** Use a proper ledger, verified payment events, transparent deductions, refunds, and reconciled payouts.
4. **Secure cross-platform access:** Ensure the same content permissions apply across mobile and web, without exposing private media.
5. **Trust and safety:** Build age assurance, consent, privacy, moderation, appeals, and incident response into the core platform.

The competitive advantage should not be merely a larger feature list. It should be a more dependable creator business: flexible pricing, understandable fees, predictable earnings, creator control, and trustworthy operations.

**Recommended next deliverable:** turn this PRD into an implementation backlog with epics, prioritized tickets, API request/response contracts, SQL migrations, detailed state machines, and acceptance tests. That will provide the development team with a concrete execution plan rather than only a product vision.

## What I would do next

I would turn this specification into a development-ready package in this order:

1. UX/UI specification — every mobile and web screen, including loading, empty, error, restricted, and success states.
2. Database implementation — PostgreSQL migrations, indexes, constraints, and financial ledger rules.
3. API contract — OpenAPI specification with request and response schemas.
4. Development backlog — epics and implementation tickets, prioritized by dependency and launch criticality.
5. Release plan — test cases, security gates, provider integration checklist, and production acceptance criteria.

One important business decision should happen before substantial coding: obtain written confirmation that the chosen payment providers and intended app distribution channels permit your specific business model. This can materially affect the architecture, checkout experience, and launch strategy.