# Getting Wander onto the App Store

A step-by-step guide for releasing Wander v1 on iPhone. It's written for a
solo developer on a Mac, exporting from Godot 4.6. Do the steps in order.
Rough timings are in brackets. Last checked 28 November 2026.

---

## 0. Before you start: what's already done in the project

These were checked and fixed in the code, so you don't need to redo them.

- **No accounts, no server.** Everything stays on the device. Friends and
  "where you study" are gone for v1. The create account screen only asks
  for a name, plus an optional birthday.
- **No age gate.** Nothing leaves the device, so no parent approval is
  needed. The old under-18 popup was removed.
- **Data controls.** Settings, Data lists what's kept, downloads it as JSON
  (into Files, On My iPhone, Wander) and deletes the account. This covers
  Apple's "delete your account in the app" rule (guideline 5.1.1(v)).
- **Privacy manifest.** Godot writes `PrivacyInfo.xcprivacy` from the
  export preset. No tracking, no tracking domains, and Godot's own
  "required reason" APIs are declared.
- **Encryption.** `ITSAppUsesNonExemptEncryption = NO` is in the plist. The
  app only uses HTTPS, so you skip the export compliance question.
- **Version.** 1.0.0, build 1 (`export_presets.cfg` and `project.godot`).
- **Bundle ID.** `com.joerobson22.wander` (it used to say pawsandprogress).
- **iPhone only, portrait.** No iPad build, so no iPad screenshots needed.
- **No location permission.** The optional "Local sunrise and weather"
  uses your rough location from your internet address (GeoJS), not GPS.
  So iOS never shows a location prompt and no usage string is needed.
- **Debug tools.** The debug bar, phone view and time buttons only exist in
  debug builds. A release export never shows them.
- **Icons and launch screen.** The 1024px app icon (light and dark) and
  the boot splash are set. Godot makes every other size.

## 1. Things only you can fix first (blockers)

Apple rejects apps with placeholder content (guideline 2.1 and 2.3). Fix
these before you submit.

1. **Fill in `legal/business.json`.** Your real email address, a postal
   address you're happy to publish, and a website. The privacy policy
   shows these. `hello@example.com` and `example.com` will be rejected.
2. **Rename the placeholder gifts.** 71 gifts in `data/gifts.json` say
   "A placeholder for Joe to rename." Search for that line and replace it.
3. **Put the privacy policy on a web page.** App Store Connect needs a
   public URL. Paste `legal/privacy_policy.md` (with your details filled
   in) into any free page: GitHub Pages, Notion or Carrd all work.
4. **A support URL.** Also required. The same site works, with a contact
   email on it.
5. **Sound licences.** `legal/LICENSES.md` still asks where the 12 mp3s in
   `assets/sounds` came from. Only ship sounds you made or may use.
6. **Open-Meteo.** Its free weather API is for non-commercial use. A free
   app with no adverts or purchases is fine. If you later add the
   Supporter Pack, buy an Open-Meteo plan or turn weather off.

## 2. Join the Apple Developer Program (1 to 2 days)

1. On your iPhone, check your Apple Account has **two-factor
   authentication** on (Settings, your name, Sign-In & Security).
2. Download the **Apple Developer** app on the iPhone or Mac.
3. Open it, sign in, tap **Enroll now** and choose **Individual / Sole
   Proprietor**. You'll scan your photo ID.
   - As an individual, your own name shows as the seller on the store.
   - If you'd rather show a company name, you need a company with a
     D-U-N-S number first. That takes weeks, so skip it for v1.
4. Pay the fee (£79 / $99 a year).
5. Wait for the "Welcome to the Apple Developer Program" email.

## 3. Set up your Mac (about an hour)

1. Update macOS, then install **Xcode 26 or newer** from the Mac App Store.
   Since 28 April 2026, Apple only accepts uploads built with the iOS 26
   SDK, which comes with Xcode 26.
2. Open Xcode once and let it install its extra parts. When it asks which
   platforms, tick **iOS**.
3. Xcode, Settings, **Accounts**, **+**, Apple Account. Sign in with your
   developer account. Your team appears as "Joe Robson (Personal Team)"
   or similar.
4. In that same window, select the team and click **Manage
   Certificates**, **+**, **Apple Distribution**. Also add an **Apple
   Development** one if it isn't there.
5. In Godot: **Editor, Manage Export Templates**, then download 4.6.3. The
   iOS template is inside it.

## 4. Find your Team ID and register the App ID (10 minutes)

1. Go to developer.apple.com, **Account**, **Membership details**. Copy
   your **Team ID** (10 letters and numbers).
2. Go to **Certificates, IDs & Profiles**, **Identifiers**, **+**.
3. Choose **App IDs**, then **App**.
4. Description: `Wander`. Bundle ID: **Explicit**,
   `com.joerobson22.wander`.
5. Leave every capability off. Wander needs none. Click **Register**.

You don't need to make a provisioning profile by hand. Xcode's automatic
signing makes one for you in step 7.

## 5. Make the App Store Connect record (20 minutes)

1. Go to appstoreconnect.apple.com, **Apps**, **+**, **New App**.
2. Platform **iOS**. Name **Wander** (if it's taken, try "Wander: Focus
   Walks" or similar). Primary language **English (U.K.)**. Bundle ID
   `com.joerobson22.wander`. SKU: anything, such as `wander-ios-1`. User
   access: **Full Access**.
3. **App Information** (left menu):
   - Subtitle (30 characters), for example "Focus with a walking buddy".
   - Category: **Productivity**. Secondary: **Education** (optional).
   - **Content Rights**: "No, it does not contain third-party content"
     (once the sound question in step 1 is settled).
   - **Age Rating**: answer the questionnaire. For Wander every answer is
     "None" or "No": no violence, no user-generated content, no chat, no
     web browsing, no gambling, no purchases. It should come out **4+**.
   - **Digital Services Act** (EU): declare whether you're a "trader". An
     app that makes no money, made as a hobby, is usually "not a trader".
     If you choose trader, your address and phone are shown publicly.
4. **Pricing and Availability**: price **Free**. Pick countries (all is
   fine).
5. **App Privacy**:
   - Privacy Policy URL: your page from step 1.
   - **Get Started**, then "Do you or your third-party partners collect
     data from this app?" Answer **No, we do not collect data from this
     app**. Nothing is stored off the device. The optional weather lookup
     only sends the device's internet address to GeoJS and Open-Meteo to
     answer that one request, which Apple doesn't count as collection.
   - Publish it. The label will read **Data Not Collected**.

## 6. Export from Godot (10 minutes)

1. Open the project in Godot 4.6.3. **Project, Export**, select **iOS**.
2. **Application, App Store Team ID**: paste your Team ID. It says
   `AAAAAA` until you do.
3. Check the **Export Path**. It's set to
   `../../Exports/Wander/v2.1/ios/Wander.xcodeproj`. Change the folder if
   you like.
4. Leave **Export Project Only** ticked. Xcode signs and uploads.
5. Click **Export Project**, untick **Export With Debug**, and save.

Each new upload needs a higher build number. Next time, set **Application,
Version** to 2, then 3, and so on. Change **Short Version** (1.0.0) only
for a new release people will see.

## 7. Archive and upload from Xcode (20 minutes, plus processing)

1. Open the exported `Wander.xcodeproj` in Xcode.
2. Click the blue project icon at the top of the left panel, then the
   **Wander** target, then **Signing & Capabilities**.
3. Tick **Automatically manage signing**. Pick your **Team**. Xcode makes
   the profile. Fix any red errors it shows (usually just the team).
4. Plug in your iPhone and press **Run** (the play button) once. This
   checks the build works on a real device. On the phone, allow
   **Developer Mode** if asked (Settings, Privacy & Security).
5. In the device menu at the top, choose **Any iOS Device (arm64)**.
6. **Product, Archive**. When it finishes, the **Organizer** opens.
7. Select the archive, then **Distribute App**, **App Store Connect**,
   **Upload**. Keep the default ticks (upload symbols, manage version).
8. Wait for the "has completed processing" email (10 to 60 minutes).

If the upload fails with "Invalid Bundle" or a missing icon, check step 6
was a release export, and that you used Xcode 26.

## 8. Test with TestFlight (a day or two)

1. In App Store Connect, open Wander, then **TestFlight**. Your build is
   listed.
2. **Internal Testing**, **+**, make a group, add yourself. Internal
   testers need no review.
3. Install **TestFlight** on your iPhone, accept the invite and install
   Wander.
4. Go through the whole app on the phone. Pay attention to:
   - Create account: the **Done** bar over the keyboard, and the keyboard
     closing after the year's fourth digit.
   - A full walk with a small pet and with a big one you ride.
   - Settings, Data: Download, then Delete.
   - Closing the app mid-walk and reopening it.
5. Optional: add friends as **External Testers**. The first external build
   needs a short beta review (about a day).

## 9. Screenshots (an hour)

Apple builds every iPhone size from the largest set, so you only need one.

- **6.9-inch display**: 1320 x 2868 pixels portrait (1290 x 2796 is also
  accepted). PNG or JPEG, no transparency.
- 3 to 10 screenshots. Five good ones is plenty: home, a walk, riding a
  big animal, gifts, stats.
- The easiest way: run the TestFlight build on the **iPhone 17 Pro Max
  simulator** in Xcode (Xcode, Open Developer Tool, Simulator) and press
  Cmd+S. The simulator saves at exactly the right size.
- Optional: a short **App Preview** video (15 to 30 seconds), recorded the
  same way with File, Record Screen.

## 10. Fill in the version page

In App Store Connect, open the **1.0 Prepare for Submission** page.

1. Upload the screenshots.
2. **Promotional text** (170 characters, can change any time).
3. **Description**: what Wander is, in plain words. No prices and no other
   platforms' names.
4. **Keywords** (100 characters, comma separated, no spaces after commas):
   for example `focus,study,pomodoro,timer,productivity,walk,pets,animals`.
5. **Support URL** and **Marketing URL** (optional).
6. **Build**: click **+** and pick the TestFlight build.
7. **Copyright**: `2026 Joe Robson`.
8. **App Review Information**: your name, email and phone. **Sign-in
   required**: untick (there's no login). In **Notes**, write something
   like: "All data stays on the device. Make an account with any name.
   Tap the orb to start a focus walk; gifts appear after 10 minutes."
9. **Version Release**: "Manually release" lets you pick the day.

## 11. Submit for review

1. Click **Add for Review**, then **Submit to App Review**.
2. Reviews usually take 1 to 2 days. You'll get emails as the status moves
   through "Waiting for Review", "In Review" and "Pending Developer
   Release" (or "Ready for Distribution").
3. If it's rejected, the message in **App Review** says which guideline.
   Fix it, upload a new build (higher build number) and reply there.
4. Once approved, press **Release This Version**. It shows on the store
   within a day.

## Common reasons a first app gets rejected

| Guideline | What to check |
| --- | --- |
| 2.1 Completeness | No "placeholder" text, no crashes, all links work |
| 2.3 Accurate metadata | Screenshots show the real app, not mock-ups |
| 4.2 Minimum functionality | Fine: Wander is a full app, not a website |
| 5.1.1 Privacy | Policy URL works and matches the app; Delete is in Settings, Data |
| 5.1.1(v) Account deletion | Settings, Data, Delete |
| 3.1 Payments | Only if you add the Supporter Pack: it must use In-App Purchase |

## After launch

- Each update: raise the build number, export, archive, upload, then
  submit the new version the same way.
- Before friends or online accounts come back, redo the privacy label, the
  age rating and the policy (see `legal/DATA.md`).
