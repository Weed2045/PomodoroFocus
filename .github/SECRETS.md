# GitHub Secrets Setup for CI/CD

Go to: **GitHub repo → Settings → Secrets and variables → Actions → New repository secret**

---

## CI (Build & Test) — No secrets needed ✅

The CI workflow runs on simulator, no signing required.

---

## CD (TestFlight) — Required Secrets

### 1. App Store Connect API Key

| Secret name | Value |
|---|---|
| `ASC_KEY_ID` | Key ID (e.g. `AB12CD34EF`) — from App Store Connect |
| `ASC_ISSUER_ID` | Issuer ID (UUID) — from App Store Connect |
| `ASC_KEY_CONTENT` | Contents of the `.p8` file (the whole text including `-----BEGIN PRIVATE KEY-----`) |

**How to create:**
1. [App Store Connect](https://appstoreconnect.apple.com) → Users and Access → Integrations → App Store Connect API
2. Click **+** → Name: `GitHub Actions` → Access: **App Manager**
3. Download the `.p8` file — you can only download it once!
4. Copy the text content of the `.p8` file into `ASC_KEY_CONTENT`

---

### 2. Distribution Certificate

| Secret name | Value |
|---|---|
| `DISTRIBUTION_CERTIFICATE_P12_BASE64` | Base64-encoded `.p12` distribution certificate |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | Password you set when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Any random string (used as temporary keychain password, e.g. `ci-keychain-2024`) |

**How to export:**
1. Xcode → Settings → Accounts → Manage Certificates → right-click **Apple Distribution** → Export Certificate
2. Save as `.p12` with a password
3. Encode: `base64 -i YourCert.p12 | pbcopy` (copies to clipboard)
4. Paste as `DISTRIBUTION_CERTIFICATE_P12_BASE64`

---

### 3. Provisioning Profiles (App Store / TestFlight)

| Secret name | Value |
|---|---|
| `PROVISIONING_PROFILE_BASE64` | Base64-encoded `.mobileprovision` for main app |
| `EXTENSION_PROVISIONING_PROFILE_BASE64` | Base64-encoded `.mobileprovision` for widget extension |

**How to create & export:**
1. [Apple Developer Portal](https://developer.apple.com) → Certificates, Identifiers & Profiles → Profiles
2. Create **App Store** provisioning profile for:
   - `com.codex.PomodoroFocus` → save as `PomodoroFocus_AppStore.mobileprovision`
   - `com.codex.PomodoroFocus.PomodoroActivityExtension` → save as `PomodoroActivityExtension_AppStore.mobileprovision`
3. Encode: `base64 -i PomodoroFocus_AppStore.mobileprovision | pbcopy`
4. Paste as `PROVISIONING_PROFILE_BASE64`

---

## Summary checklist

- [ ] `ASC_KEY_ID`
- [ ] `ASC_ISSUER_ID`
- [ ] `ASC_KEY_CONTENT`
- [ ] `DISTRIBUTION_CERTIFICATE_P12_BASE64`
- [ ] `DISTRIBUTION_CERTIFICATE_PASSWORD`
- [ ] `KEYCHAIN_PASSWORD`
- [ ] `PROVISIONING_PROFILE_BASE64`
- [ ] `EXTENSION_PROVISIONING_PROFILE_BASE64`

Once all 8 secrets are set, push a tag `v1.0.0` to trigger the first TestFlight build:
```bash
git tag v1.0.0 && git push origin v1.0.0
```
