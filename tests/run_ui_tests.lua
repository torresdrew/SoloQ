local SQ = {}
local createdFrames = {}
local createdFontStrings = {}

local function makeFrame(name, parent, template)
    local frame = {
        name = name,
        parent = parent,
        shown = false,
        children = {},
        template = template,
    }
    table.insert(createdFrames, frame)
    function frame:SetSize(width, height)
        self.width = width
        self.height = height
    end
    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        self.point = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
    end
    function frame:ClearAllPoints() end
    function frame:SetFrameStrata() end
    function frame:SetMovable() end
    function frame:EnableMouse() end
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
        function texture:SetPoint(point, relativeTo, relativePoint, x, y)
            self.point = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
        end
        function texture:SetTexCoord() end
        return texture
    end
    function frame:GetFontString()
        if not self.fontString then
            self.fontString = self:CreateFontString()
        end
        return self.fontString
    end
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

PVEFrame = makeFrame("PVEFrame")
local testGroupFinderFrame = makeFrame("GroupFinderFrame", PVEFrame)
testGroupFinderFrame.groupButton1 = makeFrame("GroupFinderFrameGroupButton1", testGroupFinderFrame)
testGroupFinderFrame.groupButton2 = makeFrame("GroupFinderFrameGroupButton2", testGroupFinderFrame)
testGroupFinderFrame.groupButton3 = makeFrame("GroupFinderFrameGroupButton3", testGroupFinderFrame)
GroupFinderFrame = nil
LFGListFrame = {
    activePanel = "ApplicationViewer",
    ApplicationViewer = "ApplicationViewer",
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

local function run()
    SoloQSettings = {
        enabled = false,
        minScore = 0,
        composition = {
            requireBloodlust = false,
            requireBattleRes = false,
        },
    }

    SQ.Applicants = {
        GetContext = function()
            return { hasActiveEntry = true, isLeader = true, isMythicPlus = true }
        end,
        GetPendingAction = function()
            return nil
        end,
        GetProposedGroup = function()
            return { invitees = { { name = "Tank-Area52" }, { name = "Healer-Area52" } } }
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
    LFGListFrame.activePanel = "SearchPanel"
    assertEquals(SQ.UI.ShouldShowPanel(), false, "search panel hides panel")

    LFGListFrame.activePanel = LFGListFrame.ApplicationViewer
    SQ.UI.SetMinScore("3010")
    assertEquals(SoloQSettings.minScore, 3010, "min score updated")

    SQ.UI.SetRequireBloodlust(true)
    assertEquals(SoloQSettings.composition.requireBloodlust, true, "bloodlust requirement updated")

    SQ.UI.SetRequireBattleRes(true)
    assertEquals(SoloQSettings.composition.requireBattleRes, true, "battle res requirement updated")

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
