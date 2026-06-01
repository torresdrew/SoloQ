local SQ = {}
local calls = {}
local listingEventHandler = nil

GROUP_FINDER_CATEGORY_ID_DUNGEONS = 2

PVEFrame = {
    shown = false,
    IsShown = function(self) return self.shown end,
    Show = function(self) self.shown = true end,
}

function PVEFrame_ToggleFrame()
    calls[#calls + 1] = { name = "PVEFrame_ToggleFrame" }
    PVEFrame.shown = not PVEFrame.shown
end

function LFGListUtil_OpenBestWindow()
    calls[#calls + 1] = { name = "LFGListUtil_OpenBestWindow" }
end

LFGListFrame = {
    CategorySelection = {
        StartGroupButton = {
            Click = function()
                calls[#calls + 1] = { name = "StartGroupButtonClick" }
                LFGListFrame.activePanel = LFGListFrame.EntryCreation
            end,
        },
    },
    EntryCreation = {
        baseFilters = nil,
        selectedFilters = nil,
        selectedCategory = nil,
        selectedGroup = nil,
        selectedActivity = nil,
        selectedPlaystyle = nil,
        generalPlaystyle = nil,
        Name = {
            text = "",
            SetText = function(self, text)
                self.text = text
            end,
            GetText = function(self)
                return self.text
            end,
        },
        ActivityDropdown = {
            GenerateMenu = function()
                calls[#calls + 1] = { name = "ActivityDropdownGenerateMenu" }
            end,
            SetShown = function(self, shown)
                self.shown = shown
            end,
        },
        GroupDropdown = {
            GenerateMenu = function()
                calls[#calls + 1] = { name = "GroupDropdownGenerateMenu" }
            end,
            SetShown = function(self, shown)
                self.shown = shown
            end,
        },
        PlayStyleDropdown = {
            GenerateMenu = function()
                calls[#calls + 1] = { name = "PlayStyleDropdownGenerateMenu" }
            end,
        },
        ActivityFinder = {
            shown = false,
            Hide = function(self)
                calls[#calls + 1] = { name = "ActivityFinderHide" }
                self.shown = false
            end,
        },
        ListGroupButton = {
            clickCreatesListing = false,
            Click = function(self)
                calls[#calls + 1] = { name = "ListGroupButtonClick" }
                if self.clickCreatesListing
                    and LFGListFrame.EntryCreation.selectedActivity == 12345
                    and LFGListFrame.EntryCreation.generalPlaystyle == 3 then
                    C_LFGList.active = true
                end
            end,
        },
    },
    ApplicationViewer = { applicants = {} },
}

function LFGListFrame_SetActivePanel(frame, panel)
    calls[#calls + 1] = { name = "LFGListFrame_SetActivePanel", panel = panel }
    if panel == frame.ApplicationViewer and not panel.applicants then
        error("bad argument #1 to 'sort' (table expected, got nil)")
    end
    frame.activePanel = panel
    if panel == frame.EntryCreation then
        LFGListEntryCreation_UpdateValidState(panel)
    end
end

function LFGListCategorySelection_SelectCategory(panel, categoryID, filters)
    calls[#calls + 1] = { name = "LFGListCategorySelection_SelectCategory", categoryID = categoryID, filters = filters }
    panel.selectedCategory = categoryID
end

function LFGListEntryCreation_Show(frame, baseFilters, categoryID, filters)
    calls[#calls + 1] = {
        name = "LFGListEntryCreation_Show",
        baseFilters = baseFilters,
        categoryID = categoryID,
        filters = filters,
    }
    frame.baseFilters = baseFilters
    frame.selectedCategory = categoryID
    frame.selectedFilters = filters
    frame.selectedGroup = nil
    frame.selectedActivity = nil
    frame.generalPlaystyle = 0
    frame.ActivityFinder.shown = true
    LFGListFrame.activePanel = frame
end

function LFGListEntryCreation_Select(frame, filters, categoryID, groupID, activityID)
    calls[#calls + 1] = {
        name = "LFGListEntryCreation_Select",
        filters = filters,
        categoryID = categoryID,
        groupID = groupID,
        activityID = activityID,
    }
    frame.selectedFilters = filters
    frame.selectedCategory = categoryID
    frame.selectedGroup = groupID
    frame.selectedActivity = activityID
end

function LFGListEntryCreation_OnPlayStyleSelectedInternal(frame, generalPlaystyle)
    calls[#calls + 1] = { name = "LFGListEntryCreation_OnPlayStyleSelectedInternal", generalPlaystyle = generalPlaystyle }
    frame.generalPlaystyle = generalPlaystyle
end

function LFGListEntryCreation_UpdateValidState(frame)
    calls[#calls + 1] = { name = "LFGListEntryCreation_UpdateValidState", frame = frame, selectedActivity = frame.selectedActivity }
    C_LFGList.GetActivityInfoTable(frame.selectedActivity)
end

C_LFGList = {
    active = false,
    createResult = true,
    createError = nil,
    HasActiveEntryInfo = function()
        return C_LFGList.active
    end,
    GetOwnedKeystoneActivityAndGroupAndLevel = function()
        return 12345, 678, 10
    end,
    GetLfgCategoryInfo = function(categoryID)
        return {
            categoryID = categoryID,
            autoChooseActivity = false,
        }
    end,
    GetActivityInfoTable = function(activityID)
        if activityID == nil then
            error("bad argument #1 to '?' (Usage: local activityInfo = C_LFGList.GetActivityInfoTable(activityID [, questID, showWarmode]))")
        end
        if activityID == 12345 then
            return {
                activityID = activityID,
                shortName = "Test Key",
                isMythicPlusActivity = true,
                categoryID = GROUP_FINDER_CATEGORY_ID_DUNGEONS,
            }
        end
        return nil
    end,
    GetActivityGroupInfo = function(groupID)
        if groupID == 678 then
            return "Test Dungeon"
        end
        return nil
    end,
    CreateListing = function(createData)
        calls[#calls + 1] = { name = "CreateListing", createData = createData }
        if C_LFGList.createError then
            error(C_LFGList.createError)
        end
        return C_LFGList.createResult
    end,
    ClearCreationTextFields = function()
        calls[#calls + 1] = { name = "ClearCreationTextFields" }
    end,
    SetSearchToActivity = function(activityID)
        calls[#calls + 1] = { name = "SetSearchToActivity", activityID = activityID }
    end,
    SetEntryTitle = function(activityID, groupID, playstyle, generalPlaystyle)
        calls[#calls + 1] = {
            name = "SetEntryTitle",
            activityID = activityID,
            groupID = groupID,
            playstyle = playstyle,
            generalPlaystyle = generalPlaystyle,
        }
    end,
}

SQ.EventFrame = {
    RegisterEvent = function(_, event)
        calls[#calls + 1] = { name = "RegisterEvent", event = event }
    end,
    HookScript = function(_, scriptName, handler)
        calls[#calls + 1] = { name = "HookScript", scriptName = scriptName }
        if scriptName == "OnEvent" then
            listingEventHandler = handler
        end
    end,
}

local function loadFile(path)
    local chunk = assert(loadfile(path))
    chunk("SoloQ", SQ)
end

local function reset()
    calls = {}
    PVEFrame.shown = false
    LFGListFrame.activePanel = nil
    LFGListFrame.CategorySelection.selectedCategory = nil
    LFGListFrame.ApplicationViewer.applicants = {}
    LFGListFrame.EntryCreation.baseFilters = nil
    LFGListFrame.EntryCreation.selectedFilters = nil
    LFGListFrame.EntryCreation.selectedCategory = nil
    LFGListFrame.EntryCreation.selectedGroup = nil
    LFGListFrame.EntryCreation.selectedActivity = nil
    LFGListFrame.EntryCreation.selectedPlaystyle = nil
    LFGListFrame.EntryCreation.generalPlaystyle = nil
    LFGListFrame.EntryCreation.Name.text = ""
    LFGListFrame.EntryCreation.ActivityDropdown.overrideName = nil
    LFGListFrame.EntryCreation.ActivityDropdown.shown = nil
    LFGListFrame.EntryCreation.GroupDropdown.overrideName = nil
    LFGListFrame.EntryCreation.GroupDropdown.shown = nil
    LFGListFrame.EntryCreation.ActivityFinder.shown = false
    LFGListFrame.EntryCreation.ListGroupButton.clickCreatesListing = false
    C_LFGList.active = false
    C_LFGList.createResult = true
    C_LFGList.createError = nil
    SQ.lastStatus = nil
end

local function assertEquals(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local function assertTrue(value, label)
    if not value then
        error(label, 2)
    end
end

local function findCall(name)
    for _, call in ipairs(calls) do
        if call.name == name then
            return call
        end
    end
    return nil
end

local function run()
    SQ.SetStatus = function(message)
        SQ.lastStatus = message
    end
    SQ.UI = {
        UpdateVisibility = function()
            calls[#calls + 1] = { name = "UpdateVisibility" }
        end,
    }
    SQ.Applicants = {
        ResetSession = function()
            calls[#calls + 1] = { name = "ResetSession" }
        end,
        ScanApplicants = function()
            calls[#calls + 1] = { name = "ScanApplicants" }
        end,
    }

    loadFile("Listing.lua")
    SQ.Listing.Init()

    reset()
    assertEquals(SQ.Listing.ListOwnedKeystone(), true, "owned keystone listing prepares form")
    assertEquals(findCall("CreateListing"), nil, "prepared listing does not call addon create listing")
    assertTrue(findCall("LFGListUtil_OpenBestWindow") ~= nil, "prepared listing opens group finder")
    assertEquals(LFGListFrame.activePanel, LFGListFrame.EntryCreation, "prepared listing opens creation panel")
    assertTrue(findCall("ClearCreationTextFields") ~= nil, "prepared listing clears creation text fields")
    local selectCall = findCall("LFGListEntryCreation_Select")
    assertEquals(selectCall, nil, "prepared listing avoids protected Blizzard activity select helper")
    assertEquals(findCall("LFGListEntryCreation_Show"), nil, "prepared listing avoids protected Blizzard entry creation helper")
    assertEquals(LFGListFrame.EntryCreation.selectedCategory, GROUP_FINDER_CATEGORY_ID_DUNGEONS, "prepared listing stores dungeon category")
    assertEquals(LFGListFrame.EntryCreation.selectedGroup, 678, "prepared listing stores selected group")
    assertEquals(LFGListFrame.EntryCreation.selectedActivity, 12345, "prepared listing stores selected activity")
    assertEquals(LFGListFrame.EntryCreation.ActivityDropdown.overrideName, "Test Key", "prepared listing updates activity dropdown text")
    assertEquals(LFGListFrame.EntryCreation.GroupDropdown.overrideName, "Test Dungeon", "prepared listing updates group dropdown text")
    assertTrue(findCall("ActivityDropdownGenerateMenu") ~= nil, "prepared listing refreshes activity dropdown")
    assertTrue(findCall("GroupDropdownGenerateMenu") ~= nil, "prepared listing refreshes group dropdown")
    assertEquals(LFGListFrame.EntryCreation.generalPlaystyle, 3, "prepared listing stores default general playstyle")
    assertTrue(findCall("PlayStyleDropdownGenerateMenu") ~= nil, "prepared listing refreshes playstyle dropdown")
    local validStateCall = findCall("LFGListEntryCreation_UpdateValidState")
    assertTrue(validStateCall ~= nil, "prepared listing refreshes entry validity")
    assertEquals(validStateCall.selectedActivity, 12345, "entry creation is shown only after selected activity is populated")
    assertEquals(LFGListFrame.EntryCreation.ActivityFinder.shown, false, "prepared listing closes activity picker")
    local titleCall = findCall("SetEntryTitle")
    assertTrue(titleCall ~= nil, "prepared listing fills keystone title through Blizzard SetEntryTitle API")
    assertEquals(titleCall.activityID, 12345, "prepared listing title uses owned keystone activity")
    assertEquals(titleCall.groupID, 678, "prepared listing title uses owned keystone group")
    assertEquals(titleCall.generalPlaystyle, 0, "prepared listing title omits the playstyle so it reads as the bare key level")
    assertEquals(LFGListFrame.EntryCreation.generalPlaystyle, 3, "listing still carries the default general playstyle even though the title omits it")
    assertEquals(findCall("LFGListEntryCreation_OnPlayStyleSelectedInternal"), nil, "prepared listing avoids protected playstyle helper")
    assertEquals(findCall("SetSearchToActivity"), nil, "prepared listing does not use search-only activity API")
    assertEquals(findCall("StartGroupButtonClick"), nil, "prepared listing does not rely on category start button")
    assertEquals(findCall("ListGroupButtonClick"), nil, "prepared listing does not click protected Blizzard list button")
    assertEquals(SQ.lastStatus, "Prepared +10 keystone listing. Click Blizzard's List Group button to post it.", "prepared listing status")
    assertTrue(listingEventHandler ~= nil, "listing event handler registered")
    C_LFGList.active = true
    listingEventHandler(nil, "LFG_LIST_ACTIVE_ENTRY_UPDATE")
    assertEquals(LFGListFrame.activePanel, LFGListFrame.ApplicationViewer, "active listing event opens application viewer")
    assertEquals(SQ.lastStatus, "Listed +10 keystone. Opened applicants.", "active listing event status")

    reset()
    LFGListFrame.ApplicationViewer.applicants = nil
    assertEquals(SQ.Listing.ListOwnedKeystone(), true, "listing prepares when application viewer is not ready")
    assertEquals(LFGListFrame.activePanel, LFGListFrame.EntryCreation, "unready application viewer still opens creation panel")
    assertEquals(SQ.lastStatus, "Prepared +10 keystone listing. Click Blizzard's List Group button to post it.", "unready application viewer prepare status")
    C_LFGList.active = true
    listingEventHandler(nil, "LFG_LIST_ACTIVE_ENTRY_UPDATE")
    assertEquals(LFGListFrame.activePanel, LFGListFrame.EntryCreation, "unready application viewer is still not forced open after event")
    assertEquals(SQ.lastStatus, "Listed +10 keystone. Active listing found; applicants are still loading.", "unready application viewer event status")

    reset()
    C_LFGList.active = true
    assertEquals(SQ.Listing.ListOwnedKeystone(), true, "active listing opens viewer")
    assertEquals(findCall("CreateListing"), nil, "active listing does not recreate listing")
    assertEquals(LFGListFrame.activePanel, LFGListFrame.ApplicationViewer, "active listing opens application viewer")

    reset()
    C_LFGList.active = true
    LFGListFrame.ApplicationViewer.applicants = nil
    assertEquals(SQ.Listing.ListOwnedKeystone(), true, "active listing opens safely when application viewer is not ready")
    assertEquals(LFGListFrame.activePanel, nil, "active listing does not force unready application viewer")
    assertEquals(SQ.lastStatus, "Opened active Group Finder listing; applicants are still loading.", "active unready listing status")

    reset()
    C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel = function()
        return nil, nil, nil
    end
    assertEquals(SQ.Listing.ListOwnedKeystone(), false, "missing keystone returns false")
    assertEquals(SQ.lastStatus, "No owned Mythic+ keystone found.", "missing keystone status")

    print("PASS tests/run_listing_tests.lua")
end

run()
