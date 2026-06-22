# Noctalia Hermes Agent

A [Noctalia](https://github.com/noctalia-dev) plugin for [Hermes Agent](https://github.com/noctalia-dev/hermes-agent).

Shows Hermes status in the bar. Provides a chat panel with streaming responses, tool-event activity, approval prompts, and one-shot prompts. Adds a `>hermes` launcher provider. Supports driving a remote Hermes bridge over SSH.

## Screenshots

| Bar popup | Chat panel | Settings |
|---|---|---|
| ![Bar popup](plugin/screenshots/bar-popup.png) | ![Chat panel](plugin/screenshots/chat-panel.png) | ![Settings](plugin/screenshots/settings.png) |

## Requirements

- Hermes Agent on `PATH` (or set `hermesCommand` in settings)
- Noctalia 4.4.1 or newer

## Install

Copy the `plugin/` directory into your Noctalia plugins folder:

```bash
cp -r plugin/ ~/.config/noctalia/plugins/noctalia-hermes-agent/
```

Restart Noctalia. The plugin detects your Hermes home, gateway, and model on first run.

## How it works

A Python bridge (`scripts/hermes_bridge.py`) runs locally and exposes HTTP endpoints for health, state, session, prompt, interrupt, approvals, and one-shot commands. The QML surfaces talk to the bridge and render state from a watched state file.

## Client-only mode

Use this when Hermes runs on a remote server. The bridge stays on the server, bound to `127.0.0.1`. You forward it to the client over an SSH tunnel. The port is not exposed and the token does not travel in plaintext.

**Server** (where Hermes lives):

```bash
cd plugin/scripts
./hermes-bridge-serve.sh 19777
```

Copy the token it prints.

**Client**, open the tunnel:

```bash
ssh -L 19777:127.0.0.1:19777 user@server
```

**Plugin settings** (Advanced):

1. Enable Client-only mode
2. Set host to `127.0.0.1`, port to `19777`
3. Paste the token

In this mode the plugin does not spawn a local bridge. Gateway controls, model selection, sessions, approvals, and the launcher all drive the remote bridge.

### Troubleshooting

**Port already in use.** A local bridge from before you enabled client-only mode, or a stale tunnel. Free the port:

```bash
ss -ltnp | grep 19777
pkill -f hermes_bridge.py
```

**Bar pill stays grey.** The bridge reports `unknown` until a session runs or a status hook fires. If the gateway is running, the pill shows idle. If it stays unknown, the gateway is not running on the server.

**Verify the tunnel:**

```bash
curl -s 127.0.0.1:19777/health
curl -s -H "X-Bridge-Token: <token>" 127.0.0.1:19778/state
```

## Settings

| Setting | Default | Description |
|---|---|---|
| `bridgeHost` | `127.0.0.1` | Bridge host |
| `bridgePort` | `19777` | Bridge port |
| `stateFile` | `~/.cache/noctalia-hermes/state.json` | Shared state file |
| `hermesHome` | `~/.hermes` | Hermes home directory |
| `hermesCommand` | `hermes` | Hermes executable |
| `autoStartBridge` | `true` | Start the bridge when Noctalia loads (local mode) |
| `autoStartGateway` | `true` | Start the gateway when the bridge comes online |
| `clientOnlyMode` | `false` | Connect to a remote bridge over SSH |
| `bridgeTokenManual` | _(empty)_ | Bridge token (required in client-only mode) |
| `statusPollIntervalSec` | `30` | Status poll interval |
| `hideWhenIdle` | `false` | Hide the bar pill when idle |
| `launcherPrefix` | `>hermes` | Launcher command prefix |
| `panelPinned` | `false` | Pin the panel as a persistent side window |
| `showToolActivity` | `false` | Show compact tool-activity line |
| `defaultProvider` | _(empty)_ | Default provider |
| `defaultModel` | _(empty)_ | Default model |

## License

MIT