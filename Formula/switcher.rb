cask "switcher" do
  version "0.1.3"
  sha256 "6339ba8fda68a3656dabb8e80e0efa0379a8cdf37e43e272938f3a2151c2141f"

  url "https://github.com/Bobronium/Switcher/releases/download/v#{version}/Switcher-v#{version}.zip"
  name "Switcher"
  desc "Switcher automates input switching for better sound quality on macOS"
  homepage "https://github.com/Bobronium/Switcher"

  livecheck do
    url "https://github.com/Bobronium/Switcher/releases"
    regex(/href=.*?Switcher[._-]v?(\d+(?:\.\d+)+)\.dmg/i)
  end

  app "build/release/Switcher.app"

  postflight do
    # Add Switcher.app to login items using AppleScript
    system_command "/usr/bin/osascript", args: [
      "-e",
      'tell application "System Events" to make login item at end with properties {path:"/Applications/Switcher.app", hidden:false, name:"Switcher"}'
    ]
    system_command "open", args: [
      "/Applications/Switcher.app",
    ]
    system_command "open", args: [
        "x-apple.systempreferences:com.apple.preference.security?General",
    ]
  end

  uninstall script: {
    executable: "/usr/bin/osascript",
    args: [
      "-e",
      'tell application "System Events" to delete login item "Switcher"'
    ]
  }

  zap trash: [
    "~/Library/Containers/com.bobronium.Switcher",
  ]
  caveats do
    'To open Switcher, press "Open Anyway" in "System Settings > Privacy & Security".'
  end
end