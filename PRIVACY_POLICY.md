# Privacy Policy

**Last Updated:** August 14, 2026

**DangerouslyNerdy 5e Toolkit** ("we", "us", "our", or the "Application") is committed to protecting user privacy. This Privacy Policy explains how data is handled when you access and use our web application.

---

## 1. Overview & Data Minimization Principle
DangerouslyNerdy 5e Toolkit is designed around the principle of strict data minimization. We **do not** require user registration, account creation, passwords, or personal identifying information (PII) to access any feature of the application.

---

## 2. Information We Handle

### A. Local Device Storage (`LocalStorage` / `SharedPreferences`)
- **What is stored:** Custom dice formulas, user-saved presets, theme preferences (light/dark/OLED mode and accent colors), and haptic/3D animation settings.
- **Where it is stored:** Exclusively on your local browser/device cache via web `LocalStorage` or platform-native `SharedPreferences`.
- **Transmission:** This data is **never** transmitted to our servers or any third-party tracking services.

### B. Ephemeral Real-Time Room Payloads (Firebase Firestore)
- **What is processed:** Temporary 6-character room codes (e.g., `ROOM-ABC123`), optional display names chosen for session feeds, and raw roll mathematical outcomes (e.g., `2d20 + 5`).
- **Purpose:** To synchronize live dice roll results between players participating in the same shared session room.
- **Lifespan & Destruction:** Room feeds are ephemeral real-time streams. Payloads are temporary and automatically expire or are overwritten. No persistent player profiles or historical cross-session telemetry are linked to your room activity.

### C. Analytics & Tracking Cookies
- **No Tracking Cookies:** We **do not** use tracking cookies, advertising IDs, or cross-site tracking technologies.
- **No Third-Party Ad Networks:** We do not partner with or serve third-party advertisements.

---

## 3. Global Privacy Regulation Compliance

### A. EU / UK General Data Protection Regulation (GDPR)
- **Legal Basis for Processing:** Processing of real-time room roll payloads is strictly based on contractual necessity to fulfill your request to join a shared room stream (Art. 6(1)(b) GDPR).
- **Data Subject Rights:** Because we do not collect personal identifiers, emails, or user accounts, we do not store identifiable personal data. You retain total control over your local browser data and can erase all local presets at any time by clearing your browser cache.

### B. California Consumer Privacy Act (CCPA / CPRA)
- **Do Not Sell or Share Personal Information:** We **do not sell** or share personal information with third parties for monetary or other valuable consideration.
- **Right to Delete:** Users may clear their local browser storage at any time to delete locally stored custom presets.

---

## 4. Third-Party Infrastructure Services
Our application utilizes the following essential cloud infrastructure provider:
- **Google Firebase / Cloud Firestore:** Operates as a backend real-time database infrastructure provider for multi-user session roll streaming. Data transmission is encrypted in transit using TLS 1.3.

---

## 5. Security
We implement industry-standard encryption protocols (HTTPS, TLS) to protect data in transit. However, no internet transmission is 100% secure, and users participate in shared public room feeds at their own risk.

---

## 6. Changes to This Privacy Policy
We may update this Privacy Policy periodically. The "Last Updated" timestamp at the top of this document indicates the effective date of any modifications.

---

## 7. Contact Information
For privacy inquiries or technical questions regarding this policy, please open an issue in the official application source repository or contact the maintainer at `kevin@burke.land`.
