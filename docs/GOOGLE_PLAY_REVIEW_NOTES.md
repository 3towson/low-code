# Google Play Store Review Notes (Data Safety & Reviewer Credentials)
## App: COD Risk Shield (`com.codcheck.app`)

> **Instructions for Submitter:** Copy the content below into the **"App access"** and **"Testing instructions"** sections in Google Play Console when submitting the app for review.

---

### 1. App Access Instructions for Google Play Reviewers

**Login Required:** Yes, part of the app requires login for merchant fraud reporting, while customer COD delivery risk checking is accessible to all users (including Guest Mode).

#### Test Account Credentials:

1. **Primary Merchant Account (KYC Approved):**
   - **Email:** `reviewer_approved@codcheck.app`
   - **Password:** `Password123!`
   - **Status:** Verified Merchant (KYC Approved)
   - **Features to Test:** Check customer COD delivery risk, view protected parcel statistics, and submit problematic customer reports with photo evidence.

2. **Secondary Merchant Account (Unverified / KYC Pending):**
   - **Email:** `reviewer_unverified@codcheck.app`
   - **Password:** `Password123!`
   - **Status:** Unverified Merchant
   - **Features to Test:** Demonstrates user onboarding and the Merchant KYC verification workflow required before submitting customer reports.

3. **System Administrator Account:**
   - **Email:** `admin@codcheck.app`
   - **Password:** `Password123!`
   - **Role:** Administrator
   - **Features to Test:** Access the moderation dashboard to inspect and approve/reject reports and review merchant KYC applications.

---

### 2. Data Safety & Privacy Disclosures

- **No Raw Phone Numbers Stored:**
  Phone numbers are processed ephemerally on Edge Functions and immediately converted into an irreversible salted SHA-256 hash (`phone_hash`). No raw phone numbers are ever saved to the database.

- **No Customer Personal Names Stored:**
  Customer names are not stored in the database (`customer_name` is NULL in all records).

- **Account Deletion:**
  Users can delete their account and associated data directly in the app (Settings > Delete Account) or via our public web page:
  👉 **https://3towson.github.io/low-code/delete-account.html**

- **Customer Dispute Portal:**
  End-consumers can submit disputes or request data erasure at:
  👉 **https://3towson.github.io/low-code/dispute.html**

- **Privacy Policy URL:**
  👉 **https://3towson.github.io/low-code/privacy-policy.html**

---

### 3. Contact & Support
- **Support Email:** `support@codcheck.app`
- **Dispute Email:** `dispute@codcheck.app`
