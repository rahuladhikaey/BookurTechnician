# BookurTechnician — Flutter & Android Security Architecture

**Applications:**
1. Flutter Customer App (`com.booktechnician.customer`)
2. Flutter Technician App (`com.booktechnician.technician`)

**Target SDK:** Android 15 (API 35)  
**Compile SDK:** Android 16 (API 36)  
**Standard:** OWASP Mobile Application Security Verification Standard (MASVS)  

---

## 1. Network & Transport Security

### A. Network Security Configuration (`network_security_config.xml`)
Both applications include strict network security XML declarations located at:
- `apps/customer_app_flutter/android/app/src/main/res/xml/network_security_config.xml`
- `apps/technician_app/android/app/src/main/res/xml/network_security_config.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Enforce HTTPS across all domains, completely disabling cleartext HTTP -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">bookurtechnician.online</domain>
        <domain includeSubdomains="true">bookurtechnician.com</domain>
        <domain includeSubdomains="true">web.app</domain>
        <domain includeSubdomains="true">firebaseapp.com</domain>
        <domain includeSubdomains="true">onrender.com</domain>
    </domain-config>
</network-security-config>
```

Both manifests link this configuration via `android:networkSecurityConfig="@xml/network_security_config"`.

---

## 2. Token & Credential Storage

### A. Technician App
- Employs `flutter_secure_storage` using Android Keystore and AES-256 encrypted shared preferences (`encryptedSharedPreferences: true`).
- Sensitive access and refresh tokens are encrypted at rest with hardware-backed keys.

### B. Customer App
- Uses local application storage scoped to the app sandbox (`/data/data/com.booktechnician.customer/`).
- Android operating system file sandbox permissions prevent external applications without root from reading shared preference files.

---

## 3. Android Permission Minimization

| Permission | Justification & Safeguards |
|---|---|
| `ACCESS_FINE_LOCATION` | Required for matching nearby technicians within 3km. Never shared globally. |
| `ACCESS_COARSE_LOCATION` | Fallback approximate location for service availability checking. |
| `POST_NOTIFICATIONS` | Android 13+ runtime permission for booking dispatch alerts. |
| `CAMERA` | Technician app: Capturing proof of work; Customer: Problem documentation. |
| `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` | Selecting service or invoice attachments. |

---

## 4. Release Build Hardening

- **Proguard / R8 Code Shrinking:** Enabled in release builds to obfuscate symbols and strip unused classes.
- **Debug Logging Disablement:** `debugPrint` and console logging statements are stripped or silenced in release binaries (`kReleaseMode == true`).
- **Signing Credentials Security:** Private keystores (`*.jks`, `*.keystore`) and `key.properties` are explicitly excluded in `.gitignore` to prevent repository leaks.
