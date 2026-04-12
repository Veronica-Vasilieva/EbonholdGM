-- EbonholdGM | Modules/Macros.lua
-- GM Macro builder: create, edit, delete, and execute multi-command sequences.
-- Macros are persisted in SavedVariables (Config.db.macros).

local GM    = EbonholdGM
local UI    = GM.UI
local T     = GM.UI.Theme
local Utils = GM.Utils

local M = {
    title = "Macros",
    icon  = nil,
}
GM:RegisterModule("Macros", M)

local PAD = T.PAD

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local _selectedIndex = nil   -- index into Config.db.macros
local _panel, _listPanel, _editorPanel
local _listRowPool = {}
local _nameLbl, _cmdLines = nil, {}

-- ---------------------------------------------------------------------------
-- Macro execution
-- ---------------------------------------------------------------------------

local function ExecuteMacro(macro)
    if not macro or not macro.commands then return end
    for _, cmd in ipairs(macro.commands) do
        if cmd and cmd ~= "" then
            GM:SendCommand(cmd)
            GM.Config:PushRecentCommand(cmd)
        end
    end
    GM:Print("Macro '" .. macro.name .. "' executed (" .. #macro.commands .. " command(s)).")
end

-- ---------------------------------------------------------------------------
-- Render macro list (left panel)
-- ---------------------------------------------------------------------------

local ROW_H = 36

local function GetMacros()
    return GM.Config.db.macros or {}
end

function M:RenderList()
    if not _listPanel then return end
    local c = T:Get()
    local macros = GetMacros()

    for _, row in ipairs(_listRowPool) do row:Hide() end

    if #macros == 0 then
        if not M._emptyLbl then
            M._emptyLbl = UI:CreateLabel(_listPanel, "No macros yet.\nClick + New to create one.", 10, "TEXT_HINT")
            M._emptyLbl:SetPoint("CENTER", _listPanel, "CENTER", 0, 0)
            M._emptyLbl:SetJustifyH("CENTER")
        end
        M._emptyLbl:Show()
        return
    end
    if M._emptyLbl then M._emptyLbl:Hide() end

    local sf = _listPanel._sf
    local sc = _listPanel._sc

    local yOff = 0
    for i, macro in ipairs(macros) do
        local row = _listRowPool[i]
        if not row then
            row = CreateFrame("Button", nil, sc)
            row:SetHeight(ROW_H)
            row:EnableMouse(true)
            row:SetBackdrop(T.BACKDROP_FLAT)

            local nameLbl = row:CreateFontString(nil, "OVERLAY")
            nameLbl:SetFont(T.FONT_BOLD, 11)
            nameLbl:SetPoint("TOPLEFT", row, "TOPLEFT", PAD, -6)
            row._nameLbl = nameLbl

            local cntLbl = row:CreateFontString(nil, "OVERLAY")
            cntLbl:SetFont(T.FONT_NORMAL, 9)
            cntLbl:SetTextColor(T.RGBA(c.TEXT_DIM))
            cntLbl:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", PAD, 6)
            row._cntLbl = cntLbl

            local runBtn = UI:CreateButton(row, "> Run", false, nil)
            runBtn:SetSize(46, 20)
            runBtn:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
            row._runBtn = runBtn

            local sep = row:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
            sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
            T.SetSolidColor(sep, T.RGBA(c.BORDER_SEP))

            _listRowPool[i] = row
        end

        row:SetPoint("TOPLEFT",  sc, "TOPLEFT",  0, -yOff)
        row:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, -yOff)
        row:Show()

        local bgCol = (i % 2 == 0) and c.BG_ROW_ALT or c.BG_ROW
        local isSelected = (_selectedIndex == i)
        row:SetBackdropColor(isSelected and T.RGBA(c.BG_ROW_HOV) or T.RGBA(bgCol))
        row:SetBackdropBorderColor(0, 0, 0, 0)

        row._nameLbl:SetText(macro.name)
        row._cntLbl:SetText(#macro.commands .. " command(s)")

        row:SetScript("OnEnter", function(self)
            if _selectedIndex ~= i then self:SetBackdropColor(T.RGBA(c.BG_ROW_HOV)) end
        end)
        row:SetScript("OnLeave", function(self)
            if _selectedIndex ~= i then self:SetBackdropColor(T.RGBA(bgCol)) end
        end)

        local capturedI = i
        row:SetScript("OnClick", function()
            _selectedIndex = capturedI
            M:RenderList()
            M:LoadEditorForIndex(capturedI)
        end)

        local capturedMacro = macro
        row._runBtn:SetScript("OnClick", function()
            ExecuteMacro(capturedMacro)
        end)

        yOff = yOff + ROW_H
    end

    sc:SetHeight(math.max(yOff, 1))
end

-- ---------------------------------------------------------------------------
-- Editor panel — edit name + command list
-- ---------------------------------------------------------------------------

local MAX_CMDS = 12

function M:LoadEditorForIndex(idx)
    if not _editorPanel then return end
    local macros = GetMacros()
    local macro  = macros[idx]
    if not macro then return end

    _editorPanel:Show()
    _nameLbl:SetText("")
    _nameLbl.editBox:SetText(macro.name)

    for i, input in ipairs(_cmdLines) do
        input.editBox:SetText(macro.commands[i] or "")
    end
end

function M:SaveEditor()
    local macros = GetMacros()
    if not _selectedIndex then return end
    local macro = macros[_selectedIndex]
    if not macro then return end

    macro.name = Utils.Trim(_nameLbl.editBox:GetText())
    macro.commands = {}
    for _, input in ipairs(_cmdLines) do
        local text = Utils.Trim(input.editBox:GetText())
        if text ~= "" then
            macro.commands[#macro.commands + 1] = text
        end
    end

    M:RenderList()
    GM:Print("Macro '" .. macro.name .. "' saved.")
end

-- ---------------------------------------------------------------------------
-- New macro
-- ---------------------------------------------------------------------------

local function NewMacro()
    local macros = GM.Config.db.macros
    table.insert(macros, { name = "New Macro", commands = {} })
    _selectedIndex = #macros
    M:RenderList()
    M:LoadEditorForIndex(_selectedIndex)
end

-- ---------------------------------------------------------------------------
-- Delete macro
-- ---------------------------------------------------------------------------

local function DeleteMacro()
    if not _selectedIndex then return end
    local macros = GM.Config.db.macros
    local name   = macros[_selectedIndex] and macros[_selectedIndex].name or "?"
    table.remove(macros, _selectedIndex)
    _selectedIndex = nil
    if _editorPanel then _editorPanel:Hide() end
    M:RenderList()
    GM:Print("Macro '" .. name .. "' deleted.")
end

-- ---------------------------------------------------------------------------
-- Module interface
-- ---------------------------------------------------------------------------

function M:OnLoad() end

function M:OnShow()
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

    UI:CreateTitle(toolbar, "GM Macros"):SetPoint("LEFT", toolbar, "LEFT", 0, 0)

    local newBtn = UI:CreateButton(toolbar, "+ New", false, NewMacro)
    newBtn:SetSize(52, 22)
    newBtn:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    Utils.AddTooltip(newBtn, "Create a new macro")

    local delBtn = UI:CreateButton(toolbar, "Delete", true, DeleteMacro)
    delBtn:SetSize(52, 22)
    delBtn:SetPoint("RIGHT", newBtn, "LEFT", -4, 0)
    Utils.AddTooltip(delBtn, "Delete selected macro")

    -- -----------------------------------------------------------------------
    -- List panel (left)
    -- -----------------------------------------------------------------------
    _listPanel = UI:CreatePanel(_panel, "BG_PANEL", "BORDER")
    _listPanel:SetPoint("TOPLEFT",    toolbar,  "BOTTOMLEFT",  0, -6)
    _listPanel:SetPoint("BOTTOMLEFT", _panel,   "BOTTOMLEFT",  PAD, PAD)
    _listPanel:SetWidth(240)

    local listSF, listSC = UI:CreateScrollFrame(_listPanel, "EGMMacroListScroll")
    listSF:SetPoint("TOPLEFT",     _listPanel, "TOPLEFT",     4,  -4)
    listSF:SetPoint("BOTTOMRIGHT", _listPanel, "BOTTOMRIGHT", -20, 4)
    _listPanel._sf = listSF
    _listPanel._sc = listSC

    -- -----------------------------------------------------------------------
    -- Editor panel (right)
    -- -----------------------------------------------------------------------
    _editorPanel = UI:CreatePanel(_panel, "BG_PANEL", "BORDER")
    _editorPanel:SetPoint("TOPLEFT",     _listPanel, "TOPRIGHT",     6, 0)
    _editorPanel:SetPoint("BOTTOMRIGHT", _panel,     "BOTTOMRIGHT", -PAD, PAD)
    _editorPanel:SetPoint("TOP",         _listPanel, "TOP")
    _editorPanel:Hide()

    -- Name input
    local nameHeader = UI:CreateSectionHeader(_editorPanel, "Macro Name")
    nameHeader:SetPoint("TOPLEFT",  _editorPanel, "TOPLEFT",  PAD, -PAD)
    nameHeader:SetPoint("TOPRIGHT", _editorPanel, "TOPRIGHT", -PAD, -PAD)

    _nameLbl = UI:CreateInput(_editorPanel, "Macro name...", nil, nil)
    _nameLbl:SetPoint("TOPLEFT",  nameHeader,   "BOTTOMLEFT",  0, -4)
    _nameLbl:SetPoint("TOPRIGHT", _editorPanel, "TOPRIGHT",    -PAD, -4)
    _nameLbl:SetHeight(T.INPUT_H)

    -- Commands
    local cmdHeader = UI:CreateSectionHeader(_editorPanel, "Commands (one per line, top to bottom)")
    cmdHeader:SetPoint("TOPLEFT",  _nameLbl,     "BOTTOMLEFT",  0, -8)
    cmdHeader:SetPoint("TOPRIGHT", _editorPanel, "TOPRIGHT",    -PAD, -8)

    _cmdLines = {}
    local lastAnchor = cmdHeader
    for i = 1, MAX_CMDS do
        local lineNum = _editorPanel:CreateFontString(nil, "OVERLAY")
        lineNum:SetFont(T.FONT_NORMAL, 9)
        lineNum:SetTextColor(T.RGBA(c.TEXT_HINT))
        lineNum:SetText(i .. ".")
        lineNum:SetPoint("LEFT", _editorPanel, "LEFT", PAD, 0)
        lineNum:SetWidth(14)

        local input = UI:CreateInput(_editorPanel, ".command " .. i, nil, nil)
        input:SetPoint("TOPLEFT",  lastAnchor, "BOTTOMLEFT",  i == 1 and 0 or 18, -4)
        input:SetPoint("TOPRIGHT", _editorPanel, "TOPRIGHT",  -PAD, -4)
        input:SetHeight(18)

        -- anchor line number to input
        lineNum:SetPoint("TOP", input, "TOP", 0, 0)

        _cmdLines[i] = input
        lastAnchor = input
    end

    -- Save + Run buttons
    local actBar = CreateFrame("Frame", nil, _editorPanel)
    actBar:SetHeight(28)
    actBar:SetPoint("BOTTOMLEFT",  _editorPanel, "BOTTOMLEFT",  PAD, PAD)
    actBar:SetPoint("BOTTOMRIGHT", _editorPanel, "BOTTOMRIGHT", -PAD, PAD)

    local saveBtn = UI:CreateButton(actBar, "Save", false, function() M:SaveEditor() end)
    saveBtn:SetSize(64, 24)
    saveBtn:SetPoint("LEFT", actBar, "LEFT", 0, 0)
    Utils.AddTooltip(saveBtn, "Save changes to this macro")

    local runNowBtn = UI:CreateButton(actBar, "> Run Now", false, function()
        M:SaveEditor()
        local macros = GetMacros()
        if _selectedIndex and macros[_selectedIndex] then
            ExecuteMacro(macros[_selectedIndex])
        end
    end)
    runNowBtn:SetSize(76, 24)
    runNowBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)
    Utils.AddTooltip(runNowBtn, "Save and immediately execute this macro")

    M:RenderList()

    return _panel
end
