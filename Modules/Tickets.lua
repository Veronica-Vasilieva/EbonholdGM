-- EbonholdGM | Modules/Tickets.lua
-- GM Ticket system panel.
-- Sends .ticket list to the server; parses CHAT_MSG_SYSTEM responses to build a ticket list.
-- Provides: claim, close, respond, teleport to player, internal notes.

local GM    = EbonholdGM
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
-- Format: { id, player, summary, status, age, assignedTo, notes }
-- status: "open" | "assigned" | "escalated" | "closed"
-- ---------------------------------------------------------------------------
local _tickets    = {}
local _selected   = nil  -- currently selected ticket
local _rowFrames  = {}
local _listening  = false  -- are we currently parsing ticket list output?

-- UI refs
local _panel, _scrollChild, _detailPanel
local _detailName, _detailSummary, _detailStatus, _detailNotes, _detailNoteInput

-- ---------------------------------------------------------------------------
-- Chat parser — reads .ticket list output from CHAT_MSG_SYSTEM
-- Example lines (TrinityCore format):
--   "Tickets currently open:"
--   "Ticket #5 by Thrall. Opened 00:03:26 ago. Not assigned. Message: help pls"
-- ---------------------------------------------------------------------------

local function ParseTicketLine(msg)
    -- Match: Ticket #N by Name. Opened TIME ago. [...]. Message: TEXT
    local id, name, age, msgText = msg:match("Ticket #(%d+) by (%S+)%. Opened ([^.]+) ago%. .+Message: (.+)")
    if id then
        local assigned = msg:match("Assigned to ([^.]+)%.") or nil
        _tickets[tonumber(id)] = {
            id         = tonumber(id),
            player     = name,
            summary    = Utils.Truncate(msgText or "", 80),
            full       = msgText or "",
            status     = assigned and "assigned" or "open",
            age        = age or "?",
            assignedTo = assigned,
            notes      = "",
        }
        return true
    end
    return false
end

local function OnSystemMsg(msg)
    if not _listening then return end
    if msg:find("^Ticket #") then
        ParseTicketLine(msg)
        M:RenderList()
    elseif msg:find("No open tickets") or msg:find("^There are no") then
        _tickets = {}
        M:RenderList()
        _listening = false
    elseif msg:find("^All tickets shown") or msg:find("^Showing all") then
        _listening = false
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

            _rowFrames[i] = row
        end

        -- Position
        row:SetPoint("TOPLEFT",  _scrollChild, "TOPLEFT",  0, -yOff)
        row:SetPoint("TOPRIGHT", _scrollChild, "TOPRIGHT", 0, -yOff)
        row:Show()

        -- Fill data
        local bgCol = (i % 2 == 0) and c.BG_ROW_ALT or c.BG_ROW
        row:SetBackdropColor(T.RGBA(bgCol))
        row:SetBackdropBorderColor(0, 0, 0, 0)

        -- Status color
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

        row:SetScript("OnEnter", function(self) self:SetBackdropColor(T.RGBA(c.BG_ROW_HOV)) end)
        row:SetScript("OnLeave", function(self) self:SetBackdropColor(T.RGBA(bgCol)) end)

        local capturedTicket = ticket
        row:SetScript("OnClick", function()
            M:SelectTicket(capturedTicket)
        end)

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
    _detailSummary:SetText(ticket.full or ticket.summary)

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
    -- Auto-refresh when panel is shown
    self:Refresh()
end

function M:Refresh()
    _tickets   = {}
    _listening = true
    Utils.ExecCommand(".ticket list")
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
    _detailName = UI:CreateTitle(_detailPanel, "—")
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

    _detailNoteInput = UI:CreateInput(_detailPanel, "Add internal note…", function(text)
        if _selected and text ~= "" then
            _selected.notes = (_selected.notes ~= "" and _selected.notes .. "\n" or "") .. text
            _detailNotes:SetText(_selected.notes)
            _detailNoteInput.editBox:SetText("")
        end
    end)
    _detailNoteInput:SetPoint("BOTTOMLEFT",  _detailPanel, "BOTTOMLEFT",  PAD, PAD + 30)
    _detailNoteInput:SetPoint("BOTTOMRIGHT", _detailPanel, "BOTTOMRIGHT", -PAD, PAD + 30)

    -- Action buttons row
    local btnY = -(PAD)
    local actions = {
        { label = "Go To Player", fn = function()
            if _selected then Utils.ExecCommand(".appear " .. _selected.player) end
        end },
        { label = "Summon",       fn = function()
            if _selected then Utils.ExecCommand(".summon " .. _selected.player) end
        end },
        { label = "Whisper",      fn = function()
            if _selected then if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then DEFAULT_CHAT_FRAME.editBox:SetText("/w " .. _selected.player .. " ") DEFAULT_CHAT_FRAME.editBox:SetFocus() end end
        end },
        { label = "Claim",        fn = function()
            if _selected then
                local me = UnitName("player")
                Utils.ExecCommand(".ticket assign " .. _selected.id .. " " .. me)
                _selected.assignedTo = me
                _selected.status = "assigned"
                M:SelectTicket(_selected)
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
                if _selected then
                    _selected.status = "closed"
                    _tickets[_selected.id] = nil
                    _detailPanel:Hide()
                    _selected = nil
                    M:RenderList()
                end
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
