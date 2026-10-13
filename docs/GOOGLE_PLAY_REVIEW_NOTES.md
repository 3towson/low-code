# Google Play Store Review Notes (Data Safety & Reviewer Credentials)
## App: COD Risk Shield (`com.codcheck.app`)

> **Instructions for Submitter:** Copy the content below into the **"App access"** and **"Testing instructions"** sections in Google Play Console when submitting the app for review.

---

### 1. App Access Instructions for Google Play Reviewers

**Login Required:** Yes, part of the app requires login for merchant fraud reporting, while customer COD delivery risk checking is accessible to all users (including Guest Mode).

#### Test Account Credentials:
*(Please provide the actual password securely in Google Play Console "App access" instructions; do not commit passwords to source control)*

1. **Primary Merchant Account (KYC Approved):**
   - **Email:** `reviewer_approved@codcheck.app`
   - **Password:** [Enter the reviewer password configured in Google Play Console]
   - **Status:** Verified Merchant (KYC Approved)
   - **Features to Test:** Check customer COD delivery risk, view protected parcel statistics, and submit problematic customer reports with photo evidence.

2. **Secondary Merchant Account (Unverified / KYC Pending):**
   - **Email:** `reviewer_unverified@codcheck.app`
   - **Password:** [Enter the reviewer password configured in Google Play Console]
   - **Status:** Unverified Merchant
   - **Features to Test:** Demonstrates user onboarding and the Merchant KYC verification workflow required before submitting customer reports.

*(Note: Admin moderation features are demonstrated via recorded video upon request to avoid exposing administrative access credentials).*

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
