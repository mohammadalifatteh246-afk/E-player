# Feature 15 Implementation Plan: Telnet / TCP Socket CLI Remote Control (VLC rc.c Parity)

## Objective
Implement VLC's famous interactive Command-Line / Telnet Remote Control interface (`rc.c` / `cli.c`) over a local TCP socket (default port `4212`), allowing external CLI tools, scripts, home automation systems, Stream Decks, and terminal users (`nc 127.0.0.1 4212` or `telnet 127.0.0.1 4212`) to query status and control playback in real-time. Also provide an in-app Cyberpunk Terminal HUD console for live command monitoring and configuration.

---

## 4-Pillar REA Architecture Breakdown

### Pillar 1: Spec & Models (`app/lib/features/telnet_rc/domain/telnet_rc_models.dart`)
- **`TelnetServerConfig`**:
  - `port`: Default `4212` (VLC default rc port).
  - `bindAddress`: `127.0.0.1` (loopback security) with option for LAN.
  - `motdBanner`: Cyberpunk E-Player CLI banner.
- **`TelnetCommandLog`**:
  - `timestamp`: DateTime.
  - `direction`: `incoming` (from client) or `outgoing` (reply from E-Player).
  - `text`: Raw command or formatted reply string.
  - `clientId`: Client identifier / socket address.
- **`TelnetServerStatus`**:
  - `isRunning`: bool.
  - `port`: int.
  - `activeClients`: int.
  - `address`: String.
  - `totalCommandsProcessed`: int.
- **`TelnetClientSession`**:
  - `id`: Unique int session ID.
  - `remoteAddress`: Socket address.
  - `connectedAt`: DateTime.

### Pillar 2: TCP Socket Engine & Command Parser (`app/lib/features/telnet_rc/data/telnet_rc_service.dart`)
- **`TelnetRcService`** (ChangeNotifier):
  - Manages `ServerSocket` lifecycle (`start(port)`, `stop()`).
  - Welcome banner sent upon client connection:
    ```
    +----[ Remote Control CLI Interface - E-Player v1.0 ]
    | Type `help` for command list. Type `quit` to disconnect.
    +----[ Ready ]
    > 
    ```
  - Parses CRLF/LF line streams and executes VLC `rc.c` command vocabulary:
    - `play`, `pause`, `stop`, `is_playing`, `status`
    - `seek <seconds|offset|percent>` (`seek 60`, `seek +10`, `seek -10`, `seek 50%`)
    - `step` / `frame_step`
    - `volume [<0..300>]`, `volup [<delta>]`, `voldown [<delta>]`, `mute`
    - `get_time`, `get_length`, `get_title`
    - `aspect <ratio>`, `fullscreen [on|off|toggle]`
    - `atrack [next|<id>]`, `strack [next|<id>]`, `ab_repeat`
    - `add <url_or_path>`, `enqueue <url_or_path>`, `playlist`, `clear`
    - `info`, `help`, `quit` / `logout`, `shutdown`
  - Maintains in-memory circular buffer (last 100 entries) of `TelnetCommandLog`.
  - Emits real-time log events via `StreamController<TelnetCommandLog>.broadcast()`.

### Pillar 3: Cyberpunk Terminal Sheet & Monitoring UI (`app/lib/features/telnet_rc/ui/telnet_rc_sheet.dart`)
- Cyberpunk styled modal bottom sheet:
  - **Server Controls Header**:
    - Online/Offline glowing status chip.
    - Start / Stop toggle switch.
    - Port indicator with copy command button (`nc 127.0.0.1 4212`).
    - Connected client counter.
  - **Live Monospace Terminal Window**:
    - Green/cyan CRT-style log display with auto-scroll.
    - Displays client connects/disconnects, incoming commands, and outputs.
    - Quick "Clear Terminal" action.
  - **Interactive CLI Command Bar**:
    - Text field allowing the user to type and execute CLI commands directly from the sheet (e.g. `status`, `seek +30`, `volume 150`, `help`).

### Pillar 4: Player Integration & Shortcuts
- Wire into `PlayerScreen`:
  - `_telnetRcService` lifecycle (init, dispose).
  - Status provider and player execution callbacks wired to libmpv / PlayerState.
  - HUD quick options menu item: `hud_telnet_rc_button` (Terminal icon).
  - Keyboard shortcut: `Ctrl+Shift+T` (`onOpenTelnetRc` in `desktop_keyboard_handler.dart`).

---

## Verification Plan

### Automated Unit & Integration Tests:
- `app/test/unit/telnet_rc_service_test.dart`:
  - Server start & stop lifecycle.
  - TCP client connection and banner reception.
  - Command dispatch & parsing:
    - `play`, `pause`, `stop`, `is_playing`
    - `seek` parsing (seconds, relative, percent)
    - `volume`, `volup`, `voldown` (0-300% range)
    - `get_time`, `get_length`, `get_title`
    - `help`, `quit`
  - Multi-client handling and disconnect cleanup.
- `app/test/unit/telnet_rc_widget_test.dart`:
  - `TelnetRcSheet` rendering with online/offline state.
  - Start/stop button interaction.
  - Monospace terminal log rendering.
  - Interactive test command input field execution.

### Static Analysis:
- `cd app; flutter analyze --no-pub` (Must pass with 0 errors, 0 warnings).
