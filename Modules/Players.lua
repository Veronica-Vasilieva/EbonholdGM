-- EbonholdGM | Modules/Players.lua
-- Player management panel: search, inspect, and act on players.
-- Actions: teleport to/from, summon, kick, ban, mute, modify.

local GM    = EbonholdGM
local UI    = GM.UI
local T     = GM.UI.Theme
local Utils = GM.Utils

local M = {
    title = "Players",
    icon  = nil,
}
GM:RegisterModule("Players", M)

local PAD = T.PAD

-- Selected player state
local _selected = nil  -- { name, class, level, race, zone, online }

-- UI refs
local _panel, _nameInput, _infoPanel, _actionPanel
local _nameLbl, _levelLbl, _classLbl, _raceLbl, _zoneLbl, _onlineLbl

-- ---------------------------------------------------------------------------
-- Search / info display
-- ---------------------------------------------------------------------------

local function DisplayPlayerInfo(name)
    if not name or name == "" then return end
    _selected = { name = name }
    _nameLbl:SetText("|cFFFFD700" .. name .. "|r")

    -- Request info via .pinfo; chat parser will update fields when server responds.
    -- Also try UnitName/target for immediate feedback if player is targeted.
    if UnitName("target") == name then
        local _, class = UnitClass("target")
        local race = UnitRace("target")
        local level = UnitLevel("target")
        _levelLbl:SetText("Level: |cFFFFFFFF" .. (level or "?") .. "|r")
        _classLbl:SetText("Class: |cFFFFFFFF" .. (class or "?") .. "|r")
        _raceLbl:SetText("Race:  |cFFFFFFFF" .. (race or "?") .. "|r")
        _zoneLbl:SetText("Zone:  |cFFFFFFFF—|r")
        _onlineLbl:SetText("Status: |cFF40E048Online|r")
    else
        _levelLbl:SetText("Level: |cFF888888—|r")
        _classLbl:SetText("Class: |cFF888888—|r")
        _raceLbl:SetText("Race:  |cFF888888—|r")
        _zoneLbl:SetText("Zone:  |cFF888888—|r")
        _onlineLbl:SetText("Status: |cFF888888unknown|r")
    end

    _infoPanel:Show()
    _actionPanel:Show()

    Utils.ExecCommand(".pinfo " .. name)
    GM.Events:Dispatch(GM.Events.PLAYER_SELECTED, name)
end

-- Parse .pinfo output from CHAT_MSG_SYSTEM to fill in extra data
local function OnSystemMsg(msg)
    if not _selected then return end
    -- Example output: "Player 'Thrall' GUID: ..., Account: ..., GMLevel: ..., Level: 80"
    local level = msg:match("Level: (%d+)")
    if level and _levelLbl then
        _levelLbl:SetText("Level: |cFFFFFFFF" .. level .. "|r")
    end
    local zone = msg:match("Zone: ([^,\n]+)")
    if zone and _zoneLbl then
        _zoneLbl:SetText("Zone:  |cFFFFFFFF" .. Utils.Trim(zone) .. "|r")
    end
end

-- ---------------------------------------------------------------------------
-- Quick action helpers
-- ---------------------------------------------------------------------------

local function TeleportTo(name)
    Utils.ExecCommand(".appear " .. name)
end

local function SummonPlayer(name)
    Utils.ExecCommand(".summon " .. name)
end

local function KickPlayer(name)
    Utils.ExecCommand(".kick " .. name, true,
        "Kick |cFFFFD700" .. name .. "|r from the server?")
end

local function FreezePlayer(name)
    Utils.ExecCommand(".freeze " .. name)
end

local function UnfreezePlayer(name)
    Utils.ExecCommand(".unfreeze " .. name)
end

local function MutePlayer(name)
    Utils.InputPopup(
        "Mute |cFFFFD700" .. name .. "|r for how many minutes?",
        "60",
        function(mins)
            Utils.InputPopup("Reason for mute:", "Breaking rules", function(reason)
                Utils.ExecCommand(".mute " .. name .. " " .. mins .. " " .. reason)
            end)
        end
    )
end

local function BanPlayer(name)
    Utils.InputPopup(
        "Ban |cFFFFD700" .. name .. "|r — duration in days (0 = permanent):",
        "0",
        function(days)
            Utils.InputPopup("Ban reason:", "Exploiting", function(reason)
                Utils.ExecCommand(".ban character " .. name .. " " .. days .. " " .. reason,
                    true, "Ban |cFFFFD700" .. name .. "|r — are you sure?")
            end)
        end
    )
end

local function ModifyLevel(name)
    Utils.InputPopup("Set level for |cFFFFD700" .. name .. "|r:", "80", function(lvl)
        Utils.ExecCommand(".character level " .. name .. " " .. lvl)
    end)
end

local function ModifyMoney(name)
    Utils.InputPopup(
        "Add copper to |cFFFFD700" .. name .. "|r\n(negative to remove, e.g. -10000):",
        "10000",
        function(amount)
            Utils.ExecCommand(".modify money " .. amount)
        end
    )
end

local function SendMessage(name)
    Utils.InputPopup("Send message to |cFFFFD700" .. name .. "|r:", "", function(msg)
        Utils.ExecCommand(".send message " .. name .. " " .. msg)
    end)
end

local function WhisperPlayer(name)
    -- Pre-fill the chat edit box with a whisper in 3.3.5a
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then
        DEFAULT_CHAT_FRAME.editBox:SetText("/w " .. name .. " ")
        DEFAULT_CHAT_FRAME.editBox:SetFocus()
    end
end

local function LookupPlayer(name)
    Utils.ExecCommand(".lookup player " .. name)
end

-- ---------------------------------------------------------------------------
-- Module interface
-- ---------------------------------------------------------------------------

function M:OnLoad()
    GM.Events:Subscribe("CHAT_MSG_SYSTEM", OnSystemMsg)
end

function M:OnSearch(text)
    if _nameInput then
        _nameInput.editBox:SetText(text or "")
    end
    if text and text ~= "" then
        DisplayPlayerInfo(text)
    end
end

function M:CreatePanel(parent)
    local c = T:Get()
    _panel = UI:CreatePanel(parent, "BG", "BORDER")

    -- -----------------------------------------------------------------------
    -- Search bar
    -- -----------------------------------------------------------------------
    local header = UI:CreateSectionHeader(_panel, "Player Search")
    header:SetPoint("TOPLEFT",  _panel, "TOPLEFT",  PAD, -PAD)
    header:SetPoint("TOPRIGHT", _panel, "TOPRIGHT", -PAD, -PAD)

    _nameInput = UI:CreateInput(_panel, "Enter player name…", function(name)
        DisplayPlayerInfo(Utils.Trim(name))
    end, nil)
    _nameInput:SetPoint("TOPLEFT",  header, "BOTTOMLEFT",  0,   -6)
    _nameInput:SetPoint("TOPRIGHT", _panel, "TOPRIGHT",  -PAD - 148, -PAD - 22)
    _nameInput:SetHeight(T.INPUT_H)

    local searchBtn = UI:CreateButton(_panel, "Search", false, function()
        local name = Utils.Trim(_nameInput.editBox:GetText())
        if name ~= "" then DisplayPlayerInfo(name) end
    end)
    searchBtn:SetSize(56, T.INPUT_H)
    searchBtn:SetPoint("LEFT",  _nameInput, "RIGHT", 4, 0)
    searchBtn:SetPoint("TOP",   _nameInput, "TOP",   0, 0)

    -- Target shortcut
    local targetBtn = UI:CreateButton(_panel, "Use Target", false, function()
        local name = UnitName("target")
        if name then
            _nameInput.editBox:SetText(name)
            DisplayPlayerInfo(name)
        else
            GM:Print("No target selected.")
        end
    end)
    targetBtn:SetSize(80, T.INPUT_H)
    targetBtn:SetPoint("LEFT", searchBtn, "RIGHT", 4, 0)
    targetBtn:SetPoint("TOP",  searchBtn, "TOP",   0, 0)
    Utils.AddTooltip(targetBtn, "Fill from current target")

    -- -----------------------------------------------------------------------
    -- Info card
    -- -----------------------------------------------------------------------
    _infoPanel = UI:CreatePanel(_panel, "BG_PANEL", "BORDER")
    _infoPanel:SetPoint("TOPLEFT",  _nameInput, "BOTTOMLEFT",  0, -8)
    _infoPanel:SetHeight(120)
    _infoPanel:SetPoint("LEFT",  _panel, "LEFT",  PAD, 0)
    _infoPanel:SetPoint("RIGHT", _panel, "RIGHT", -PAD, 0)
    _infoPanel:Hide()

    _nameLbl   = UI:CreateLabel(_infoPanel, "—", 14, "TEXT_ACCENT")
    _nameLbl:SetPoint("TOPLEFT", _infoPanel, "TOPLEFT", PAD, -PAD)

    local col1x, col2x = PAD, 180
    local rowY = -PAD - 20

    _levelLbl = UI:CreateLabel(_infoPanel, "Level: —", 11)
    _levelLbl:SetPoint("TOPLEFT", _infoPanel, "TOPLEFT", col1x, rowY)

    _classLbl = UI:CreateLabel(_infoPanel, "Class: —", 11)
    _classLbl:SetPoint("TOPLEFT", _infoPanel, "TOPLEFT", col2x, rowY)

    rowY = rowY - 16
    _raceLbl = UI:CreateLabel(_infoPanel, "Race:  —", 11)
    _raceLbl:SetPoint("TOPLEFT", _infoPanel, "TOPLEFT", col1x, rowY)

    _zoneLbl = UI:CreateLabel(_infoPanel, "Zone:  —", 11)
    _zoneLbl:SetPoint("TOPLEFT", _infoPanel, "TOPLEFT", col2x, rowY)

    rowY = rowY - 16
    _onlineLbl = UI:CreateLabel(_infoPanel, "Status: —", 11)
    _onlineLbl:SetPoint("TOPLEFT", _infoPanel, "TOPLEFT", col1x, rowY)

    -- -----------------------------------------------------------------------
    -- Action buttons panel
    -- -----------------------------------------------------------------------
    _actionPanel = UI:CreatePanel(_panel, "BG_PANEL", "BORDER")
    _actionPanel:SetPoint("TOPLEFT",  _infoPanel, "BOTTOMLEFT",  0, -8)
    _actionPanel:SetPoint("LEFT",  _panel, "LEFT",  PAD, 0)
    _actionPanel:SetPoint("RIGHT", _panel, "RIGHT", -PAD, 0)
    _actionPanel:SetHeight(200)
    _actionPanel:Hide()

    local actHeader = UI:CreateSectionHeader(_actionPanel, "Quick Actions")
    actHeader:SetPoint("TOPLEFT",  _actionPanel, "TOPLEFT",  PAD, -PAD)
    actHeader:SetPoint("TOPRIGHT", _actionPanel, "TOPRIGHT", -PAD, -PAD)

    -- Helper: make a grid of action buttons
    local btnDefs = {
        { label = "Teleport To",  tip = "Teleport yourself to this player", fn = TeleportTo  },
        { label = "Summon",       tip = "Summon player to your location",   fn = SummonPlayer },
        { label = "Whisper",      tip = "Open a whisper chat window",       fn = WhisperPlayer},
        { label = "Send Msg",     tip = "Send a system message to player",  fn = SendMessage  },
        { label = "Freeze",       tip = "Freeze player in place",           fn = FreezePlayer },
        { label = "Unfreeze",     tip = "Unfreeze player",                  fn = UnfreezePlayer},
        { label = "Mute",         tip = "Mute player for N minutes",        fn = MutePlayer   },
        { label = "Set Level",    tip = "Change player character level",    fn = ModifyLevel  },
        { label = "Give Money",   tip = "Add copper to player",             fn = ModifyMoney  },
        { label = "Lookup",       tip = "Run .pinfo lookup",                fn = LookupPlayer },
        { label = "Kick",         tip = "Kick player from server",          fn = KickPlayer,  danger = true },
        { label = "Ban",          tip = "Ban player account",               fn = BanPlayer,   danger = true },
    }

    local COLS = 4
    local BTN_W = 90
    local BTN_H = 24
    local xGap  = 4
    local yGap  = 4
    local startX = PAD
    local startY = -(PAD + 20)

    for i, def in ipairs(btnDefs) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local btn = UI:CreateButton(_actionPanel, def.label, def.danger or false, nil)
        btn:SetSize(BTN_W, BTN_H)
        btn:SetPoint("TOPLEFT", _actionPanel, "TOPLEFT",
            startX + col * (BTN_W + xGap),
            startY - row * (BTN_H + yGap))
        Utils.AddTooltip(btn, def.label, def.tip)
        local capturedFn = def.fn
        btn:SetScript("OnClick", function()
            if _selected and _selected.name then
                capturedFn(_selected.name)
            else
                GM:Print("No player selected.")
            end
        end)
    end

    -- -----------------------------------------------------------------------
    -- Recent / online players hint
    -- -----------------------------------------------------------------------
    local hintLbl = UI:CreateLabel(_panel, "Search by name, or target a player and click 'Use Target'.", 10, "TEXT_HINT")
    hintLbl:SetPoint("BOTTOMLEFT", _panel, "BOTTOMLEFT", PAD, PAD)

    return _panel
end
