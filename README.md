<p align="center"><a href="https://github.com/rapid-community/RapidOS"><img src="https://i.imgur.com/M2N83g1.png" alt="RapidOS logo" width="75"/></a></p>
<h1 align="center">RapidOS</h1>
<p align="center">Turning dreams into reality</p>

*RapidOS is an open-source project that aims to revolutionize the Windows experience. RapidOS it's powerful, streamlined and user-centric system that puts you in control.* ⚡

## ❓ Why RapidOS

RapidOS is here to make your Windows experience faster, cleaner, and more secure. We're not just tweaking the system - we're giving you more control over it. Here's why RapidOS could be the right choice for you:

#### 🔒 **Privacy at It's Core**:
- Keep your data safe.
- Block unnecessary telemetry.
- Prevent unwanted access to your system.

#### 🏎️ **Boosted Speed**:
- Get fast performance.
- Remove all unnecessary bloatware.
- Fine-tune system settings for the best results.

#### 🖥️ **Simple and Clean**:
- Enjoy a sleek, minimalist interface.
- No more clutter or unnecessary features.

#### 💡 **Get Involved**:
- Share your ideas and influence the development of RapidOS in Discord.
- Give feedback to help improve the system.

#### 🛠️ **Community Support**:
- Access help from a supportive community.
- Get guidance when things go wrong.

In short, RapidOS enhances your Windows experience by focusing on privacy, speed, simplicity, community, creativity and support.

## ⚙️ RapidOS Versions

### 🔒 Stable RapidOS
- **What is it**: A tweaked Windows for daily use.
- **What you get**: Secure, reliable, and easy to use.

### 🏎️ Speed RapidOS
- **What is it**: Made for power users who want speed without losing a lot of stability.
- **What you get**: Fast performance while staying stable.

### 🎮 Extreme RapidOS
- **What is it**: Maxed out for gaming and heavy tasks, but less stable.
- **What you get**: Top performance with instability.

You can choose any of these versions in the playbook under custom features!

***Note**: The playbook is still in beta, so by default we use the stable version. Once fully released, you'll have access to all options.*

## 🔧 System Changes & Enhancements

RapidOS is designed to be smooth and reliable. With the **1.0 Beta2** release coming up, we're fixing any remaining issues to improve performance and stability.

>[!Tip]
>
>If you'd like to customize our project for your personal use, you can deploy it yourself. Instructions on how to do this can be found below.

**For more details, check our GitHub FAQ Readme pages:**

- **[What's Removed from AppX (UWP apps)](https://github.com/rapid-community/RapidOS/blob/main/AppX%20README.md)**: See what's been removed from AppX apps.
- **[Service Changes Across Versions](https://github.com/rapid-community/RapidOS/blob/main/Services%20README.md)**: Find out which services have been changed or disabled in different versions of RapidOS.

## 🧰 Versatility & Control (Coming in v1.0 Stable)

We're enhancing control for advanced users with **RapidOS Toolbox**:

- **General Settings**: Review and undo changes made during RapidOS installation.
- **Advanced Tweaks**: Access additional Windows configuration options (**use with caution, as these are not used by default to ensure system stability**).

> ❗ **Note**: Some changes, like removing built-in apps, can’t be fully recovered.

## 🔓 Open-Source and Safe

This project is fully open-source, meaning you're free to dive into the code, contribute, or suggest improvements. Just like **AME Wizard**, **RapidOS** is designed to be secure and clean from any harmful software.

- 🔗 [Check the AME Wizard Codebase](https://github.com/Ameliorated-LLC/trusted-uninstaller-cli/tree/master).
- 🔗 [Check out RapidOS Code](https://github.com/rapid-community/RapidOS/tree/main).

Open-source projects thrive on community involvement, ensuring that they remain transparent, regularly updated, and trustworthy.

## 🔨 How to Get Started

RapidOS is now available for download! Built on the powerful **[AME Wizard](https://ameliorated.io/)**, it lets you customize Windows like never before.
With AME Wizard, you can use custom playbooks scripts and settings that - adjust your system to fit your needs. In just a few easy steps, **RapidOS** can completely transform your Windows experience.

---

### 💻 Supported Windows Builds

>[!Tip]
>
>If your computer meets the official system requirements for Windows 11, it's a good idea to go with Windows 11 to get the latest features and updates.

- **Windows 10 22H2 - `19045`**
- **Windows 11 23H2 - `22631`**
- **Windows 11 24H2 - `26100`**

Any other build **is not** officially supported by RapidOS.

---

### 🌐 Install Latest Windows

>[!Important]
>
>It's a good idea to do a clean install of the OS. This helps avoid any leftover problems from old installs (like outdated drivers or messy settings from old RapidOS versions), so you'll get the best performance, security and overall smooth experience.

>[!Caution]
>
>At this time, RapidOS does **not support ARM64** processors. Full support for ARM64 will be introduced likely in version 2.0. Thank you for your understanding.

You need to install supported Windows build using one of these methods:

1. **Media Creation Tool**  
   The official [Media Creation Tool](https://www.microsoft.com/software-download) from Microsoft is an easy way to create a bootable USB or directly upgrade your system.

2. **GraveSoft Windows Image Archive**  
   Head over to [GraveSoft](https://msdl.gravesoft.dev/) to download a wide range of Windows ISO images.

3. **Uppdump**  
   [Uppdump](https://uupdump.net/) is a tool for downloading Windows updates and builds directly from Microsoft's servers, but it’s known to be **unstable** during the download process.

---

### 💾 Install Windows on a USB Drive

After installing or building Windows, you need to transfer it to a USB drive (if you haven't used the Media Creation Tool). You can do this in two ways:

- Use [Ventoy](https://www.ventoy.net/), a tool that allows you to boot multiple ISOs from a single USB drive.
- Use [Rufus](https://rufus.ie/), a lightweight utility designed to create bootable USB drives for installing operating systems.

>[!Tip]
>
>If you use Ventoy, I highly recommend using the ReviOS Ventoy settings, as this method is really effective on 24H2 versions for bypassing the required Microsoft account login and the need for an internet connection. Additionally, this method will disable BitLocker, automatic updates (including driver auto-updates): [ventoy-conf](https://github.com/meetrevision/ventoy-conf/).

---

### 🚀 Post-Windows Installation Guide

After creating a bootable USB drive with **Rufus** or **Ventoy**, follow these steps to set up Windows before reaching the desktop:

#### 1. BIOS Settings
- **Access BIOS**: Reboot your PC and enter BIOS (usually by pressing `Esc`, `Del`, `F2` or `F12`).
- **Boot Order**: Ensure your USB drive is set as the first boot device.
- **Secure Boot**: Be aware that **Ventoy** might not work well with Secure Boot enabled. Keep this in mind and consider disabling it temporarily for the installation process.

#### 2. Windows OOBE (Out-of-Box Experience)
Once the installation process starts, you'll need to disconnect your Ethernet cable. Then you will be guided through Windows OOBE. If you're using Windows 23H2, you can bypass network requirements:

- **Bypass Network Requirement**: 
  - At the network setup screen, press `Shift + F10` to open a command prompt.
  - Type `OOBE\BYPASSNRO` and press Enter.
  - The system will restart, and after reboot, the option to "I don't have internet" will appear, allowing you to proceed without connecting to a network.
  
>[!Important]
>
>For Windows 10 22H2 and Windows 11 24H2, `OOBE\BYPASSNRO` is not available. This method works only for Windows 11 23H2. To bypass the necessary internet connection, use the ReviOS Ventoy configuration described earlier.

#### 3. Choose How to Handle Driver Installation:

It is recommended to manually install drivers for better control and stability. Here's how:

- **To Prevent Automatic Driver Installation**: Use the registry tweak available here (Credits to AtlasOS): [Disable Automatic Driver Installation](https://github.com/Atlas-OS/Atlas/releases/download/0.4.0/Disable.Automatic.Driver.Installation.reg). After applying this tweak, you can reconnect to the internet via Wi-Fi or Ethernet cable.

**Option 1: Manually Install Drivers**
- **Download Drivers**: 
  - Use **NVCleanInstall** for Nvidia drivers.
  - Download drivers directly from your motherboard's manufacturer website, or from AMD, Intel and other relevant sources.
  - Alternatively, you can use **[Snappy Driver Installer (SDI)](https://sdi-tool.org/)** if necessary.

**Option 2: Allow Windows to Install Drivers Automatically**
- **Keep Internet Connected**: If you prefer Windows to handle driver installation, leave the system connected to the internet during installation.
  - Windows will automatically download and install the necessary drivers after reaching the desktop.

#### 4. Re-enable Secure Boot
After finishing the setup and confirming everything works, remember to re-enable **Secure Boot** in your BIOS to ensure maximum security.

---

### 📥 Installing RapidOS

To install RapidOS, follow these steps:

1. **Download and Extract Files:**
   - Install [AME Wizard](https://ameliorated.io/).
   - Download the RapidOS Playbook from:
     - [GitHub releases page](https://github.com/rapid-community/RapidOS/releases).
     - [Our website](https://rapid-community.ru).
   - Extract both downloads to your desktop.

2. **Update Windows:**
   - Open **Settings** and update Windows, including optional updates, until no more updates are available. If updates are paused, click **Resume Updates** to continue.

3. **Update Microsoft Store:**
   - Open the Microsoft Store and update all apps. You might need to update the Microsoft Store itself first.

4. **Restart Your Computer:**
   - Restart after all updates are complete. Check for updates again until there are no more available.

5. **Run AME Wizard:**
   - Open **AME Wizard Beta.exe** from the AME Wizard folder. 
   - If SmartScreen warns that AME Wizard is unrecognized, click **More info** and then **Run anyway**.

6. **Update AME Wizard:**
   - Click on **Updates** at the top of AME Wizard and ensure it is up to date.

7. **Install RapidOS Playbook:**
   - Drag **RapidOS.apbx** from the Atlas Playbook into AME Wizard.
   - Follow the on-screen instructions in AME Wizard to complete the installation of the RapidOS Playbook.

*Note: The basis for this installation guide was sourced from AtlasOS.*

## 🛠️ Want to Deploy?

If you're looking to deploy, make sure to read the [official documentation by Ameliorated](https://docs.ameliorated.io/) to fully understand how the playbooks work.

In short, while the playbooks are in `.apbx` format, they are actually `7z` archives protected with the password `malte`.
Our playbooks consist of `.yml` (default AME Wizard configuration files), `.ps1` and `.bat` files.

In most `.yml` files, you can adjust many of RapidOS's changes. For example, you can configure AppX file to prevent the deletion of necessary apps you need. In `custom.yml`, you can also disable specific `.yml` files by commenting them out with `#`.

You'll need a text editor to deploy the project:

<a href="https://www.sublimetext.com"><img src="https://img.shields.io/badge/sublime_text-%23575757.svg?style=for-the-badge&logo=sublime-text&logoColor=important"></a>
<a href="https://notepad-plus-plus.org"><img src="https://img.shields.io/badge/Notepad++-90E59A.svg?style=for-the-badge&logo=notepad%2b%2b&logoColor=black"></a>
<a href="https://code.visualstudio.com"><img src="https://img.shields.io/badge/Visual%20Studio%20Code-0078d7.svg?style=for-the-badge&logo=visual-studio-code&logoColor=white"></a>

## 📧 How to Contact Us

For any questions, feedback or suggestions, you can:

- **Join our [Discord server](https://dsc.gg/rapid-community)**  
  Connect with the RapidOS community and interact with developers.

- **Follow us on [X.com](https://x.com/community_rapid)**  
  Stay updated with the latest news and announcements.

Feel free to reach out - we're here to help!

## 🧾 License

RapidOS is licensed under the [GNU General Public License v3.0](https://github.com/rapid-community/RapidOS/blob/main/LICENSE). By using, distributing, or contributing to this project, you agree to the terms and conditions of this license.

>[!Warning]
>
>Except for the source code licensed under **GPLv3**, you are not allowed to use the name RapidOS for any projects based on the Playbook system, including forks and unofficial builds. This rule ensures that the RapidOS name is used only in its intended context and prevents misuse.

## 🌟 Support Us

**Love the project?** Show your support by clicking the ⭐ (top right) and joining our community of [stargazers](https://github.com/rapid-community/RapidOS/stargazers)!

[![Stargazers repo roster for @rapid-community/RapidOS](https://reporoster.com/stars/dark/rapid-community/RapidOS)](https://github.com/rapid-community/RapidOS/stargazers)

## 🌊 Join the RapidOS Community Today!

RapidOS is more than just a project. It is a vision, a passion and a community.
Join us today and unlock a new level of Windows experience with RapidOS! ✨