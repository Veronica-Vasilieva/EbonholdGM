## [1.1.1] - 2026-04-12

### Added
- **Minimum window size enforced**: `win:SetMinResize(520, 400)` prevents the resize handle from collapsing the window below a usable size. The layout breaks below these dimensions.

### Fixed
- **Saved size below minimum clamped on load**: If a SavedVariables entry stores a broken sub-minimum size (e.g. from dragging all the way to the left before this fix), it is now clamped to `WIN_MIN_W` / `WIN_MIN_H` at load time so the window always opens correctly.
- **Resize OnMouseUp double-clamps**: After releasing the resize handle the saved width/height are also clamped, preventing a bad value ever reaching SavedVariables.
- **Minimize restore used stale height**: The minimize button restored to `H` captured at build time. If the user had resized since then, the window snapped to the wrong height. Now saves `win._restoreH = win:GetHeight()` at minimize-time and restores that value.

## [1.1.0] - 2026-04-12

### Fixed
- **Macros — rows not selectable**: List rows were created as `Frame` without `EnableMouse(true)`, so `OnMouseDown` never fired, `_selectedIndex` was never set, and the Delete button always had no target. Changed rows to `Button` type, added `EnableMouse(true)`, and switched the handler from `OnMouseDown` to `OnClick` for reliable input in 3.3.5a.

## [1.0.9] - 2026-04-12

### Fixed
- **Scroll frames overflowing panel bottom**: All three scroll-frame `BOTTOMRIGHT` anchors had a negative Y offset, which moves the bottom edge *below* the parent panel in WoW's coordinate system (Y increases upward). Fixed in Chat, Commands, and Teleport modules by flipping the sign to positive, keeping all content inside the main window.

## [1.0.8] - 2026-04-12

### Fixed
- **Full ASCII sweep**: Removed all remaining non-ASCII characters from every `.lua` file. WoW 3.3.5a renders multi-byte characters as `?`. Replacements across 8 files:
  - `…` -> `...` (Utils, MainFrame, Commands, Players, Chat, Teleport, Tickets, Macros)
  - `—` (em dash) -> `-` (MainFrame, Init, Players, Tickets)
  - `□` -> `[+]` (MainFrame minimize-restore button)
  - `💾` -> removed (Macros Save button)
  - `📍` -> removed (Teleport Save Here button)
  - `✕` -> `X` (Teleport delete row button)

## [1.0.7] - 2026-04-12

### Fixed
- **Players — "Use Target" button outside window**: The search input's right anchor was only `-PAD-60` from the panel edge, leaving only 68px for buttons. Search (56px) + Use Target (80px) + gaps (8px) = 144px required. Extended the input right offset to `-PAD-148` so both buttons fit inside the frame.

## [1.0.6] - 2026-04-12

### Fixed
- **Unicode characters rendered as `?`**: WoW 3.3.5a cannot render multi-byte Unicode. Replaced all occurrences across 5 files:
  - `★` / `☆` → `*` / `-` (Commands.lua: Favs button label, favorite star per-row)
  - `⟳` → removed (Tickets.lua: Refresh button)
  - `→` → `->` (Tickets.lua: assigned-to display; Teleport.lua: Send button)
  - `▶` → `>` (Macros.lua: Run and Run Now buttons)
  - `⚙` → `[S]` (Chat.lua: Keywords button)

## [1.0.5] - 2026-04-12

### Fixed
- **Commands category tabs overflow**: "Teleport" and "Tickets" category filter buttons were rendered outside the right edge of the window. The 15 category buttons summed to ~887px but the content area is only 768px (820 window − 52 sidebar). Reduced per-character width multiplier from 7→6 and padding from 12→8, reducing total to ~718px which fits comfortably.

## [1.0.4] - 2026-04-12

### Fixed
- **Window config key mismatch**: `UI:Build()` read `cfg:GetNested("ui", "width/height")` but window dimensions are stored under the `"window"` section — always fell back to hardcoded values. Fixed key lookup to `"window"`.
- **Default window height too short**: Increased from 570 → 640 to ensure all 6 sidebar module buttons fit within the frame.

## [1.0.3] - 2026-04-12

### Fixed
- **Root cause of blank window — `SetShown` crash**: `hint:SetShown(...)` inside `UI:CreateInput` was called immediately (not just in event handlers) at the end of every input box creation. `SetShown` does not exist in WoW 3.3.5a (added in 4.x). This crashed `UI:Build()` right after the minimize button was created — before the sidebar frame, content area, `BuildSidebar()`, or any module panels were ever reached. Replaced with `if … then hint:Show() else hint:Hide() end`.
- **`ChatFrame_SendTell` doesn't exist in 3.3.5a**: Replaced all three call-sites (Players, Tickets, Chat modules) with the 3.3.5a pattern: pre-filling `DEFAULT_CHAT_FRAME.editBox` with `/w <name> ` and calling `:SetFocus()`.

## [1.0.2] - 2026-04-12

### Fixed
- **Critical crash — blank window interior**: `_tabButtons[nil] = btn` in `Commands.lua` (the "All" category button stored its reference with a `nil` key). Lua 5.1 throws "table index is nil" here, which unwound the entire `CreatePanel → BuildSidebar → UI:Build()` call stack. Fixed by using `_tabButtons[catName or "__all"]`.
- **Scroll child zero-width rows**: `child:SetWidth(sf:GetWidth() or 200)` evaluated to `child:SetWidth(0)` at panel-creation time because `GetWidth()` returns 0 before the scroll frame is anchored and sized. Replaced with an `OnSizeChanged` handler that keeps the child width in sync. All TOPRIGHT-anchored rows are now correctly sized.
- **Backdrop textures**: `T.BACKDROP_FLAT` used `Interface\\Buttons\\WHITE8X8` as `bgFile`. The working EchoBuddy addon shows WHITE8X8 is only used via `SetTexture`, not as a backdrop `bgFile`. Changed `BACKDROP_FLAT` to `UI-Tooltip-Background` + `UI-Tooltip-Border` and updated main window to use `BACKDROP_DIALOG` (`UI-DialogBox-Background` + `UI-DialogBox-Border`), matching the confirmed-working pattern.
- **Panel crash isolation**: Wrapped `mod:CreatePanel()` calls in `pcall` in `Sidebar.lua` so future per-module errors print to chat and do not abort the entire sidebar build.

## [1.0.1] - 2026-04-12

### Fixed
- Replaced all `SetColorTexture` calls (added in WoW 5.x) with a `T.SetSolidColor` polyfill that uses `SetTexture` + `SetVertexColor` + `SetAlpha` — the 3.3.5a-compatible equivalent. This was causing a silent Lua crash on `UI:Build()` before the sidebar, content area, and status bar were created, resulting in a completely empty window interior.

---

## [1.0.0] - 2026-04-12

### Added
- Initial release of EbonholdGM — professional GM & admin control panel for TrinityCore/AzerothCore 3.3.5a
- **Core architecture**: modular plugin registry, centralized event dispatcher, SavedVariables config system
- **UI framework**: dark-themed component library (panels, buttons, inputs, scroll frames, rows, separators, section headers) with a reusable Theme color palette
- **Main window**: draggable/resizable 820×570 window with title bar, sidebar navigation, content area, status bar with live coordinates, and minimize/restore
- **Sidebar**: icon tab system — click to switch between modules; active tab highlighted with gold stripe
- **Global search bar**: top-of-window search that delegates to the active module's `OnSearch` handler
- **Commands module**: VSCode-style searchable command palette with 70+ TrinityCore commands organized by category (GM Mode, Account, Character, Modify, Teleport, NPC, GameObject, Items, Spells, Server, Tickets, Ban/Kick, Lookup). Features live filter, category tab buttons, favorites (★), recent commands list, parameter-prompt popup, and danger confirmation for destructive commands
- **Players module**: player search by name or current target; info card (level, class, race, zone, online status); 12 quick-action buttons (Teleport To, Summon, Whisper, Send Message, Freeze/Unfreeze, Mute, Set Level, Give Money, Lookup, Kick, Ban)
- **Tickets module**: auto-refreshes `.ticket list` on open; parses CHAT_MSG_SYSTEM responses into scrollable ticket rows with status color stripes; detail panel with player message, GM notes, and action buttons (Go To Player, Summon, Whisper, Claim, Respond, Close)
- **Chat module**: rolling 200-message log capturing Say/Yell/Whisper/Guild/Channel/System; keyword highlighting with alert sound; per-channel filter tabs; text search; hover reveals instant action row (Tele/Whisper/Mute); click sender name to jump to Players panel; configurable keyword list via popup
- **Teleport module**: searchable list of 80+ built-in zone/city/raid teleport locations; custom location save (`.tele add`); per-row Go (self) and Send → (target) buttons; live coordinate display; raw `.go x y z` input bar
- **Macros module**: create/edit/delete multi-command GM macros persisted in SavedVariables; up to 12 commands per macro; one-click Run and Save+Run; list panel with row-level ▶ Run shortcut
- Slash commands: `/egm` (toggle window), `/egm reset` (wipe DB), `/egm version`
