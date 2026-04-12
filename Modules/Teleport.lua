-- EbonholdGM | Modules/Teleport.lua
-- Teleport & world tools.
-- Features: predefined zone list (searchable), custom locations, coord display,
-- quick-teleport buttons, save/delete custom locations.

local GM    = EbonholdGM
local UI    = GM.UI
local T     = GM.UI.Theme
local Utils = GM.Utils

local M = {
    title = "Teleport",
    icon  = nil,
}
GM:RegisterModule("Teleport", M)

local PAD = T.PAD

-- ---------------------------------------------------------------------------
-- Built-in location database
-- { name, cmd }  where cmd is the .tele name used by TrinityCore
-- ---------------------------------------------------------------------------

local ZONES = {
    -- Eastern Kingdoms
    { name = "Stormwind",       cmd = "stormwind"       },
    { name = "Ironforge",       cmd = "ironforge"       },
    { name = "Undercity",       cmd = "undercity"       },
    { name = "Orgrimmar",       cmd = "orgrimmar"       },
    { name = "Thunder Bluff",   cmd = "thunderbluff"    },
    { name = "Darnassus",       cmd = "darnassus"       },
    { name = "Exodar",          cmd = "exodar"          },
    { name = "Silvermoon City", cmd = "silvermoon"      },
    { name = "Shattrath City",  cmd = "shattrath"       },
    { name = "Dalaran",         cmd = "dalaran"         },
    { name = "Booty Bay",       cmd = "bootybay"        },
    { name = "Gadgetzan",       cmd = "gadgetzan"       },
    { name = "Nethergarde Keep",cmd = "nethergarde"     },
    { name = "Blackrock Mountain",cmd="blackrockmountain"},
    { name = "Burning Steppes", cmd = "burningsteppes"  },
    { name = "Searing Gorge",   cmd = "searinggorge"    },
    { name = "Wetlands",        cmd = "wetlands"        },
    { name = "Loch Modan",      cmd = "lochmodan"       },
    { name = "Dun Morogh",      cmd = "dunmorogh"       },
    { name = "Elwynn Forest",   cmd = "elwynn"          },
    { name = "Westfall",        cmd = "westfall"        },
    { name = "Redridge Mountains",cmd="redridge"        },
    { name = "Duskwood",        cmd = "duskwood"        },
    { name = "Stranglethorn Vale",cmd="stranglethorn"   },
    { name = "Swamp of Sorrows",cmd = "swampofsorrows"  },
    { name = "Blasted Lands",   cmd = "blastedlands"    },
    { name = "Deadwind Pass",   cmd = "deadwindpass"    },
    { name = "Plaguelands East",cmd = "plaguelands"     },
    { name = "Stratholme",      cmd = "stratholme"      },
    { name = "Scholomance",     cmd = "scholomance"     },
    { name = "Tirisfal Glades", cmd = "tirisfal"        },
    { name = "Silverpine Forest",cmd="silverpine"       },
    { name = "Hillsbrad Foothills",cmd="hillsbrad"      },
    { name = "Arathi Highlands",cmd = "arathi"          },
    { name = "Alterac Mountains",cmd="alterac"          },
    -- Kalimdor
    { name = "Durotar",         cmd = "durotar"         },
    { name = "The Barrens",     cmd = "barrens"         },
    { name = "Crossroads",      cmd = "crossroads"      },
    { name = "Stonetalon Mountains",cmd="stonetalon"    },
    { name = "Desolace",        cmd = "desolace"        },
    { name = "Feralas",         cmd = "feralas"         },
    { name = "Thousand Needles",cmd = "thousandneedles" },
    { name = "Tanaris",         cmd = "tanaris"         },
    { name = "Un'Goro Crater",  cmd = "ungoro"          },
    { name = "Silithus",        cmd = "silithus"        },
    { name = "Felwood",         cmd = "felwood"         },
    { name = "Winterspring",    cmd = "winterspring"    },
    { name = "Ashenvale",       cmd = "ashenvale"       },
    { name = "Darkshore",       cmd = "darkshore"       },
    { name = "Moonglade",       cmd = "moonglade"       },
    { name = "Teldrassil",      cmd = "teldrassil"      },
    -- Outland
    { name = "Hellfire Peninsula",cmd="hellfire"        },
    { name = "Zangarmarsh",     cmd = "zangarmarsh"     },
    { name = "Terokkar Forest", cmd = "terokkar"        },
    { name = "Nagrand",         cmd = "nagrand"         },
    { name = "Blade's Edge Mountains",cmd="bladesedge"  },
    { name = "Netherstorm",     cmd = "netherstorm"     },
    { name = "Shadowmoon Valley",cmd="shadowmoon"       },
    -- Northrend
    { name = "Howling Fjord",   cmd = "howlingfjord"    },
    { name = "Borean Tundra",   cmd = "boreantundra"    },
    { name = "Dragonblight",    cmd = "dragonblight"    },
    { name = "Grizzly Hills",   cmd = "grizzlyhills"    },
    { name = "Zul'Drak",        cmd = "zuldrak"         },
    { name = "Sholazar Basin",  cmd = "sholazar"        },
    { name = "Storm Peaks",     cmd = "stormpeaks"      },
    { name = "Icecrown",        cmd = "icecrown"        },
    { name = "Crystalsong Forest",cmd="crystalsong"     },
    { name = "Icecrown Citadel",cmd = "icc"             },
    { name = "Trial of the Crusader",cmd="toc"          },
    { name = "Ulduar",          cmd = "ulduar"          },
    { name = "Naxxramas",       cmd = "naxxramas"       },
    { name = "The Eye of Eternity",cmd="eoe"            },
    { name = "The Obsidian Sanctum",cmd="os"            },
    { name = "Vault of Archavon",cmd="voa"              },
    { name = "Ruby Sanctum",    cmd = "rs"              },
    -- PvP zones
    { name = "Wintergrasp",     cmd = "wintergrasp"     },
    { name = "Alterac Valley",  cmd = "alteracvalley"   },
    { name = "Warsong Gulch",   cmd = "warsong"         },
    { name = "Arathi Basin",    cmd = "arathibasin"     },
    { name = "Isle of Conquest",cmd = "isleofconquest"  },
    { name = "Eye of the Storm",cmd = "eyeofthestorm"   },
    { name = "Strand of the Ancients",cmd="strand"      },
}

-- UI refs
local _panel, _searchInput, _scrollChild, _rowPool
local _filterText = ""

-- ---------------------------------------------------------------------------
-- Build combined list: built-in + custom
-- ---------------------------------------------------------------------------

local function GetAllLocations()
    local all = {}
    for _, z in ipairs(ZONES) do all[#all + 1] = { name = z.name, cmd = z.cmd, custom = false } end
    for _, z in ipairs(GM.Config.db.customLocations or {}) do
        all[#all + 1] = { name = z.name, cmd = z.cmd, custom = true }
    end
    if _filterText ~= "" then
        local out = {}
        for _, z in ipairs(all) do
            if Utils.Contains(z.name, _filterText) or Utils.Contains(z.cmd, _filterText) then
                out[#out + 1] = z
            end
        end
        return out
    end
    return all
end

-- ---------------------------------------------------------------------------
-- Render rows
-- ---------------------------------------------------------------------------

local ROW_H = 28

function M:RenderList()
    if not _scrollChild then return end
    local c   = T:Get()
    local locs = GetAllLocations()

    _rowPool = _rowPool or {}
    for _, row in ipairs(_rowPool) do row:Hide() end

    local yOff = 0
    for i, loc in ipairs(locs) do
        local row = _rowPool[i]
        if not row then
            row = CreateFrame("Frame", nil, _scrollChild)
            row:SetHeight(ROW_H)
            row:SetBackdrop(T.BACKDROP_FLAT)

            -- Name label
            local nameLbl = row:CreateFontString(nil, "OVERLAY")
            nameLbl:SetFont(T.FONT_NORMAL, 11)
            nameLbl:SetPoint("LEFT", row, "LEFT", PAD, 0)
            row._nameLbl = nameLbl

            -- Custom badge
            local badge = row:CreateFontString(nil, "OVERLAY")
            badge:SetFont(T.FONT_NORMAL, 9)
            badge:SetTextColor(0.4, 0.9, 0.5, 1)
            badge:SetPoint("LEFT", nameLbl, "RIGHT", 6, 0)
            row._badge = badge

            -- Teleport self button
            local goBtn = UI:CreateButton(row, "Go", false, nil)
            goBtn:SetSize(36, 20)
            goBtn:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
            row._goBtn = goBtn

            -- Teleport player button
            local sendBtn = UI:CreateButton(row, "Send ->", false, nil)
            sendBtn:SetSize(52, 20)
            sendBtn:SetPoint("RIGHT", goBtn, "LEFT", -4, 0)
            row._sendBtn = sendBtn

            -- Delete button (custom only)
            local delBtn = UI:CreateButton(row, "X", true, nil)
            delBtn:SetSize(22, 20)
            delBtn:SetPoint("RIGHT", sendBtn, "LEFT", -4, 0)
            row._delBtn = delBtn

            -- Separator
            local sep = row:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
            sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
            T.SetSolidColor(sep, T.RGBA(c.BORDER_SEP))

            row:SetScript("OnEnter", function(self) self:SetBackdropColor(T.RGBA(c.BG_ROW_HOV)) end)

            _rowPool[i] = row
        end

        row:SetPoint("TOPLEFT",  _scrollChild, "TOPLEFT",  0, -yOff)
        row:SetPoint("TOPRIGHT", _scrollChild, "TOPRIGHT", 0, -yOff)
        row:Show()

        local bgCol = (i % 2 == 0) and c.BG_ROW_ALT or c.BG_ROW
        row:SetBackdropColor(T.RGBA(bgCol))
        row:SetBackdropBorderColor(0, 0, 0, 0)
        row:SetScript("OnLeave", function(self) self:SetBackdropColor(T.RGBA(bgCol)) end)

        row._nameLbl:SetText(loc.custom and ("|cFF80FF80" .. loc.name .. "|r") or loc.name)
        row._badge:SetText(loc.custom and "[custom]" or "")

        local capturedLoc = loc
        row._goBtn:SetScript("OnClick", function()
            Utils.ExecCommand(".tele " .. capturedLoc.cmd)
        end)
        row._sendBtn:SetScript("OnClick", function()
            local target = UnitName("target")
            if target then
                Utils.ExecCommand(".tele name " .. target .. " " .. capturedLoc.cmd)
            else
                GM:Print("No target selected for Send.")
            end
        end)
        Utils.AddTooltip(row._sendBtn, "Teleport target to this location")

        if loc.custom then
            row._delBtn:Show()
            row._delBtn:SetScript("OnClick", function()
                -- Remove from custom locations
                local customs = GM.Config.db.customLocations
                for j = #customs, 1, -1 do
                    if customs[j].name == capturedLoc.name then
                        table.remove(customs, j)
                    end
                end
                M:RenderList()
            end)
        else
            row._delBtn:Hide()
        end

        yOff = yOff + ROW_H
    end

    _scrollChild:SetHeight(math.max(yOff, 1))
end

-- ---------------------------------------------------------------------------
-- Save current location
-- ---------------------------------------------------------------------------

local function SaveCurrentLocation()
    Utils.InputPopup("Save current location as:", Utils.ZoneName() .. " Spot", function(name)
        -- We can't directly get world coords without a zone change, so use .tele add
        Utils.ExecCommand(".tele add " .. name)
        -- Also store in our custom list with the name as cmd
        local customs = GM.Config.db.customLocations
        table.insert(customs, { name = name, cmd = name })
        M:RenderList()
        GM:Print("Location saved: " .. name)
    end)
end

-- ---------------------------------------------------------------------------
-- Module interface
-- ---------------------------------------------------------------------------

function M:OnLoad()
    _rowPool = {}
end

function M:OnShow()
    M:RenderList()
end

function M:OnSearch(text)
    _filterText = text or ""
    if _searchInput then _searchInput.editBox:SetText(_filterText) end
    M:RenderList()
end

function M:CreatePanel(parent)
    local c = T:Get()
    _panel = UI:CreatePanel(parent, "BG", "BORDER")

    -- -----------------------------------------------------------------------
    -- Top bar
    -- -----------------------------------------------------------------------
    local toolbar = CreateFrame("Frame", nil, _panel)
    toolbar:SetHeight(32)
    toolbar:SetPoint("TOPLEFT",  _panel, "TOPLEFT",  PAD, -PAD)
    toolbar:SetPoint("TOPRIGHT", _panel, "TOPRIGHT", -PAD, -PAD)

    local titleLbl = UI:CreateTitle(toolbar, "Teleport & World")
    titleLbl:SetPoint("LEFT", toolbar, "LEFT", 0, 0)

    local saveBtn = UI:CreateButton(toolbar, "Save Here", false, SaveCurrentLocation)
    saveBtn:SetSize(90, 22)
    saveBtn:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    Utils.AddTooltip(saveBtn, "Save your current location")

    -- -----------------------------------------------------------------------
    -- Coord / info strip
    -- -----------------------------------------------------------------------
    local coordStrip = UI:CreatePanel(_panel, "BG_PANEL", "BORDER")
    coordStrip:SetHeight(26)
    coordStrip:SetPoint("TOPLEFT",  toolbar, "BOTTOMLEFT",  0, -4)
    coordStrip:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, -4)

    local coordLbl = UI:CreateLabel(coordStrip, "", 10, "TEXT_DIM")
    coordLbl:SetPoint("LEFT", coordStrip, "LEFT", PAD, 0)

    -- Update coords every 1 second
    local tick = 0
    coordStrip:SetScript("OnUpdate", function(self, elapsed)
        tick = tick + elapsed
        if tick >= 1 then
            tick = 0
            local x, y = Utils.PlayerCoords()
            if x then
                coordLbl:SetText(string.format("Coords: |cFFFFFFFF%.2f, %.2f|r   Zone: |cFFFFFFFF%s|r", x, y, Utils.ZoneName()))
            else
                coordLbl:SetText("Zone: |cFFFFFFFF" .. Utils.ZoneName() .. "|r")
            end
        end
    end)

    -- Quick .go input
    local goLabel = UI:CreateLabel(coordStrip, ".go:", 10, "TEXT_DIM")
    goLabel:SetPoint("LEFT", coordLbl, "RIGHT", 16, 0)

    local goInput = UI:CreateInput(coordStrip, "x y z [mapId]", function(text)
        if text ~= "" then
            Utils.ExecCommand(".go " .. text)
        end
    end)
    goInput:SetPoint("LEFT",   goLabel, "RIGHT", 4, 0)
    goInput:SetPoint("RIGHT",  coordStrip, "RIGHT", -PAD, 0)
    goInput:SetHeight(18)
    goInput:SetPoint("TOP",    coordStrip, "TOP",    0, -4)
    goInput:SetPoint("BOTTOM", coordStrip, "BOTTOM", 0, 4)

    -- -----------------------------------------------------------------------
    -- Search bar
    -- -----------------------------------------------------------------------
    _searchInput = UI:CreateInput(_panel, "Search locations...", nil, function(text)
        _filterText = text or ""
        M:RenderList()
    end)
    _searchInput:SetPoint("TOPLEFT",  coordStrip, "BOTTOMLEFT",  0, -4)
    _searchInput:SetPoint("TOPRIGHT", coordStrip, "BOTTOMRIGHT", 0, -4)
    _searchInput:SetHeight(T.INPUT_H)

    -- -----------------------------------------------------------------------
    -- Scroll list
    -- -----------------------------------------------------------------------
    local sf, sc = UI:CreateScrollFrame(_panel, "EGMTeleScroll")
    sf:SetPoint("TOPLEFT",     _searchInput, "BOTTOMLEFT",  0,    -4)
    sf:SetPoint("BOTTOMRIGHT", _panel,       "BOTTOMRIGHT", -20, PAD)
    _scrollChild = sc

    M:RenderList()

    return _panel
end
