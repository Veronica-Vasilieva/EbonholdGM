-- EbonholdGM | Modules/Chat.lua
-- Real-time chat monitor panel.
-- Captures Say/Yell/Whisper/Guild/Channel messages, highlights keywords,
-- and provides instant right-click context actions on player names.

local GM    = EbonholdGM
local UI    = GM.UI
local T     = GM.UI.Theme
local Utils = GM.Utils

local M = {
    title = "Chat",
    icon  = nil,
}
GM:RegisterModule("Chat", M)

local PAD    = T.PAD
local MAX_MSGS = 200   -- rolling buffer size

-- ---------------------------------------------------------------------------
-- Message buffer
-- ---------------------------------------------------------------------------

local _messages = {}   -- { channel, sender, text, time, flagged }

-- Channel display info: { label, color hex }
local CHANNEL_INFO = {
    CHAT_MSG_SAY       = { "[S]",  "FFFFFF" },
    CHAT_MSG_YELL      = { "[Y]",  "FF4040" },
    CHAT_MSG_WHISPER   = { "[W]",  "FF80FF" },
    CHAT_MSG_GUILD     = { "[G]",  "40C040" },
    CHAT_MSG_CHANNEL   = { "[Ch]", "FFA040" },
    CHAT_MSG_SYSTEM    = { "[Sys]","AAAAAA" },
}

local MONITORED_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER",
    "CHAT_MSG_GUILD", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM",
}

-- UI refs
local _panel, _scrollChild, _scrollFrame
local _pauseCapture = false
local _filterText   = ""
local _filterChannel = nil  -- nil = all
local _rowPool = {}

-- ---------------------------------------------------------------------------
-- Keyword highlighting
-- ---------------------------------------------------------------------------

local function IsKeywordFlagged(text)
    local keywords = GM.Config.db.chatKeywords or {}
    local ltext = text:lower()
    for _, kw in ipairs(keywords) do
        if ltext:find(kw:lower(), 1, true) then return true end
    end
    return false
end

local function HighlightKeywords(text)
    local keywords = GM.Config.db.chatKeywords or {}
    local result = text
    for _, kw in ipairs(keywords) do
        result = result:gsub(kw, "|cFFFF4040" .. kw .. "|r")
        result = result:gsub(kw:upper(),   "|cFFFF4040" .. kw:upper()   .. "|r")
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Add message to buffer + re-render
-- ---------------------------------------------------------------------------

local function AddMessage(event, text, sender)
    if _pauseCapture then return end

    local flagged = IsKeywordFlagged(text)
    local entry = {
        event   = event,
        sender  = sender or "",
        text    = text   or "",
        time    = date("%H:%M"),
        flagged = flagged,
    }
    table.insert(_messages, 1, entry)   -- newest first
    if #_messages > MAX_MSGS then
        _messages[MAX_MSGS + 1] = nil
    end

    -- Play alert if flagged
    if flagged then
        PlaySoundFile("Sound\\Interface\\AlarmClockWarning2.wav")
    end

    M:RenderLog()
end

-- ---------------------------------------------------------------------------
-- Event subscriptions
-- ---------------------------------------------------------------------------

local function SetupListeners()
    for _, event in ipairs(MONITORED_EVENTS) do
        GM.Events:Subscribe(event, function(text, sender, ...)
            AddMessage(event, text, sender)
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Render log rows
-- ---------------------------------------------------------------------------

local ROW_H = 32

local function FilteredMessages()
    local out = {}
    for _, msg in ipairs(_messages) do
        local chanMatch = (not _filterChannel) or (msg.event == _filterChannel)
        local textMatch = (_filterText == "") or Utils.Contains(msg.text, _filterText)
                       or Utils.Contains(msg.sender, _filterText)
        if chanMatch and textMatch then
            out[#out + 1] = msg
        end
    end
    return out
end

function M:RenderLog()
    if not _scrollChild then return end
    local c = T:Get()

    for _, row in ipairs(_rowPool) do row:Hide() end

    local msgs = FilteredMessages()
    if #msgs == 0 then
        _scrollChild:SetHeight(1)
        return
    end

    local yOff = 0
    for i, msg in ipairs(msgs) do
        local row = _rowPool[i]
        if not row then
            row = CreateFrame("Frame", nil, _scrollChild)
            row:SetHeight(ROW_H)
            row:SetBackdrop(T.BACKDROP_FLAT)

            -- Flag stripe
            local stripe = row:CreateTexture(nil, "ARTWORK")
            stripe:SetWidth(3)
            stripe:SetPoint("TOPLEFT")
            stripe:SetPoint("BOTTOMLEFT")
            row._stripe = stripe

            -- Time
            local timeLbl = row:CreateFontString(nil, "OVERLAY")
            timeLbl:SetFont(T.FONT_NORMAL, 9)
            timeLbl:SetTextColor(T.RGBA(c.TEXT_HINT))
            timeLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -6)
            timeLbl:SetWidth(32)
            row._time = timeLbl

            -- Channel badge
            local chanLbl = row:CreateFontString(nil, "OVERLAY")
            chanLbl:SetFont(T.FONT_BOLD, 9)
            chanLbl:SetPoint("LEFT", timeLbl, "RIGHT", 3, 0)
            chanLbl:SetWidth(30)
            row._chan = chanLbl

            -- Sender (clickable button)
            local senderBtn = CreateFrame("Button", nil, row)
            senderBtn:SetSize(90, 14)
            senderBtn:SetPoint("LEFT", chanLbl, "RIGHT", 3, 0)
            local senderLbl = senderBtn:CreateFontString(nil, "OVERLAY")
            senderLbl:SetFont(T.FONT_BOLD, 10)
            senderLbl:SetAllPoints()
            senderLbl:SetJustifyH("LEFT")
            senderBtn._label = senderLbl
            row._senderBtn = senderBtn
            row._senderLbl = senderLbl

            -- Message text
            local textLbl = row:CreateFontString(nil, "OVERLAY")
            textLbl:SetFont(T.FONT_NORMAL, 10)
            textLbl:SetPoint("TOPLEFT",  row, "TOPLEFT",  PAD + 130, -4)
            textLbl:SetPoint("TOPRIGHT", row, "TOPRIGHT", -PAD, -4)
            textLbl:SetJustifyH("LEFT")
            textLbl:SetWordWrap(true)
            row._text = textLbl

            -- Action buttons (hidden, shown on hover)
            local actFrame = CreateFrame("Frame", nil, row)
            actFrame:SetPoint("TOPRIGHT",    row, "TOPRIGHT",    -PAD, -4)
            actFrame:SetSize(140, 18)
            actFrame:Hide()
            row._actFrame = actFrame

            local function makeActBtn(label, xoff, fn)
                local btn = UI:CreateButton(actFrame, label, false, nil)
                btn:SetSize(44, 16)
                btn:SetPoint("RIGHT", actFrame, "RIGHT", xoff, 0)
                btn:SetScript("OnClick", function()
                    if row._sender and row._sender ~= "" then fn(row._sender) end
                end)
            end
            makeActBtn("Tele",    0,   function(n) Utils.ExecCommand(".appear " .. n) end)
            makeActBtn("Whisp", -48,   function(n)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then
                    DEFAULT_CHAT_FRAME.editBox:SetText("/w " .. n .. " ")
                    DEFAULT_CHAT_FRAME.editBox:SetFocus()
                end
            end)
            makeActBtn("Mute",  -96,   function(n)
                Utils.InputPopup("Mute " .. n .. " for minutes:", "60", function(m)
                    Utils.ExecCommand(".mute " .. n .. " " .. m)
                end)
            end)

            row:SetScript("OnEnter", function(self)
                self:SetBackdropColor(T.RGBA(c.BG_ROW_HOV))
                self._actFrame:Show()
            end)
            row:SetScript("OnLeave", function(self)
                self:SetBackdropColor(T.RGBA(self._bgCol or c.BG_ROW))
                self._actFrame:Hide()
            end)

            -- Sender button opens context menu
            senderBtn:SetScript("OnClick", function(self)
                local name = self._sender
                if name and name ~= "" then
                    GM:GetModule("Players"):OnSearch(name)
                    GM.UI:SwitchModule("Players")
                end
            end)
            Utils.AddTooltip(senderBtn, "Click to open in Players panel")

            -- Separator
            local sep = row:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
            sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
            T.SetSolidColor(sep, T.RGBA(c.BORDER_SEP))

            _rowPool[i] = row
        end

        row:SetPoint("TOPLEFT",  _scrollChild, "TOPLEFT",  0, -yOff)
        row:SetPoint("TOPRIGHT", _scrollChild, "TOPRIGHT", 0, -yOff)
        row:Show()

        -- Data
        local bgCol = msg.flagged and { 0.18, 0.04, 0.04, 0.9 }
                                   or ((i % 2 == 0) and c.BG_ROW_ALT or c.BG_ROW)
        row:SetBackdropColor(T.RGBA(bgCol))
        row:SetBackdropBorderColor(0, 0, 0, 0)
        row._bgCol   = bgCol
        row._sender  = msg.sender
        row._actFrame:Hide()

        -- Stripe
        if msg.flagged then
            T.SetSolidColor(row._stripe, 1, 0.25, 0.25, 0.9)
            row._stripe:Show()
        else
            row._stripe:Hide()
        end

        -- Channel badge
        local info = CHANNEL_INFO[msg.event] or { "[?]", "888888" }
        row._chan:SetText("|cFF" .. info[2] .. info[1] .. "|r")

        -- Time
        row._time:SetText("|cFF555555" .. msg.time .. "|r")

        -- Sender
        local senderColor = msg.flagged and "FF4040" or "FFD700"
        row._senderLbl:SetText(msg.sender ~= "" and ("|cFF" .. senderColor .. msg.sender .. "|r:") or "")
        row._senderBtn._sender = msg.sender

        -- Text with keyword highlights
        row._text:SetText(HighlightKeywords(msg.text))

        yOff = yOff + ROW_H
    end

    _scrollChild:SetHeight(math.max(yOff, 1))
end

-- ---------------------------------------------------------------------------
-- Module interface
-- ---------------------------------------------------------------------------

function M:OnLoad()
    SetupListeners()
end

function M:OnShow()
    M:RenderLog()
end

function M:CreatePanel(parent)
    local c = T:Get()
    _panel = UI:CreatePanel(parent, "BG", "BORDER")

    -- -----------------------------------------------------------------------
    -- Toolbar
    -- -----------------------------------------------------------------------
    local toolbar = CreateFrame("Frame", nil, _panel)
    toolbar:SetHeight(32)
    toolbar:SetPoint("TOPLEFT",  _panel, "TOPLEFT",  PAD, -PAD)
    toolbar:SetPoint("TOPRIGHT", _panel, "TOPRIGHT", -PAD, -PAD)

    local titleLbl = UI:CreateTitle(toolbar, "Chat Monitor")
    titleLbl:SetPoint("LEFT", toolbar, "LEFT", 0, 0)

    -- Pause toggle
    local pauseBtn = UI:CreateButton(toolbar, "Pause", false, nil)
    pauseBtn:SetSize(56, 22)
    pauseBtn:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    pauseBtn:SetScript("OnClick", function(self)
        _pauseCapture = not _pauseCapture
        self._label:SetText(_pauseCapture and "Resume" or "Pause")
    end)
    Utils.AddTooltip(pauseBtn, "Pause/resume capturing chat messages")

    local clearBtn = UI:CreateButton(toolbar, "Clear", false, function()
        _messages = {}
        M:RenderLog()
    end)
    clearBtn:SetSize(48, 22)
    clearBtn:SetPoint("RIGHT", pauseBtn, "LEFT", -4, 0)
    Utils.AddTooltip(clearBtn, "Clear chat log")

    -- -----------------------------------------------------------------------
    -- Channel filter buttons
    -- -----------------------------------------------------------------------
    local filterBar = CreateFrame("Frame", nil, _panel)
    filterBar:SetHeight(22)
    filterBar:SetPoint("TOPLEFT",  toolbar, "BOTTOMLEFT",  0, -4)
    filterBar:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, -4)

    local filterBtns = {}
    local filterX = 0
    local function makeFilterBtn(label, eventKey)
        local info = eventKey and CHANNEL_INFO[eventKey] or { "All", "FFD700" }
        local btn = UI:CreateButton(filterBar, label, false, nil)
        local w = #label * 7 + 12
        btn:SetSize(w, 18)
        btn:SetPoint("LEFT", filterBar, "LEFT", filterX, 0)
        filterX = filterX + w + 3
        btn:SetScript("OnClick", function()
            if _filterChannel == eventKey then
                _filterChannel = nil
            else
                _filterChannel = eventKey
            end
            M:RenderLog()
        end)
        filterBtns[eventKey or "all"] = btn
    end
    makeFilterBtn("All",     nil)
    makeFilterBtn("Say",     "CHAT_MSG_SAY")
    makeFilterBtn("Yell",    "CHAT_MSG_YELL")
    makeFilterBtn("Whisper", "CHAT_MSG_WHISPER")
    makeFilterBtn("Guild",   "CHAT_MSG_GUILD")
    makeFilterBtn("Channel", "CHAT_MSG_CHANNEL")

    -- Search input
    local searchInput = UI:CreateInput(filterBar, "Search sender or text...", nil, function(text)
        _filterText = text or ""
        M:RenderLog()
    end)
    searchInput:SetPoint("LEFT",   filterBar, "LEFT",   filterX + 6, 0)
    searchInput:SetPoint("RIGHT",  filterBar, "RIGHT",  0,           0)
    searchInput:SetHeight(18)

    -- -----------------------------------------------------------------------
    -- Keyword editor button
    -- -----------------------------------------------------------------------
    local kwBtn = UI:CreateButton(_panel, "[S] Keywords", false, function()
        local current = table.concat(GM.Config.db.chatKeywords or {}, ", ")
        Utils.InputPopup("Edit flagged keywords (comma-separated):", current, function(input)
            local kws = {}
            for _, kw in ipairs(Utils.Split(input, ",")) do
                local trimmed = Utils.Trim(kw)
                if trimmed ~= "" then kws[#kws + 1] = trimmed end
            end
            GM.Config.db.chatKeywords = kws
            GM:Print("Keywords updated: " .. table.concat(kws, ", "))
        end)
    end)
    kwBtn:SetSize(88, 18)
    kwBtn:SetPoint("BOTTOMRIGHT", _panel, "BOTTOMRIGHT", -PAD, PAD)

    -- -----------------------------------------------------------------------
    -- Scroll frame
    -- -----------------------------------------------------------------------
    _scrollFrame, _scrollChild = UI:CreateScrollFrame(_panel, "EGMChatScroll")
    _scrollFrame:SetPoint("TOPLEFT",     filterBar, "BOTTOMLEFT",  0,    -4)
    _scrollFrame:SetPoint("BOTTOMRIGHT", _panel,    "BOTTOMRIGHT", -20, PAD + 24)

    return _panel
end
