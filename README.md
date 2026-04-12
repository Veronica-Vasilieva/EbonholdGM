# EbonholdGM

Professional GM & Admin control panel for WoW 3.3.5a (TrinityCore / AzerothCore).

![Version](https://img.shields.io/badge/version-1.0.6-gold)
![Interface](https://img.shields.io/badge/interface-30300-blue)
![WoW](https://img.shields.io/badge/WoW-3.3.5a-blueviolet)

---

## Features

### Commands
VSCode-style searchable command palette with 70+ TrinityCore commands organized by category. Live filter, category tabs (GM Mode, Account, Character, Modify, Teleport, NPC, GameObject, Items, Spells, Server, Tickets, Ban/Kick, Lookup, Mail), favorites (`*`), recent commands list, parameter-prompt popup, and danger confirmation for destructive commands.

### Players
Player search by name or current target. Info card showing level, class, race, zone, and online status. Quick-action buttons: Teleport To, Summon, Whisper, Send Message, Freeze/Unfreeze, Mute, Set Level, Give Money, Lookup, Kick, Ban.

### Tickets
Auto-refreshes `.ticket list` on open. Parses `CHAT_MSG_SYSTEM` responses into a scrollable ticket list with status color stripes. Detail panel with player message, GM notes, and action buttons (Go To Player, Summon, Whisper, Claim, Respond, Close).

### Chat Monitor
Rolling 200-message log capturing Say/Yell/Whisper/Guild/Channel/System. Keyword highlighting with alert sound. Per-channel filter tabs. Text search. Hover reveals instant action row (Teleport/Whisper/Mute). Click sender name to jump to Players panel. Configurable keyword list.

### Teleport
Searchable list of 80+ built-in zone/city/raid teleport locations. Custom location save (`.tele add`). Per-row Go (self) and Send (target) buttons. Live coordinate display. Raw `.go x y z` input bar.

### Macros
Create, edit, and delete multi-command GM macro sequences, persisted in SavedVariables. Up to 12 commands per macro. One-click Run and Save+Run. List panel with per-row quick Run shortcut.

---

## Installation

1. Download the latest zip from the [Releases](../../releases) page
2. Extract into your `Interface/AddOns/` folder
3. **The folder must be named `EbonholdGM` exactly** — rename if your zip tool used a different name
4. `/reload` in-game

> Tested on Project Ebonhold (Valanior) — TrinityCore 3.3.5a

---

## Usage

| Command | Action |
|---|---|
| `/egm` | Toggle the main window |
| `/egm version` | Print current version to chat |
| `/egm reset` | Wipe SavedVariables (reload required) |

---

## Architecture

```
EbonholdGM/
  Core/
    Init.lua        -- Namespace, module registry, slash commands, bootstrap
    Config.lua      -- SavedVariables loading, defaults, nested accessors
    Events.lua      -- Central pub/sub event dispatcher
  Utils/
    Utils.lua       -- Trim, Split, Contains, ExecCommand, InputPopup, AddTooltip
  UI/
    Themes.lua      -- Color palette, layout tokens, backdrop definitions, SetSolidColor polyfill
    Components.lua  -- Panel, Label, Button, IconButton, Input, ScrollFrame, Row, SectionHeader
    MainFrame.lua   -- Root window: titlebar, sidebar slot, content area, status bar, resize handle
    Sidebar.lua     -- Icon tab strip; SwitchModule()
  Modules/
    Commands.lua    -- Command palette
    Players.lua     -- Player management
    Tickets.lua     -- Ticket system
    Chat.lua        -- Chat monitor
    Teleport.lua    -- Teleport tools
    Macros.lua      -- Macro builder
```

Modules self-register via `EbonholdGM:RegisterModule(name, module)`. Each module provides:
- `title` — display name
- `OnLoad()` — called once after PLAYER_LOGIN
- `CreatePanel(parent)` — returns a Frame filling the content area
- *(optional)* `OnSearch(text)` — receives global search bar input
- *(optional)* `OnShow()` — called when the module tab is activated

---

## WoW 3.3.5a Compatibility

This addon is written strictly for the 3.3.5a API. Notable compatibility decisions:

- `SetColorTexture` does not exist — solid colours use `SetTexture("WHITE8X8")` + `SetVertexColor` + `SetAlpha`
- `SetShown(bool)` does not exist — replaced with explicit `Show()`/`Hide()` branches
- `ChatFrame_SendTell` does not exist — whispers use `DEFAULT_CHAT_FRAME.editBox:SetText("/w name ")` + `:SetFocus()`
- Multi-byte Unicode characters render as `?` — all labels use ASCII equivalents
- Zero XML, zero Ace libraries, zero external dependencies

---

## SavedVariables

`EbonholdGM_DB` stores:

| Key | Contents |
|---|---|
| `window` | Last position and size |
| `chatKeywords` | Keyword alert list |
| `customLocations` | User-saved teleport locations |
| `macros` | Saved GM macro sequences |
| `favCommands` | Starred command palette entries |
| `recentCommands` | Last 20 executed commands |
| `activeModule` | Last open tab |

---

## License

MIT — free to use, modify, and redistribute.
