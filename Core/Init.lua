-- EbonholdGM | Core/Init.lua
-- Main addon namespace, module registry, and bootstrap.

EbonholdGM = {
    ADDON_NAME    = "EbonholdGM",
    ADDON_VERSION = "1.1.9",
    _modules      = {},   -- name -> module table (ordered by registration)
    _moduleOrder  = {},   -- insertion-ordered names
    UI            = {},   -- UI subsystem (populated by UI files)
    Utils         = {},   -- Utility functions
}

local GM = EbonholdGM

-- ---------------------------------------------------------------------------
-- Module registry
-- ---------------------------------------------------------------------------

--- Register a module so it appears in the sidebar.
-- @param name    string   Unique key (e.g. "Commands")
-- @param module  table    Must contain: .title, .icon (texture path), .OnLoad(), .CreatePanel(parent)
function GM:RegisterModule(name, module)
    if self._modules[name] then
        self:Print("|cFFFF4444Duplicate module registered: " .. name .. "|r")
        return
    end
    module._name = name
    self._modules[name] = module
    table.insert(self._moduleOrder, name)
end

--- Return the ordered list of registered modules.
function GM:GetModules()
    local out = {}
    for _, name in ipairs(self._moduleOrder) do
        out[#out + 1] = self._modules[name]
    end
    return out
end

--- Return a single module by name.
function GM:GetModule(name)
    return self._modules[name]
end

-- ---------------------------------------------------------------------------
-- Chat / print helpers
-- ---------------------------------------------------------------------------

function GM:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF4FC3F7[EbonholdGM]|r " .. tostring(msg))
end

function GM:PrintError(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF4444[EbonholdGM] ERROR:|r " .. tostring(msg))
end

--- Send a GM dot-command as a Say chat message (server intercepts it).
function GM:SendCommand(cmd)
    if not cmd or cmd == "" then return end
    SendChatMessage(cmd, "SAY")
end

-- ---------------------------------------------------------------------------
-- Slash command
-- ---------------------------------------------------------------------------

SLASH_EBONHOLDGM1 = "/egm"
SLASH_EBONHOLDGM2 = "/ebonholdgm"
SlashCmdList["EBONHOLDGM"] = function(input)
    local arg = strtrim(input or "")
    if arg == "reset" then
        EbonholdGM_DB = nil
        GM:Print("Database reset. Reload UI to apply.")
    elseif arg == "version" then
        GM:Print("Version " .. GM.ADDON_VERSION)
    else
        -- Toggle main frame
        if GM.MainFrame then
            if GM.MainFrame:IsShown() then
                GM.MainFrame:Hide()
            else
                GM.MainFrame:Show()
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Bootstrap — ADDON_LOADED
-- ---------------------------------------------------------------------------

local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:RegisterEvent("PLAYER_LOGIN")
bootFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "EbonholdGM" then
        GM.Config:Load()
    elseif event == "PLAYER_LOGIN" then
        -- All files are loaded by now; build UI then init modules.
        GM.UI:Build()
        for _, mod in ipairs(GM:GetModules()) do
            if mod.OnLoad then
                local ok, err = pcall(mod.OnLoad, mod)
                if not ok then
                    GM:PrintError("Module " .. (mod._name or "?") .. " OnLoad failed: " .. tostring(err))
                end
            end
        end
        GM:Print("v" .. GM.ADDON_VERSION .. " loaded - |cFFFFD700/egm|r to open")
    end
end)
