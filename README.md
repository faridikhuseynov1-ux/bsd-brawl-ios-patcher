# BSD Brawl Stars iOS Patcher

Port of the **BSD (Brawl Stars Decompiled)** mod from Android to iOS.  
Applies CSV patches and provides a mod menu dylib for injection.

---

## What's included

| File | Description |
|------|-------------|
| `patch_ipa.ps1` | Windows PowerShell script — applies CSV patches from APK to IPA |
| `ModMenu.m` | Objective-C source for the in-game mod menu (iOS dylib) |
| `inject_dylib.sh` | macOS shell script — compiles and injects the mod menu into IPA |

---

## Part 1 — CSV Patches (Windows)

Patches these files from the BSD mod APK into the Brawl Stars IPA:

- `csv_client/effects.csv` — visual effects changes
- `csv_client/music.csv` — music changes  
- `csv_logic/location_themes.csv` — location theme changes
- `csv_logic/themes.csv` — theme changes

### Requirements
- Windows 10/11
- PowerShell 5+
- BSD mod APK (`bsd_brawl_v67.264.apk`)
- Brawl Stars IPA (`BrawlStars_67.264_iOS.ipa`)

### Usage

1. Place `patch_ipa.ps1`, the APK and the IPA in the same folder
2. Right-click `patch_ipa.ps1` → **Run with PowerShell**
3. Wait for the script to finish (copying 1+ GB takes ~1 min)
4. Install `BrawlStars_67.264_iOS_MODDED.ipa` via [Sideloadly](https://sideloadly.io/)

Or run manually with custom paths:
```powershell
.\patch_ipa.ps1 -ApkPath "path\to\mod.apk" -IpaPath "path\to\game.ipa" -OutputPath "output.ipa"
```

---

## Part 2 — Mod Menu (macOS only)

The mod menu is a `.dylib` injected into the game binary.  
It shows an in-game overlay triggered by **triple-tap with 2 fingers**.

### Mods in the menu

| Mod | Description |
|-----|-------------|
| BSDCsvPatches | Effects, music, themes patches |
| LeonCloneMod | Leon clone skin |
| SecretPinsMod | Unlocks secret pins |
| OldRankSystemMod | Restores old rank system |

### Requirements
- **macOS** with Xcode installed
- [`insert_dylib`](https://github.com/Tyilo/insert_dylib): `brew install insert_dylib`
- A patched IPA from Part 1

### Usage

```bash
# Make executable
chmod +x inject_dylib.sh

# Run (pass your patched IPA)
./inject_dylib.sh BrawlStars_67.264_iOS_MODDED.ipa
```

The script will:
1. Compile `ModMenu.m` → `ModMenu.dylib`
2. Extract the IPA
3. Copy the dylib into the app bundle
4. Inject it into the `laser` binary
5. Repack as `BrawlStars_MODDED_MENU.ipa`

Then sign and install with [Sideloadly](https://sideloadly.io/).

---

## Installation

### Free Apple ID (no jailbreak)
1. Download [Sideloadly](https://sideloadly.io/)
2. Connect iPhone via USB
3. Drag the modded IPA into Sideloadly
4. Enter your Apple ID → click **Start**
5. Trust the app: **Settings → General → VPN & Device Management**

> ⚠️ Free accounts expire every **7 days** — re-sign to keep playing.  
> Paid Developer account ($99/year) lasts 1 year.

---

## Notes

- APK and IPA files are **not included** (too large for GitHub)
- The mod menu toggle states are saved between sessions via `NSUserDefaults`
- This is for educational purposes only

---

## Credits

- BSD Framework by the BSD team
- iOS port by [faridikhuseynov1-ux](https://github.com/faridikhuseynov1-ux)
