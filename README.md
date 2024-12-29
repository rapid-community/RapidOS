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

<!-- 

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

> ❗ **Note**: *The playbook is still in beta, so by default we use the stable version. Once fully released, you'll have access to all options.*

-->

## 🔧 System Changes & Enhancements

RapidOS is designed to be smooth and reliable. Every release we're fixing any remaining issues to improve performance and stability.

>[!Tip]
>
>If you'd like to customize our project for your personal use, you can deploy it yourself. Instructions on how to do this can be found below.

**For more details, check our GitHub FAQ Readme pages:**

- **[What's Removed from AppX (UWP apps)](https://github.com/rapid-community/RapidOS/blob/main/Readme%20Collection/AppX%20README.md)**: See what's been removed from AppX apps.
- **[Service Changes Across Versions](https://github.com/rapid-community/RapidOS/blob/main/Readme%20Collection/Services%20README.md)**: Find out which services have been changed or disabled in different versions of RapidOS.

<!--

## 🧰 Versatility & Control

We're enhancing control for advanced users with **RapidOS Toolbox**:

- **General Settings**: Review and undo changes made during RapidOS installation.
- **Advanced Tweaks**: Access additional Windows configuration options (**use with caution, as these are not used by default to ensure system stability**).

> ❗ **Note**: Some changes, like removing built-in apps, can't be fully recovered.

-->

## 🔓 Open-Source and Safe

This project is fully open-source, meaning you're free to dive into the code, contribute, or suggest improvements. Just like **AME Wizard**, **RapidOS** is designed to be secure and clean from any harmful software.

- 🔗 [Check the AME Wizard Codebase](https://github.com/Ameliorated-LLC/trusted-uninstaller-cli/tree/master/TrustedUninstaller.CLI).
- 🔗 [Check out RapidOS Code](https://github.com/rapid-community/RapidOS/tree/main/RapidOS%20Sources).

Open-source projects thrive on community involvement, ensuring that they remain transparent, regularly updated and trustworthy.

## 🔨 How to Get Started

RapidOS is now available for download! Built on the powerful **[AME Wizard](https://ameliorated.io/)**, it lets you customize Windows like never before.
With AME Wizard, you can use custom playbooks scripts and settings that - adjust your system to fit your needs. In just a few easy steps, **RapidOS** can completely transform your Windows experience.

---

### 💻 Supported Windows Builds

>[!Tip]
>
>If your computer meets the official system requirements for Windows 11, it's a good idea to go with Windows 11 to get the latest features and updates.

- **Windows 10 22H2 - `19045`**
- **Windows 11 22H2 - `22621`**
- **Windows 11 23H2 - `22631`**
- **Windows 11 24H2 - `26100`**

Any other build **is not** officially supported by RapidOS.

---

In the [**RapidOS Documentation**](docs.rapid-community.ru), you'll find a straightforward guide to help you install Windows and RapidOS:

1. **Installing Windows**:
   - We cover all the methods for installing Windows, whether you're using the Media Creation Tool, MSDL, or UPPDump.
   - You'll learn how to make a bootable USB using **Rufus** or **Ventoy**, with clear steps for each.
   - There's a section on the Windows installation process, including the OOBE setup and how to handle drivers (manual or automatic), plus tips for bypassing network requirements if needed.

2. **Installing RapidOS**:
   - We'll show you how to get everything ready before you install RapidOS.
   - You'll get detailed instructions for downloading and running AME Wizard, the tool used to install RapidOS.
   - Finally, we walk you through the installation of RapidOS itself, with all the steps to make sure everything works smoothly.

The guide is designed to be simple and easy to follow, so you won't miss a thing. Everything is laid out clearly, so you can get your system up and running with minimal hassle.

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

- **Follow us on [Telegram](https://t.me/rapid_community)**  
  Stay up to date with exclusive news, discussions, and updates about the docs, the site, and the Playbook.

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