local SQ = {}
local scripts = {}

function CreateFrame()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, scriptName, handler)
            scripts[scriptName] = handler
        end,
    }
end

SLASH_SOLOQ1 = nil
SlashCmdList = {}

local function loadFile(path)
    local chunk = assert(loadfile(path))
    chunk("SoloQ", SQ)
end

local function assertEquals(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local function run()
    SoloQSettings = {
        enabled = true,
        thresholds = {
            TANK = { minScore = 3000 },
        },
    }

    loadFile("Debug.lua")
    loadFile("Init.lua")

    local pveReady = false
    local uiAttempts = 0
    local uiSuccesses = 0
    local applicantSuccesses = 0
    local listingSuccesses = 0
    local applicantsInitialized = false
    local listingInitialized = false
    SQ.UI = {
        Init = function()
            uiAttempts = uiAttempts + 1
            if not pveReady then
                return
            end
            uiSuccesses = uiSuccesses + 1
        end,
    }
    SQ.Applicants = {
        Init = function()
            if applicantsInitialized then
                return
            end
            applicantsInitialized = true
            applicantSuccesses = applicantSuccesses + 1
        end,
    }
    SQ.Listing = {
        Init = function()
            if listingInitialized then
                return
            end
            listingInitialized = true
            listingSuccesses = listingSuccesses + 1
        end,
    }

    SQ.Startup()
    pveReady = true
    SQ.Startup()

    assertEquals(uiAttempts, 2, "startup retries ui init")
    assertEquals(uiSuccesses, 1, "ui init succeeds after pve ready")
    assertEquals(applicantSuccesses, 1, "applicants init remains idempotent")
    assertEquals(listingSuccesses, 1, "listing init remains idempotent")

    pveReady = false
    uiAttempts = 0
    uiSuccesses = 0

    scripts.OnEvent(nil, "PLAYER_LOGIN")
    pveReady = true
    scripts.OnEvent(nil, "ADDON_LOADED", "Blizzard_GroupFinder")

    assertEquals(uiAttempts, 2, "group finder addon load retries ui init")
    assertEquals(uiSuccesses, 1, "group finder addon load initializes ui after pve ready")

    SQ.ApplyDefaults(SoloQSettings, SQ.DEFAULT_SETTINGS)

    assertEquals(SoloQSettings.enabled, true, "existing enabled preserved")
    assertEquals(SoloQSettings.debug, false, "debug default added")
    assertEquals(SoloQSettings.minScore, 3000, "min score migrated from old thresholds")
    assertEquals(SoloQSettings.thresholds, nil, "old thresholds table removed")
    assertEquals(SoloQSettings.composition.requireBloodlust, false, "bloodlust requirement default added")
    assertEquals(SoloQSettings.composition.requireBattleRes, false, "battle res requirement default added")
    assertEquals(SoloQSettings.notifications.playReadySound, false, "ready sound default disabled")
    assertEquals(SoloQSettings.notifications.readySound, "READY_CHECK", "ready sound default key added")

    SQ.ResetSettings()
    assertEquals(SoloQSettings.enabled, false, "reset disabled")
    assertEquals(SoloQSettings.minScore, 0, "reset min score")
    assertEquals(SoloQSettings.composition.requireBloodlust, false, "reset bloodlust requirement")
    assertEquals(SoloQSettings.composition.requireBattleRes, false, "reset battle res requirement")
    assertEquals(SoloQSettings.notifications.playReadySound, false, "reset ready sound disabled")
    assertEquals(SoloQSettings.notifications.readySound, "READY_CHECK", "reset ready sound key")

    SQ.SetStatus("Ready")
    assertEquals(SQ.lastStatus, "Ready", "status stored")

    assertEquals(SLASH_SOLOQ1, "/soloq", "slash command registered")
    assertEquals(type(SlashCmdList.SOLOQ), "function", "slash handler registered")

    local toggleCalls = 0
    local refreshCalls = 0
    SQ.UI = {
        Toggle = function()
            toggleCalls = toggleCalls + 1
        end,
        Refresh = function()
            refreshCalls = refreshCalls + 1
        end,
    }

    SlashCmdList.SOLOQ("")
    assertEquals(toggleCalls, 1, "default slash toggles ui")

    local originalPrint = print
    print = function() end
    SlashCmdList.SOLOQ("debug")
    assertEquals(SoloQSettings.debug, true, "debug slash enables debug")
    SlashCmdList.SOLOQ("debug")
    print = originalPrint
    assertEquals(SoloQSettings.debug, false, "debug slash disables debug")

    SoloQSettings.enabled = true
    SoloQSettings.minScore = 2500
    refreshCalls = 0
    SlashCmdList.SOLOQ("reset")
    assertEquals(SoloQSettings.enabled, false, "reset slash disabled")
    assertEquals(SoloQSettings.minScore, 0, "reset slash min score")
    assertEquals(refreshCalls, 1, "reset slash refreshes ui")

    -- Direct SQ.MigrateSettings coverage (edge cases not exercised via Startup)
    local migMulti = {
        thresholds = {
            TANK = { minScore = 2800 },
            HEALER = { minScore = 3000 },
            DAMAGER = { minScore = 2600 },
        },
    }
    SQ.MigrateSettings(migMulti)
    assertEquals(migMulti.minScore, 3000, "migration takes the max across roles")
    assertEquals(migMulti.thresholds, nil, "migration clears thresholds after multi-role migrate")

    local migEmpty = { thresholds = {} }
    SQ.MigrateSettings(migEmpty)
    assertEquals(migEmpty.minScore, 0, "empty thresholds migrates to zero")
    assertEquals(migEmpty.thresholds, nil, "empty thresholds cleared")

    local migPreserve = { minScore = 1500, thresholds = { TANK = { minScore = 3000 } } }
    SQ.MigrateSettings(migPreserve)
    assertEquals(migPreserve.minScore, 1500, "existing minScore preserved over old thresholds")
    assertEquals(migPreserve.thresholds, nil, "stale thresholds cleared when minScore already set")

    SQ.MigrateSettings(nil)

    print("PASS tests/run_init_tests.lua")
end

run()
