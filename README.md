# Switcher

**Switcher** is a macOS utility designed to enhance the sound quality of AirPods (Max/Pro) and potentially other Bluetooth headphones when connected to a Mac.

## The Problem

Many users experience significantly degraded sound quality when using AirPods with their Mac. This issue commonly arises due to the Mac automatically switching the sound input to the AirPods' microphone, which triggers the use of a lower-quality audio codec (HFP - Hands-Free Profile).

A user on Reddit, [Tom-Solid](https://www.reddit.com/r/airpods/comments/11zhtj0/finally_quick_fix_for_poor_sound_quality_on_mac/), describes the issue:

> "The sound was tinny, lacked bass, and was marred by crackling sounds... It turns out that using the AirPods' microphone on a Mac may automatically switch to HFP, which results in poor audio quality even during playback."

## Manual Solution

To manually fix this issue:
- Navigate to **Sound Settings** on your Mac.
- Access the **Output & Input** section.
- Click on the **Input** tab.
- Select any input device other than your Apple AirPod's microphone.

Following these steps should immediately improve the sound quality.

## How Switcher Helps

Switcher automates the above process. It actively monitors media playback events on your Mac. Due to technical limitations, it cannot differentiate between Play and Pause events. However, it will switch the audio input to the internal microphone whenever these events are detected, ensuring optimal sound quality without the need for manual intervention.

## Installation

To install Switcher, follow these steps:

1. **Download the Application**
   - Download the `Switcher.app` file from the latest release or build application from the source code.

2. **Install the Application**
   - Open your `Downloads` folder.
   - Drag `Switcher.app` to the `Applications` folder on your Mac.

3. **First-time Setup**
   - Since macOS will recognize software downloaded from the internet as from an unidentified developer, right-click `Switcher.app` in the `Applications` folder and select `Open`. This will prompt a security dialog from which you can grant permission to run the app.

4. **Set to Launch at Login**
   - If you want Switcher to launch automatically each time you log in to your Mac:
     - Open `System Settings` -> `General` -> `Login Items`
     - Click the `+` button and navigate to the `Applications` folder.
     - Select `Switcher.app` and click `Add`.

