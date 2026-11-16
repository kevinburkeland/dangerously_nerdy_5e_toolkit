# Privacy Policy

**Last Updated:** November 15, 2026

**DangerouslyNerdy 5e Toolkit** ("we", "us", "our", or the "Application") is committed to protecting user privacy. This Privacy Policy explains how data is handled when you access and use our web application.

---

## 1. Overview & Data Minimization Principle
DangerouslyNerdy 5e Toolkit is designed around the principle of strict data minimization. We **do not** require user registration, account creation, passwords, or personal identifying information (PII) to access any feature of the application.

---

## 2. Information We Handle

### A. On your device
- **What is stored:** your campaigns, characters, homebrew content, map images, dice presets and app settings.
- **Where:** only in your browser's storage on your device (IndexedDB and LocalStorage on the web; the app's own storage on Android).
- **Transmission:** this data only leaves your device when you share it in a room (section B).

### B. Shared rooms (Google Firebase Cloud Firestore)
When you create or join a room, the app uses Cloud Firestore to keep the room working:
- **The room record:** the room code, campaign name, the ruleset, a one-way hash of the DM's host key, who is present, and summaries of the characters players choose to share.
- **Connection setup:** short messages that let devices connect to each other directly (WebRTC).
- **Relay:** if two devices can't connect directly, campaign updates are relayed through Firestore instead.
- **Party records:** the shared loot list, the party event log and dice rolls.

Map images are sent directly between devices and are never stored in Firestore. Anyone who has a room's code can read that room's records, so share codes only with your group. There are no accounts, and nothing in a room is linked to your identity unless you type it in (for example as a character or display name).

**How long it is kept:** relay messages carry an expiry time one hour after they are sent, and dice rolls 24 hours after. Room records, the loot list and the event log are not deleted automatically today.

### C. Analytics & Tracking Cookies
- **No Tracking Cookies:** We **do not** use tracking cookies, advertising IDs, or cross-site tracking technologies.
- **No Third-Party Ad Networks:** We do not partner with or serve third-party advertisements.
- **Crash reports (Android app only):** if the Android app crashes or hits an error, the error details and basic device information are sent to Google Firebase Crashlytics. The web app sends no crash reports.

---

## 3. Global Privacy Regulation Compliance

### A. EU / UK General Data Protection Regulation (GDPR)
- **Legal Basis for Processing:** Processing of shared room records is strictly based on contractual necessity to fulfill your request to join a shared room (Art. 6(1)(b) GDPR).
- **Data Subject Rights:** Because we do not collect personal identifiers, emails, or user accounts, we do not store identifiable personal data. You retain total control over your local browser data and can erase all local presets at any time by clearing your browser cache.

### B. California Consumer Privacy Act (CCPA / CPRA)
- **Do Not Sell or Share Personal Information:** We **do not sell** or share personal information with third parties for monetary or other valuable consideration.
- **Right to Delete:** Users may clear their local browser storage at any time to delete locally stored custom presets.

---

## 4. Third-Party Infrastructure Services
- **Google Firebase / Cloud Firestore:** stores the shared room records described in section 2B. Data is encrypted in transit.
- **Google Firebase Crashlytics (Android app only):** receives crash reports as described in section 2C.

Firestore collections used: `rooms`, `hostProof`, `nodes`, `signals`, `signaling`, `relay_messages`, `loot`, `events`, `rolls`.

---

## 5. Security
We implement industry-standard encryption protocols (HTTPS, TLS) to protect data in transit. However, no internet transmission is 100% secure, and users participate in shared public room feeds at their own risk.

---

## 6. Changes to This Privacy Policy
We may update this Privacy Policy periodically. The "Last Updated" timestamp at the top of this document indicates the effective date of any modifications.

---

## 7. Contact Information
For privacy inquiries or technical questions regarding this policy, please open an issue in the official application source repository or contact the maintainer at `kevin@burke.land`.
