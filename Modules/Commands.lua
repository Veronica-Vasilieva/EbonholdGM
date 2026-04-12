-- EbonholdGM | Modules/Commands.lua
-- VSCode-style searchable command palette for TrinityCore/AzerothCore GM commands.
-- Features: live filter, parameter prompts, favorites, recent commands.

local GM    = EbonholdGM
local UI    = GM.UI
local T     = GM.UI.Theme
local Utils = GM.Utils

-- ---------------------------------------------------------------------------
-- Command database
-- Format: { cmd=".dot command", desc="description", params="{param1} [param2]",
--           category="Category", danger=false }
-- ---------------------------------------------------------------------------

local CMD_DB = {
    -- GM Mode
    { cmd=".gm on",           desc="Enable GM mode for yourself",                 params="",               category="GM Mode" },
    { cmd=".gm off",          desc="Disable GM mode",                             params="",               category="GM Mode" },
    { cmd=".gm chat on",      desc="Enable GM chat mode",                         params="",               category="GM Mode" },
    { cmd=".gm chat off",     desc="Disable GM chat mode",                        params="",               category="GM Mode" },
    { cmd=".gm visible on",   desc="Make yourself visible to players",            params="",               category="GM Mode" },
    { cmd=".gm visible off",  desc="Make yourself invisible to players",          params="",               category="GM Mode" },
    { cmd=".gm fly on",       desc="Enable fly mode",                             params="",               category="GM Mode" },
    { cmd=".gm fly off",      desc="Disable fly mode",                            params="",               category="GM Mode" },

    -- Account / Characters
    { cmd=".account",             desc="Display account level of target player",  params="",               category="Account" },
    { cmd=".account set gmlevel", desc="Set GM level for an account",             params="{account} {level} [{realm}]", category="Account" },
    { cmd=".account set password",desc="Change account password",                 params="{account} {pass} {pass}",    category="Account" },
    { cmd=".account ban",         desc="Ban an account",                          params="{account} {days} {reason}",  category="Account", danger=true },
    { cmd=".account unban",       desc="Unban an account",                        params="{account}",       category="Account" },
    { cmd=".account kick",        desc="Kick an account from the server",         params="{account}",       category="Account", danger=true },

    -- Character
    { cmd=".character level",     desc="Set character level",                     params="{name} {level}",  category="Character" },
    { cmd=".character rename",    desc="Rename a character",                      params="{name}",          category="Character" },
    { cmd=".character customize", desc="Allow character customization on login",  params="{name}",          category="Character" },
    { cmd=".character changerace",desc="Allow race change on login",              params="{name}",          category="Character" },
    { cmd=".character changefaction",desc="Allow faction change on login",        params="{name}",          category="Character" },
    { cmd=".character deleted restore", desc="Restore a deleted character",       params="{name}",          category="Character" },
    { cmd=".character deleted purge",   desc="Permanently delete pending chars",  params="",               category="Character", danger=true },

    -- Player / Target actions
    { cmd=".modify hp",       desc="Set target HP",                              params="{amount}",        category="Modify" },
    { cmd=".modify mana",     desc="Set target mana",                            params="{amount}",        category="Modify" },
    { cmd=".modify money",    desc="Add money to target (copper)",               params="{amount}",        category="Modify" },
    { cmd=".modify rep",      desc="Set target reputation with a faction",       params="{factionId} {rank}", category="Modify" },
    { cmd=".modify speed",    desc="Set target movement speed (1=normal)",       params="{rate}",          category="Modify" },
    { cmd=".modify scale",    desc="Set target model scale",                     params="{scale}",         category="Modify" },
    { cmd=".modify standstate",desc="Change standing animation state",           params="{state}",         category="Modify" },

    -- Teleport
    { cmd=".go",              desc="Teleport yourself to coordinates",            params="{x} {y} {z} [{mapId}]", category="Teleport" },
    { cmd=".go creature",     desc="Teleport to a creature by GUID/name",        params="{name|guid}",     category="Teleport" },
    { cmd=".go object",       desc="Teleport to a game object",                  params="{name|guid}",     category="Teleport" },
    { cmd=".go player",       desc="Teleport to a player's location",            params="{name}",          category="Teleport" },
    { cmd=".go graveyard",    desc="Teleport to a graveyard",                    params="{graveyardId}",   category="Teleport" },
    { cmd=".go zonexy",       desc="Teleport to zone coordinates",               params="{x} {y} [{zoneId}]", category="Teleport" },
    { cmd=".tele",            desc="Teleport to a named location",               params="{name}",          category="Teleport" },
    { cmd=".tele add",        desc="Register current location as a teleport",    params="{name}",          category="Teleport" },
    { cmd=".tele del",        desc="Delete a saved teleport location",           params="{name}",          category="Teleport" },
    { cmd=".tele name",       desc="Teleport a player to a named location",      params="{player} {name}", category="Teleport" },

    -- Summon / Send
    { cmd=".summon",          desc="Summon a player to your location",           params="{name}",          category="Teleport" },
    { cmd=".appear",          desc="Teleport yourself to a player",              params="{name}",          category="Teleport" },
    { cmd=".send mail",       desc="Send mail to a player",                      params="{name} {subject} {text}", category="Mail" },
    { cmd=".send items",      desc="Send items by mail to a player",             params="{name} {subject} {text} {itemId:count} …", category="Mail" },
    { cmd=".send money",      desc="Send money by mail to a player",             params="{name} {subject} {text} {copper}", category="Mail" },
    { cmd=".send message",    desc="Send system message to a player",            params="{name} {text}",   category="Mail" },

    -- NPC
    { cmd=".npc add",         desc="Spawn NPC at your location",                 params="{creatureId}",    category="NPC" },
    { cmd=".npc delete",      desc="Delete targeted NPC",                        params="",               category="NPC", danger=true },
    { cmd=".npc info",        desc="Show NPC info for targeted creature",        params="",               category="NPC" },
    { cmd=".npc move",        desc="Move NPC to your position",                  params="",               category="NPC" },
    { cmd=".npc set level",   desc="Set NPC level",                              params="{level}",        category="NPC" },
    { cmd=".npc set model",   desc="Set NPC display model",                      params="{modelId}",      category="NPC" },
    { cmd=".npc set faction", desc="Set NPC faction template",                   params="{factionId}",    category="NPC" },
    { cmd=".npc set flag",    desc="Set NPC flag",                               params="{flag}",         category="NPC" },

    -- Game Object
    { cmd=".gobject add",     desc="Spawn a game object",                        params="{objectId}",     category="GameObject" },
    { cmd=".gobject delete",  desc="Delete targeted game object",                params="",               category="GameObject", danger=true },
    { cmd=".gobject move",    desc="Move game object to your position",          params="",               category="GameObject" },
    { cmd=".gobject near",    desc="List nearby game objects",                   params="[{distance}]",   category="GameObject" },
    { cmd=".gobject info",    desc="Show info for targeted game object",         params="",               category="GameObject" },

    -- Items
    { cmd=".additem",         desc="Add item to your inventory",                 params="{itemId} [{count}]", category="Items" },
    { cmd=".removeitem",      desc="Remove item by entry ID",                    params="{itemId} [{count}]", category="Items" },

    -- Spells / Auras
    { cmd=".aura",            desc="Apply aura/spell to target",                 params="{spellId}",      category="Spells" },
    { cmd=".unaura",          desc="Remove aura from target",                    params="{spellId}",      category="Spells" },
    { cmd=".cast",            desc="Cast a spell on target",                     params="{spellId}",      category="Spells" },
    { cmd=".learn",           desc="Teach a spell to target",                    params="{spellId}",      category="Spells" },
    { cmd=".unlearn",         desc="Remove a spell from target",                 params="{spellId}",      category="Spells" },

    -- Server
    { cmd=".server info",     desc="Show server uptime and version info",        params="",               category="Server" },
    { cmd=".server plimit",   desc="Set or show player limit",                   params="[{count}]",      category="Server" },
    { cmd=".server shutdown", desc="Initiate server shutdown in N seconds",      params="{seconds}",      category="Server", danger=true },
    { cmd=".server restart",  desc="Restart server in N seconds",                params="{seconds}",      category="Server", danger=true },
    { cmd=".server idleshutdown", desc="Shutdown after idle period",             params="{seconds}",      category="Server", danger=true },
    { cmd=".announce",        desc="Broadcast announcement to all players",      params="{message}",      category="Server" },
    { cmd=".notify",          desc="Broadcast screen notification",              params="{message}",      category="Server" },
    { cmd=".channel set ownership", desc="Toggle channel ownership",             params="{channel} [on|off]", category="Server" },

    -- Tickets
    { cmd=".ticket list",     desc="List all open GM tickets",                   params="",               category="Tickets" },
    { cmd=".ticket close",    desc="Close a GM ticket by ID",                    params="{ticketId}",     category="Tickets" },
    { cmd=".ticket closedlist",desc="Show closed ticket list",                   params="",               category="Tickets" },
    { cmd=".ticket assign",   desc="Assign ticket to a GM",                      params="{ticketId} {gmName}", category="Tickets" },
    { cmd=".ticket unassign", desc="Unassign a ticket",                          params="{ticketId}",     category="Tickets" },
    { cmd=".ticket respond",  desc="Respond to a ticket",                        params="{ticketId} {text}", category="Tickets" },
    { cmd=".ticket delete",   desc="Permanently delete a ticket",                params="{ticketId}",     category="Tickets", danger=true },

    -- Misc
    { cmd=".ban character",   desc="Ban a character",                            params="{name} {days} {reason}", category="Ban/Kick", danger=true },
    { cmd=".ban ip",          desc="Ban an IP address",                          params="{ip} {days} {reason}",   category="Ban/Kick", danger=true },
    { cmd=".unban character", desc="Unban a character",                          params="{name}",          category="Ban/Kick" },
    { cmd=".kick",            desc="Kick a player from the server",              params="{name} [{reason}]", category="Ban/Kick", danger=true },
    { cmd=".mute",            desc="Mute a player for N minutes",                params="{name} {minutes} [{reason}]", category="Ban/Kick" },
    { cmd=".unmute",          desc="Unmute a player",                            params="{name}",          category="Ban/Kick" },
    { cmd=".freeze",          desc="Freeze a player in place",                   params="{name}",          category="Ban/Kick" },
    { cmd=".unfreeze",        desc="Unfreeze a player",                          params="{name}",          category="Ban/Kick" },

    -- Lookup
    { cmd=".lookup player",   desc="Search for players by name",                 params="{name}",          category="Lookup" },
    { cmd=".lookup creature", desc="Search for creature templates by name",      params="{name}",          category="Lookup" },
    { cmd=".lookup object",   desc="Search for game objects by name",            params="{name}",          category="Lookup" },
    { cmd=".lookup item",     desc="Search for items by name",                   params="{name}",          category="Lookup" },
    { cmd=".lookup spell",    desc="Search for spells by name",                  params="{name}",          category="Lookup" },
    { cmd=".lookup quest",    desc="Search for quests by name",                  params="{name}",          category="Lookup" },
    { cmd=".lookup faction",  desc="Search for factions by name",                params="{name}",          category="Lookup" },
    { cmd=".lookup tele",     desc="List saved teleport locations",              params="[{name}]",        category="Lookup" },
    { cmd=".pinfo",           desc="Show account/character info for a player",   params="{name}",          category="Lookup" },
    { cmd=".getdistance",     desc="Get distance to target",                     params="",               category="Lookup" },
    { cmd=".wp show on",      desc="Show waypoints for selected creature",       params="",               category="Lookup" },
    { cmd=".wp show off",     desc="Hide waypoints",                             params="",               category="Lookup" },
}

-- ---------------------------------------------------------------------------
-- Module definition
-- ---------------------------------------------------------------------------

local M = {
    title = "Commands",
    icon  = nil,  -- no icon; sidebar will show "CO"
}
GM:RegisterModule("Commands", M)

-- Internal state
local _filtered  = {}   -- filtered subset of CMD_DB
local _rowFrames = {}   -- reusable row widgets
local _searchText = ""

-- UI refs (set in CreatePanel)
local _panel, _searchInput, _scrollChild, _noResults
local _tabButtons = {}  -- category tab filter buttons
local _activeCategory = nil  -- nil = all

-- ---------------------------------------------------------------------------
-- Filtering
-- ---------------------------------------------------------------------------

local function FilterCommands(text, category)
    _filtered = {}
    local ltext = (text or ""):lower()
    for _, entry in ipairs(CMD_DB) do
        local catMatch = (not category) or (entry.category == category)
        if catMatch then
            if ltext == "" or Utils.Contains(entry.cmd, ltext) or Utils.Contains(entry.desc, ltext) then
                _filtered[#_filtered + 1] = entry
            end
        end
    end
    -- Favorites float to top
    table.sort(_filtered, function(a, b)
        local af = GM.Config:IsFavCommand(a.cmd)
        local bf = GM.Config:IsFavCommand(b.cmd)
        if af ~= bf then return af end
        return a.cmd < b.cmd
    end)
end

-- ---------------------------------------------------------------------------
-- Row rendering
-- ---------------------------------------------------------------------------

local ROW_H = 44
local PAD   = T.PAD

local function RenderRows()
    if not _scrollChild then return end
    local c = T:Get()

    -- Hide all existing rows
    for _, row in ipairs(_rowFrames) do row:Hide() end

    -- Show no-results message
    if #_filtered == 0 then
        if _noResults then _noResults:Show() end
        return
    end
    if _noResults then _noResults:Hide() end

    local yOff = 0
    for i, entry in ipairs(_filtered) do
        -- Reuse or create row
        local row = _rowFrames[i]
        if not row then
            row = CreateFrame("Button", nil, _scrollChild)
            row:SetHeight(ROW_H)
            row:SetBackdrop(T.BACKDROP_FLAT)

            -- Command text
            local cmdLabel = row:CreateFontString(nil, "OVERLAY")
            cmdLabel:SetFont(T.FONT_BOLD, 12)
            cmdLabel:SetPoint("TOPLEFT", row, "TOPLEFT", PAD, -6)
            row._cmd = cmdLabel

            -- Params hint
            local paramLabel = row:CreateFontString(nil, "OVERLAY")
            paramLabel:SetFont(T.FONT_NORMAL, 10)
            paramLabel:SetPoint("LEFT", cmdLabel, "RIGHT", 6, 0)
            row._params = paramLabel

            -- Description
            local descLabel = row:CreateFontString(nil, "OVERLAY")
            descLabel:SetFont(T.FONT_NORMAL, 10)
            descLabel:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", PAD, 6)
            row._desc = descLabel

            -- Category badge
            local catBadge = row:CreateFontString(nil, "OVERLAY")
            catBadge:SetFont(T.FONT_NORMAL, 9)
            catBadge:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -PAD, 6)
            row._cat = catBadge

            -- Star (favorite) button
            local starBtn = CreateFrame("Button", nil, row)
            starBtn:SetSize(16, 16)
            starBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -PAD, -4)
            local starTex = starBtn:CreateFontString(nil, "OVERLAY")
            starTex:SetFont(T.FONT_BOLD, 14)
            starTex:SetAllPoints()
            starTex:SetJustifyH("CENTER")
            row._starBtn  = starBtn
            row._starTex  = starTex

            -- Execute button (right side)
            local execBtn = UI:CreateButton(row, "Run", false, nil)
            execBtn:SetSize(40, 20)
            execBtn:SetPoint("TOPRIGHT", starBtn, "TOPLEFT", -4, 2)
            row._execBtn = execBtn

            -- Separator line
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

        -- Populate data
        local isFav = GM.Config:IsFavCommand(entry.cmd)
        local bgCol = (i % 2 == 0) and c.BG_ROW_ALT or c.BG_ROW

        row:SetBackdropColor(T.RGBA(bgCol))
        row:SetBackdropBorderColor(0, 0, 0, 0)

        row._cmd:SetText(entry.danger and Utils.Colorize(entry.cmd, 1, 0.35, 0.35)
                                       or Utils.Colorize(entry.cmd, 0.9, 0.78, 0.2))
        row._params:SetText(entry.params ~= "" and ("|cFF888888" .. entry.params .. "|r") or "")
        row._desc:SetText("|cFF999999" .. entry.desc .. "|r")
        row._cat:SetText("|cFF555555" .. (entry.category or "") .. "|r")
        row._starTex:SetText(isFav and "|cFFFFD700*|r" or "|cFF444444-|r")

        -- Hover
        local capturedBg = bgCol
        row:SetScript("OnEnter", function(self) self:SetBackdropColor(T.RGBA(c.BG_ROW_HOV)) end)
        row:SetScript("OnLeave", function(self) self:SetBackdropColor(T.RGBA(capturedBg)) end)

        -- Row click — execute or prompt for params
        local capturedEntry = entry
        row:SetScript("OnClick", function(self)
            M:ExecuteEntry(capturedEntry)
        end)

        -- Exec button click
        row._execBtn:SetScript("OnClick", function()
            M:ExecuteEntry(capturedEntry)
        end)

        -- Star button
        row._starBtn:SetScript("OnClick", function()
            local nowFav = GM.Config:ToggleFavCommand(capturedEntry.cmd)
            row._starTex:SetText(nowFav and "|cFFFFD700*|r" or "|cFF444444-|r")
            -- Re-sort so favorites float back up
            FilterCommands(_searchText, _activeCategory)
            RenderRows()
        end)

        yOff = yOff + ROW_H
    end

    -- Update scroll child height
    _scrollChild:SetHeight(math.max(yOff, 1))
end

-- ---------------------------------------------------------------------------
-- Execute an entry (prompt params if needed)
-- ---------------------------------------------------------------------------

function M:ExecuteEntry(entry)
    if entry.params and entry.params ~= "" then
        -- Extract param names for placeholder
        local placeholder = entry.cmd .. " " .. entry.params
        Utils.InputPopup(
            "Execute: |cFFFFD700" .. entry.cmd .. "|r\n|cFF888888" .. entry.desc .. "|r",
            placeholder,
            function(fullCmd)
                Utils.ExecCommand(fullCmd, entry.danger,
                    "This is a |cFFFF4444dangerous|r command. Proceed?")
            end
        )
    else
        Utils.ExecCommand(entry.cmd, entry.danger,
            "This is a |cFFFF4444dangerous|r command. Proceed?")
    end
end

-- ---------------------------------------------------------------------------
-- Module interface
-- ---------------------------------------------------------------------------

function M:OnLoad()
    -- Pre-filter on load (no search text)
    FilterCommands("", nil)
end

function M:OnSearch(text)
    _searchText = text or ""
    if _searchInput then
        _searchInput.editBox:SetText(_searchText)
    end
    FilterCommands(_searchText, _activeCategory)
    RenderRows()
end

function M:OnShow()
    RenderRows()
end

function M:CreatePanel(parent)
    local c = T:Get()

    _panel = UI:CreatePanel(parent, "BG", "BORDER")

    -- -----------------------------------------------------------------------
    -- Top row: search + recent/favorites toggle
    -- -----------------------------------------------------------------------
    local topBar = CreateFrame("Frame", nil, _panel)
    topBar:SetHeight(36)
    topBar:SetPoint("TOPLEFT",  _panel, "TOPLEFT",  PAD, -PAD)
    topBar:SetPoint("TOPRIGHT", _panel, "TOPRIGHT", -PAD, -PAD)

    _searchInput = UI:CreateInput(topBar, "Filter commands…", nil, function(text)
        _searchText = text
        FilterCommands(text, _activeCategory)
        RenderRows()
    end)
    _searchInput:SetPoint("TOPLEFT",  topBar, "TOPLEFT",  0, -7)
    _searchInput:SetPoint("TOPRIGHT", topBar, "TOPRIGHT", -110, -7)
    _searchInput:SetHeight(22)

    local recentBtn = UI:CreateButton(topBar, "Recent", false, function()
        _activeCategory = nil
        _searchText = ""
        _searchInput.editBox:SetText("")
        -- Show only recent commands
        _filtered = {}
        for _, cmdText in ipairs(GM.Config.db.recentCommands or {}) do
            for _, entry in ipairs(CMD_DB) do
                if entry.cmd == cmdText then
                    _filtered[#_filtered + 1] = entry
                    break
                end
            end
        end
        RenderRows()
    end)
    recentBtn:SetSize(50, 22)
    recentBtn:SetPoint("TOPRIGHT", topBar, "TOPRIGHT", -54, -7)
    Utils.AddTooltip(recentBtn, "Show recently executed commands")

    local favBtn = UI:CreateButton(topBar, "* Favs", false, function()
        _activeCategory = nil
        _searchText = ""
        _searchInput.editBox:SetText("")
        _filtered = {}
        for _, entry in ipairs(CMD_DB) do
            if GM.Config:IsFavCommand(entry.cmd) then
                _filtered[#_filtered + 1] = entry
            end
        end
        RenderRows()
    end)
    favBtn:SetSize(48, 22)
    favBtn:SetPoint("TOPRIGHT", topBar, "TOPRIGHT", 0, -7)
    Utils.AddTooltip(favBtn, "Show favorite commands")

    -- -----------------------------------------------------------------------
    -- Category filter tabs
    -- -----------------------------------------------------------------------
    local categories = {}
    local seen = {}
    for _, entry in ipairs(CMD_DB) do
        if not seen[entry.category] then
            seen[entry.category] = true
            categories[#categories + 1] = entry.category
        end
    end
    table.sort(categories)

    local catBar = CreateFrame("Frame", nil, _panel)
    catBar:SetHeight(24)
    catBar:SetPoint("TOPLEFT",  topBar, "BOTTOMLEFT",  0, -4)
    catBar:SetPoint("TOPRIGHT", topBar, "BOTTOMRIGHT", 0, -4)

    local catBtnX = 0
    local function makeCatBtn(label, catName)
        local btn = UI:CreateButton(catBar, label, false, nil)
        btn:SetHeight(18)
        local w = #label * 6 + 8
        btn:SetWidth(w)
        btn:SetPoint("LEFT", catBar, "LEFT", catBtnX, 0)
        catBtnX = catBtnX + w + 2

        btn:SetScript("OnClick", function()
            if _activeCategory == catName then
                _activeCategory = nil
            else
                _activeCategory = catName
            end
            FilterCommands(_searchText, _activeCategory)
            RenderRows()
        end)
        _tabButtons[catName or "__all"] = btn
        return btn
    end

    -- "All" button
    makeCatBtn("All", nil)
    for _, cat in ipairs(categories) do
        makeCatBtn(cat, cat)
    end

    -- -----------------------------------------------------------------------
    -- Scroll frame
    -- -----------------------------------------------------------------------
    local scrollFrame, scrollChild = UI:CreateScrollFrame(_panel, "EGMCommandsScroll")
    scrollFrame:SetPoint("TOPLEFT",     catBar,  "BOTTOMLEFT",  0,    -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", _panel,  "BOTTOMRIGHT", -20, -PAD)
    _scrollChild = scrollChild

    -- No results label
    _noResults = _panel:CreateFontString(nil, "OVERLAY")
    _noResults:SetFont(T.FONT_NORMAL, 12)
    _noResults:SetTextColor(T.RGBA(c.TEXT_HINT))
    _noResults:SetText("No commands match your search.")
    _noResults:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
    _noResults:Hide()

    -- Initial render
    FilterCommands("", nil)
    RenderRows()

    return _panel
end
