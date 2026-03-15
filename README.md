# R-1010

R-1010 is a macOS rhythm machine app backed by SuperCollider.

The app uses:

- SwiftUI for the macOS GUI
- `sclang` for script evaluation and runtime bridging
- `scsynth` for audio generation and transport timing

## Status

Current implementation includes:

- SuperCollider dependency discovery on app launch
- Live `sclang` / `scsynth` runtime boot
- A preview-only scheme that skips runtime boot
- Pattern/page-based step sequencing
- Atomic live resync for pattern/page/clear changes
- Voice editor with `engine`, `preset`, `tap`, and sound parameters
- Settings window with `color mode` selection

## Requirements

- macOS 14 or later
- Xcode with Swift 6 support
- SuperCollider installed

SuperCollider is searched in these locations:

- `R1010_SCLANG_PATH` / `R1010_SCSYNTH_PATH`
- `/Applications/SuperCollider.app`
- `~/Applications/SuperCollider.app`
- Homebrew Cask directories
- `/opt/homebrew/bin` and `/usr/local/bin`

## Open And Run

Open the project:

```bash
open R1010.xcodeproj
```

Build from the command line:

```bash
xcodebuild -project R1010.xcodeproj -scheme R1010 -configuration Debug build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO
```

Preview-only build:

```bash
xcodebuild -project R1010.xcodeproj -scheme 'R1010 Preview' -configuration Debug build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO
```

Run tests:

```bash
xcodebuild -project R1010.xcodeproj -scheme R1010 -destination platform=macOS test CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO
```

If you change `project.yml`, regenerate the project with:

```bash
xcodegen generate
```

## Project Structure

- `Sources/R1010App`: app source code
- `docs/app-spec.md`: product specification
- `docs/ui-design.md`: UI design notes
- `docs/supercollider-runtime-design.md`: runtime design notes
- `r1010-design.pen`: design source
- `project.yml`: XcodeGen project definition

## Notes

- `R1010` is the internal project/module/target name.
- `R-1010` is the displayed app name.
- The `R1010 Preview` scheme skips SuperCollider boot by setting `R1010_SKIP_RUNTIME_BOOT=1`.

## License

MIT. See `LICENSE`.
