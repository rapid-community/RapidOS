<p align="center"><a href="https://github.com/rapid-community/RapidOS"><img src="https://i.imgur.com/M2N83g1.png" alt="RapidOS logo" width="75"/></a></p>
<h1 align="center">RapidOS</h1>
<p align="center">Turning dreams into reality</p>

*RapidOS is an open-source project that aims to revolutionize the Windows experience - a powerful, streamlined, user-centric system that puts you in control.* ⚡

## ❓ Why RapidOS?

RapidOS modifies Windows to make your system faster, cleaner, and more secure. It's not standalone software - just a set of tweaks applied for real, everyday improvements. Here's why you should consider it:

#### 🔒 Privacy first
RapidOS locks down your privacy. It blocks Windows telemetry that tracks you and strengthens security to keep unwanted access out.

#### 🏎️ Better performance
It's all about speed. RapidOS cuts out bloatware that slows your system and adjusts settings for better performance. No gaming miracles, just faster daily use.

#### 🖥️ Clean and simple
The interface gets streamlined. No clutter or unnecessary features - RapidOS keeps it simple and easy to use for anyone who likes things clean.

#### 💡 Join the community
RapidOS is a project you can jump into. Hit up [Rapid Community](https://discord.rapid-community.ru) to share ideas, provide feedback to help improve the system, or chat with others who want a better Windows.

#### 🛠️ Support when you need it
If something goes wrong, community's got you. Developers and active users offer quick tips or help with bigger issues.

*RapidOS turns Windows into something better: private, fast, and simple, backed by a solid crew.*

## 🔧 System changes & enhancements

RapidOS is designed to be smooth and reliable. Every release we're fixing any remaining issues to improve performance and stability.

>[!Tip]
>
>If you'd like to customize our project for your personal use, you can deploy it yourself. Instructions on how to do this can be found below.

**For more details, check our GitHub FAQ pages:**

- [What's removed from UWP apps](https://github.com/rapid-community/RapidOS/blob/main/Readme%20Collection/UWP%20README.md): See what's been removed from UWP apps
- [Service adjustments](https://github.com/rapid-community/RapidOS/blob/main/Readme%20Collection/Services%20README.md): Find out which services have been changed, disabled or internet-restricted

## 🔓 Open-source and safe

This project is fully open-source, meaning you're free to dive into the code, contribute, or suggest improvements. Just like **AME Beta**, **RapidOS** is designed to be secure and clean from any harmful software.

🔗 [Check the AME Beta codebase](https://github.com/Ameliorated-LLC/trusted-uninstaller-cli/tree/public/TrustedUninstaller.CLI)  
🔗 [Check out RapidOS code](https://github.com/rapid-community/RapidOS/tree/main/RapidOS%20Sources)

Open-source projects thrive on community involvement, ensuring that they remain transparent, regularly updated and trustworthy.

## 🔨 How to get started

RapidOS is available for download! Built on the powerful **[AME Beta](https://amelabs.net/)**, it lets you customize Windows like never before. You can use custom playbooks scripts and settings that - adjust your system to fit your needs. In just a few easy steps, **RapidOS** can completely transform your Windows experience.

---

### 💻 Supported Windows builds

>[!Tip]
>
>If your computer meets the official system requirements for Windows 11, it's a good idea to go with Windows 11 to get the latest features and updates. Also, it is not recommended to install RapidOS on non-Pro versions of Windows.

- **Windows 10 22H2 - `19045`**
- **Windows 11 22H2 - `22621`**
- **Windows 11 23H2 - `22631`**
- **Windows 11 24H2 - `26100`**
- **Windows 11 25H2 - `26200`**

Any other build **is not** officially supported by RapidOS.

---

### 📜 Documentation

In the [**RapidOS documentation**](https://docs.rapid-community.ru/), you'll find a straightforward guide to help you install Windows and RapidOS:

1. **Installing Windows**:
   - We cover all the methods for installing Windows, whether you're using the Media Creation Tool, MSDL, or uppdump.
   - You'll learn how to make a bootable USB using **Rufus** or **Ventoy**, with clear steps for each.
   - There's a section on the Windows installation process, including the OOBE setup and how to handle drivers (manual or automatic), plus tips for bypassing network requirements if needed.

2. **Installing RapidOS**:
   - We'll show you how to get everything ready before you install RapidOS.
   - You'll get detailed instructions for downloading and running AME Beta, the tool used to install RapidOS.
   - Finally, we walk you through the installation of RapidOS itself, covering all the necessary steps.

The guide is designed to be simple and easy to follow, so you won't miss a thing. Everything is laid out clearly, so you can get your system up and running with minimal hassle.

## 🛠️ Want to deploy?

If you're looking to deploy, make sure to read the [official documentation by Ameliorated](https://docs.amelabs.net/) to fully understand how the playbooks work.

In short, while the playbooks are in `.apbx` format, they are actually `7z` archives protected with the password `malte`.
Our playbooks consist of `.yml` (default AME Beta configuration files), `.ps1` and `.bat` files.

In most `.yml` files, you can adjust many of RapidOS's changes. For example, you can configure AppX file to prevent the deletion of necessary apps you need. In `custom.yml`, you can also disable specific `.yml` files by commenting them out with `#`.

You'll need a text editor to deploy the project:

<a href="https://www.sublimetext.com"><img src="https://img.shields.io/badge/sublime_text-%23575757.svg?style=for-the-badge&logo=sublime-text&logoColor=important"></a>
<a href="https://notepad-plus-plus.org"><img src="https://img.shields.io/badge/Notepad++-90E59A.svg?style=for-the-badge&logo=notepad%2b%2b&logoColor=black"></a>
<a href="https://code.visualstudio.com"><img src="https://img.shields.io/badge/Visual%20Studio%20Code-0078d7.svg?style=for-the-badge&logo=visual-studio-code&logoColor=white"></a>

## 📧 How to contact us

For any questions, feedback or suggestions, you can:

- **Join our [Discord server](http://discord.rapid-community.ru)**  
  Connect with the Rapid Community and interact with developers.

- **Follow us on [X.com](https://x.com/community_rapid)**  
  Stay updated with the latest news and announcements.

- **Follow us on [Telegram](https://telegram.rapid-community.ru)**  
  Stay up to date with exclusive news, discussions, and updates about the docs, the website, and the Playbook.

Feel free to reach out - we're here to help!

## 📝 License

RapidOS is licensed under the [GNU Affero General Public License v3.0](https://github.com/rapid-community/RapidOS/blob/main/LICENSE). By using, distributing, or contributing to this project, you agree to the terms and conditions of this license.

>[!Warning]
>
>Except for the source code licensed under **AGPLv3**, you are not allowed to use the name RapidOS for any projects based on the Playbook system, including unofficial builds. This rule ensures that the RapidOS name is used only in its intended context and prevents misuse.

## 🌟 Support us

**Love the project?** Show your support by clicking the ⭐ (top right) and joining our community of [stargazers](https://github.com/rapid-community/RapidOS/stargazers)!

[![Stargazers repo roster for @rapid-community/RapidOS](https://reporoster.com/stars/dark/rapid-community/RapidOS)](https://github.com/rapid-community/RapidOS/stargazers)

## 🌊 Join the Rapid Community today!

RapidOS is more than just a project. It is a vision, a passion and a community.
Join us today and unlock a new level of Windows experience with RapidOS! ✨