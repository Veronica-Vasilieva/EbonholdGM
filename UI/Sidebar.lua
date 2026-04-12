-- EbonholdGM | UI/Sidebar.lua
-- Builds the left icon-tab sidebar and wires module panel switching.

local GM    = EbonholdGM
local UI    = GM.UI
local T     = GM.UI.Theme
local Utils = GM.Utils

-- Keeps track of tab buttons keyed by module name.
local _tabs   = {}
-- Keeps track of created panels keyed by module name.
local _panels = {}

-- ---------------------------------------------------------------------------
-- BuildSidebar  — called from MainFrame after modules are registered.
-- ---------------------------------------------------------------------------

function UI:BuildSidebar()
    local sidebar  = UI._sidebar
    local content  = UI._content
    local c        = T:Get()
    local modules  = GM:GetModules()

    local btnSize  = T.SIDEBAR_W - 8
    local spacing  = 4
    local yOffset  = -(T.PAD)

    for _, mod in ipairs(modules) do
        local name = mod._name

        -- Icon button
        local btn = UI:CreateIconButton(sidebar, mod.icon, mod.title or name, nil)
        btn:SetSize(btnSize, btnSize)
        btn:SetPoint("TOP", sidebar, "TOP", 0, yOffset)
        btn._moduleName = name

        -- If no icon texture, show first 2 letters of title
        if not mod.icon and btn._label then
            local abbrev = (mod.title or name):sub(1, 2):upper()
            btn._label:SetText(abbrev)
            btn._label:SetFont(T.FONT_BOLD, 12, "OUTLINE")
            btn._label:SetTextColor(T.RGBA(c.TEXT_DIM))
        end

        btn:SetScript("OnClick", function()
            UI:SwitchModule(name)
        end)

        _tabs[name] = btn
        yOffset = yOffset - btnSize - spacing

        -- Create module panel (lazy — only once)
        if not _panels[name] and mod.CreatePanel then
            local ok, result = pcall(mod.CreatePanel, mod, content)
            if ok then
                result:SetAllPoints(content)
                result:Hide()
                _panels[name] = result
            else
                GM:PrintError("Panel build failed [" .. name .. "]: " .. tostring(result))
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- SwitchModule  — show a module panel, hide all others, update tab highlight
-- ---------------------------------------------------------------------------

function UI:SwitchModule(name)
    local c  = T:Get()
    local mod = GM:GetModule(name)
    if not mod then return end

    -- Hide all panels
    for _, panel in pairs(_panels) do
        panel:Hide()
    end

    -- Deactivate all tabs
    for tabName, btn in pairs(_tabs) do
        btn:SetBackdropColor(T.RGBA(c.TAB_NORMAL))
        if btn._stripe then btn._stripe:Hide() end
        if btn._label  then btn._label:SetTextColor(T.RGBA(c.TEXT_DIM)) end
    end

    -- Show target panel (create lazily if not yet created)
    if not _panels[name] and mod.CreatePanel then
        local ok, result = pcall(mod.CreatePanel, mod, UI._content)
        if ok then
            result:SetAllPoints(UI._content)
            result:Hide()
            _panels[name] = result
        else
            GM:PrintError("Panel build failed [" .. name .. "]: " .. tostring(result))
            return
        end
    end

    local panel = _panels[name]
    if panel then panel:Show() end

    -- Activate the tab
    local btn = _tabs[name]
    if btn then
        btn:SetBackdropColor(T.RGBA(c.TAB_ACTIVE))
        if btn._stripe then btn._stripe:Show() end
        if btn._label  then btn._label:SetTextColor(T.RGBA(c.TEXT_ACCENT)) end
    end

    UI.activeModule = mod
    UI:SetModuleLabel(mod.title or name)
    GM.Config:Set("activeModule", name)
    GM.Events:Dispatch(GM.Events.MODULE_SWITCHED, name, mod)

    -- Notify module it's now visible
    if mod.OnShow then mod:OnShow() end
end

--- Return the currently visible panel frame for the active module.
function UI:GetActivePanel()
    if UI.activeModule then
        return _panels[UI.activeModule._name]
    end
end
