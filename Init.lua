local addonName, SQ = ...
SQ = SQ or {}

SoloQ = SQ
SoloQSettings = SoloQSettings or {}

SQ.DEFAULT_SETTINGS = {
    enabled = false,
    debug = false,
    minScore = 0,
    composition = {
        requireBloodlust = false,
        requireBattleRes = false,
    },
}

local function copyDefaults(defaults)
    local copy = {}
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            copy[key] = copyDefaults(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function SQ.ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            SQ.ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function SQ.MigrateSettings(target)
    if not target then
        return
    end
    if target.minScore == nil and type(target.thresholds) == "table" then
        local maxScore = 0
        for _, roleSettings in pairs(target.thresholds) do
            local score = tonumber(roleSettings and roleSettings.minScore) or 0
            if score > maxScore then
                maxScore = score
            end
        end
        target.minScore = maxScore
    end
    target.thresholds = nil
end

function SQ.ResetSettings()
    SoloQSettings = copyDefaults(SQ.DEFAULT_SETTINGS)
    SQ.SetStatus("Settings reset.")
    if SQ.UI and SQ.UI.Refresh then
        SQ.UI.Refresh()
    end
end

function SQ.ToggleDebug()
    SoloQSettings.debug = not SoloQSettings.debug
    SQ.SetStatus("Debug logging " .. (SoloQSettings.debug and "enabled." or "disabled."))
end

function SQ.TogglePanel()
    if SQ.UI and SQ.UI.Toggle then
        SQ.UI.Toggle()
    else
        SQ.SetStatus("UI is not loaded.")
    end
end

local function handleSlash(input)
    input = string.lower(input or "")
    if input == "debug" then
        SQ.ToggleDebug()
    elseif input == "reset" then
        SQ.ResetSettings()
    else
        SQ.TogglePanel()
    end
end

SLASH_SOLOQ1 = "/soloq"
SlashCmdList = SlashCmdList or {}
SlashCmdList.SOLOQ = handleSlash

function SQ.Startup()
    SQ.MigrateSettings(SoloQSettings)
    SQ.ApplyDefaults(SoloQSettings, SQ.DEFAULT_SETTINGS)
    -- Retry module init because Blizzard frames may not exist on the first addon event.
    if SQ.Applicants and SQ.Applicants.Init then
        SQ.Applicants.Init()
    end
    if SQ.Listing and SQ.Listing.Init then
        SQ.Listing.Init()
    end
    if SQ.UI and SQ.UI.Init then
        SQ.UI.Init()
    end
    SQ.SetStatus("SoloQ loaded.")
end

if CreateFrame then
    local frame = CreateFrame("Frame", "SoloQEventFrame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function(_, event, loadedAddonName)
        if event == "ADDON_LOADED" and loadedAddonName and loadedAddonName ~= addonName and loadedAddonName ~= "Blizzard_GroupFinder" then
            return
        end
        if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
            SQ.Startup()
        end
    end)
    SQ.EventFrame = frame
end
