# PrimateAudio

A native macOS GUI for [Monkey's Audio](https://www.monkeysaudio.com/) (`.ape` / `.mac`)
lossless files, written in Swift with AppKit. PrimateAudio is a thin Cocoa front-end
over the official Monkey's Audio Codec library (**libMAC**): it does not reimplement
the codec, it drives the same library the official tools use.

> **Unofficial project.** PrimateAudio is not affiliated with, sponsored by, or
> endorsed by Monkey's Audio or Matthew T. Ashland. "Monkey's Audio" is a
> trademark of its respective owner. See [Licensing](#licensing).

## Features

- **Compress** — WAV → APE
- **Decompress** — APE → WAV
- **Verify** — integrity check an APE/MAC file
- **Convert** — APE → APE, re-encoded at the selected compression level
- **Make APL** — generate `.apl` image-link files; from a `.cue` sheet it emits one
  `.apl` per track, from an APE/MAC it emits a single whole-file `.apl`
- Compression levels: Fast, Normal, High, Extra High, Insane
- Batch a list of files with per-file status
- Native app menu, About panel with license/credits

## Requirements

- macOS 12.0 or later
- Apple Silicon (**arm64**) — the bundled `libMAC` dylib is arm64-only
- To **build**: Xcode command line tools and the libMAC headers/library:
  ```sh
  brew install mac
  ```
  libMAC is used at link time and is copied into the app bundle at build time, so
  the built app does not depend on Homebrew at runtime.

## Building

```sh
git clone https://github.com/mattwaltbriggs/PrimateAudio.git
cd PrimateAudio
xcodebuild -project PrimateAudio.xcodeproj -scheme PrimateAudio -configuration Release
```

Or open `PrimateAudio.xcodeproj` in Xcode and press Run. The product is
`PrimateAudio.app`.

The build embeds `libMAC.17.dylib` into `PrimateAudio.app/Contents/Frameworks/` and
rewrites its install name to `@rpath/libMAC.17.dylib`, so the result is self-contained.

## Installing a release build

Pre-built zips are published on the [Releases page](https://github.com/mattwaltbriggs/PrimateAudio/releases).

These builds are **not signed with a Developer ID or notarized by Apple**, so macOS
Gatekeeper will warn on first launch. To open it anyway:

1. Unzip and move `PrimateAudio.app` to `/Applications`.
2. **Right-click → Open**, then confirm. (Or: **System Settings → Privacy & Security
   → Open Anyway**.)
3. Alternatively, clear the quarantine flag:
   ```sh
   xattr -dr com.apple.quarantine /Applications/PrimateAudio.app
   ```

## Usage

1. **Add** files (`.wav`, `.ape`, `.mac`, `.cue`) to the list with the **Add** button.
2. Choose an operation (Compress / Decompress / Verify / Convert / Make APL) and a
   compression level where applicable.
3. Click **Run** (or the equivalent action). Output is written next to the input file
   and listed in the status column.

## Architecture

- `AppDelegate.swift` — main menu, About window (license + credits)
- `ViewController.swift` — the file list UI and operation dispatch
- `MACProcessor.swift` — Swift bridges to libMAC (`@_silgen_name`), wide-string
  helpers, and the APL/APE-tag writers
- `Main.storyboard` — window, table view, and controls

On macOS `wchar_t` is UTF-32, so all strings crossing the libMAC boundary are
converted to NUL-terminated UTF-32 code units.

## Licensing

PrimateAudio is released under the **MIT License** — see [LICENSE](LICENSE).
Copyright © 2026 Matthew Briggs.

It **bundles** the Monkey's Audio Codec library (libMAC), distributed under its own
**3-clause BSD license**, Copyright © 2000–2026 Matthew T. Ashland. The full text is
reproduced in [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt) and shown in the
app's About window.

The BSD license permits redistribution of the library in binary form provided the
copyright notice, the list of conditions, and the disclaimer are reproduced. It also
states that the copyright holder's name may not be used to endorse or promote
derived products without permission — hence the prominent "unofficial" notice above.