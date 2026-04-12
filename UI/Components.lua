-- EbonholdGM | UI/Components.lua
-- Reusable UI widget factory. Every visual element is built from here so
-- theming is centralized and consistent.

local GM   = EbonholdGM
local UI   = GM.UI
local T    = GM.UI.Theme
local Utils = GM.Utils

local _uid = 0
local function UID(prefix)
    _uid = _uid + 1
    return (prefix or "EGMGM") .. _uid
end

-- ---------------------------------------------------------------------------
-- Panel  (styled backdrop frame)
-- ---------------------------------------------------------------------------

--- Create a styled panel frame.
-- @param parent  Frame
-- @param bgKey   Theme color key (default "BG_PANEL")
-- @param bdrKey  Theme border key (default "BORDER")
function UI:CreatePanel(parent, bgKey, bdrKey)
    local f = CreateFrame("Frame", UID("EGMPanel"), parent)
    f:SetBackdrop(T.BACKDROP_FLAT)
    T:ApplyPanel(f, bgKey or "BG_PANEL", bdrKey or "BORDER")
    return f
end

-- ---------------------------------------------------------------------------
-- Label  (FontString wrapper)
-- ---------------------------------------------------------------------------

--- Create a label (FontString).
-- @param size    number   font size (default 11)
-- @param colorKey  string  theme text key (default "TEXT")
function UI:CreateLabel(parent, text, size, colorKey)
    local c  = T:Get()
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(T.FONT_NORMAL, size or 11)
    local col = c[colorKey or "TEXT"]
    fs:SetTextColor(T.RGBA(col))
    fs:SetText(text or "")
    return fs
end

--- Create a title label (larger, accent color).
function UI:CreateTitle(parent, text)
    local c  = T:Get()
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(T.FONT_BOLD, 13, "OUTLINE")
    local col = c.TEXT_ACCENT
    fs:SetTextColor(T.RGBA(col))
    fs:SetText(text or "")
    return fs
end

-- ---------------------------------------------------------------------------
-- Separator  (horizontal rule)
-- ---------------------------------------------------------------------------

function UI:CreateSeparator(parent, width)
    local c   = T:Get()
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    if width then sep:SetWidth(width) end
    T.SetSolidColor(sep, T.RGBA(c.BORDER_SEP))
    return sep
end

-- ---------------------------------------------------------------------------
-- Button  (styled push button)
-- ---------------------------------------------------------------------------

--- Create a styled text button.
-- @param text      string
-- @param danger    bool   if true, uses red color scheme
-- @param onClick   function
function UI:CreateButton(parent, text, danger, onClick)
    local c   = T:Get()
    local btn = CreateFrame("Button", UID("EGMBtn"), parent)
    btn:SetHeight(T.BTN_H)

    -- backdrop
    btn:SetBackdrop(T.BACKDROP_FLAT)
    local bg  = danger and c.BG_DANGER  or c.BG_BTN
    local bdr = danger and c.TEXT_RED   or c.BORDER
    btn:SetBackdropColor(T.RGBA(bg))
    btn:SetBackdropBorderColor(T.RGBA(bdr))

    -- label
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetFont(T.FONT_BOLD, 11)
    lbl:SetAllPoints()
    lbl:SetJustifyH("CENTER")
    local textCol = danger and c.TEXT_RED or c.TEXT_ACCENT
    lbl:SetTextColor(T.RGBA(textCol))
    lbl:SetText(text or "")
    btn._label = lbl

    -- hover / press highlights
    btn:SetScript("OnEnter", function(self)
        local hbg = danger and { 0.45, 0.08, 0.08, 0.95 } or c.BG_BTN_HOV
        self:SetBackdropColor(T.RGBA(hbg))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T.RGBA(bg))
    end)
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(T.RGBA(c.BG_BTN_PRESS))
    end)
    btn:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(T.RGBA(bg))
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

--- Create an icon-only button (for toolbars / sidebar).
-- @param iconPath  string  texture path or nil
-- @param tooltip   string
function UI:CreateIconButton(parent, iconPath, tooltip, onClick)
    local c   = T:Get()
    local btn = CreateFrame("Button", UID("EGMIconBtn"), parent)
    btn:SetSize(T.SIDEBAR_W - 8, T.SIDEBAR_W - 8)
    btn:SetBackdrop(T.BACKDROP_FLAT)
    btn:SetBackdropColor(T.RGBA(c.TAB_NORMAL))
    btn:SetBackdropBorderColor(0, 0, 0, 0)

    if iconPath then
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(iconPath)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        btn._icon = tex
    else
        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(T.FONT_BOLD, 18, "OUTLINE")
        lbl:SetAllPoints()
        lbl:SetJustifyH("CENTER")
        lbl:SetTextColor(T.RGBA(c.TEXT_DIM))
        lbl:SetText("?")
        btn._label = lbl
    end

    -- active stripe on the left
    local stripe = btn:CreateTexture(nil, "ARTWORK")
    stripe:SetWidth(3)
    stripe:SetPoint("TOPLEFT")
    stripe:SetPoint("BOTTOMLEFT")
    T.SetSolidColor(stripe, T.RGBA(c.TAB_ACCENT))
    stripe:Hide()
    btn._stripe = stripe

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T.RGBA(c.TAB_HOVER))
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, 1, 0.82, 0, 1)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        local isCur = (GM.UI.activeModule and GM.UI.activeModule._name == self._moduleName)
        self:SetBackdropColor(isCur and T.RGBA(c.TAB_ACTIVE) or T.RGBA(c.TAB_NORMAL))
        GameTooltip:Hide()
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

-- ---------------------------------------------------------------------------
-- EditBox  (styled input field)
-- ---------------------------------------------------------------------------

--- Create a styled input box.
-- @param placeholder  string  hint text shown when empty
-- @param onEnter      function  called with (text) when Enter is pressed
-- @param onChange     function  called with (text) on every keystroke
function UI:CreateInput(parent, placeholder, onEnter, onChange)
    local c = T:Get()

    local container = CreateFrame("Frame", UID("EGMInputCont"), parent)
    container:SetHeight(T.INPUT_H)
    container:SetBackdrop(T.BACKDROP_FLAT)
    container:SetBackdropColor(T.RGBA(c.BG_INPUT))
    container:SetBackdropBorderColor(T.RGBA(c.BORDER))

    local eb = CreateFrame("EditBox", UID("EGMInput"), container)
    eb:SetPoint("TOPLEFT",     container, "TOPLEFT",  4, -2)
    eb:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 2)
    eb:SetFont(T.FONT_NORMAL, 11)
    eb:SetTextColor(T.RGBA(c.TEXT))
    eb:SetCursorPosition(0)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(256)

    -- placeholder
    local hint = container:CreateFontString(nil, "OVERLAY")
    hint:SetFont(T.FONT_NORMAL, 11)
    hint:SetTextColor(T.RGBA(c.TEXT_HINT))
    hint:SetText(placeholder or "")
    hint:SetPoint("LEFT", eb, "LEFT", 0, 0)

    local function updateHint()
        -- SetShown doesn't exist in WoW 3.3.5a
        if eb:GetText() == "" then hint:Show() else hint:Hide() end
    end

    eb:SetScript("OnTextChanged", function(self, userInput)
        updateHint()
        if onChange and userInput then onChange(self:GetText()) end
    end)
    eb:SetScript("OnEnterPressed", function(self)
        if onEnter then onEnter(self:GetText()) end
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    eb:SetScript("OnEditFocusGained", function(self)
        container:SetBackdropBorderColor(T.RGBA(c.BORDER_FOCUS))
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        container:SetBackdropBorderColor(T.RGBA(c.BORDER))
    end)

    updateHint()
    container.editBox = eb
    container.hint    = hint
    return container
end

-- ---------------------------------------------------------------------------
-- ScrollFrame  with auto-expanding scroll child
-- ---------------------------------------------------------------------------

--- Create a scroll frame whose child grows as content is added.
-- Returns: scrollFrame, scrollChild
function UI:CreateScrollFrame(parent, name)
    local sf = CreateFrame("ScrollFrame", name or UID("EGMScroll"), parent, "UIPanelScrollFrameTemplate")
    -- Hide the default ugly scroll bar arrows; we keep the functional thumb
    if sf.ScrollBar then
        sf.ScrollBar:SetWidth(8)
    end

    local child = CreateFrame("Frame", UID("EGMScrollChild"), sf)
    child:SetHeight(1)  -- grows dynamically; width driven by OnSizeChanged below
    sf:SetScrollChild(child)

    -- Keep child width in sync with the scroll frame (GetWidth() is 0 at creation time)
    sf:SetScript("OnSizeChanged", function(self, w, h)
        if w and w > 0 then child:SetWidth(w) end
    end)

    sf._child = child
    return sf, child
end

-- ---------------------------------------------------------------------------
-- Row  (clickable list item)
-- ---------------------------------------------------------------------------

--- Create a list row with hover highlight and optional click handler.
-- @param index  number  row index (for alternating bg)
function UI:CreateRow(parent, index, onClick)
    local c   = T:Get()
    local row = CreateFrame("Button", UID("EGMRow"), parent)
    row:SetHeight(T.ROW_H)

    local isAlt = (index and index % 2 == 0)
    local bgCol = isAlt and c.BG_ROW_ALT or c.BG_ROW
    row:SetBackdrop(T.BACKDROP_FLAT)
    row:SetBackdropColor(T.RGBA(bgCol))
    row:SetBackdropBorderColor(0, 0, 0, 0)

    row:SetScript("OnEnter", function(self) self:SetBackdropColor(T.RGBA(c.BG_ROW_HOV)) end)
    row:SetScript("OnLeave", function(self) self:SetBackdropColor(T.RGBA(bgCol)) end)
    if onClick then row:SetScript("OnClick", function(self) onClick(self) end) end

    return row
end

-- ---------------------------------------------------------------------------
-- StatusBar  (thin progress/color bar)
-- ---------------------------------------------------------------------------

function UI:CreateColorBar(parent, r, g, b)
    local bar = parent:CreateTexture(nil, "ARTWORK")
    T.SetSolidColor(bar, r or 0.9, g or 0.75, b or 0.25, 0.85)
    return bar
end

-- ---------------------------------------------------------------------------
-- Section header  (inside a module panel)
-- ---------------------------------------------------------------------------

function UI:CreateSectionHeader(parent, text)
    local c   = T:Get()
    local f   = CreateFrame("Frame", nil, parent)
    f:SetHeight(20)

    local lbl = f:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(T.FONT_BOLD, 10, "OUTLINE")
    lbl:SetTextColor(T.RGBA(c.TEXT_ACCENT))
    lbl:SetText((text or ""):upper())
    lbl:SetPoint("LEFT", f, "LEFT", 0, 0)

    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    T.SetSolidColor(line, T.RGBA(c.BORDER_SEP))
    line:SetPoint("LEFT",  lbl, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", f,   "RIGHT", 0, 0)

    f._label = lbl
    return f
end
