# Payed Scripts Hub

**All-1 Lua launcher** for the 8 paid duel hubs, built to work on Xeno executor (v1.3.65) and other locked-down executors.

## What it does

- Embeds all 8 hub sources deflate-compressed + base64-encoded (1.2 MB source → 314 KB payload → 358 KB total)
- Runs **one hub at a time** — they are mutually incompatible (fight over WalkSpeed/AssemblyLinearVelocity, keybinds, ScreenGuis)
- Provides a polished UI with search, hover tints, gradient header, per-hub accent colors, RUNNING/STOP states, minimize-to-PS pill, and RightShift toggle with click-to-rebind
- Executor-safe: pcall-guarded service access, optional CoreGui, loadstring fallback chain, on-screen error panel

## Files

| File | Description |
|---|---|
| `PayedScriptsHub.lua` | The fused hub launcher (358 KB, 3959 lines) |
| `launcher.template.lua` | UI/wrapper template (the `--@@HUBS@@` marker gets replaced by the build script) |
| `build-hub.js` | Node build script — reads 8 `.txt` hub files, deflate+base64-encodes, injects into template |
| `inflate.lua` | Standalone raw DEFLATE + base64 decoder (bit32-first with fallback) — proven 8/8 round-trip byte-exact |
| `mock_roblox.lua` | Mock Roblox API for integration testing (fengari) |

## How it works (brief)

1. **Build**: `node build-hub.js` reads `*.txt` files from the folder, deflate-compresses each to raw bytes, base64-encodes them, and injects the payloads at the `--@@HUBS@@` marker in `launcher.template.lua`, producing `PayedScriptsHub.lua`.
2. **Run**: Execute `PayedScriptsHub.lua` in Roblox. The UI appears. Use `RightShift` to show/hide.
3. **Launch**: Click a hub's "LOAD" button. It:
   - Stops any currently running hub (removes its ScreenGuis + its `_G` flags)
   - Decompresses the selected hub's source
   - Compiles it with `loadstring()` (fallback chain: `loadstring → _G.loadstring → getgenv().loadstring → load`)
   - Runs it in a protected thread
   - Auto-hides the panel once the launched hub creates its ScreenGui
4. **Stop**: Click "STOP" to remove the running hub's GUIs and `_G` flags. (Heartbeat loops survive in pure Luau — rejoin for a clean slate.)

## Executor notes

- No service is touched without a `pcall`; `CoreGui` is optional (falls back to `PlayerGui` → `gethui()`)
- `loadstring()` is looked up through multiple fallbacks; if none exist, an on-screen error is shown
- The error panel draws the actual failure message instead of dying silently
- UI is parented to `PlayerGui` (with CoreGui fallback); `ResetOnSpawn = false`
- STOP only removes GUIs matching each hub's declared `guiSet` names — no accidental game-UI removal

## Requirements

- Roblox with Xeno executor (v1.3.65 tested) or compatible executor
- Must have `bit32` table (Roblox Luau has it natively)
- `loadstring` must be available (all mainstream executors provide it)

## Building from source

```bash
node build-hub.js
```

This reads all `*.txt` files in the folder, compresses them, and writes `PayedScriptsHub.lua`.

## Test results

- **47/47** integration tests passing (launch, stop, switch, search, rebind, minimize, drag, auto-hide)
- **8/8** hubs round-trip byte-exact (decompression produces the exact original `.txt` source)
- Hostile-environment tests passed: CoreGui denied, TweenService missing, panel dismissable