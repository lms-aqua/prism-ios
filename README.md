# Prism iOS

An iOS 26+ SwiftUI app for https://prism.codystechcorner.com/ using WKWebView.
The website provides sign-in, library browsing, and playback. Cookies and website
storage persist across launches. The shell enables inline video, AirPlay, and
Picture in Picture; actual availability depends on the website player and media.

## Build with MobAI iOS Builder on Windows

`builder.json` selects the shared `Prism` Xcode scheme and an unsigned Debug build.
The official Builder v0.11.0 Windows executable is installed locally as
`.tools\builder.exe` (ignored by Git), with its release SHA256 checked at download.
Git must also be installed and available on PATH.

From PowerShell in this folder, after creating an empty GitHub repository:

```powershell
git init
git add .
git commit -m "Create Prism iOS app"
git branch -M main
git remote add origin https://github.com/lms-aqua/prism-ios.git
git push -u origin main
.\.tools\builder.exe auth github
.\.tools\builder.exe init
```

Review the generated workflows and commit/push them if `init` has not already
done so. `init` also fills in the GitHub owner/repository in `builder.json`.
Then build:

```powershell
.\.tools\builder.exe ios build --unsigned
```

For a remote simulator, create a MobAI API key in MobAI under Account > API Keys,
and add it to the GitHub repository's Actions secrets as `MOBAI_API_KEY`. Then:

```powershell
.\.tools\builder.exe ios share
```

Open the resulting CI Device in MobAI. An unsigned IPA cannot be installed
directly on an iPhone without signing; Builder documents signing and MobAI
installation options at https://github.com/MobAI-App/ios-builder.

## Xcode

Open `Prism.xcodeproj` and run the shared `Prism` scheme on an iPhone simulator.
Device builds require a signing team. No third-party Swift dependencies are used.

## First device/simulator checks

- Launch, sign in, browse your library, then relaunch and check sign-in persists.
- Play a movie; check inline and full-screen playback, rotation, scrubbing,
  audio/subtitles, AirPlay, and Picture in Picture where the player supports them.
- Follow a same-site link and swipe back; check external links open in Safari.
- Launch without connectivity and use Try again after restoring the connection.
- Check content near the notch and home indicator in portrait and landscape.

## Current limits

This is a website-backed first version, with no native library API or downloads.
A native library/player needs the site's documented authentication and media API
contract. Playback and login have not yet been verified on an iOS device.