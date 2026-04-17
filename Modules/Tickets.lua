-- GMPanel | Modules/Tickets.lua
-- GM Ticket system panel.
-- Sends .ticket list to the server; parses CHAT_MSG_SYSTEM responses to build a ticket list.
-- Provides: claim, close, respond, teleport to player, internal notes.

local GM    = GMPanel
local UI    = GM.UI
local T     = GM.UI.Theme
local Utils = GM.Utils

local M = {
    title = "Tickets",
    icon  = nil,
}
GM:RegisterModule("Tickets", M)

local PAD = T.PAD

-- ---------------------------------------------------------------------------
-- Ticket data
-- Format: { id, player, summary, full, status, age, assignedTo, notes }
-- status: "open" | "assigned" | "escalated" | "closed"
-- ---------------------------------------------------------------------------
local _tickets    = {}
local _selected   = nil   -- currently selected ticket
local _rowFrames  = {}
local _listening  = false  -- are we currently parsing ticket list output?
local _pendingEntry = nil  -- holds a partially-parsed ticket awaiting its Message: line

-- UI refs
local _panel, _scrollChild, _detailPanel, _statusLbl
local _detailName, _detailSummary, _detailStatus, _detailNotes, _detailNoteInput

-- ---------------------------------------------------------------------------
-- Parser helpers
-- ---------------------------------------------------------------------------

-- Strip WoW color/texture escape codes so regexes see plain text.
local function Strip(msg)
    return (msg
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|T[^|]+|t", "")
        :gsub("|n", " "))
end

-- Try to extract ticket header data from a single (already-stripped) message.
-- After stripping, AzerothCore/TrinityCore sends ticket lines in the form:
--   "Ticket: N. Created by: Name Created: <age> ago Last change: <mod> ago [rest]"
-- The [rest] may contain "Assigned to: GMName" and/or "Ticket Message: [text]".
local function ParseHeader(msg)
    -- Primary: match "Ticket: N. Created by: Name Created: <age> ago"
    local id, name, age = msg:match("Ticket:%s*(%d+)%.%s*Created by:%s*(%S+)%s+Created:%s*(.-)%s+ago")
    if not id then
        -- Fallback: minimal match in case age/lastmod format differs
        id, name = msg:match("Ticket:%s*(%d+)%.%s*Created by:%s*(%S+)")
        age = msg:match("Created:%s*(.-)%s+ago") or "?"
    end
    if not id then return nil end

    local entry = { id = tonumber(id), player = name, age = age }

    -- Assignment
    entry.assignedTo = msg:match("Assigned to:%s*(%S+)")

    -- Ticket message on the same line: complete "[text]" or partial "[text..."
    local msgFull = msg:match("Ticket Message:%s*%[(.-)%]")
    if msgFull then
        entry.msgText = msgFull
        entry.msgOpen = false
    else
        local msgPart = msg:match("Ticket Message:%s*%[(.+)")
        if msgPart then
            entry.msgText = msgPart
            entry.msgOpen = true   -- closing ']' expected on a following line
        end
        -- else msgText=nil, msgOpen=nil -> no message found on this line
    end
    return entry
end

local function TicketCount()
    local n = 0
    for _ in pairs(_tickets) do n = n + 1 end
    return n
end

local function FinaliseEntry(entry, msgText)
    local txt = msgText or entry.msgText or ""
    local assigned = entry.assignedTo
    _tickets[entry.id] = {
        id         = entry.id,
        player     = entry.player,
        age        = entry.age,
        summary    = Utils.Truncate(txt, 80),
        full       = txt,
        status     = assigned and "assigned" or "open",
        assignedTo = assigned,
        notes      = entry.notes or "",
    }
end

local function StatusDone()
    if not _statusLbl then return end
    local n = TicketCount()
    _statusLbl:SetText(n == 0 and "|cFF888888No open tickets|r"
                               or "|cFFFFD700" .. n .. " ticket(s) loaded|r")
end

-- ---------------------------------------------------------------------------
-- CHAT_MSG_SYSTEM listener
-- ---------------------------------------------------------------------------

local function OnSystemMsg(rawMsg)
    if not _listening then return end
    local msg = Strip(rawMsg)

    -- ---- multi-line ticket message continuation ---------------------------
    -- If the previous ticket's message had no closing ']', accumulate lines.
    if _pendingEntry and _pendingEntry.msgOpen then
        local closing = msg:match("^(.-)%]")
        if closing ~= nil then
            -- Found the closing bracket; finalise now.
            _pendingEntry.msgText = (_pendingEntry.msgText or "") .. closing
            _pendingEntry.msgOpen  = false
            FinaliseEntry(_pendingEntry, _pendingEntry.msgText)
            _pendingEntry = nil
            M:RenderList()
            if _statusLbl then _statusLbl:SetText("|cFFFFD700" .. TicketCount() .. " ticket(s) loaded|r") end
        else
            -- Still open; append this line and wait for more.
            _pendingEntry.msgText = (_pendingEntry.msgText or "") .. " " .. msg
        end
        return
    end

    -- ---- end-of-list markers -----------------------------------------------
    -- "Showing list of open tickets..." is what the server sends AFTER all ticket
    -- lines (used by GMGenie as the finalize trigger).
    if msg:find("[Ss]howing list of open tickets")
    or msg:find("[Aa]ll tickets shown")
    or msg:find("[Nn]o open tickets") or msg:find("[Nn]o tickets")
    or msg:find("[Tt]here are no")    or msg:find("0 ticket") then
        if _pendingEntry then
            FinaliseEntry(_pendingEntry, _pendingEntry.msgText or "")
            _pendingEntry = nil
        end
        _listening = false
        M:RenderList()
        StatusDone()
        return
    end

    -- ---- new ticket header line -------------------------------------------
    -- Detect by the stripped "Ticket: N." prefix.
    if msg:find("Ticket:") and msg:find("Created by:") then
        -- Flush any previous incomplete entry (no message line arrived).
        if _pendingEntry then
            FinaliseEntry(_pendingEntry, _pendingEntry.msgText or "")
            _pendingEntry = nil
        end

        local entry = ParseHeader(msg)
        if entry then
            if entry.msgText ~= nil and not entry.msgOpen then
                -- Complete ticket on one line.
                FinaliseEntry(entry, entry.msgText)
                M:RenderList()
                if _statusLbl then _statusLbl:SetText("|cFFFFD700" .. TicketCount() .. " ticket(s) loaded|r") end
            else
                -- Message is absent or still open; hold and wait.
                _pendingEntry = entry
            end
        end
        return
    end
end

-- ---------------------------------------------------------------------------
-- Render ticket list rows
-- ---------------------------------------------------------------------------

function M:RenderList()
    if not _scrollChild then return end
    local c = T:Get()

    for _, row in ipairs(_rowFrames) do row:Hide() end

    local sortedTickets = {}
    for _, t in pairs(_tickets) do
        sortedTickets[#sortedTickets + 1] = t
    end
    table.sort(sortedTickets, function(a, b) return a.id < b.id end)

    if #sortedTickets == 0 then
        _scrollChild:SetHeight(1)
        return
    end

    local ROW_H = 46
    local yOff  = 0
    for i, ticket in ipairs(sortedTickets) do
        local row = _rowFrames[i]
        if not row then
            row = CreateFrame("Button", nil, _scrollChild)
            row:SetHeight(ROW_H)
            row:SetBackdrop(T.BACKDROP_FLAT)
            -- Per-row data; scripts set once.
            row._ticket = nil
            row._bgCol  = c.BG_ROW

            -- Status stripe
            local stripe = row:CreateTexture(nil, "ARTWORK")
            stripe:SetWidth(4)
            stripe:SetPoint("TOPLEFT")
            stripe:SetPoint("BOTTOMLEFT")
            row._stripe = stripe

            -- Ticket ID
            local idLbl = row:CreateFontString(nil, "OVERLAY")
            idLbl:SetFont(T.FONT_BOLD, 11)
            idLbl:SetPoint("TOPLEFT", row, "TOPLEFT", PAD + 6, -6)
            row._idLbl = idLbl

            -- Player name
            local playerLbl = row:CreateFontString(nil, "OVERLAY")
            playerLbl:SetFont(T.FONT_NORMAL, 11)
            playerLbl:SetPoint("LEFT", idLbl, "RIGHT", 8, 0)
            row._playerLbl = playerLbl

            -- Age
            local ageLbl = row:CreateFontString(nil, "OVERLAY")
            ageLbl:SetFont(T.FONT_NORMAL, 10)
            ageLbl:SetTextColor(T.RGBA(c.TEXT_DIM))
            ageLbl:SetPoint("TOPRIGHT", row, "TOPRIGHT", -PAD, -6)
            row._ageLbl = ageLbl

            -- Summary
            local sumLbl = row:CreateFontString(nil, "OVERLAY")
            sumLbl:SetFont(T.FONT_NORMAL, 10)
            sumLbl:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  PAD + 6, 6)
            sumLbl:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -PAD,    6)
            sumLbl:SetJustifyH("LEFT")
            row._sumLbl = sumLbl

            -- Separator
            local sep = row:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
            sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
            T.SetSolidColor(sep, T.RGBA(c.BORDER_SEP))

            -- Scripts set ONCE; read row._ticket / row._bgCol at call time.
            row:SetScript("OnEnter", function(self) self:SetBackdropColor(T.RGBA(c.BG_ROW_HOV)) end)
            row:SetScript("OnLeave", function(self) self:SetBackdropColor(T.RGBA(row._bgCol)) end)
            row:SetScript("OnClick", function()
                if row._ticket then M:SelectTicket(row._ticket) end
            end)

            _rowFrames[i] = row
        end

        -- Position
        row:SetPoint("TOPLEFT",  _scrollChild, "TOPLEFT",  0, -yOff)
        row:SetPoint("TOPRIGHT", _scrollChild, "TOPRIGHT", 0, -yOff)
        row:Show()

        -- Update data fields (no closures allocated)
        local bgCol = (i % 2 == 0) and c.BG_ROW_ALT or c.BG_ROW
        row._bgCol   = bgCol
        row._ticket  = ticket

        row:SetBackdropColor(T.RGBA(bgCol))
        row:SetBackdropBorderColor(0, 0, 0, 0)

        -- Status color stripe
        local statusCol = c.TEXT_GREEN
        if ticket.status == "assigned"  then statusCol = c.TEXT_BLUE  end
        if ticket.status == "escalated" then statusCol = c.TEXT_ORANGE end
        if ticket.status == "closed"    then statusCol = c.TEXT_DIM    end
        T.SetSolidColor(row._stripe, T.RGBA(statusCol))

        row._idLbl:SetText(Utils.Colorize("#" .. ticket.id, T.RGBA(c.TEXT_ACCENT)))
        row._playerLbl:SetText("|cFFFFFFFF" .. ticket.player .. "|r"
            .. (ticket.assignedTo and " |cFF4FC3F7-> " .. ticket.assignedTo .. "|r" or ""))
        row._ageLbl:SetText(ticket.age)
        row._sumLbl:SetText("|cFF888888" .. ticket.summary .. "|r")

        yOff = yOff + ROW_H
    end

    _scrollChild:SetHeight(math.max(yOff, 1))
end

-- ---------------------------------------------------------------------------
-- Select / detail panel
-- ---------------------------------------------------------------------------

function M:SelectTicket(ticket)
    _selected = ticket
    if not _detailPanel then return end
    _detailPanel:Show()

    _detailName:SetText("|cFFFFD700Ticket #" .. ticket.id .. "|r  from  |cFFFFFFFF" .. ticket.player .. "|r")
    _detailSummary:SetText(ticket.full ~= "" and ticket.full or ticket.summary)

    local statusStr = ticket.status:upper()
    local statusColors = { open="FF4444", assigned="4FC3F7", escalated="FFA040", closed="888888" }
    local hex = statusColors[ticket.status] or "FFFFFF"
    _detailStatus:SetText("Status: |cFF" .. hex .. statusStr .. "|r"
        .. (ticket.assignedTo and "  |cFF888888assigned to " .. ticket.assignedTo .. "|r" or ""))

    _detailNotes:SetText(ticket.notes ~= "" and ticket.notes or "|cFF555555No internal notes.|r")
end

-- ---------------------------------------------------------------------------
-- Module interface
-- ---------------------------------------------------------------------------

function M:OnLoad()
    GM.Events:Subscribe("CHAT_MSG_SYSTEM", OnSystemMsg)
end

function M:OnShow()
    self:Refresh()
end

function M:OnResize()
    M:RenderList()
end

function M:Refresh()
    _tickets      = {}
    _pendingEntry = nil
    _listening    = true
    if _statusLbl then _statusLbl:SetText("|cFF888888Loading...|r") end
    -- Send via GUILD (same channel GMGenie uses; server intercepts GM commands on any channel)
    SendChatMessage(".ticket list", "GUILD")
    M:RenderList()
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

    local titleLbl = UI:CreateTitle(toolbar, "Open Tickets")
    titleLbl:SetPoint("LEFT", toolbar, "LEFT", 0, 0)

    local refreshBtn = UI:CreateButton(toolbar, "Refresh", false, function() M:Refresh() end)
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    Utils.AddTooltip(refreshBtn, "Reload ticket list from server")

    local closedBtn = UI:CreateButton(toolbar, "Closed", false, function()
        Utils.ExecCommand(".ticket closedlist")
    end)
    closedBtn:SetSize(60, 22)
    closedBtn:SetPoint("RIGHT", refreshBtn, "LEFT", -4, 0)

    -- Status label (shows "Loading...", "N tickets", "No open tickets")
    _statusLbl = UI:CreateLabel(toolbar, "", 10, "TEXT_DIM")
    _statusLbl:SetPoint("LEFT", titleLbl, "RIGHT", 12, 0)

    -- -----------------------------------------------------------------------
    -- Ticket list (left column)
    -- -----------------------------------------------------------------------
    local listFrame = UI:CreatePanel(_panel, "BG_PANEL", "BORDER")
    listFrame:SetPoint("TOPLEFT",     toolbar, "BOTTOMLEFT",  0, -6)
    listFrame:SetPoint("BOTTOMLEFT",  _panel,  "BOTTOMLEFT",  PAD, PAD)
    listFrame:SetWidth(280)

    local sf, sc = UI:CreateScrollFrame(listFrame, "EGMTicketsScroll")
    sf:SetPoint("TOPLEFT",     listFrame, "TOPLEFT",     4,  -4)
    sf:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -20, 4)
    _scrollChild = sc

    -- -----------------------------------------------------------------------
    -- Detail panel (right column)
    -- -----------------------------------------------------------------------
    _detailPanel = UI:CreatePanel(_panel, "BG_PANEL", "BORDER")
    _detailPanel:SetPoint("TOPLEFT",     listFrame,  "TOPRIGHT",     6, 0)
    _detailPanel:SetPoint("BOTTOMRIGHT", _panel,     "BOTTOMRIGHT",  -PAD, PAD)
    _detailPanel:SetPoint("TOP",         listFrame,  "TOP")
    _detailPanel:Hide()

    -- Detail header
    _detailName = UI:CreateTitle(_detailPanel, "-")
    _detailName:SetPoint("TOPLEFT", _detailPanel, "TOPLEFT", PAD, -PAD)
    _detailName:SetPoint("TOPRIGHT", _detailPanel, "TOPRIGHT", -PAD, -PAD)

    _detailStatus = UI:CreateLabel(_detailPanel, "", 10, "TEXT_DIM")
    _detailStatus:SetPoint("TOPLEFT", _detailName, "BOTTOMLEFT", 0, -4)

    local sep1 = UI:CreateSeparator(_detailPanel)
    sep1:SetPoint("TOPLEFT",  _detailStatus, "BOTTOMLEFT",  0, -6)
    sep1:SetPoint("TOPRIGHT", _detailPanel,  "TOPRIGHT",    -PAD, -6)

    -- Message text
    local msgHeader = UI:CreateSectionHeader(_detailPanel, "Player Message")
    msgHeader:SetPoint("TOPLEFT",  sep1,        "BOTTOMLEFT",  0,    -6)
    msgHeader:SetPoint("TOPRIGHT", _detailPanel, "TOPRIGHT",   -PAD, -6)

    _detailSummary = UI:CreateLabel(_detailPanel, "", 11)
    _detailSummary:SetPoint("TOPLEFT",  msgHeader,    "BOTTOMLEFT",  0, -4)
    _detailSummary:SetPoint("TOPRIGHT", _detailPanel, "TOPRIGHT",    -PAD, -4)
    _detailSummary:SetJustifyH("LEFT")
    _detailSummary:SetWordWrap(true)

    -- Internal notes
    local notesHeader = UI:CreateSectionHeader(_detailPanel, "GM Notes")
    notesHeader:SetPoint("TOPLEFT",  _detailSummary, "BOTTOMLEFT",  0, -8)
    notesHeader:SetPoint("TOPRIGHT", _detailPanel,   "TOPRIGHT",   -PAD, -8)

    _detailNotes = UI:CreateLabel(_detailPanel, "", 10, "TEXT_DIM")
    _detailNotes:SetPoint("TOPLEFT",  notesHeader,  "BOTTOMLEFT",  0, -4)
    _detailNotes:SetPoint("TOPRIGHT", _detailPanel, "TOPRIGHT",    -PAD, -4)
    _detailNotes:SetJustifyH("LEFT")
    _detailNotes:SetWordWrap(true)

    _detailNoteInput = UI:CreateInput(_detailPanel, "Add internal note...", function(text)
        if _selected and text ~= "" then
            _selected.notes = (_selected.notes ~= "" and _selected.notes .. "\n" or "") .. text
            _detailNotes:SetText(_selected.notes)
            _detailNoteInput.editBox:SetText("")
        end
    end)
    _detailNoteInput:SetPoint("BOTTOMLEFT",  _detailPanel, "BOTTOMLEFT",  PAD, PAD + 30)
    _detailNoteInput:SetPoint("BOTTOMRIGHT", _detailPanel, "BOTTOMRIGHT", -PAD, PAD + 30)

    -- Action buttons row
    local actions = {
        { label = "Go To Player", fn = function()
            if _selected then Utils.ExecCommand(".appear " .. _selected.player) end
        end },
        { label = "Summon",       fn = function()
            if _selected then Utils.ExecCommand(".summon " .. _selected.player) end
        end },
        { label = "Whisper",      fn = function()
            if _selected then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then
                    DEFAULT_CHAT_FRAME.editBox:SetText("/w " .. _selected.player .. " ")
                    DEFAULT_CHAT_FRAME.editBox:SetFocus()
                end
            end
        end },
        { label = "Claim",        fn = function()
            if _selected then
                local me = UnitName("player")
                Utils.ExecCommand(".ticket assign " .. _selected.id .. " " .. me)
                _selected.assignedTo = me
                _selected.status = "assigned"
                M:SelectTicket(_selected)
                M:RenderList()
            end
        end },
        { label = "Respond",      fn = function()
            if _selected then
                Utils.InputPopup("Response to ticket #" .. _selected.id .. ":", "", function(resp)
                    Utils.ExecCommand(".ticket respond " .. _selected.id .. " " .. resp)
                end)
            end
        end },
        { label = "Close",        fn = function()
            if _selected then
                Utils.ExecCommand(".ticket close " .. _selected.id, true,
                    "Close ticket #" .. _selected.id .. "?")
                _selected.status = "closed"
                _tickets[_selected.id] = nil
                _detailPanel:Hide()
                _selected = nil
                M:RenderList()
            end
        end, danger = true },
    }

    local actBar = CreateFrame("Frame", nil, _detailPanel)
    actBar:SetHeight(28)
    actBar:SetPoint("BOTTOMLEFT",  _detailPanel, "BOTTOMLEFT",  PAD, PAD)
    actBar:SetPoint("BOTTOMRIGHT", _detailPanel, "BOTTOMRIGHT", -PAD, PAD)

    local xOff = 0
    for _, def in ipairs(actions) do
        local btn = UI:CreateButton(actBar, def.label, def.danger or false, def.fn)
        local w = #def.label * 7 + 14
        btn:SetSize(w, 22)
        btn:SetPoint("LEFT", actBar, "LEFT", xOff, 0)
        xOff = xOff + w + 4
    end

    return _panel
end
