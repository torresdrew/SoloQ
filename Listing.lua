local addonName, SQ = ...
SQ = SQ or {}

local Listing = {}
SQ.Listing = Listing
local initialized = false
local pendingApplicantOpen = nil

local function setStatus(message)
    if SQ.SetStatus then
        SQ.SetStatus(message)
    end
end

local function isActiveListing()
    return C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo() or false
end

local function callIfExists(fn, ...)
    if not fn then
        return false
    end
    return pcall(fn, ...)
end

local function callMethodIfExists(object, methodName, ...)
    local method = object and object[methodName] or nil
    if not method then
        return false
    end
    return pcall(method, object, ...)
end

local function getDungeonCategoryID()
    return GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2
end

local function getLegacyNoPlaystyle()
    if Enum and Enum.LFGEntryPlaystyle and Enum.LFGEntryPlaystyle.None then
        return Enum.LFGEntryPlaystyle.None
    end
    return 0
end

local function getDefaultListingGeneralPlaystyle()
    if Enum and Enum.LFGEntryGeneralPlaystyle and Enum.LFGEntryGeneralPlaystyle.FunSerious then
        return Enum.LFGEntryGeneralPlaystyle.FunSerious
    end
    return 3
end

local function getNoGeneralPlaystyle()
    if Enum and Enum.LFGEntryGeneralPlaystyle and Enum.LFGEntryGeneralPlaystyle.None then
        return Enum.LFGEntryGeneralPlaystyle.None
    end
    return 0
end

local function isMissingGeneralPlaystyle(generalPlaystyle)
    return generalPlaystyle == nil
        or generalPlaystyle == getNoGeneralPlaystyle()
        or generalPlaystyle == getLegacyNoPlaystyle()
end

local function openPVEFrame()
    if PVEFrame and PVEFrame.IsShown and not PVEFrame:IsShown() then
        if PVEFrame_ToggleFrame then
            PVEFrame_ToggleFrame()
            return
        end
        if PVEFrame.Show then
            PVEFrame:Show()
        end
    elseif not PVEFrame and PVEFrame_ToggleFrame then
        PVEFrame_ToggleFrame()
    end
end

local function openBestLFGWindow()
    callIfExists(LFGListUtil_OpenBestWindow)
end

local function setActivePanel(panel)
    if LFGListFrame and panel and LFGListFrame_SetActivePanel then
        return callIfExists(LFGListFrame_SetActivePanel, LFGListFrame, panel)
    end
    return false
end

local function showEntryCreationPanel(key)
    local frame = LFGListFrame
    local entry = frame and frame.EntryCreation
    if not frame or not entry then
        return false
    end

    entry.baseFilters = frame.baseFilters or 0
    entry.selectedFilters = 0
    entry.selectedCategory = getDungeonCategoryID()
    entry.selectedGroup = key.groupID
    entry.selectedActivity = key.activityID
    entry.selectedPlaystyle = getLegacyNoPlaystyle()
    entry.generalPlaystyle = getDefaultListingGeneralPlaystyle()

    setActivePanel(entry)
    return frame.activePanel == entry
end

local function isApplicationViewerReady()
    local viewer = LFGListFrame and LFGListFrame.ApplicationViewer or nil
    return viewer and type(viewer.applicants) == "table" or false
end

local function openApplicationViewer()
    openPVEFrame()
    openBestLFGWindow()
    local opened = false
    if isApplicationViewerReady() then
        opened = setActivePanel(LFGListFrame.ApplicationViewer)
    end
    if SQ.UI and SQ.UI.UpdateVisibility then
        SQ.UI.UpdateVisibility()
    end
    return opened
end

local function resetAndScanApplicants()
    if SQ.Applicants and SQ.Applicants.ResetSession then
        SQ.Applicants.ResetSession()
    end
    if SQ.Applicants and SQ.Applicants.ScanApplicants then
        SQ.Applicants.ScanApplicants()
    end
end

local function getLfgCategoryInfo(categoryID)
    if not C_LFGList or not C_LFGList.GetLfgCategoryInfo then
        return nil
    end

    local ok, categoryInfo = callIfExists(C_LFGList.GetLfgCategoryInfo, categoryID)
    return ok and categoryInfo or nil
end

local function getActivityInfo(activityID)
    if not C_LFGList or not C_LFGList.GetActivityInfoTable then
        return nil
    end

    local ok, activityInfo = callIfExists(C_LFGList.GetActivityInfoTable, activityID)
    return ok and activityInfo or nil
end

local function getActivityGroupName(groupID)
    if not C_LFGList or not C_LFGList.GetActivityGroupInfo then
        return nil
    end

    local ok, groupName = callIfExists(C_LFGList.GetActivityGroupInfo, groupID)
    return ok and groupName or nil
end

local function refreshDropdown(dropdown)
    callMethodIfExists(dropdown, "GenerateMenu")
end

local function setDropdownShown(dropdown, shown)
    callMethodIfExists(dropdown, "SetShown", shown)
end

local function updateValidState(entry)
    if LFGListEntryCreation_UpdateValidState then
        callIfExists(LFGListEntryCreation_UpdateValidState, entry)
    end
end

local function refreshActivityDropdowns(entry, categoryID, groupID, activityID)
    local categoryInfo = getLfgCategoryInfo(categoryID) or {}
    local activityInfo = getActivityInfo(activityID)
    local groupName = getActivityGroupName(groupID)
    local autoChooseActivity = categoryInfo.autoChooseActivity and true or false

    if entry.ActivityDropdown then
        entry.ActivityDropdown.overrideName = activityInfo and activityInfo.shortName or nil
        setDropdownShown(entry.ActivityDropdown, (groupName ~= nil) and not autoChooseActivity)
        refreshDropdown(entry.ActivityDropdown)
    end

    if entry.GroupDropdown then
        entry.GroupDropdown.overrideName = groupName or (activityInfo and activityInfo.shortName) or nil
        setDropdownShown(entry.GroupDropdown, not autoChooseActivity)
        refreshDropdown(entry.GroupDropdown)
    end
end

local function selectOwnedKeystoneActivity(key)
    local entry = LFGListFrame and LFGListFrame.EntryCreation
    if not entry then
        return false
    end

    local categoryID = entry.selectedCategory or getDungeonCategoryID()
    entry.selectedCategory = categoryID
    entry.selectedGroup = key.groupID
    entry.selectedActivity = key.activityID
    if entry.selectedPlaystyle == nil then
        entry.selectedPlaystyle = getLegacyNoPlaystyle()
    end
    refreshActivityDropdowns(entry, categoryID, key.groupID, key.activityID)
    if entry.ActivityFinder and entry.ActivityFinder.Hide then
        callIfExists(function()
            entry.ActivityFinder:Hide()
        end)
    end
    updateValidState(entry)
    return true
end

local function applyDefaultPlaystyle()
    local entry = LFGListFrame and LFGListFrame.EntryCreation
    if not entry then
        return false
    end

    if not isMissingGeneralPlaystyle(entry.generalPlaystyle) then
        refreshDropdown(entry.PlayStyleDropdown)
        updateValidState(entry)
        return true
    end

    entry.generalPlaystyle = getDefaultListingGeneralPlaystyle()
    refreshDropdown(entry.PlayStyleDropdown)
    updateValidState(entry)
    return true
end

local function setEntryTitleForKey(key)
    local entry = LFGListFrame and LFGListFrame.EntryCreation
    if not entry then
        return false
    end

    -- The entry-creation title box (LFGListEntryCreation.Name) is a secure edit
    -- box declared with securityDisableSetText="true", so the client ignores
    -- :SetText from insecure addon code. Blizzard builds the keystone title from
    -- C_LFGList.SetEntryTitle, appending the general-playstyle word ("Competitive"
    -- for FunSerious, etc.) when one is supplied. Pass None for both playstyles so
    -- the generated title is just the key level (e.g. "+10").
    --
    -- The listing itself keeps entry.generalPlaystyle (set in applyDefaultPlaystyle
    -- and read from the form when List Group is clicked), so the playstyle is still
    -- attached to the group -- it is only left out of the visible title text.
    if C_LFGList and C_LFGList.SetEntryTitle then
        return callIfExists(
            C_LFGList.SetEntryTitle,
            key.activityID,
            key.groupID,
            getLegacyNoPlaystyle(),
            getNoGeneralPlaystyle()
        )
    end

    -- Fallback: if SetEntryTitle is missing, let Blizzard's helper title it (this
    -- path includes the playstyle word, e.g. "+10 Competitive").
    if LFGListEntryCreation_SetTitleFromActivityInfo then
        return callIfExists(LFGListEntryCreation_SetTitleFromActivityInfo, entry)
    end

    return false
end

local function clearCreationTextFields()
    if C_LFGList and C_LFGList.ClearCreationTextFields then
        callIfExists(C_LFGList.ClearCreationTextFields)
    end
end

local function openCreationPanel(key)
    openPVEFrame()
    openBestLFGWindow()

    if LFGListFrame and LFGListFrame.CategorySelection and LFGListCategorySelection_SelectCategory then
        callIfExists(
            LFGListCategorySelection_SelectCategory,
            LFGListFrame.CategorySelection,
            getDungeonCategoryID(),
            0
        )
    end

    showEntryCreationPanel(key)

    if LFGListFrame then
        if LFGListFrame.activePanel ~= LFGListFrame.EntryCreation then
            setActivePanel(LFGListFrame.EntryCreation or LFGListFrame.CategorySelection)
        end
    end

    clearCreationTextFields()
    selectOwnedKeystoneActivity(key)
    applyDefaultPlaystyle()
    setEntryTitleForKey(key)

    if SQ.UI and SQ.UI.UpdateVisibility then
        SQ.UI.UpdateVisibility()
    end
end

local function finishAfterListing(key, status)
    pendingApplicantOpen = nil
    local opened = openApplicationViewer()
    if opened then
        setStatus(status)
    else
        setStatus("Listed +" .. tostring(key.keystoneLevel)
            .. " keystone. Open Group Finder applicants when Blizzard finishes loading them.")
    end
    resetAndScanApplicants()
end

local function queuePreparedListing(key)
    pendingApplicantOpen = {
        keystoneLevel = key.keystoneLevel,
    }
    setStatus("Prepared +" .. tostring(key.keystoneLevel)
        .. " keystone listing. Click Blizzard's List Group button to post it.")
end

local function tryOpenPendingApplicants()
    if not pendingApplicantOpen or not isActiveListing() then
        return false
    end

    local key = pendingApplicantOpen
    local opened = openApplicationViewer()
    if opened then
        pendingApplicantOpen = nil
        setStatus("Listed +" .. tostring(key.keystoneLevel) .. " keystone. Opened applicants.")
    else
        setStatus("Listed +" .. tostring(key.keystoneLevel)
            .. " keystone. Active listing found; applicants are still loading.")
    end
    resetAndScanApplicants()
    return opened
end

local function finishAfterActiveListing()
    pendingApplicantOpen = nil
    local opened = openApplicationViewer()
    setStatus(opened and "Opened active Group Finder listing."
        or "Opened active Group Finder listing; applicants are still loading.")
    resetAndScanApplicants()
end

function Listing.GetOwnedKeystone()
    if not C_LFGList or not C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel then
        return nil, "Owned keystone API is unavailable."
    end

    local activityID, groupID, keystoneLevel = C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel()
    if not activityID or activityID == 0 or not keystoneLevel or keystoneLevel == 0 then
        return nil, "No owned Mythic+ keystone found."
    end

    return {
        activityID = activityID,
        groupID = groupID,
        keystoneLevel = keystoneLevel,
    }
end

function Listing.ListOwnedKeystone()
    if isActiveListing() then
        finishAfterActiveListing()
        return true
    end

    local key, reason = Listing.GetOwnedKeystone()
    if not key then
        setStatus(reason)
        return false
    end

    openCreationPanel(key)
    queuePreparedListing(key)
    return true
end

function Listing.OnEvent(_, event)
    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" or event == "LFG_LIST_APPLICANT_LIST_UPDATED" then
        tryOpenPendingApplicants()
    end
end

function Listing.Init()
    if initialized or not SQ.EventFrame or not SQ.EventFrame.HookScript then
        return
    end
    initialized = true
    SQ.EventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    SQ.EventFrame:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
    SQ.EventFrame:HookScript("OnEvent", Listing.OnEvent)
end
