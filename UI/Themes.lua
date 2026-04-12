-- EbonholdGM | UI/Themes.lua
-- Color palette, font constants, and size tokens used by every UI file.

local GM = EbonholdGM
GM.UI.Theme = {}
local T = GM.UI.Theme

-- ---------------------------------------------------------------------------
-- Font paths (WoW 3.3.5a built-ins — always available)
-- ---------------------------------------------------------------------------
T.FONT_NORMAL  = "Fonts\\FRIZQT__.TTF"
T.FONT_BOLD    = "Fonts\\FRIZQT__.TTF"
T.FONT_MONO    = "Fonts\\MORPHEUS.TTF"

-- ---------------------------------------------------------------------------
-- Layout tokens
-- ---------------------------------------------------------------------------
T.SIDEBAR_W    = 52      -- sidebar icon column width
T.TITLEBAR_H   = 32      -- top title bar height
T.STATUSBAR_H  = 20      -- bottom status bar height
T.PAD          = 8       -- standard inner padding
T.CORNER_R     = 3       -- "corner radius" (approximated via textures)
T.BTN_H        = 22      -- standard button height
T.ROW_H        = 24      -- list row height
T.INPUT_H      = 22      -- edit box height

-- ---------------------------------------------------------------------------
-- Dark theme  (default)
-- ---------------------------------------------------------------------------
T.dark = {
    -- Window & panels
    BG           = { 0.055, 0.055, 0.07,  0.97 },  -- near-black blue-gray
    BG_PANEL     = { 0.08,  0.08,  0.10,  0.92 },  -- slightly lighter panel
    BG_ROW       = { 0.10,  0.10,  0.13,  0.85 },
    BG_ROW_ALT   = { 0.08,  0.08,  0.11,  0.85 },
    BG_ROW_HOV   = { 0.18,  0.16,  0.08,  0.90 },  -- golden hover
    BG_SIDEBAR   = { 0.035, 0.035, 0.05,  0.98 },
    BG_TITLEBAR  = { 0.035, 0.035, 0.05,  1.00 },
    BG_INPUT     = { 0.04,  0.04,  0.06,  1.00 },
    BG_BTN       = { 0.14,  0.12,  0.06,  0.90 },
    BG_BTN_HOV   = { 0.22,  0.18,  0.08,  0.95 },
    BG_BTN_PRESS = { 0.10,  0.08,  0.03,  1.00 },
    BG_DANGER    = { 0.35,  0.06,  0.06,  0.90 },
    BG_SUCCESS   = { 0.06,  0.25,  0.10,  0.90 },

    -- Borders
    BORDER       = { 0.22,  0.19,  0.10,  0.80 },  -- subtle gold tint
    BORDER_FOCUS = { 0.90,  0.75,  0.25,  1.00 },  -- bright gold when active
    BORDER_SEP   = { 0.15,  0.14,  0.10,  0.60 },  -- separator lines

    -- Text
    TEXT         = { 1.00,  1.00,  1.00,  1.00 },
    TEXT_DIM     = { 0.65,  0.65,  0.65,  1.00 },
    TEXT_HINT    = { 0.40,  0.40,  0.40,  1.00 },
    TEXT_ACCENT  = { 1.00,  0.82,  0.20,  1.00 },  -- gold
    TEXT_RED     = { 1.00,  0.35,  0.35,  1.00 },
    TEXT_GREEN   = { 0.40,  0.90,  0.45,  1.00 },
    TEXT_BLUE    = { 0.45,  0.75,  1.00,  1.00 },
    TEXT_ORANGE  = { 1.00,  0.60,  0.20,  1.00 },

    -- Sidebar tab
    TAB_NORMAL   = { 0.05,  0.05,  0.07,  1.00 },
    TAB_ACTIVE   = { 0.14,  0.12,  0.06,  1.00 },
    TAB_HOVER    = { 0.12,  0.10,  0.05,  1.00 },
    TAB_ACCENT   = { 0.90,  0.75,  0.25,  1.00 },  -- active tab left stripe
}

-- Light theme stub (mirrors dark with lighter values; swap in settings if desired)
T.light = T.dark   -- TODO: implement a full light palette if needed

--- Return the active color table based on Config.
function T:Get()
    local theme = GM.Config:GetNested("ui", "theme") or "dark"
    return self[theme] or self.dark
end

--- Shorthand: unpack a color array.
function T.RGBA(col)
    return col[1], col[2], col[3], col[4] or 1
end

--- SetColorTexture polyfill for WoW 3.3.5a (that API was added in 5.x).
-- Usage: T.SetSolidColor(texture, r, g, b, a)
function T.SetSolidColor(tex, r, g, b, a)
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetVertexColor(r or 1, g or 1, b or 1)
    tex:SetAlpha(a or 1)
end

--- Apply backdrop color + border to a frame using the active theme.
function T:ApplyPanel(frame, bgKey, borderKey)
    local c = self:Get()
    local bg  = c[bgKey     or "BG_PANEL"]
    local bdr = c[borderKey or "BORDER"]
    frame:SetBackdropColor(T.RGBA(bg))
    frame:SetBackdropBorderColor(T.RGBA(bdr))
end

-- Flat panel backdrop — solid bg + thin tooltip border (matches EchoBuddy pattern)
T.BACKDROP_FLAT = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 16,
    insets   = { left = 5, right = 5, top = 5, bottom = 5 },
}

-- Dialog-style backdrop for the main window (matches EchoBuddy mainFrame)
T.BACKDROP_DIALOG = {
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true, tileSize = 32, edgeSize = 32,
    insets   = { left = 11, right = 12, top = 12, bottom = 11 },
}
