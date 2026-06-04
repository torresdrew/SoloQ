local SQ = {}
local createdFrames = {}
local createdFontStrings = {}
local playedSounds = {}

SOUNDKIT = {
    READY_CHECK = 1001,
    RAID_WARNING = 1002,
    AUCTION_WINDOW_OPEN = 1003,
    TELL_MESSAGE = 1004,
}

function PlaySound(sound, channel)
    playedSounds[#playedSounds + 1] = { sound = sound, channel = channel }
end

local function makeFrame(name, parent, template)
    local frame = {
        name = name,
        parent = parent,
        shown = false,
        children = {},
        template = template,
        frameLevel = 1,
    }
    table.insert(createdFrames, frame)
    function frame:SetSize(width, height)
        self.width = width
        self.height = height
    end
    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        self.point = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
    end
    function frame:SetAllPoints(relativeTo) self.allPoints = relativeTo end
    function frame:ClearAllPoints() self.point = nil; self.allPoints = nil end
    function frame:SetFrameStrata(value) self.frameStrata = value end
    function frame:SetFrameLevel(value) self.frameLevel = value end
    function frame:GetFrameLevel() return self.frameLevel end
    function frame:SetMovable() end
    function frame:EnableMouse(value) self.mouseEnabled = value end
    function frame:RegisterForDrag() end
    function frame:SetScript(name, handler) self[name] = handler end
    function frame:CreateFontString()
        local fontString = {}
        function fontString:SetPoint(point, relativeTo, relativePoint, x, y)
            self.point = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
        end
        function fontString:SetWidth(width) self.width = width end
        function fontString:SetHeight(height) self.height = height end
        function fontString:SetWordWrap(value) self.wordWrap = value end
        function fontString:SetJustifyH(value) self.justifyH = value end
        function fontString:SetText(text) self.text = text end
        function fontString:ClearAllPoints() end
        table.insert(createdFontStrings, fontString)
        return fontString
    end
    function frame:CreateTexture()
        local texture = {}
        function texture:SetTexture(path) self.texture = path end
        function texture:SetSize(width, height) self.width = width; self.height = height end
        function texture:SetColorTexture(red, green, blue, alpha)
            self.colorTexture = { red = red, green = green, blue = blue, alpha = alpha }
        end
        function texture:SetAllPoints(relativeTo) self.allPoints = relativeTo end
        function texture:SetPoint(point, relativeTo, relativePoint, x, y)
            self.point = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
        end
        function texture:SetAlpha(value) self.alpha = value end
        function texture:SetTexCoord() end
        return texture
    end
    function frame:GetFontString()
        if not self.fontString then
            self.fontString = self:CreateFontString()
        end
        return self.fontString
    end
    function frame:GetName() return self.name end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:SetText(text) self.text = text end
    function frame:GetText() return self.text or "" end
    function frame:SetChecked(value) self.checked = value end
    function frame:GetChecked() return self.checked end
    function frame:SetEnabled(value) self.enabled = value end
    function frame:SetAutoFocus() end
    function frame:SetNumeric() end
    function frame:SetNumber(value) self.text = tostring(value) end
    function frame:GetNumber() return tonumber(self.text) or 0 end
    function frame:SetWidth(width) self.width = width end
    function frame:SetHeight(height) self.height = height end
    return frame
end

function CreateFrame(_, name, parent, template)
    return makeFrame(name, parent, template)
end

local dropdownButtons = {}

local function requireDropdownName(dropdown)
    local name = dropdown and dropdown.GetName and dropdown:GetName()
    assert(name and name ~= "", "dropdown must be named for Blizzard dropdown helpers")
    return name
end

function UIDropDownMenu_SetWidth(dropdown, width)
    requireDropdownName(dropdown)
    dropdown.dropdownWidth = width
end

function UIDropDownMenu_SetText(dropdown, text)
    requireDropdownName(dropdown)
    dropdown.text = text
end

function UIDropDownMenu_EnableDropDown(dropdown)
    requireDropdownName(dropdown)
    dropdown.enabled = true
end

function UIDropDownMenu_DisableDropDown(dropdown)
    requireDropdownName(dropdown)
    dropdown.enabled = false
end

function UIDropDownMenu_CreateInfo()
    return {}
end

function UIDropDownMenu_AddButton(info)
    dropdownButtons[#dropdownButtons + 1] = info
end

function UIDropDownMenu_Initialize(dropdown, initialize)
    requireDropdownName(dropdown)
    dropdown.initialize = initialize
    initialize(dropdown)
end

PVEFrame = makeFrame("PVEFrame")
local testGroupFinderFrame = makeFrame("GroupFinderFrame", PVEFrame)
testGroupFinderFrame.groupButton1 = makeFrame("GroupFinderFrameGroupButton1", testGroupFinderFrame)
testGroupFinderFrame.groupButton2 = makeFrame("GroupFinderFrameGroupButton2", testGroupFinderFrame)
testGroupFinderFrame.groupButton3 = makeFrame("GroupFinderFrameGroupButton3", testGroupFinderFrame)
GroupFinderFrame = nil
local testApplicationViewer = makeFrame("LFGListFrameApplicationViewer", PVEFrame)
local testApplicationScrollFrame = makeFrame("LFGListApplicationViewerScrollFrame", testApplicationViewer)
testApplicationScrollFrame:SetFrameLevel(5)
testApplicationViewer.ScrollFrame = testApplicationScrollFrame
LFGListFrame = {
    activePanel = testApplicationViewer,
    ApplicationViewer = testApplicationViewer,
}

local function loadFile(path)
    local chunk = assert(loadfile(path))
    chunk("SoloQ", SQ)
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

local function findFontStringByText(text)
    for _, fontString in ipairs(createdFontStrings) do
        if fontString.text == text then
            return fontString
        end
    end
    return nil
end

local function findButtonByText(text)
    for _, frame in ipairs(createdFrames) do
        if frame.template == "UIPanelButtonTemplate" and frame.text == text then
            return frame
        end
    end
    return nil
end

local function findFrameByTemplateAndY(template, y)
    for _, frame in ipairs(createdFrames) do
        if frame.template == template and frame.point and frame.point.y == y then
            return frame
        end
    end
    return nil
end

local function findFrameByName(name)
    for _, frame in ipairs(createdFrames) do
        if frame.name == name then
            return frame
        end
    end
    return nil
end

local function run()
    SoloQSettings = {
        enabled = false,
        minScore = 0,
        composition = {
            requireBloodlust = false,
            requireBattleRes = false,
        },
        notifications = {
            playReadySound = false,
            readySound = "UNKNOWN_SOUND",
        },
    }

    local proposedGroup = {
        invitees = { { name = "Tank-Area52" }, { name = "Healer-Area52" } },
    }
    SQ.Applicants = {
        GetContext = function()
            return { hasActiveEntry = true, isLeader = true, isMythicPlus = true }
        end,
        GetPendingAction = function()
            return nil
        end,
        GetProposedGroup = function()
            return proposedGroup
        end,
    }
    local listedKey = false
    SQ.Listing = {
        ListOwnedKeystone = function()
            listedKey = true
            return true
        end,
    }
    SQ.SetStatus = function(message)
        SQ.lastStatus = message
    end

    loadFile("UI.lua")
    SQ.UI.Init()
    GroupFinderFrame = testGroupFinderFrame
    SQ.UI.Init()

    local pendingText = findFontStringByText("Pending: none")
    local inviteButton = findButtonByText("Invite")
    assertTrue(pendingText ~= nil, "pending label exists")
    assertTrue(inviteButton ~= nil, "single invite button exists")
    assertEquals(pendingText.height, 14, "pending label has fixed single-line height")
    assertEquals(pendingText.wordWrap, false, "pending label does not wrap behind buttons")
    assertTrue((pendingText.point.y - pendingText.height) > inviteButton.point.y, "pending label clears invite button")

    local listKeyButton = findButtonByText("SoloQ: Prep Key")
    assertTrue(listKeyButton ~= nil, "group finder prep key button exists")
    assertTrue(listKeyButton.icon ~= nil, "prep key button has an icon")
    assertEquals(listKeyButton.icon.texture, "Interface\\AddOns\\SoloQ\\assets\\hero_rat.tga", "prep key icon uses hero_rat tga")
    assertEquals(listKeyButton.fontString.justifyH, "CENTER", "prep key label re-centers beside the icon")
    assertEquals(listKeyButton.icon.point.relativePoint, "LEFT", "prep key icon sits to the left of the label")
    assertEquals(listKeyButton.icon.point.relativeTo, listKeyButton.fontString, "prep key icon anchors to the label")
    assertEquals(listKeyButton.height, 32, "prep key button is taller for a bigger icon")
    assertEquals(listKeyButton.parent, GroupFinderFrame, "prep key button is on group finder frame")
    assertEquals(listKeyButton.point.point, "TOP", "prep key button anchors from top")
    assertEquals(listKeyButton.point.relativeTo, testGroupFinderFrame.groupButton3, "prep key button anchors under premade groups")
    assertEquals(listKeyButton.point.relativePoint, "BOTTOM", "prep key button anchors below premade groups")
    listKeyButton.OnClick()
    assertEquals(listedKey, true, "group finder button prepares owned keystone")

    assertEquals(SQ.UI.ShouldShowPanel(), true, "application viewer mplus shows panel")
    SQ.UI.UpdateVisibility()
    local evaluationCheck = findFrameByTemplateAndY("UICheckButtonTemplate", -34)
    local applicantCover = findFrameByName("SoloQApplicantCover")
    assertTrue(applicantCover ~= nil, "applicant list cover exists")
    assertEquals(applicantCover.parent, LFGListFrame.ApplicationViewer, "applicant cover is parented to application viewer")
    assertEquals(applicantCover.allPoints, testApplicationScrollFrame, "applicant cover anchors over application scroll frame")
    assertEquals(applicantCover.frameLevel, testApplicationScrollFrame.frameLevel + 20, "applicant cover sits above applicant rows")
    assertEquals(applicantCover.frameStrata, "FULLSCREEN", "applicant cover uses high strata")
    assertEquals(applicantCover.mouseEnabled, true, "applicant cover blocks hidden applicant clicks")
    assertTrue(applicantCover.background ~= nil, "applicant cover has opaque background")
    assertEquals(applicantCover.background.allPoints, applicantCover, "applicant cover background fills cover")
    assertEquals(applicantCover.background.colorTexture.alpha, 0.92, "applicant cover background hides applicant rows")
    assertTrue(applicantCover.icon ~= nil, "applicant cover has rat texture")
    assertEquals(applicantCover.icon.texture, "Interface\\AddOns\\SoloQ\\assets\\hero_rat.tga", "applicant cover uses hero rat texture")
    assertEquals(applicantCover.icon.width, 220, "applicant cover rat texture width")
    assertEquals(applicantCover.icon.height, 188, "applicant cover rat texture height")
    assertEquals(applicantCover.icon.point.point, "CENTER", "applicant cover rat texture is centered")
    assertEquals(applicantCover.shown, false, "applicant cover stays hidden while evaluation is disabled")

    evaluationCheck:SetChecked(true)
    evaluationCheck.OnClick(evaluationCheck)
    assertEquals(SoloQSettings.enabled, true, "evaluation checkbox enables setting")
    assertEquals(applicantCover.shown, true, "enabled evaluation shows applicant cover")

    evaluationCheck:SetChecked(false)
    evaluationCheck.OnClick(evaluationCheck)
    assertEquals(SoloQSettings.enabled, false, "evaluation checkbox disables setting")
    assertEquals(applicantCover.shown, false, "disabled evaluation hides applicant cover")

    evaluationCheck:SetChecked(true)
    evaluationCheck.OnClick(evaluationCheck)
    assertEquals(applicantCover.shown, true, "reenabled evaluation restores applicant cover")

    LFGListFrame.activePanel = "SearchPanel"
    assertEquals(SQ.UI.ShouldShowPanel(), false, "search panel hides panel")
    SQ.UI.UpdateVisibility()
    assertEquals(applicantCover.shown, false, "search panel hides applicant cover")

    LFGListFrame.activePanel = LFGListFrame.ApplicationViewer
    SQ.UI.UpdateVisibility()
    assertEquals(applicantCover.shown, true, "application viewer restores applicant cover")
    SQ.UI.SetMinScore("3010")
    assertEquals(SoloQSettings.minScore, 3010, "min score updated")

    SQ.UI.SetRequireBloodlust(true)
    assertEquals(SoloQSettings.composition.requireBloodlust, true, "bloodlust requirement updated")

    SQ.UI.SetRequireBattleRes(true)
    assertEquals(SoloQSettings.composition.requireBattleRes, true, "battle res requirement updated")

    local readySoundLabel = findFontStringByText("Play ready sound")
    local readySoundCheck = findFrameByTemplateAndY("UICheckButtonTemplate", -154)
    local readySoundDropdown = findFrameByTemplateAndY("UIDropDownMenuTemplate", -178)
    assertTrue(readySoundLabel ~= nil, "ready sound checkbox label exists")
    assertTrue(readySoundCheck ~= nil, "ready sound checkbox exists")
    assertTrue(readySoundDropdown ~= nil, "ready sound dropdown exists")
    assertEquals(readySoundDropdown.name, "SoloQReadySoundDropdown", "ready sound dropdown has stable global name")
    assertEquals(readySoundCheck.checked, false, "play ready sound defaults unchecked")
    assertEquals(readySoundDropdown.selectedKey, "READY_CHECK", "invalid ready sound falls back to default key")
    assertEquals(readySoundDropdown.text, "Ready Check", "ready sound dropdown defaults to ready check label")
    assertEquals(readySoundDropdown.enabled, false, "ready sound dropdown disabled when sound is unchecked")

    readySoundCheck:SetChecked(true)
    readySoundCheck.OnClick(readySoundCheck)
    assertEquals(SoloQSettings.notifications.playReadySound, true, "play ready sound setting updated")
    assertEquals(readySoundDropdown.enabled, true, "ready sound dropdown enabled when sound is checked")

    readySoundDropdown:SelectValue("AUCTION_BELL")
    assertEquals(SoloQSettings.notifications.readySound, "AUCTION_BELL", "ready sound selection updates setting")
    assertEquals(readySoundDropdown.selectedKey, "AUCTION_BELL", "ready sound dropdown stores selected key")
    assertEquals(readySoundDropdown.text, "Auction Bell", "ready sound dropdown shows selected label")

    SoloQSettings.notifications.readySound = nil
    SQ.UI.Refresh()
    assertEquals(SoloQSettings.notifications.readySound, "READY_CHECK", "missing ready sound falls back to default key")
    assertEquals(readySoundDropdown.selectedKey, "READY_CHECK", "ready sound dropdown refresh falls back to default key")

    playedSounds = {}
    proposedGroup = { invitees = { { name = "Tank-Area52" } } }
    SQ.UI.UpdatePendingAction()
    assertEquals(#playedSounds, 0, "incomplete proposal does not play ready sound")

    proposedGroup = { complete = true, invitees = { { name = "Tank-Area52" } } }
    SQ.UI.UpdatePendingAction()
    assertEquals(#playedSounds, 1, "complete proposal plays ready sound once")

    SQ.UI.UpdatePendingAction()
    assertEquals(#playedSounds, 1, "repeated complete proposal does not replay ready sound")

    proposedGroup = { invitees = { { name = "Tank-Area52" } } }
    SQ.UI.UpdatePendingAction()
    proposedGroup = { complete = true, invitees = { { name = "Healer-Area52" } } }
    SQ.UI.UpdatePendingAction()
    assertEquals(#playedSounds, 2, "incomplete then complete proposal plays ready sound again")

    SoloQSettings.notifications.playReadySound = false
    proposedGroup = nil
    SQ.UI.UpdatePendingAction()
    proposedGroup = { complete = true, invitees = { { name = "Dps-Area52" } } }
    SQ.UI.UpdatePendingAction()
    assertEquals(#playedSounds, 2, "disabled setting does not play ready sound")
    SoloQSettings.notifications.playReadySound = true
    SQ.UI.UpdatePendingAction()
    assertEquals(#playedSounds, 2, "enabling sound while complete does not play stale ready sound")

    SoloQSettings.notifications.readySound = "TELL_MESSAGE"
    proposedGroup = nil
    SQ.UI.UpdatePendingAction()
    proposedGroup = { complete = true, invitees = { { name = "Dps2-Area52" } } }
    SQ.UI.UpdatePendingAction()
    assertEquals(#playedSounds, 3, "selected ready sound plays once")
    assertEquals(playedSounds[3].sound, SOUNDKIT.TELL_MESSAGE, "selected ready sound uses expected soundkit id")
    assertEquals(playedSounds[3].channel, "Master", "selected ready sound uses master channel")

    local realPlaySound = PlaySound
    local realSoundKit = SOUNDKIT

    proposedGroup = nil
    SQ.UI.UpdatePendingAction()
    PlaySound = nil
    proposedGroup = { complete = true, invitees = { { name = "Dps3-Area52" } } }
    local ok = pcall(SQ.UI.UpdatePendingAction)
    assertTrue(ok, "missing PlaySound does not error")
    assertEquals(#playedSounds, 3, "missing PlaySound does not play ready sound")
    PlaySound = realPlaySound

    proposedGroup = nil
    SQ.UI.UpdatePendingAction()
    SOUNDKIT = nil
    proposedGroup = { complete = true, invitees = { { name = "Dps4-Area52" } } }
    ok = pcall(SQ.UI.UpdatePendingAction)
    assertTrue(ok, "missing SOUNDKIT does not error")
    assertEquals(#playedSounds, 3, "missing SOUNDKIT does not play ready sound")
    SOUNDKIT = realSoundKit

    proposedGroup = nil
    SQ.UI.UpdatePendingAction()
    SOUNDKIT = { READY_CHECK = realSoundKit.READY_CHECK }
    proposedGroup = { complete = true, invitees = { { name = "Dps5-Area52" } } }
    ok = pcall(SQ.UI.UpdatePendingAction)
    assertTrue(ok, "missing selected SOUNDKIT constant does not error")
    assertEquals(#playedSounds, 3, "missing selected SOUNDKIT constant does not play ready sound")
    SOUNDKIT = realSoundKit

    local executedAction
    SQ.Applicants.ExecutePendingAction = function(action)
        executedAction = action
        return true
    end
    SQ.UI.ClickPendingAction("INVITE")
    assertEquals(executedAction, "INVITE", "ui click executes pending invite")

    local executedGroup = false
    SQ.Applicants.ExecuteProposedGroup = function()
        executedGroup = true
        return true
    end
    SQ.UI.ClickInviteGroup()
    assertEquals(executedGroup, true, "ui click executes proposed group")

    print("PASS tests/run_ui_tests.lua")
end

run()
