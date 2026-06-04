local addonName, SQ = ...
SQ = SQ or {}

local UI = {}
SQ.UI = UI

local PANEL_WIDTH = 260
local PANEL_HEIGHT = 432
local LINE_HEIGHT = 14
local BUTTON_HEIGHT = 22
local MIN_SCORE_Y = -70
local COMPOSITION_BLOODLUST_Y = -106
local COMPOSITION_BATTLE_RES_Y = -130
local READY_SOUND_CHECK_Y = -154
local READY_SOUND_DROPDOWN_Y = -178
local GROUP_HEADER_Y = -214
local GROUP_SLOT_START_Y = -232
local GROUP_SLOT_SPACING = 16
local INVITE_GROUP_BUTTON_Y = -320
local PENDING_Y = -352
local ACTION_BUTTON_Y = -376
local LIST_KEY_ICON = "Interface\\AddOns\\SoloQ\\assets\\hero_rat.tga"
local LIST_KEY_BUTTON_WIDTH = 200
local LIST_KEY_BUTTON_HEIGHT = 32
local APPLICANT_COVER_NAME = "SoloQApplicantCover"
local APPLICANT_COVER_BACKGROUND_ALPHA = 0.92
local APPLICANT_COVER_ICON_WIDTH = 220
local APPLICANT_COVER_ICON_HEIGHT = 188
local READY_SOUND_DEFAULT_KEY = "READY_CHECK"
local READY_SOUND_DROPDOWN_NAME = "SoloQReadySoundDropdown"
local READY_SOUND_DROPDOWN_WIDTH = 170
-- Icon kept at the art's ~1.17:1 aspect (626x535) so it is not squished.
local LIST_KEY_ICON_WIDTH = 30
local LIST_KEY_ICON_HEIGHT = 26
local ROLE_LABELS = {
    TANK = "Tank",
    HEALER = "Healer",
    DAMAGER = "DPS",
}
local READY_SOUND_OPTIONS = {
    { key = "READY_CHECK", label = "Ready Check", soundKit = "READY_CHECK" },
    { key = "RAID_WARNING", label = "Raid Warning", soundKit = "RAID_WARNING" },
    { key = "AUCTION_BELL", label = "Auction Bell", soundKit = "AUCTION_WINDOW_OPEN" },
    { key = "TELL_MESSAGE", label = "Tell Message", soundKit = "TELL_MESSAGE" },
}

local panel
local controls = {}
local applicantCover
local updateApplicantCoverVisibility
local initialized = false
local hookedGlobals = {}
local frameScriptsHooked = false
local forcedVisible = false
local readySoundWasComplete = false

local function getCompositionSettings()
    SoloQSettings.composition = SoloQSettings.composition or {}
    if SoloQSettings.composition.requireBloodlust == nil then
        SoloQSettings.composition.requireBloodlust = false
    end
    if SoloQSettings.composition.requireBattleRes == nil then
        SoloQSettings.composition.requireBattleRes = false
    end
    return SoloQSettings.composition
end

local function getReadySoundOption(key)
    for _, option in ipairs(READY_SOUND_OPTIONS) do
        if option.key == key then
            return option
        end
    end
    return nil
end

local function getNotificationSettings()
    SoloQSettings.notifications = SoloQSettings.notifications or {}
    if SoloQSettings.notifications.playReadySound == nil then
        SoloQSettings.notifications.playReadySound = false
    end
    if not getReadySoundOption(SoloQSettings.notifications.readySound) then
        SoloQSettings.notifications.readySound = READY_SOUND_DEFAULT_KEY
    end
    return SoloQSettings.notifications
end

local function isCompleteProposal(proposal)
    return (proposal and proposal.complete and proposal.invitees and #proposal.invitees > 0) and true or false
end

local function playReadySoundIfNeeded(proposal)
    local isComplete = isCompleteProposal(proposal)
    if not isComplete then
        readySoundWasComplete = false
        return
    end

    if readySoundWasComplete then
        return
    end

    readySoundWasComplete = true

    local notifications = getNotificationSettings()
    if not notifications.playReadySound then
        return
    end

    local option = getReadySoundOption(notifications.readySound)
    if not option or not option.soundKit or type(PlaySound) ~= "function" or type(SOUNDKIT) ~= "table" then
        return
    end

    local sound = SOUNDKIT[option.soundKit]
    if sound ~= nil then
        PlaySound(sound, "Master")
    end
end

local function setText(fontString, text)
    if fontString and fontString.SetText then
        fontString:SetText(text)
    end
end

local function setSingleLine(fontString)
    if fontString and fontString.SetHeight then
        fontString:SetHeight(LINE_HEIGHT)
    end
    if fontString and fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end
    if fontString and fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(false)
    end
end

local function createLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    setSingleLine(label)
    label:SetText(text)
    return label
end

local function createCheck(parent, x, y, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check:SetScript("OnClick", function(self)
        onClick(self:GetChecked())
    end)
    return check
end

local function findOption(options, key)
    for _, option in ipairs(options) do
        if option.key == key then
            return option
        end
    end
    return nil
end

local function setDropdownSelected(dropdown, option)
    if not dropdown or not option then
        return
    end
    dropdown.selectedKey = option.key
    dropdown.text = option.label
    if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(dropdown, option.label)
    elseif dropdown.SetText then
        dropdown:SetText(option.label)
    end
end

local function setDropdownEnabled(dropdown, enabled)
    if not dropdown then
        return
    end
    dropdown.enabled = enabled and true or false
    if dropdown.enabled then
        if UIDropDownMenu_EnableDropDown then
            UIDropDownMenu_EnableDropDown(dropdown)
        elseif dropdown.SetEnabled then
            dropdown:SetEnabled(true)
        end
    else
        if UIDropDownMenu_DisableDropDown then
            UIDropDownMenu_DisableDropDown(dropdown)
        elseif dropdown.SetEnabled then
            dropdown:SetEnabled(false)
        end
    end
end

local function createDropdown(parent, name, x, y, width, options, onSelect)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    dropdown.options = options
    if dropdown.SetSize then
        dropdown:SetSize(width, BUTTON_HEIGHT)
    end
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(dropdown, width)
    elseif dropdown.SetWidth then
        dropdown:SetWidth(width)
    end

    function dropdown:SelectValue(key)
        local option = findOption(options, key) or findOption(options, READY_SOUND_DEFAULT_KEY)
        onSelect(option.key)
        setDropdownSelected(self, option)
    end

    if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
        UIDropDownMenu_Initialize(dropdown, function()
            for _, option in ipairs(options) do
                local key = option.key
                local info = UIDropDownMenu_CreateInfo()
                info.text = option.label
                info.value = key
                info.checked = dropdown.selectedKey == key
                info.func = function()
                    dropdown:SelectValue(key)
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end

    return dropdown
end

local function createButton(parent, text, x, y, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, BUTTON_HEIGHT)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function createFreeButton(parent, name, text, width, onClick)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetSize(width, BUTTON_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function attachLeftIcon(button, texturePath, width, height)
    if not button or not button.CreateTexture then
        return nil
    end
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(texturePath)
    icon:SetSize(width, height)
    button.icon = icon

    -- Sit the icon just left of the (centered) label rather than at the
    -- button's far-left edge; fall back to the edge if there is no label.
    local label = button.GetFontString and button:GetFontString()
    if label then
        label:SetJustifyH("CENTER")
        icon:SetPoint("RIGHT", label, "LEFT", -4, 0)
    else
        icon:SetPoint("LEFT", button, "LEFT", 4, 0)
    end

    return icon
end

local function getApplicantViewer()
    return LFGListFrame and LFGListFrame.ApplicationViewer or nil
end

local function getApplicantCoverAnchor(viewer)
    if not viewer then
        return nil
    end
    return viewer.ScrollFrame or viewer.ScrollBox or viewer
end

local function createApplicantCover()
    if applicantCover then
        return applicantCover
    end

    local viewer = getApplicantViewer()
    local anchor = getApplicantCoverAnchor(viewer)
    if not viewer or not anchor or not CreateFrame then
        return nil
    end

    applicantCover = CreateFrame("Frame", APPLICANT_COVER_NAME, viewer)
    applicantCover:SetAllPoints(anchor)
    applicantCover:SetFrameStrata("FULLSCREEN")
    if applicantCover.SetFrameLevel then
        local anchorLevel = anchor.GetFrameLevel and anchor:GetFrameLevel() or 1
        applicantCover:SetFrameLevel(anchorLevel + 20)
    end
    applicantCover:EnableMouse(true)

    local background = applicantCover:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(applicantCover)
    if background.SetColorTexture then
        background:SetColorTexture(0, 0, 0, APPLICANT_COVER_BACKGROUND_ALPHA)
    else
        background:SetTexture(0, 0, 0, APPLICANT_COVER_BACKGROUND_ALPHA)
    end
    applicantCover.background = background

    local icon = applicantCover:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(LIST_KEY_ICON)
    icon:SetSize(APPLICANT_COVER_ICON_WIDTH, APPLICANT_COVER_ICON_HEIGHT)
    icon:SetPoint("CENTER", applicantCover, "CENTER", 0, 0)
    applicantCover.icon = icon

    applicantCover:Hide()
    return applicantCover
end

local function hookIfExists(name, handler)
    if hookedGlobals[name] then
        return
    end
    if hooksecurefunc and _G and _G[name] then
        hooksecurefunc(name, handler)
        hookedGlobals[name] = true
    end
end

local function createEditBox(parent, x, y, onEnter)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(58, 22)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetScript("OnEnterPressed", function(self)
        onEnter(self:GetNumber())
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        onEnter(self:GetNumber())
    end)
    return box
end

function UI.SetMinScore(value)
    local score = tonumber(value) or 0
    if score < 0 then
        score = 0
    end
    SoloQSettings.minScore = math.floor(score)
    SQ.SetStatus("Updated score threshold.")
end

function UI.SetRequireBloodlust(enabled)
    getCompositionSettings().requireBloodlust = enabled and true or false
    SQ.SetStatus("Updated bloodlust/heroism requirement.")
end

function UI.SetRequireBattleRes(enabled)
    getCompositionSettings().requireBattleRes = enabled and true or false
    SQ.SetStatus("Updated battle res requirement.")
end

function UI.SetPlayReadySound(enabled)
    getNotificationSettings().playReadySound = enabled and true or false
    setDropdownEnabled(controls.readySoundDropdown, getNotificationSettings().playReadySound)
    SQ.SetStatus("Updated ready sound notification.")
end

function UI.SetReadySound(key)
    local option = getReadySoundOption(key) or getReadySoundOption(READY_SOUND_DEFAULT_KEY)
    getNotificationSettings().readySound = option.key
    setDropdownSelected(controls.readySoundDropdown, option)
    SQ.SetStatus("Updated ready sound.")
end

function UI.Refresh()
    if controls.enabled then
        controls.enabled:SetChecked(SoloQSettings.enabled)
    end

    if controls.minScore then
        controls.minScore:SetNumber(SoloQSettings.minScore or 0)
    end

    local composition = getCompositionSettings()
    if controls.requireBloodlust then
        controls.requireBloodlust:SetChecked(composition.requireBloodlust)
    end
    if controls.requireBattleRes then
        controls.requireBattleRes:SetChecked(composition.requireBattleRes)
    end

    local notifications = getNotificationSettings()
    if controls.playReadySound then
        controls.playReadySound:SetChecked(notifications.playReadySound)
    end
    if controls.readySoundDropdown then
        setDropdownSelected(controls.readySoundDropdown, getReadySoundOption(notifications.readySound))
        setDropdownEnabled(controls.readySoundDropdown, notifications.playReadySound)
    end
    if updateApplicantCoverVisibility then
        updateApplicantCoverVisibility()
    end

    UI.UpdatePendingAction()
    UI.UpdateStatus()
end

function UI.UpdateStatus()
    if controls.status then
        controls.status:SetText(SQ.lastStatus or "")
    end
end

function UI.ClickPendingAction(action)
    if SQ.Applicants and SQ.Applicants.ExecutePendingAction then
        return SQ.Applicants.ExecutePendingAction(action)
    end
    SQ.SetStatus("Applicant actions are not loaded.")
    return false
end

function UI.ClickInviteGroup()
    if SQ.Applicants and SQ.Applicants.ExecuteProposedGroup then
        return SQ.Applicants.ExecuteProposedGroup()
    end
    SQ.SetStatus("Group proposal is not loaded.")
    return false
end

function UI.ClickListKey()
    if SQ.Listing and SQ.Listing.ListOwnedKeystone then
        return SQ.Listing.ListOwnedKeystone()
    end
    SQ.SetStatus("Listing helper is not loaded.")
    return false
end

function UI.UpdatePendingAction()
    local pending = SQ.Applicants and SQ.Applicants.GetPendingAction and SQ.Applicants.GetPendingAction() or nil
    local proposal = SQ.Applicants and SQ.Applicants.GetProposedGroup and SQ.Applicants.GetProposedGroup() or nil
    playReadySoundIfNeeded(proposal)

    if controls.group then
        local count = proposal and proposal.invitees and #proposal.invitees or 0
        local suffix = ""
        local utility = proposal and proposal.utility or nil
        local missing = {}
        if utility and utility.requireBloodlust and not utility.hasBloodlust then
            missing[#missing + 1] = "lust"
        end
        if utility and utility.requireBattleRes and not utility.hasBattleRes then
            missing[#missing + 1] = "brez"
        end
        if #missing > 0 then
            suffix = " missing " .. table.concat(missing, "/")
        end
        setText(controls.group, "Proposed group: " .. tostring(count) .. " invite" .. (count == 1 and "" or "s") .. suffix)
    end
    if controls.groupSlots then
        local slots = proposal and proposal.slots or {}
        for index, slotText in ipairs(controls.groupSlots) do
            local slot = slots[index]
            local role = slot and slot.role or nil
            local candidate = slot and slot.candidate or nil
            local name = slot and slot.name or (candidate and candidate.name)
            local text = role and ((ROLE_LABELS[role] or role) .. ": " .. (name or "needed")) or ""
            setText(slotText, text)
        end
    end
    if controls.pending then
        setText(controls.pending, pending and ("Pending: " .. tostring(pending.name)) or "Pending: none")
    end
    if controls.inviteGroupButton and controls.inviteGroupButton.SetEnabled then
        controls.inviteGroupButton:SetEnabled((proposal and proposal.complete and proposal.invitees and #proposal.invitees > 0) and true or false)
    end
    if controls.inviteButton and controls.inviteButton.SetEnabled then
        controls.inviteButton:SetEnabled((pending and pending.action == SQ.Rules.ACTION_INVITE) and true or false)
    end
    if controls.declineButton and controls.declineButton.SetEnabled then
        controls.declineButton:SetEnabled((pending and pending.action == SQ.Rules.ACTION_DECLINE) and true or false)
    end
end

function UI.ShouldShowPanel()
    if forcedVisible then
        return true
    end
    if not PVEFrame or not LFGListFrame or LFGListFrame.activePanel ~= LFGListFrame.ApplicationViewer then
        return false
    end
    local context = SQ.Applicants and SQ.Applicants.GetContext and SQ.Applicants.GetContext()
    return context and context.hasActiveEntry and context.isLeader and context.isMythicPlus or false
end

local function shouldShowApplicantCover()
    if not LFGListFrame or not LFGListFrame.ApplicationViewer or LFGListFrame.activePanel ~= LFGListFrame.ApplicationViewer then
        return false
    end
    if not SoloQSettings or not SoloQSettings.enabled then
        return false
    end
    local context = SQ.Applicants and SQ.Applicants.GetContext and SQ.Applicants.GetContext()
    return context and context.hasActiveEntry and context.isLeader and context.isMythicPlus or false
end

function updateApplicantCoverVisibility()
    local cover = createApplicantCover()
    if not cover then
        return
    end
    if shouldShowApplicantCover() then
        cover:Show()
    else
        cover:Hide()
    end
end

function UI.UpdateVisibility()
    if not panel then
        return
    end
    if UI.ShouldShowPanel() then
        panel:Show()
        UI.Refresh()
    else
        panel:Hide()
    end
    updateApplicantCoverVisibility()
end

function UI.Toggle()
    forcedVisible = not forcedVisible
    UI.UpdateVisibility()
end

local function createPanel()
    panel = CreateFrame("Frame", "SoloQPanel", PVEFrame, "BasicFrameTemplateWithInset")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("TOPLEFT", PVEFrame, "TOPRIGHT", 0, -20)
    panel:SetFrameStrata("FULLSCREEN")
    panel:Hide()

    panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
    panel.title:SetText("SoloQ")

    controls.enabled = createCheck(panel, 10, -34, function(checked)
        SoloQSettings.enabled = checked and true or false
        SQ.SetStatus("Applicant evaluation " .. (SoloQSettings.enabled and "enabled." or "disabled."))
        updateApplicantCoverVisibility()
    end)
    createLabel(panel, "Enable applicant evaluation", 38, -39)

    createLabel(panel, "Min score", 10, MIN_SCORE_Y - 5)
    controls.minScore = createEditBox(panel, 172, MIN_SCORE_Y - 2, function(value)
        UI.SetMinScore(value)
    end)

    controls.requireBloodlust = createCheck(panel, 10, COMPOSITION_BLOODLUST_Y, function(checked)
        UI.SetRequireBloodlust(checked)
    end)
    createLabel(panel, "Require lust/heroism", 38, COMPOSITION_BLOODLUST_Y - 5)

    controls.requireBattleRes = createCheck(panel, 10, COMPOSITION_BATTLE_RES_Y, function(checked)
        UI.SetRequireBattleRes(checked)
    end)
    createLabel(panel, "Require battle res", 38, COMPOSITION_BATTLE_RES_Y - 5)

    controls.playReadySound = createCheck(panel, 10, READY_SOUND_CHECK_Y, function(checked)
        UI.SetPlayReadySound(checked)
    end)
    createLabel(panel, "Play ready sound", 38, READY_SOUND_CHECK_Y - 5)

    controls.readySoundDropdown = createDropdown(panel, READY_SOUND_DROPDOWN_NAME, 32, READY_SOUND_DROPDOWN_Y, READY_SOUND_DROPDOWN_WIDTH, READY_SOUND_OPTIONS, function(key)
        UI.SetReadySound(key)
    end)

    controls.group = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    controls.group:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, GROUP_HEADER_Y)
    controls.group:SetWidth(PANEL_WIDTH - 24)
    setSingleLine(controls.group)
    controls.group:SetJustifyH("LEFT")
    controls.group:SetText("Proposed group: 0 invites")

    controls.groupSlots = {}
    for i = 1, 5 do
        controls.groupSlots[i] = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        controls.groupSlots[i]:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, GROUP_SLOT_START_Y - ((i - 1) * GROUP_SLOT_SPACING))
        controls.groupSlots[i]:SetWidth(PANEL_WIDTH - 24)
        setSingleLine(controls.groupSlots[i])
        controls.groupSlots[i]:SetJustifyH("LEFT")
        controls.groupSlots[i]:SetText("")
    end

    controls.inviteGroupButton = createButton(panel, "Invite Group", 12, INVITE_GROUP_BUTTON_Y, 236, function()
        UI.ClickInviteGroup()
    end)

    controls.pending = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    controls.pending:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, PENDING_Y)
    controls.pending:SetWidth(PANEL_WIDTH - 24)
    setSingleLine(controls.pending)
    controls.pending:SetJustifyH("LEFT")
    controls.pending:SetText("Pending: none")

    controls.inviteButton = createButton(panel, "Invite", 12, ACTION_BUTTON_Y, 108, function()
        UI.ClickPendingAction(SQ.Rules.ACTION_INVITE)
    end)
    controls.declineButton = createButton(panel, "Decline", 140, ACTION_BUTTON_Y, 108, function()
        UI.ClickPendingAction(SQ.Rules.ACTION_DECLINE)
    end)

    controls.status = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    controls.status:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12)
    controls.status:SetWidth(PANEL_WIDTH - 24)
    setSingleLine(controls.status)
    controls.status:SetJustifyH("LEFT")
    controls.status:SetText("")
end

local function getPremadeGroupsAnchor()
    if not GroupFinderFrame then
        return nil
    end

    return GroupFinderFrame.groupButton3
        or GroupFinderFrame.groupButton2
        or GroupFinderFrame.groupButton1
        or GroupFinderFrame
end

local function createGroupFinderButton()
    if controls.listKeyButton or not GroupFinderFrame then
        return
    end

    local anchor = getPremadeGroupsAnchor()
    if not anchor then
        return
    end

    controls.listKeyButton = createFreeButton(GroupFinderFrame, "SoloQListKeyButton", "SoloQ: Prep Key", LIST_KEY_BUTTON_WIDTH, function()
        UI.ClickListKey()
    end)
    controls.listKeyButton:SetHeight(LIST_KEY_BUTTON_HEIGHT)
    controls.listKeyButton:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
    attachLeftIcon(controls.listKeyButton, LIST_KEY_ICON, LIST_KEY_ICON_WIDTH, LIST_KEY_ICON_HEIGHT)
end

function UI.Init()
    if not CreateFrame or not PVEFrame then
        return
    end
    if not initialized then
        initialized = true
        createPanel()
        UI.Refresh()
    end

    createGroupFinderButton()
    createApplicantCover()

    hookIfExists("LFGListFrame_SetActivePanel", UI.UpdateVisibility)
    hookIfExists("PVEFrame_ShowFrame", UI.UpdateVisibility)
    hookIfExists("GroupFinderFrame_ShowGroupFrame", function()
        createGroupFinderButton()
        UI.UpdateVisibility()
    end)
    if not frameScriptsHooked then
        frameScriptsHooked = true
        if PVEFrame.HookScript then
            PVEFrame:HookScript("OnShow", UI.UpdateVisibility)
            PVEFrame:HookScript("OnHide", UI.UpdateVisibility)
        end
    end
end
