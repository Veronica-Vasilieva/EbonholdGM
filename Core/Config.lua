-- EbonholdGM | Core/Config.lua
-- SavedVariables loading, defaults, and per-key accessors.

local GM = EbonholdGM
GM.Config = {}
local Config = GM.Config

-- ---------------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------------

local DEFAULTS = {
    -- Window position
    window = {
        x      = nil,   -- nil = center on first open
        y      = nil,
        width  = 820,
        height = 640,
    },
    -- Per-module enabled flags
    modules = {
        Commands = true,
        Players  = true,
        Tickets  = true,
        Chat     = true,
        Teleport = true,
        Macros   = true,
    },
    -- UI options
    ui = {
        scale       = 1.0,
        alpha       = 0.97,
        theme       = "dark",   -- "dark" | "light"
        sidebarWide = false,
    },
    -- Active module (last open tab)
    activeModule = "Commands",
    -- Chat monitor keywords
    chatKeywords = { "hack", "cheat", "exploit", "gold", "sell", "buy", "account" },
    -- Custom teleport locations  { name, map, x, y, z }
    customLocations = {},
    -- Saved macros  { name, commands = {string, ...} }
    macros = {},
    -- Command favorites (command .text keys)
    favCommands = {},
    -- Recent commands (ordered list of .text, max 20)
    recentCommands = {},
}

-- ---------------------------------------------------------------------------
-- Deep-copy defaults into target (only missing keys)
-- ---------------------------------------------------------------------------

local function applyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                applyDefaults(target[k], v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            applyDefaults(target[k], v)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function Config:Load()
    if type(EbonholdGM_DB) ~= "table" then
        EbonholdGM_DB = {}
    end
    applyDefaults(EbonholdGM_DB, DEFAULTS)
    self.db = EbonholdGM_DB
end

function Config:Get(key)
    return self.db and self.db[key]
end

function Config:Set(key, value)
    if self.db then
        self.db[key] = value
    end
end

--- Convenience: get a nested value like Config:GetNested("ui", "scale")
function Config:GetNested(section, key)
    if self.db and self.db[section] then
        return self.db[section][key]
    end
end

function Config:SetNested(section, key, value)
    if self.db then
        if not self.db[section] then self.db[section] = {} end
        self.db[section][key] = value
    end
end

--- Add a command to the recent list (max 20, no duplicates).
function Config:PushRecentCommand(text)
    local list = self.db.recentCommands
    -- Remove if already present
    for i = #list, 1, -1 do
        if list[i] == text then table.remove(list, i) end
    end
    table.insert(list, 1, text)
    if #list > 20 then list[21] = nil end
end

--- Toggle a command in favorites.
function Config:ToggleFavCommand(text)
    local favs = self.db.favCommands
    for i, v in ipairs(favs) do
        if v == text then
            table.remove(favs, i)
            return false
        end
    end
    table.insert(favs, text)
    return true
end

function Config:IsFavCommand(text)
    for _, v in ipairs(self.db.favCommands) do
        if v == text then return true end
    end
    return false
end
