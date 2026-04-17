-- GMPanel | Utils/Utils.lua
-- General-purpose helpers shared across all modules.

local GM = GMPanel
local Utils = GM.Utils

-- ---------------------------------------------------------------------------
-- String utilities
-- ---------------------------------------------------------------------------

function Utils.Trim(s)
    return s:match("^%s*(.-)%s*$")
end

function Utils.Split(s, sep)
    local parts = {}
    local pattern = "([^" .. sep .. "]+)"
    for part in s:gmatch(pattern) do
        parts[#parts + 1] = part
    end
    return parts
end

--- Case-insensitive substring check.
function Utils.Contains(haystack, needle)
    return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

--- Truncate string to maxLen, appending "..." if cut.
function Utils.Truncate(s, maxLen)
    if #s <= maxLen then return s end
    return s:sub(1, maxLen - 1) .. "..."
end

--- Wrap a string in a WoW color escape.
function Utils.Colorize(text, r, g, b)
    local hex = string.format("%02x%02x%02x", math.floor(r*255), math.floor(g*255), math.floor(b*255))
    return "|cFF" .. hex .. text .. "|r"
end

-- ---------------------------------------------------------------------------
-- Table utilities
-- ---------------------------------------------------------------------------

function Utils.TableContains(t, value)
    for _, v in ipairs(t) do
        if v == value then return true end
    end
    return false
end

function Utils.TableRemoveValue(t, value)
    for i = #t, 1, -1 do
        if t[i] == value then table.remove(t, i) end
    end
end

--- Shallow copy of a table.
function Utils.ShallowCopy(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

-- ---------------------------------------------------------------------------
-- Number / math
-- ---------------------------------------------------------------------------

function Utils.Clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

function Utils.Round(n, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(n * mult + 0.5) / mult
end

-- ---------------------------------------------------------------------------
-- WoW-specific helpers
-- ---------------------------------------------------------------------------

--- Get the name of the current player.
function Utils.PlayerName()
    return UnitName("player") or "Unknown"
end

--- Get the current map/zone name.
function Utils.ZoneName()
    return GetRealZoneText() or GetZoneText() or "Unknown"
end

--- Get player coordinates (returns x, y as 0-100 floats, or nil if not available).
function Utils.PlayerCoords()
    local x, y = GetPlayerMapPosition("player")
    if x and x ~= 0 then
        return Utils.Round(x * 100, 2), Utils.Round(y * 100, 2)
    end
    return nil, nil
end

--- Send a GM dot-command. Wrapper around GM:SendCommand with optional confirm dialog.
function Utils.ExecCommand(cmd, confirm, confirmMsg)
    if confirm then
        StaticPopupDialogs["EGMGM_CONFIRM_CMD"] = {
            text          = confirmMsg or ("Execute: |cFFFFD700" .. cmd .. "|r ?"),
            button1       = "Execute",
            button2       = "Cancel",
            OnAccept      = function() GM:SendCommand(cmd) end,
            timeout       = 0,
            whileDead     = true,
            hideOnEscape  = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("EGMGM_CONFIRM_CMD")
    else
        GM:SendCommand(cmd)
    end
    GM.Config:PushRecentCommand(cmd)
    GM.Events:Dispatch(GM.Events.COMMAND_EXEC, cmd)
end

--- Open a simple input popup and call onConfirm(value) with the typed text.
function Utils.InputPopup(title, placeholder, onConfirm)
    StaticPopupDialogs["EGMGM_INPUT"] = {
        text            = title,
        button1         = "OK",
        button2         = "Cancel",
        hasEditBox      = 1,
        editBoxWidth    = 220,
        OnAccept        = function(self)
            local val = self.editBox:GetText()
            if onConfirm and val and val ~= "" then
                onConfirm(Utils.Trim(val))
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local val = self:GetText()
            if onConfirm and val and val ~= "" then
                onConfirm(Utils.Trim(val))
            end
            parent:Hide()
        end,
        timeout       = 0,
        whileDead     = true,
        hideOnEscape  = true,
        preferredIndex = 3,
    }
    local popup = StaticPopup_Show("EGMGM_INPUT")
    if popup then
        popup.editBox:SetText(placeholder or "")
        popup.editBox:HighlightText()
    end
end

--- Format a unix-style timestamp (seconds) into HH:MM:SS.
function Utils.FormatTime(secs)
    secs = math.floor(secs or 0)
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%d:%02d", m, s)
    end
end

--- Add a simple OnEnter/OnLeave tooltip to any frame.
function Utils.AddTooltip(frame, title, body)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0, 1)
        if body then
            GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end
