# GOOGLE PLAY RELEASE SIGNING & AAB DEPLOYMENT GUIDE
## BookurTechnician Android Applications
**Standard:** Google Play App Signing & Android Keystore Architecture

Google Play Console requires production applications to be uploaded in the **Android App Bundle (.aab)** format signed with an **Upload Keystore**. Google Play then uses **Play App Signing** to generate device-optimized split APKs signed with your Google Play App Signing Key.

---

## 1. Automated AAB Generation
We have provided an automated script to build release AABs for both Customer and Partner apps:
```powershell
powershell -ExecutionPolicy Bypass -File .\build_aab.ps1
```
The resulting upload bundles will be saved to:
- `release_aab\BookurTechnician_Customer_App.aab`
- `release_aab\BookurTechnician_Technician_Partner.aab`

---

## 2. Generating Your Production Upload Keystore
To sign your app for official Google Play distribution, run the following Java `keytool` command in PowerShell / Command Prompt:

### For Customer App:
```powershell
keytool -genkey -v -keystore apps\customer_app_flutter\android\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### For Technician Partner App:
```powershell
keytool -genkey -v -keystore apps\technician_app\android\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
*Note: Store the keystore file and passwords in a secure password manager. Never commit `.jks` files or raw passwords to public Git repositories.*

---

## 3. Configuring `key.properties` for Release Signing

In both `apps\customer_app_flutter\android\` and `apps\technician_app\android\`, create a file named `key.properties`:

```properties
storePassword=YOUR_SECURE_STORE_PASSWORD
keyPassword=YOUR_SECURE_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

### Gradle Signing Config in `build.gradle`
Both apps' `android/app/build.gradle` already read `key.properties` if present:
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            shrinkResources false
        }
    }
}
```

---

## 4. Google Play Console Upload Checklist

1. **Log in to Google Play Console:** https://play.google.com/console
2. **Create New App:**
   - App Name: `BookurTechnician - Home Service`
   - Default Language: English (India)
   - App or Game: App
   - Free or Paid: Free
3. **Set Up App Release:**
   - Navigate to `Release > Production` (or `Internal Testing` first).
   - Click **Create new release**.
   - Upload `release_aab\BookurTechnician_Customer_App.aab`.
   - Release Name: `1.0.1 (Build 2) - Production Release`.
   - Release Notes: Copy from `docs/playstore/GOOGLE_PLAY_STORE_LISTING_METADATA.md`.
4. **Complete Store Listing:**
   - App Icon: 512x512 PNG.
   - Feature Graphic: 1024x500 JPG/PNG.
   - Screenshots: Upload at least 4 phone screenshots (1080x2400).
   - Descriptions: Copy title, short description, and full description from `docs/playstore/GOOGLE_PLAY_STORE_LISTING_METADATA.md`.
5. **Data Safety Questionnaire:**
   - Follow `docs/playstore/PLAY_CONSOLE_DATA_SAFETY_SPECIFICATION.md` line by line.
6. **Privacy Policy & Account Deletion URLs:**
   - Privacy Policy URL: `https://bookurtechnician.online/privacy-policy`
   - Account Deletion URL: `https://bookurtechnician.online/delete-account`
7. **Submit for Review:**
   - Send for review. Google Play typically reviews new apps within 24 to 72 hours.
