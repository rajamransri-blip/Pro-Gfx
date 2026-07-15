# 🎮 SK VIP CONFIG - Advanced Gaming Tool (Powered by Shizuku)

![App Version](https://img.shields.io/badge/Version-1.0.0-blue.svg)
![Flutter](https://img.shields.io/badge/Built_with-Flutter_3.19.0-02569B.svg?logo=flutter)
![Shizuku](https://img.shields.io/badge/Powered_by-Shizuku-00FF66.svg)
![Firebase](https://img.shields.io/badge/Database-Firebase-FFCA28.svg?logo=firebase)
![Build](https://img.shields.io/badge/Build-GitHub_Actions-2088FF.svg?logo=github-actions)

**SK VIP CONFIG** is a premium, rootless Android gaming utility app built with Flutter and Native Kotlin. It leverages the **Shizuku API** to safely inject `.pak` and `OBB` files directly into restricted Android/data directories without requiring device root.

With a fully dynamic **Firebase Realtime Database** backend, an integrated **Native VPN Firewall**, and a persistent UPI-based unlock system, this tool is designed for absolute control and seamless updates.

---

## ✨ Pro Features

*   **⚡ Rootless Injection (Shizuku):** Bypass Android 11+ storage restrictions to read/write into `Android/data` and `Android/obb` securely using Shizuku.
*   **🛡️ Native Firewall VPN:** Custom Android `VpnService` written in Kotlin, controllable via dynamic JSON configurations directly from the app settings.
*   **☁️ Firebase Cloud Sync:** 
    *   **Dynamic URLs:** Game modules (Wall Hack, OBB) download URLs are fetched from Firebase in real-time. No need to update the app to change file links!
    *   **Persistent Unlocks:** Payment verifications and unlocked features are saved to the cloud using unique Device IDs.
*   **💳 Secure Payment Gateway:** UPI UTR/Reference ID validation UI simulating premium secure transactions.
*   **🎨 Cyberpunk UI/UX:** Stunning Dark Matrix theme with Neon glowing borders, auto-gliding user feedback carousels, and PhonePe-style secure trust badges.
*   **🤖 Fully Automated CI/CD:** GitHub Actions workflow automatically injects permissions, Google Services JSON, Shizuku dependencies, and compiles the Release APK.

---

## 📸 Screenshots

*(Add your screenshots here by dragging and dropping them into GitHub)*

| Home Dashboard | Module Injector | VPN JSON Config |
| :---: | :---: | :---: |
| <img src="https://via.placeholder.com/250x500.png?text=Home+Screen" width="220"> | <img src="https://via.placeholder.com/250x500.png?text=Injection+Screen" width="220"> | <img src="https://via.placeholder.com/250x500.png?text=VPN+Config" width="220"> |

---

## 🛠️ Tech Stack

*   **Frontend:** Flutter (Dart)
*   **Native Backend:** Kotlin (Android VpnService, MethodChannels)
*   **System Bypass:** Shizuku API (`dev.rikka.shizuku`)
*   **Database:** Firebase Realtime Database
*   **Local Storage:** SharedPreferences (Auto-sync with Cloud)
*   **Automation:** GitHub Actions (Ubuntu-latest, Zulu Java 17)

---

## 🚀 How to Setup & Build (GitHub Actions)

This project is configured to build automatically via GitHub Actions, meaning you don't need Android Studio to compile the APK!

### 1. Setup Firebase Credentials
1. Go to your GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions**.
2. Click on **New repository secret**.
3. Name: `GOOGLE_SERVICES_JSON`
4. Secret: Paste the entire content of your `google-services.json` file here.
5. Click **Add secret**.

### 2. Trigger the Build
1. Go to the **Actions** tab in your GitHub repository.
2. Select **Build APK** from the left menu.
3. Click **Run workflow**.
4. Once completed, download your `app-release.apk` from the Artifacts section!

---

## 💻 Running Locally (For Developers)

If you want to compile the app on your own PC using VS Code or Android Studio:

1. Clone the repository:
   ```bash
   git clone [https://github.com/yourusername/gaming_tool.git](https://github.com/yourusername/gaming_tool.git)
