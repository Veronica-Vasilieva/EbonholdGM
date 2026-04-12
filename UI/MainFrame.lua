-- EbonholdGM | UI/MainFrame.lua
-- Builds the main window: titlebar, sidebar slot, content area, status bar.
-- Modules plug their panels into the content area; Sidebar.lua wires the tabs.

local GM    = EbonholdGM
local UI    = GM.UI
local T     = GM.UI.Theme
local Utils = GM.Utils

-- ---------------------------------------------------------------------------
-- GM.UI:Build()  — called once from Init.lua after PLAYER_LOGIN
-- ---------------------------------------------------------------------------

function UI:Build()
    local c   = T:Get()
    local cfg = GM.Config

    local W = cfg:GetNested("window", "width")  or 820
    local H = cfg:GetNested("window", "height") or 640

    -- -----------------------------------------------------------------------
    -- Root frame
    -- -----------------------------------------------------------------------
    local win = CreateFrame("Frame", "EbonholdGMFrame", UIParent)
    win:SetSize(W, H)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetResizable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetBackdrop(T.BACKDROP_DIALOG)
    win:SetBackdropColor(T.RGBA(c.BG))
    win:SetBackdropBorderColor(T.RGBA(c.BORDER))

    -- Position: saved or centered
    local sx = cfg:GetNested("window", "x")
    local sy = cfg:GetNested("window", "y")
    if sx and sy then
        win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", sx, sy)
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    end

    -- Save position on move
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetLeft(), self:GetTop() - UIParent:GetHeight()
        cfg:SetNested("window", "x", x)
        cfg:SetNested("window", "y", y)
    end)
    win:Hide()
    GM.MainFrame = win

    -- -----------------------------------------------------------------------
    -- Title bar
    -- -----------------------------------------------------------------------
    local titleBar = CreateFrame("Frame", nil, win)
    titleBar:SetHeight(T.TITLEBAR_H)
    titleBar:SetPoint("TOPLEFT",  win, "TOPLEFT",  0, 0)
    titleBar:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
    titleBar:SetBackdrop(T.BACKDROP_FLAT)
    titleBar:SetBackdropColor(T.RGBA(c.BG_TITLEBAR))
    titleBar:SetBackdropBorderColor(T.RGBA(c.BORDER))

    -- Make window draggable via titlebar
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() win:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function()
        win:StopMovingOrSizing()
        local x = win:GetLeft()
        local y = win:GetTop() - UIParent:GetHeight()
        cfg:SetNested("window", "x", x)
        cfg:SetNested("window", "y", y)
    end)

    -- Logo / title text
    local logo = titleBar:CreateFontString(nil, "OVERLAY")
    logo:SetFont(T.FONT_BOLD, 13, "OUTLINE")
    logo:SetPoint("LEFT", titleBar, "LEFT", T.SIDEBAR_W + T.PAD, 0)
    logo:SetText("|cFF4FC3F7Ebonhold|r|cFFFFD700GM|r  |cFF666666v" .. GM.ADDON_VERSION .. "|r")

    -- Active module label (right side of logo)
    local modLabel = titleBar:CreateFontString(nil, "OVERLAY")
    modLabel:SetFont(T.FONT_NORMAL, 11)
    modLabel:SetTextColor(T.RGBA(c.TEXT_DIM))
    modLabel:SetPoint("LEFT", logo, "RIGHT", 12, 0)
    UI._modLabel = modLabel

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    closeBtn:SetScript("OnClick", function() win:Hide() end)

    -- Minimize button (hides to minimap-style button)
    local minBtn = CreateFrame("Button", nil, titleBar)
    minBtn:SetSize(18, 18)
    minBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    minBtn:SetBackdrop(T.BACKDROP_FLAT)
    minBtn:SetBackdropColor(0.20, 0.18, 0.08, 0.9)
    minBtn:SetBackdropBorderColor(T.RGBA(c.BORDER))
    local minLbl = minBtn:CreateFontString(nil, "OVERLAY")
    minLbl:SetFont(T.FONT_BOLD, 11)
    minLbl:SetAllPoints()
    minLbl:SetJustifyH("CENTER")
    minLbl:SetTextColor(T.RGBA(c.TEXT_ACCENT))
    minLbl:SetText("_")
    minBtn:SetScript("OnClick", function()
        -- Collapse to just title bar
        if win._minimized then
            win:SetHeight(H)
            win._minimized = false
            minLbl:SetText("_")
        else
            win:SetHeight(T.TITLEBAR_H)
            win._minimized = true
            minLbl:SetText("□")
        end
    end)
    Utils.AddTooltip(minBtn, "Minimize / Restore")

    -- Global search bar
    local searchCont = UI:CreateInput(titleBar, "Search commands, players, locations…", nil, function(text)
        UI:OnGlobalSearch(text)
    end)
    searchCont:SetPoint("LEFT",  titleBar, "LEFT",  T.SIDEBAR_W + 200, 0)
    searchCont:SetPoint("RIGHT", minBtn,  "LEFT",   -8,  0)
    searchCont:SetHeight(22)
    -- vertically center
    searchCont:SetPoint("TOP",  titleBar, "TOP",    0, -5)
    searchCont:SetPoint("BOTTOM", titleBar, "BOTTOM", 0, 5)
    UI._globalSearch = searchCont

    -- -----------------------------------------------------------------------
    -- Sidebar column
    -- -----------------------------------------------------------------------
    local sidebar = CreateFrame("Frame", nil, win)
    sidebar:SetWidth(T.SIDEBAR_W)
    sidebar:SetPoint("TOPLEFT",    win, "TOPLEFT",    0, -T.TITLEBAR_H)
    sidebar:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 0, T.STATUSBAR_H)
    sidebar:SetBackdrop(T.BACKDROP_FLAT)
    sidebar:SetBackdropColor(T.RGBA(c.BG_SIDEBAR))
    sidebar:SetBackdropBorderColor(T.RGBA(c.BORDER))
    UI._sidebar = sidebar

    -- Sidebar vertical accent line on right
    local sideAccent = win:CreateTexture(nil, "ARTWORK")
    sideAccent:SetWidth(1)
    sideAccent:SetPoint("TOPRIGHT",    sidebar, "TOPRIGHT",    0, 0)
    sideAccent:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
    T.SetSolidColor(sideAccent, T.RGBA(c.BORDER))

    -- -----------------------------------------------------------------------
    -- Content area
    -- -----------------------------------------------------------------------
    local content = CreateFrame("Frame", nil, win)
    content:SetPoint("TOPLEFT",     win, "TOPLEFT",     T.SIDEBAR_W, -T.TITLEBAR_H)
    content:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0,            T.STATUSBAR_H)
    UI._content = content

    -- -----------------------------------------------------------------------
    -- Status bar
    -- -----------------------------------------------------------------------
    local statusBar = CreateFrame("Frame", nil, win)
    statusBar:SetHeight(T.STATUSBAR_H)
    statusBar:SetPoint("BOTTOMLEFT",  win, "BOTTOMLEFT",  0, 0)
    statusBar:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0)
    statusBar:SetBackdrop(T.BACKDROP_FLAT)
    statusBar:SetBackdropColor(T.RGBA(c.BG_TITLEBAR))
    statusBar:SetBackdropBorderColor(T.RGBA(c.BORDER))

    local statusText = statusBar:CreateFontString(nil, "OVERLAY")
    statusText:SetFont(T.FONT_NORMAL, 10)
    statusText:SetTextColor(T.RGBA(c.TEXT_DIM))
    statusText:SetPoint("LEFT", statusBar, "LEFT", T.SIDEBAR_W + T.PAD, 0)
    UI._statusText = statusText

    -- Coords display on right of status bar
    local coordText = statusBar:CreateFontString(nil, "OVERLAY")
    coordText:SetFont(T.FONT_NORMAL, 10)
    coordText:SetTextColor(T.RGBA(c.TEXT_DIM))
    coordText:SetPoint("RIGHT", statusBar, "RIGHT", -T.PAD, 0)
    UI._coordText = coordText

    -- Coord update ticker (every 1s)
    local coordTick = 0
    statusBar:SetScript("OnUpdate", function(self, elapsed)
        coordTick = coordTick + elapsed
        if coordTick >= 1 then
            coordTick = 0
            local x, y = Utils.PlayerCoords()
            if x then
                coordText:SetText(string.format("%.2f, %.2f  %s", x, y, Utils.ZoneName()))
            else
                coordText:SetText(Utils.ZoneName())
            end
        end
    end)

    -- -----------------------------------------------------------------------
    -- Resize handle (bottom-right corner)
    -- -----------------------------------------------------------------------
    local resizeHandle = CreateFrame("Frame", nil, win)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0)
    resizeHandle:EnableMouse(true)

    local resizeTex = resizeHandle:CreateTexture(nil, "OVERLAY")
    resizeTex:SetAllPoints()
    T.SetSolidColor(resizeTex, T.RGBA(c.TEXT_DIM))
    resizeTex:SetAlpha(0.3)

    resizeHandle:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then win:StartSizing("BOTTOMRIGHT") end
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        win:StopMovingOrSizing()
        cfg:SetNested("window", "width",  win:GetWidth())
        cfg:SetNested("window", "height", win:GetHeight())
        -- Reflow content
        content:SetWidth(win:GetWidth() - T.SIDEBAR_W)
    end)

    -- -----------------------------------------------------------------------
    -- Build sidebar tabs (populated by Sidebar.lua after modules register)
    -- -----------------------------------------------------------------------
    UI:BuildSidebar()

    -- -----------------------------------------------------------------------
    -- Show first module
    -- -----------------------------------------------------------------------
    local startMod = cfg:Get("activeModule") or "Commands"
    UI:SwitchModule(startMod)

    UI:SetStatus("Ready  —  " .. Utils.PlayerName())
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

function UI:SetStatus(msg)
    if UI._statusText then UI._statusText:SetText(tostring(msg)) end
end

function UI:SetModuleLabel(name)
    if UI._modLabel then UI._modLabel:SetText(tostring(name)) end
end

--- Show main frame.
function UI:Show()
    if GM.MainFrame then GM.MainFrame:Show() end
end

--- Hide main frame.
function UI:Hide()
    if GM.MainFrame then GM.MainFrame:Hide() end
end

--- Global search bar handler — delegates to the active module if it supports search,
--- otherwise switches to Command palette.
function UI:OnGlobalSearch(text)
    local active = UI.activeModule
    if active and active.OnSearch then
        active:OnSearch(text)
    else
        UI:SwitchModule("Commands")
        local cmd = GM:GetModule("Commands")
        if cmd and cmd.OnSearch then cmd:OnSearch(text) end
    end
end
