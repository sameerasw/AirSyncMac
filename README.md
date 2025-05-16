# AirSync (macOS Client)  

*Sync Android notifications to your Mac and share your clipboard seamlessly between devices.*

---

## Table of Contents

- [About](#about)
- [Features](#features)
- [Architecture Overview](#architecture-overview)
- [Screenshots](#screenshots)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Building from Source](#build-from-source)
- [Configuration](#configuration)
- [Usage](#usage)
- [Security & Privacy](#security--privacy)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)
- [Acknowledgements](#acknowledgements)
- [Contact](#contact)

---

## About

**AirSync** for macOS is the companion desktop application to [AirSync for Android](https://github.com/sameerasw/AirSync).  
It enables:

- Real-time mirroring of Android notifications to your Mac desktop.
- Bi-directional clipboard sharing between Android and macOS.
- A workflow for users who work across Android and Mac devices also mized with scrcpy.

AirSync Mac is designed for functionality, speed, and a native macOS experience and also to learn SwiftUI :3 .

---

## Features

- 🖥️ **Notification Mirroring:** Receive and interact with Android notifications on your Mac.
- 📋 **Clipboard Sync:** Copy text or images on one device to instantly share with the other.
- ⚡ **Native Experience:** Built entirely with Swift and SwiftUI for smooth integration.
- 🛡️ **No Cloud, No 3rd Party:** Direct LAN-only communication, no remote servers bs because I don't knwo how to.

---

## Architecture Overview

- **Language:** Swift (100%)
- **Platform:** macOS (10.15+ recommended)
- **Communication:** TCP over LAN
- **Core Components:**
  - Background service for notification reception
  - Notification UI integration (macOS Notification Center)
- **Companion App:** [AirSync for Android](https://github.com/sameerasw/AirSync)

---

## Screenshots

<!-- Replace with your actual screenshots -->
<p align="center">

  ![CleanShot 2025-05-15 at 11  24 37@2x](https://github.com/user-attachments/assets/bf8983fe-42df-4653-823e-c5168b5ad99f)
  
</p>

---

## Getting Started

### Prerequisites

- macOS 10.15 (Catalina) or higher, actually I'm not sure
- [AirSync for Android](https://github.com/sameerasw/AirSync) installed on your Android device
- Both devices on the same Wi-Fi network

### Installation

#### Download

Get [from releases](https://github.com/sameerasw/AirSyncMac/releases/latest).

#### Build from Source

1. **Clone the repository**
    ```sh
    git clone https://github.com/sameerasw/AirSyncMac.git
    cd AirSyncMac
    ```
2. **Open in Xcode**
    - Double-click `AirSyncMac.xcodeproj`
3. **Build and Run**
    - Select your target and run the app (⌘R)

##### Permissions Required

- **Local Network Access:** For device discovery and communication.
- **Notifications:** To display mirrored notifications.
- **Clipboard Access:** To enable clipboard sync.
- **Sandboxing is disabled** to call external shell scripts like scrcpy.

---

## Configuration

1. **Initial Setup:**  
   - Launch AirSyncMac.
   - Allow network and show notification permissions as prompted.
   - Ensure your Android app is open and both devices are on the same network.

2. **Pairing Devices:**  
   - Enter the IP and the port displayed on the Android device when the server is running.
   - Once connected, you will be notified.

3. **Preferences:**  
   - Not much.
   - App will stay in the menubar when closed unless you quit.

---

## Usage

- **Notifications:**  
  - Android notifications will appear in your Mac’s Notification Center.
  - You can configure their importance and visibility in system settings.
  - Viewing the notification will launch scrcpy in a virtual screen fo Android with the target app opened.

- **Clipboard:**  
  - Text sent by the Android client will be copied to the clipboard automatically.
  - You can easily send what's on the clipboard or a custom text.

---

## Security & Privacy

- **End-to-End Encryption:** nah, nothing
- **LAN Only:** Data never leaves your local network.
- **No Analytics:** No telemetry, analytics, or data collection. I mean why?
- **Open Source:** Review the code for full transparency.

---

## Troubleshooting & FAQ

- **Not Connecting?**
    - Check that both devices are on the same network.
    - Make sure local network permissions are granted in macOS System Preferences or when popped up.
    - Make sure the IP and port are correct.
    - Make sure nto filtered by the firewall.
    - VPN usage may affect the connection.
- **Notifications not showing?**
    - Ensure show notification settings are enabled.
- **Pairing fails?**
    - Retry pairing; restart both apps if needed.

> For more help, please open an [issue](https://github.com/sameerasw/AirSyncMac/issues).

---

## Contributing

Contributions are welcome!  
See [CONTRIBUTING.md](CONTRIBUTING.md) (not an actual thing yet) for guidelines.

- Fork the repo
- Create a feature branch (`git checkout -b feature/YourFeature`)
- Commit your changes
- Open a pull request

---

## Roadmap

- [ ] Actionable notifications (reply, dismiss from Mac)
- [x] Multi-device support (untested, for multiple mac clients for the same device)
- [ ] UI improvements
- [ ] Automatic clipboard
- [ ] Improved menubar menu

---

## License

[MIT](LICENSE)

---

## Acknowledgements

- Swift, SwiftUI, and Apple developer tools
- [AirSync for Android](https://github.com/sameerasw/AirSync)
- Vibe coded the basics, It's my first Swift app so it helped to learn

---

## Contact

- **Author:** [sameerasw.com](https://www.sameerasw.com) putanythinghere@sameerasw.com
- **Issues & Feedback:** [GitHub Issues](https://github.com/sameerasw/AirSyncMac/issues)
- **Android Client:** [AirSync for Android](https://github.com/sameerasw/AirSync)
