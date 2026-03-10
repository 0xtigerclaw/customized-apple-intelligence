# RightClickWriter

RightClickWriter is a macOS menu bar app for cross-app writing help.

It gives you:
- `Cmd+G` for fast rewrite of copied text
- `Cmd+H` for reply drafting from selected text
- cloud-first inference (`gpt-oss:120b-cloud`)
- local fallback (`qwen3:4b`)
- preview-before-replace workflow
- optional right-click Service support in apps that expose macOS Services

## Requirements

- macOS 14+
- Xcode 16+ or Swift 6+
- [Ollama](https://ollama.com/download) installed
- Accessibility permission for `RightClickWriter.app`

## Installation

```bash
git clone https://github.com/0xtigerclaw/customized-apple-intelligence.git
cd customized-apple-intelligence
./Scripts/bootstrap_ollama.sh
./Scripts/run_app.sh
```

What these scripts do:
- `bootstrap_ollama.sh`
  - checks Ollama availability
  - validates cloud model visibility
  - pulls local fallback model (`qwen3:4b`)
- `run_app.sh`
  - builds the app
  - creates/updates `RightClickWriter.app`
  - signs with stable bundle id `io.rightclickwriter.RightClickWriter`
  - refreshes Services registration
  - launches the app

## First-Run Permissions

RightClickWriter needs Accessibility access for cross-app selection and insertion.

1. Open `System Settings` -> `Privacy & Security` -> `Accessibility`.
2. Ensure `RightClickWriter.app` is listed and enabled.
3. If permission appears broken, reset once:

```bash
tccutil reset Accessibility io.rightclickwriter.RightClickWriter
./Scripts/run_app.sh
```

## Usage

### 1) Rewrite copied text (`Cmd+G`)

1. Copy text (`Cmd+C`) in any app.
2. Press `Cmd+G`.
3. Review output in the panel.
4. Choose `Copy Output` or `Replace in App`.

### 2) Draft a reply from selected text (`Cmd+H`)

1. Select the incoming message text.
2. Press `Cmd+H`.
3. The app generates a concise, ready-to-send reply.
4. Copy or insert from the panel.

Notes:
- If selected text APIs fail in an app, RightClickWriter tries a safe `Cmd+C` capture fallback.
- If no real selection is detected, it shows a clear error instead of using stale clipboard text.

### 3) Menu bar actions

Menu items include:
- `Rewrite Copied Text (<current mode>)`
- mode switcher (`Friendly`, `Professional`, `Break It Down`)
- `Open Preview Panel`
- `Open Settings`

## Inference Routing

Default route:
1. `Ollama Cloud` using `gpt-oss:120b-cloud` (about 10-12s timeout)
2. `Ollama Local` using `qwen3:4b` fallback

Manual premium route:
- `Upgrade with Clawd` calls:
  - `clawdbot` from `CLAWDBOT_PATH` or `/usr/local/bin/clawdbot`
  - working directory from `CLAWDBOT_WORKDIR` or `$HOME`

## Right-Click Context Menu Support

The app registers an `NSServices` action (`Rewrite with Right-Click Writer`), but macOS limits where it appears.

- In supported apps, you may see it under `Services` in the context menu.
- Many custom context menus (common in Electron/webview apps) do not expose Services.

So universal behavior is driven by hotkeys (`Cmd+G`, `Cmd+H`) and the menu bar app.

## Spotlight Launcher (Optional)

You can keep Spotlight on `Cmd+Space` and still trigger rewrite:

```bash
./Scripts/install_spotlight_launcher.sh
```

Then:
1. `Cmd+Space`
2. Type `Rewrite Clipboard`
3. Press `Enter`

## Development

Project structure:
- `Sources/RightClickWriter/App` app lifecycle, coordinator, status bar
- `Sources/RightClickWriter/Accessibility` selection read/replace and fallbacks
- `Sources/RightClickWriter/Inference` providers and routing
- `Sources/RightClickWriter/UI` panel and settings
- `Sources/RewriteClipboardLauncher` Spotlight helper app
- `Scripts` bootstrap/build/install helpers

Run tests:

```bash
cd customized-apple-intelligence
swift test
```

Current test coverage includes:
- prompt generation
- provider routing and fallback
- Clawdbot response parsing
- insertion fallback behavior

## Privacy

- No persistent raw-text logging.
- Logs are metadata-only (trigger/provider/latency/lengths).
- Secure input fields are intentionally blocked.
