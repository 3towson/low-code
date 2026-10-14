# Apple App Store Review Notes (Guideline 5.1.1(viii) Compliance)
## App: COD Risk Shield

> **Instructions for Submitter:** Copy the content below into the **"App Review Information — Notes"** field in Apple App Store Connect when submitting the app for review.

---

### App Review Information: Notes for the Reviewer

**Dear Apple App Review Team,**

Thank you for reviewing **COD Risk Shield**.

We would like to proactively provide technical and operational details regarding how our app strictly complies with **App Store Review Guideline 5.1.1(viii)** (*Data Collection and Storage — Compiling Personal Information*), Privacy Best Practices, and data minimization standards.

---

### 1. Purpose of the Application (Fraud Prevention)
In Southeast Asia, **Cash on Delivery (COD)** is a predominant payment method for independent online merchants. However, sellers face severe fraud and financial losses from fraudulent orders, fake addresses, and intentional parcel refusals (incurring double logistics fees and lost perishable goods).

COD Risk Shield is a risk-mitigation tool designed exclusively to help verified merchants evaluate COD delivery risks before dispatching goods.

---

### 2. Strict Compliance with Guideline 5.1.1(viii) & Data Minimization

To respect the privacy of end-consumers and avoid accumulating personal information, the application implements the following architecture:

#### A. Zero Storage of Raw Phone Numbers (One-Way Cryptographic Hashing)
- The app **NEVER stores actual customer phone numbers** in the database.
- When an order is checked or reported, the phone number is processed ephemerally on a secure serverless Edge Function and immediately converted into an irreversible **HMAC-SHA256 cryptographic hash using a server-side secret key** (`phone_hash`).
- Only this irreversible hash is queried or referenced. Neither the system administrators nor other merchants can ever reverse the hash to recover the real phone number.

#### B. Zero Storage of Customer Names
- As of version 1.1.0, the app **does NOT store end-customer names** in the reporting database (`customer_name` is NULL in all database records).
- All risk assessments are evaluated solely on aggregate statistical occurrences of the irreversible hash.

#### C. Strict KYC Requirement for Reporting Merchants
- Merchants cannot report any customer anonymously.
- A merchant must complete a **Merchant KYC Verification** (verifying business existence, legitimate shop URL, and business contact) before they are permitted to submit any report.
- Unverified merchants are blocked from reporting.

#### D. Administrator Moderation (No Direct Public UGC)
- Reports submitted by merchants are **NOT published immediately**.
- Every report is held in a `pending` state and requires manual review by an administrator who inspects the uploaded transaction/order evidence before the report can contribute to the risk score.

#### E. Automatic Data Expiration & Retention
- Reports contribute to risk evaluation only within a **12-month rolling window**. Older records expire automatically and do not impact risk scores.
- Evidence images are permanently deleted from secure storage after **12 months**, and report rows in the database are permanently purged after **24 months** via automated daily background jobs.

---

### 3. Customer Dispute & Data Subject Rights (Dispute Portal)

We respect the rights of data subjects and provide transparent, accessible channels for end-consumers to dispute reports or request deletion:

1. **Public Dispute Portal:**
   Any individual can submit a dispute or request data erasure directly via our web portal:
   👉 **https://3towson.github.io/low-code/dispute.html**
   - No app download or account creation required.
   - Allows phone owners to report identity theft, incorrect reports, or exercise their Right to Erasure under PDPA / privacy regulations.
   - Dedicated dispute SLA: investigated and resolved by administrators within 3 business days.

2. **Dedicated Privacy & Dispute Email:**
   - `codriskshield.support@gmail.com`

3. **Public Privacy Policy:**
   👉 **https://3towson.github.io/low-code/privacy-policy.html**

4. **Account Deletion (Guideline 5.1.1(v)):**
   - In-app via Settings Dialog
   - Web URL: **https://3towson.github.io/low-code/delete-account.html**

---

### 4. Demo Accounts for Review
To assist with your testing, please use the following pre-configured credentials (please provide the actual password securely in App Store Connect "Sign-In Information" fields; do not commit passwords to source control):

1. **Verified Merchant Account (KYC Approved):**
   - **Email:** `reviewer_approved@codcheck.app`
   - **Password:** [Enter the reviewer password configured in App Store Connect]
   - **Role:** Approved Merchant
   - **Purpose:** Test core features immediately: check customer COD delivery risk, view statistics, and submit problematic customer reports with photo evidence.

2. **New Merchant Account (Unverified / KYC Pending):**
   - **Email:** `reviewer_unverified@codcheck.app`
   - **Password:** [Enter the reviewer password configured in App Store Connect]
   - **Role:** Unverified Merchant
   - **Purpose:** Experience the Merchant KYC Verification workflow. When tapping the report button, this account will be prompted to submit shop verification documents before reporting is unlocked.

*(Note: Administrator moderation workflows are demonstrated via attached demo video if requested, in accordance with zero-trust security best practices.)*

---

### 5. Authentication & Email Verification URLs
- **Site URL (Email Confirmation Landing):** `https://3towson.github.io/low-code/email-verified.html`
- **Password Reset URL:** `https://3towson.github.io/low-code/reset-password.html`

If you require any further technical clarifications or demonstration, please do not hesitate to contact us.

Warm regards,  
**COD Risk Shield Team**  
codriskshield.support@gmail.com

