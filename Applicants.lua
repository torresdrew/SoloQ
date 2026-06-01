local addonName, SQ = ...
SQ = SQ or {}

local Applicants = {}
SQ.Applicants = Applicants

local ACTION_ERROR_LIMIT = 3
local processedApplicants = {}
local actionErrors = 0
local initialized = false
local activeAction = nil
local pendingAction = nil
local proposedGroup = nil
local scanCandidates = nil

local TARGET_GROUP = {
    TANK = 1,
    HEALER = 1,
    DAMAGER = 3,
}

local GROUP_ROLES = {
    "TANK",
    "HEALER",
    "DAMAGER",
}

local BLOODLUST_CLASSES = {
    EVOKER = true,
    HUNTER = true,
    MAGE = true,
    SHAMAN = true,
}

local BATTLE_RES_CLASSES = {
    DEATHKNIGHT = true,
    DRUID = true,
    PALADIN = true,
    WARLOCK = true,
}

local function isRetail()
    if WOW_PROJECT_ID and WOW_PROJECT_MAINLINE then
        return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
    end
    return C_LFGList ~= nil
end

local function getApplicantStatus(applicantInfo)
    return applicantInfo and (applicantInfo.applicationStatus or applicantInfo.status)
end

local function buildContext()
    local hasActiveEntry = C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo()
    local activeEntry = hasActiveEntry and C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo() or nil
    local activityID = activeEntry and activeEntry.activityIDs and activeEntry.activityIDs[1] or nil
    local activityInfo = activityID and C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID, activeEntry.questID) or nil

    return {
        isRetail = isRetail(),
        hasActiveEntry = hasActiveEntry and activeEntry ~= nil or false,
        isLeader = UnitIsGroupLeader and UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) or false,
        isMythicPlus = activityInfo and activityInfo.isMythicPlusActivity or false,
        activeEntry = activeEntry,
        activityInfo = activityInfo,
    }
end

local function buildApplicant(applicantID)
    local info = C_LFGList.GetApplicantInfo(applicantID)
    if not info then
        return nil
    end

    local numMembers = info.numMembers or 0
    local applicant = {
        applicantID = applicantID,
        status = getApplicantStatus(info),
        numMembers = numMembers,
        info = info,
    }

    if numMembers > 0 then
        applicant.members = {}
    end

    for memberIndex = 1, numMembers do
        local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage,
            assignedRole, relationship, dungeonScore = C_LFGList.GetApplicantMemberInfo(applicantID, memberIndex)
        local member = {
            name = name,
            class = class,
            localizedClass = localizedClass,
            level = level,
            itemLevel = itemLevel,
            honorLevel = honorLevel,
            tank = tank,
            healer = healer,
            damage = damage,
            assignedRole = assignedRole,
            relationship = relationship,
            dungeonScore = dungeonScore,
        }
        applicant.members[memberIndex] = member
        if memberIndex == 1 then
            applicant.member = member
        end
    end

    return applicant
end

local function rememberAction(applicantID, decision)
    processedApplicants[applicantID] = {
        action = decision.action,
        reason = decision.reason,
    }
end

local function updatePendingUI()
    if SQ.UI and SQ.UI.UpdatePendingAction then
        SQ.UI.UpdatePendingAction()
    end
end

local function addCandidate(candidate)
    if not scanCandidates or not candidate then
        return
    end

    scanCandidates[#scanCandidates + 1] = candidate
end

local function normalizeClass(class)
    if not class then
        return nil
    end
    return string.gsub(string.upper(tostring(class)), "[^A-Z]", "")
end

local function getMemberCapabilities(member)
    local class = member and normalizeClass(member.class or member.localizedClass)
    return {
        bloodlust = BLOODLUST_CLASSES[class] == true,
        battleRes = BATTLE_RES_CLASSES[class] == true,
    }
end

local function addMemberCapabilities(capabilities, member)
    local memberCapabilities = getMemberCapabilities(member)
    capabilities.bloodlust = capabilities.bloodlust or memberCapabilities.bloodlust
    capabilities.battleRes = capabilities.battleRes or memberCapabilities.battleRes
end

local function getCompositionRequirements()
    local composition = SoloQSettings and SoloQSettings.composition or nil
    return {
        bloodlust = composition and composition.requireBloodlust == true or false,
        battleRes = composition and composition.requireBattleRes == true or false,
    }
end

local function buildCandidate(applicant, decisions)
    local candidate = {
        applicantID = applicant.applicantID,
        name = applicant.member and applicant.member.name or tostring(applicant.applicantID),
        counts = {
            TANK = 0,
            HEALER = 0,
            DAMAGER = 0,
        },
        decision = {
            action = SQ.Rules.ACTION_INVITE,
            reason = "Invited: proposed group.",
        },
        score = 0,
        slots = {},
        capabilities = {
            bloodlust = false,
            battleRes = false,
        },
    }

    for index, decision in ipairs(decisions) do
        local member = applicant.members and applicant.members[index] or applicant.member
        local role = decision.role
        if candidate.counts[role] == nil then
            return nil
        end
        candidate.counts[role] = candidate.counts[role] + 1
        candidate.score = candidate.score + (decision.score or 0)
        addMemberCapabilities(candidate.capabilities, member)
        candidate.slots[#candidate.slots + 1] = {
            role = role,
            name = member and member.name or candidate.name,
            score = decision.score or 0,
            capabilities = getMemberCapabilities(member),
        }
    end

    if #candidate.slots == 1 then
        candidate.role = candidate.slots[1].role
        candidate.name = candidate.slots[1].name
    end

    return candidate
end

local function setPendingAction(applicant, decision)
    local name = applicant.member and applicant.member.name or tostring(applicant.applicantID)
    pendingAction = {
        applicantID = applicant.applicantID,
        action = decision.action,
        decision = decision,
        name = name,
    }
    SQ.SetStatus((decision.action == SQ.Rules.ACTION_INVITE and "Would invite " or "Would decline ") .. tostring(name) .. ": " .. decision.reason, true)
    updatePendingUI()
end

local function recordActionError(message)
    actionErrors = actionErrors + 1
    SQ.SetStatus(message)

    if actionErrors >= ACTION_ERROR_LIMIT then
        SoloQSettings.enabled = false
        SQ.SetStatus("Disabled: action API errors detected; reload or re-enable after testing.")
    end
end

local function getCurrentGroupState()
    local state = {
        counts = {
            TANK = 0,
            HEALER = 0,
            DAMAGER = 0,
        },
        capabilities = {
            bloodlust = false,
            battleRes = false,
        },
    }

    local function getUnitRole(unit)
        local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or nil
        if (not role or role == "NONE") and unit == "player" and GetSpecialization and GetSpecializationRole then
            local specIndex = GetSpecialization()
            role = specIndex and GetSpecializationRole(specIndex) or role
        end
        return role
    end

    local function addUnit(unit)
        local role = getUnitRole(unit)
        if state.counts[role] ~= nil then
            state.counts[role] = state.counts[role] + 1
        end
        if UnitClass then
            local localizedClass, class = UnitClass(unit)
            addMemberCapabilities(state.capabilities, {
                class = class or localizedClass,
                localizedClass = localizedClass,
            })
        end
    end

    addUnit("player")
    if IsInGroup and IsInGroup() and GetNumGroupMembers then
        for i = 1, math.max(0, GetNumGroupMembers() - 1) do
            addUnit("party" .. i)
        end
    end

    return state
end

local function candidateSort(left, right)
    if left.score == right.score then
        return left.applicantID < right.applicantID
    end
    return left.score > right.score
end

local function buildProposedGroup(candidates)
    local currentState = getCurrentGroupState()
    local currentCounts = currentState.counts
    local currentCapabilities = currentState.capabilities
    local requirements = getCompositionRequirements()
    local neededCounts = {}
    local missingCount = 0

    for _, role in ipairs(GROUP_ROLES) do
        local needed = math.max(0, (TARGET_GROUP[role] or 0) - (currentCounts[role] or 0))
        neededCounts[role] = needed
        missingCount = missingCount + needed
    end

    table.sort(candidates, candidateSort)

    local function stateKey(counts, capabilities)
        return table.concat({
            tostring(counts.TANK or 0),
            tostring(counts.HEALER or 0),
            tostring(counts.DAMAGER or 0),
            capabilities and capabilities.bloodlust and "1" or "0",
            capabilities and capabilities.battleRes and "1" or "0",
        }, ":")
    end

    local function copyCounts(counts)
        return {
            TANK = counts.TANK or 0,
            HEALER = counts.HEALER or 0,
            DAMAGER = counts.DAMAGER or 0,
        }
    end

    local function copySelected(selected)
        local value = {}
        for i, candidate in ipairs(selected) do
            value[i] = candidate
        end
        return value
    end

    local function copyCapabilities(capabilities)
        return {
            bloodlust = capabilities and capabilities.bloodlust or false,
            battleRes = capabilities and capabilities.battleRes or false,
        }
    end

    local function hasNeededCounts(counts)
        for _, role in ipairs(GROUP_ROLES) do
            if (counts[role] or 0) ~= (neededCounts[role] or 0) then
                return false
            end
        end
        return true
    end

    local function satisfiesRequirements(capabilities)
        if requirements.bloodlust and not (capabilities and capabilities.bloodlust) then
            return false
        end
        if requirements.battleRes and not (capabilities and capabilities.battleRes) then
            return false
        end
        return true
    end

    local function betterProposal(candidateState, existingState)
        if not existingState then
            return true
        end
        if candidateState.score ~= existingState.score then
            return candidateState.score > existingState.score
        end
        return #candidateState.selected < #existingState.selected
    end

    local states = {
        [stateKey({}, currentCapabilities)] = {
            counts = {},
            capabilities = copyCapabilities(currentCapabilities),
            score = 0,
            selected = {},
        },
    }

    for _, candidate in ipairs(candidates) do
        local snapshot = {}
        for key, state in pairs(states) do
            snapshot[key] = state
        end

        for _, state in pairs(snapshot) do
            local counts = copyCounts(state.counts)
            local fits = true
            for _, role in ipairs(GROUP_ROLES) do
                counts[role] = counts[role] + (candidate.counts[role] or 0)
                if counts[role] > (neededCounts[role] or 0) then
                    fits = false
                    break
                end
            end

            if fits then
                local selected = copySelected(state.selected)
                selected[#selected + 1] = candidate
                local capabilities = copyCapabilities(state.capabilities)
                capabilities.bloodlust = capabilities.bloodlust or (candidate.capabilities and candidate.capabilities.bloodlust) or false
                capabilities.battleRes = capabilities.battleRes or (candidate.capabilities and candidate.capabilities.battleRes) or false
                local nextState = {
                    counts = counts,
                    capabilities = capabilities,
                    score = state.score + candidate.score,
                    selected = selected,
                }
                local key = stateKey(counts, capabilities)
                if betterProposal(nextState, states[key]) then
                    states[key] = nextState
                end
            end
        end
    end

    local roleCompleteState = nil
    local targetState = nil
    for _, state in pairs(states) do
        if hasNeededCounts(state.counts) then
            if betterProposal(state, roleCompleteState) then
                roleCompleteState = state
            end
            if satisfiesRequirements(state.capabilities) and betterProposal(state, targetState) then
                targetState = state
            end
        end
    end

    local selected = targetState and targetState.selected or {}
    local slots = {}
    local invitees = {}
    local invitedByID = {}
    local finalCapabilities = targetState and targetState.capabilities
        or roleCompleteState and roleCompleteState.capabilities
        or currentCapabilities
    for _, role in ipairs(GROUP_ROLES) do
        for i = 1, (neededCounts[role] or 0) do
            slots[#slots + 1] = {
                role = role,
                candidate = nil,
            }
        end
    end

    for _, candidate in ipairs(selected) do
        for _, candidateSlot in ipairs(candidate.slots) do
            for _, proposalSlot in ipairs(slots) do
                if not proposalSlot.candidate and proposalSlot.role == candidateSlot.role then
                    proposalSlot.candidate = candidate
                    proposalSlot.name = candidateSlot.name
                    proposalSlot.score = candidateSlot.score
                    break
                end
            end
        end
    end

    for _, slot in ipairs(slots) do
        local candidate = slot.candidate
        if candidate and not invitedByID[candidate.applicantID] then
            invitees[#invitees + 1] = candidate
            invitedByID[candidate.applicantID] = true
        end
    end

    proposedGroup = {
        invitees = invitees,
        slots = slots,
        currentCounts = currentCounts,
        utility = {
            requireBloodlust = requirements.bloodlust,
            hasBloodlust = finalCapabilities and finalCapabilities.bloodlust or false,
            requireBattleRes = requirements.battleRes,
            hasBattleRes = finalCapabilities and finalCapabilities.battleRes or false,
        },
        roleComplete = roleCompleteState ~= nil,
        utilityComplete = satisfiesRequirements(finalCapabilities),
        complete = targetState ~= nil and #invitees > 0,
    }
end

local function isSoloQBlockedSource(source)
    return source == "SoloQ" or source == addonName
end

local function isInviteDeclineAction(actionName)
    actionName = tostring(actionName or "")
    return string.find(actionName, "C_LFGList.InviteApplicant", 1, true) ~= nil
        or string.find(actionName, "C_LFGList.DeclineApplicant", 1, true) ~= nil
        or string.find(actionName, "InviteApplicant", 1, true) ~= nil
        or string.find(actionName, "DeclineApplicant", 1, true) ~= nil
end

local function isRelevantBlockedAction(source, actionName)
    if not isSoloQBlockedSource(source) then
        return false
    end

    return activeAction ~= nil or isInviteDeclineAction(actionName)
end

function Applicants.ResetSession()
    processedApplicants = {}
    pendingAction = nil
    proposedGroup = nil
    updatePendingUI()
end

function Applicants.GetContext()
    return buildContext()
end

function Applicants.GetPendingAction()
    return pendingAction
end

function Applicants.GetProposedGroup()
    return proposedGroup
end

function Applicants.ExecuteAction(applicantID, decision)
    local fn
    if decision.action == SQ.Rules.ACTION_INVITE then
        fn = C_LFGList.InviteApplicant
    elseif decision.action == SQ.Rules.ACTION_DECLINE then
        fn = C_LFGList.DeclineApplicant
    else
        return true
    end

    local actionState = { blocked = false, errorRecorded = false }
    activeAction = actionState
    local ok, err = pcall(fn, applicantID)
    if activeAction == actionState then
        activeAction = nil
    end

    if actionState.blocked then
        return false
    end

    if ok then
        actionErrors = 0
        return true
    end

    if not actionState.errorRecorded then
        recordActionError("Action failed: " .. tostring(err))
    end

    return false
end

function Applicants.ExecutePendingAction(expectedAction)
    if not pendingAction then
        SQ.SetStatus("No pending applicant action.")
        return false
    end
    if expectedAction and pendingAction.action ~= expectedAction then
        SQ.SetStatus("Pending applicant action does not match this button.")
        return false
    end

    local action = pendingAction
    if Applicants.ExecuteAction(action.applicantID, action.decision) then
        pendingAction = nil
        rememberAction(action.applicantID, action.decision)
        SQ.SetStatus((action.decision.action == SQ.Rules.ACTION_INVITE and "Invited " or "Declined ") .. tostring(action.name) .. ": " .. action.decision.reason)
        updatePendingUI()
        return true
    end

    updatePendingUI()
    return false
end

function Applicants.ExecuteProposedGroup()
    if not proposedGroup then
        SQ.SetStatus("No proposed applicants to invite.")
        return false
    end
    if not proposedGroup.complete then
        if proposedGroup.roleComplete and not proposedGroup.utilityComplete then
            SQ.SetStatus("Proposed group is missing required utility.")
        else
            SQ.SetStatus("Proposed group is missing required roles.")
        end
        return false
    end
    if not proposedGroup.invitees or #proposedGroup.invitees == 0 then
        SQ.SetStatus("No proposed applicants to invite.")
        return false
    end

    local invited = 0
    for _, candidate in ipairs(proposedGroup.invitees) do
        if Applicants.ExecuteAction(candidate.applicantID, candidate.decision) then
            rememberAction(candidate.applicantID, candidate.decision)
            invited = invited + 1
        else
            SQ.SetStatus("Stopped group invite after action failure.")
            updatePendingUI()
            return false
        end
    end

    SQ.SetStatus("Invited " .. tostring(invited) .. " proposed applicants.")
    proposedGroup = nil
    pendingAction = nil
    updatePendingUI()
    return true
end

function Applicants.ProcessApplicant(applicantID, context)
    if processedApplicants[applicantID] then
        return
    end

    local applicant = buildApplicant(applicantID)
    if not applicant then
        return
    end

    if applicant.numMembers ~= 1 then
        if applicant.status ~= "applied" then
            return
        end

        local decisions = {}
        for index, member in ipairs(applicant.members or {}) do
            local memberApplicant = {
                applicantID = applicant.applicantID,
                status = applicant.status,
                numMembers = 1,
                member = member,
            }
            local decision = SQ.Rules.Evaluate(context, memberApplicant, SoloQSettings)
            if decision.action ~= SQ.Rules.ACTION_INVITE then
                SQ.SetStatus("Ignored " .. tostring(applicantID) .. ": queued group member does not pass SoloQ rules.")
                return
            end
            decisions[index] = decision
        end

        addCandidate(buildCandidate(applicant, decisions))
        return
    end

    local decision = SQ.Rules.Evaluate(context, applicant, SoloQSettings)
    if decision.action == SQ.Rules.ACTION_IGNORE then
        if applicant.numMembers ~= 1 then
            SQ.SetStatus("Ignored " .. tostring(applicantID) .. ": queued group could not be evaluated.")
        end
        return
    end

    if decision.action == SQ.Rules.ACTION_INVITE then
        addCandidate(buildCandidate(applicant, { decision }))
    end
    setPendingAction(applicant, decision)
end

function Applicants.ScanApplicants()
    if not SoloQSettings or not SoloQSettings.enabled then
        return
    end
    if not C_LFGList or not C_LFGList.GetApplicants then
        return
    end

    local context = buildContext()
    if not context.isRetail or not context.hasActiveEntry or not context.isLeader or not context.isMythicPlus then
        return
    end

    scanCandidates = {}
    pendingAction = nil
    proposedGroup = nil

    local applicantIDs = C_LFGList.GetApplicants()
    for _, applicantID in ipairs(applicantIDs) do
        Applicants.ProcessApplicant(applicantID, context)
    end
    buildProposedGroup(scanCandidates)
    scanCandidates = nil
    updatePendingUI()
end

function Applicants.OnEvent(_, event, source, actionName)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if isRelevantBlockedAction(source, actionName) then
            if activeAction then
                activeAction.blocked = true
                activeAction.errorRecorded = true
            end
            recordActionError("Action blocked: " .. tostring(actionName or "protected action"))
        end
        return
    end

    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
        Applicants.ResetSession()
    end
    Applicants.ScanApplicants()
    if SQ.UI and SQ.UI.UpdateVisibility then
        SQ.UI.UpdateVisibility()
    end
end

function Applicants.Init()
    if initialized or not SQ.EventFrame then
        return
    end
    initialized = true
    SQ.EventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    SQ.EventFrame:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
    SQ.EventFrame:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")
    SQ.EventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    SQ.EventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    SQ.EventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
    SQ.EventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    SQ.EventFrame:HookScript("OnEvent", Applicants.OnEvent)
end
