# App Review response — draft, not sent

Submission: `86deeeed-7156-484d-aa26-e3ee81a1b1a5`
App: 글링 - 캐나다 한인 커뮤니티, 1.0.0 (9)
Issue: Guideline 2.1 — Information Needed — New App Submission

**Pending before submission:** capture and inspect the physical-device video, record the exact model/OS/build and attachment name below, and obtain approval to send the completed response. Do not describe simulator footage as physical-device footage.

---

Hello App Review Team,

Thank you for your guidance. Below is the requested information about Gling.

## 1. Physical-device demonstration

VIDEO PENDING — complete this section after recording and verification.

The recording must start with launching the submitted app and demonstrate ordinary registration/onboarding, login, feed browsing, posting and comments, direct conversations and group meetups, reporting, blocking, and account deletion. Record the Membership screen as it actually appears in this build. The submitted build currently has no paid products available for purchase.

Device: iPhone X (owner-selected physical device)
iOS version: PENDING recording verification; connected device currently reports 16.7.14 (20H370). Check supported updates before capture.
App version/build: 1.0.0 (9), verify on device
Recording/attachment: PENDING
Flow timestamps and physical-device QA result: PENDING

Before sending, state the actual OS and clarify that this is an iPhone X recording. Do not claim it demonstrates the current iOS 26 release or that App Review has accepted the device's latest supported OS as satisfying its latest-OS request.

## 2. Purpose and audience

Gling is a Korean-language local community app for people living in or preparing to move to Vancouver and Toronto, Canada, including residents, newcomers and students. It helps people find relevant local information and make local connections through a city-based feed, photos, comments, group meetups and consent-based direct conversations. Topics include daily life, food, travel, shopping, settlement, transportation, housing and education. It is a public consumer community, not an app restricted to a particular business or organization.

## 3. Setup and access to main features

No sample files, payment, Canadian phone number, device location permission or physical presence in Canada are required. Choose Vancouver or Toronto manually; the public feed can be read without an account.

For review, tap the person icon at the top-right beside Search, select "심사용 계정 로그인 / Review access", and use the existing username and password in the App Review Information fields. Tap "심사 계정으로 로그인 / Sign in". This account has ordinary member permissions and uses the same app features and server rules as other members. It has no admin privileges or special content access.

For ordinary account creation, use Kakao sign-in or native Sign in with Apple on iOS. A new member completes the nickname/city profile and accepts the terms, privacy policy and external AI safety-processing disclosure. Public email registration is not offered; the review login accepts only pre-authorized review accounts.

The bottom tabs are Today, Meetups, Write, Chat and Notifications. Open a post for comments and its reporting/blocking controls. Direct conversations require recipient acceptance before either person can send a message. Group membership requires host approval; accepted members can open the shared group conversation. The free membership allows one post per day, three group slots and three separate direct-conversation slots. Ending a direct conversation applies a 24-hour slot cooldown to the original requester; the recipient recovers their slot immediately. Voluntarily leaving a group applies a 24-hour group-slot cooldown.

Account deletion is in Profile > Settings > Delete account, with confirmation steps. Apple-linked accounts reauthorize before revocation and deletion. The video should use a separate disposable account for deletion so the supplied review account stays available.

Seeded posts/authors provide initial community content and are not claims of existing customer activity. Plus and Premium plan information is visible, but the subscription products are not currently available for purchase. Credits, credit packs and paid post promotion are not exposed in this release. No advertising is currently served.

## 4. External services and tools

- Supabase: authentication/session management, PostgreSQL data storage, uploaded photo storage, realtime community/chat updates and server-side Edge Functions.
- Kakao: OAuth account authentication. The iOS browser authentication session begins on our owned gling.ej-entertainment.com page and then forwards to the existing Supabase/Kakao authorization flow.
- Apple: native Sign in with Apple. Apple TestFlight is used to distribute the submitted beta build.
- OpenAI API: server-side safety classification of new posts, comments and private/group messages, plus optional photo-assisted draft writing. Users are shown the external AI processing disclosure before account participation. Automatic analysis prioritizes content for authorized human review; permanent bans are not decided solely by AI. Conversations are not represented as end-to-end encrypted. Authorized administrator access is audited.
- RevenueCat and Apple's StoreKit: integrated subscription and entitlement infrastructure. No paid product is currently for sale in this submission; credit/boost purchases are unavailable.
- GitHub Pages: hosts public support/legal/share pages and the branded login entry page. Cloudflare supplies domain/DNS and email-forwarding infrastructure.
- Resend: the server implementation uses it for operator safety-alert emails when configured. It is not a user messaging or advertising feature.
- Expo / React Native: mobile application framework.

## 5. Regional behavior

The iOS app uses the same functionality, login options, membership rules and safety controls across supported regions. Content is organized by the city the user selects. Vancouver and Toronto are open; other listed cities are marked as coming soon. The city choice is manual and is not a device GPS/geofence check. The app's interface and initial content are in Korean. There are no regional purchases or region-specific paid features in this build.

## 6. Regulated services and third-party material

Gling is a community platform and does not itself provide regulated medical, financial, gambling or professional services. Members may discuss local housing or jobs, but the app does not process rent, escrow or marketplace transaction payments.

The app does not depend on a licensed third-party media catalog, broadcast content or professional-service credentials. User-submitted content is subject to the community rules and reporting/moderation process. One seeded Vancouver image is attributed in its post to Vlad D on Unsplash (photo reference: https://unsplash.com/photos/19aJ-K6fUmY). The general Unsplash license is available at https://unsplash.com/license. The source attribution is retained in the post and our seed-content migration.

Support: https://gling.ej-entertainment.com
Privacy: https://gling.ej-entertainment.com/privacy
Terms: https://gling.ej-entertainment.com/terms
