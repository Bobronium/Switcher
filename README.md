<p align="center">
  <img src="Switcher/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" alt="App Icon" width="256" height="256">
</p>

<h2 align="center"><strong>Switcher</strong> saves you from shitty sound when using a microphone with Bluetooth headphones on macOS</h2>

## The Problem

Bluetooth doesn't have enough bandwidth to support high-quality audio and microphone input simultaneously. When you connect your AirPods to your Mac, the system may switch to the HFP codec to enable the microphone.
This codec is designed for phone calls and has a lower audio quality than the A2DP codec used for music playback.

[Tom-Solid](https://www.reddit.com/r/airpods/comments/11zhtj0/finally_quick_fix_for_poor_sound_quality_on_mac/), describes the issue:

> "The sound was tinny, lacked bass, and was marred by crackling sounds... It turns out that using the AirPods' microphone on a Mac may automatically switch to HFP, which results in poor audio quality even during playback."

## How Switcher Helps

Switcher is a simple utility that automatically switches the sound input to a non-Bluetooth microphone upon connecting your AirPods to your Mac.
This action prevents the Mac from using the HFP codec, ensuring that you always receive the best sound quality.

<details>
<summary>Manual Solution (doesn't persist)</summary>

To manually fix this issue, upon each connection of AirPods to your Mac, you can follow these steps:
- Navigate to **Sound Settings** on your Mac.
- Access the **Output & Input** section.
- Click on the **Input** tab.
- Select any input device other than your Apple AirPod's microphone.

Following these steps should immediately improve the sound quality.
</details>

## Installation

### Homebrew
```shell
brew install Bobronium/tap/switcher
```
The application is using ad-hock signature, so you need to allow it in the system settings. The window will open automatically during the installation.

It will automatically launch at login. To remove it from the login items, run:
```shell
osascript -e 'tell application "System Events" to delete login item "Switcher"'
```
or see manual installation instructions below.


### Manual
1. **Download the Application**
   - Download the `Switcher-vX.X.X.dmg` from the [latest release](https://github.com/Bobronium/Switcher/releases/latest) or build application from the source code.

2. **Install the Application**
   - Open `Switcher-vX.X.X.dmg`.
   - Drag `Switcher.app` to the `Applications` folder on your Mac.

3. **Set to Launch at Login**
   - If you want Switcher to launch automatically each time you log in to your Mac:
     - Open `System Settings` -> `General` -> `Login Items`
     - Click the `+` button and navigate to the `Applications` folder.
     - Select `Switcher.app` and click `Add`.


### Credits
- [Tom-Solid](https://www.reddit.com/r/airpods/comments/11zhtj0/finally_quick_fix_for_poor_sound_quality_on_mac/) for the original solution.
- @elrumo for the [App Icon](https://github.com/elrumo/macOS_Big_Sur_icons_replacements)
- Many other people who made this possible by providing their source code, questions and answers, which were used to my education and later were used to train LLMs that helped me to write Swift code.


### Development
#### Create an icon:
```bash
curl https://parsefiles.back4app.com/JPaQcFfEEQ1ePBxbf6wvzkPMEqKYHhPYv8boI1Rc/f76537cc3a5709222e29fe1fa9d85595_1708726295537.icns -o original_icon.icns
uv run stylize_icons.py original_icon.icns switcher.icns --jpeg-quality 10 --pixelation-factor 16 --saturation-factor 0.24 --angle 109 --pixelated-line --offset 11
uv run stylize_icons.py switcher.icns switcher.icns      --jpeg-quality 8  --pixelation-factor 1  --saturation-factor 1    --angle 109 --pixelated-line --offset 11
uv run icns_to_appiconset.py switcher.icns Switcher/Assets.xcassets/AppIcon.appiconset
```

