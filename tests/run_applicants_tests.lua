local SQ = {}
local calls = {}
local applicants = {}
local applicantMembers = {}
local activeEntry = { activityIDs = { 777 }, questID = nil }
local activityInfo = { isMythicPlusActivity = true, fullName = "Test Key" }
local currentRoles = {}
local currentClasses = {}

LE_PARTY_CATEGORY_HOME = 1
WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_ID = 1

function UnitIsGroupLeader(unit, category)
    return unit == "player" and category == LE_PARTY_CATEGORY_HOME
end

function UnitGroupRolesAssigned(unit)
    return currentRoles[unit] or "NONE"
end

function UnitClass(unit)
    local class = currentClasses[unit] or "WARRIOR"
    return class, class
end

function IsInGroup()
    return currentRoles.party1 ~= nil
end

function GetNumGroupMembers()
    local count = 1
    for unit in pairs(currentRoles) do
        if string.find(unit, "party", 1, true) == 1 then
            count = count + 1
        end
    end
    return count
end

C_LFGList = {
    HasActiveEntryInfo = function()
        return activeEntry ~= nil
    end,
    GetActiveEntryInfo = function()
        return activeEntry
    end,
    GetActivityInfoTable = function(activityID)
        if activityID == 777 then
            return activityInfo
        end
    end,
    GetApplicants = function()
        local ids = {}
        for id in pairs(applicants) do
            ids[#ids + 1] = id
        end
        table.sort(ids)
        return ids
    end,
    GetApplicantInfo = function(applicantID)
        return applicants[applicantID]
    end,
    GetApplicantMemberInfo = function(applicantID, memberIndex)
        local member = applicantMembers[applicantID]
        if member[memberIndex] then
            member = member[memberIndex]
        end
        return member.name, member.class, member.localizedClass, member.level, member.itemLevel,
            member.honorLevel, member.tank, member.healer, member.damage, member.assignedRole,
            member.relationship, member.dungeonScore
    end,
    InviteApplicant = function(applicantID)
        calls[#calls + 1] = { action = "invite", applicantID = applicantID }
    end,
    DeclineApplicant = function(applicantID)
        calls[#calls + 1] = { action = "decline", applicantID = applicantID }
    end,
}

local function loadFile(path)
    local chunk = assert(loadfile(path))
    chunk("SoloQ", SQ)
end

local function resetState()
    calls = {}
    currentRoles = {
        player = "DAMAGER",
    }
    currentClasses = {
        player = "WARRIOR",
    }
    applicants = {
        [1] = { applicantID = 1, applicationStatus = "applied", numMembers = 1 },
    }
    applicantMembers = {
        [1] = {
            name = "Passer-Area52",
            class = "MAGE",
            localizedClass = "Mage",
            level = 80,
            itemLevel = 700,
            honorLevel = 0,
            tank = false,
            healer = false,
            damage = true,
            assignedRole = "DAMAGER",
            relationship = nil,
            dungeonScore = 2700,
        },
    }
    SoloQSettings = {
        enabled = true,
        debug = false,
        minScore = 2600,
        composition = {
            requireBloodlust = false,
            requireBattleRes = false,
        },
    }
    if SQ.Applicants and SQ.Applicants.ResetSession then
        SQ.Applicants.ResetSession()
    end
end

local function makeMember(name, role, score, class)
    return {
        name = name,
        class = class or "WARRIOR",
        localizedClass = class or "Warrior",
        level = 80,
        itemLevel = 700,
        honorLevel = 0,
        tank = role == "TANK",
        healer = role == "HEALER",
        damage = role == "DAMAGER",
        assignedRole = role,
        relationship = nil,
        dungeonScore = score,
    }
end

local function setApplicant(id, name, role, score, class)
    applicants[id] = { applicantID = id, applicationStatus = "applied", numMembers = 1 }
    applicantMembers[id] = makeMember(name, role, score, class)
end

local function setApplicantGroup(id, members)
    applicants[id] = { applicantID = id, applicationStatus = "applied", numMembers = #members }
    applicantMembers[id] = members
end

local function assertEquals(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local function run()
    loadFile("Debug.lua")
    loadFile("Rules.lua")
    loadFile("Applicants.lua")

    resetState()
    SQ.Applicants.ScanApplicants()
    assertEquals(#calls, 0, "passing applicant is not auto-invited")
    assertEquals(SQ.lastStatus, "Would invite Passer-Area52: Invited: DPS 2700 >= 2600.", "passing applicant recommendation")
    assertEquals(SQ.Applicants.GetPendingAction().action, SQ.Rules.ACTION_INVITE, "passing applicant pending invite")

    SQ.Applicants.ScanApplicants()
    assertEquals(#calls, 0, "dedupe prevents repeated protected calls")
    assertEquals(SQ.Applicants.ExecutePendingAction(SQ.Rules.ACTION_INVITE), true, "pending invite executes")
    assertEquals(#calls, 1, "pending invite action count")
    assertEquals(calls[1].action, "invite", "pending invite calls blizzard api")
    assertEquals(SQ.Applicants.GetPendingAction(), nil, "pending invite clears after success")

    resetState()
    applicantMembers[1].dungeonScore = 2500
    SQ.Applicants.ScanApplicants()
    assertEquals(#calls, 0, "failing applicant is not auto-declined")
    assertEquals(SQ.lastStatus, "Would decline Passer-Area52: Declined: DPS 2500 < 2600.", "failing applicant recommendation")
    assertEquals(SQ.Applicants.ExecutePendingAction(SQ.Rules.ACTION_DECLINE), true, "pending decline executes")
    assertEquals(#calls, 1, "pending decline action count")
    assertEquals(calls[1].action, "decline", "pending decline calls blizzard api")

    resetState()
    setApplicant(1, "Tank-Area52", "TANK", 3100)
    setApplicant(2, "Healer-Area52", "HEALER", 3000)
    setApplicant(3, "DpsHigh-Area52", "DAMAGER", 3200)
    setApplicant(4, "DpsMid-Area52", "DAMAGER", 2900)
    setApplicant(5, "DpsLow-Area52", "DAMAGER", 2700)
    SQ.Applicants.ScanApplicants()
    local proposal = SQ.Applicants.GetProposedGroup()
    assertEquals(#proposal.invitees, 4, "proposal fills missing slots")
    assertEquals(proposal.invitees[1].role, "TANK", "proposal includes tank first")
    assertEquals(proposal.invitees[2].role, "HEALER", "proposal includes healer second")
    assertEquals(proposal.invitees[3].name, "DpsHigh-Area52", "proposal picks highest dps first")
    assertEquals(proposal.invitees[4].name, "DpsMid-Area52", "proposal picks second highest dps")
    assertEquals(SQ.Applicants.ExecuteProposedGroup(), true, "proposal group executes")
    assertEquals(#calls, 4, "proposal group invite count")
    assertEquals(calls[1].applicantID, 1, "proposal invites tank")
    assertEquals(calls[2].applicantID, 2, "proposal invites healer")
    assertEquals(calls[3].applicantID, 3, "proposal invites top dps")
    assertEquals(calls[4].applicantID, 4, "proposal invites second dps")

    resetState()
    setApplicantGroup(10, {
        makeMember("TankGroup-Area52", "TANK", 3150),
        makeMember("HealerGroup-Area52", "HEALER", 3050),
    })
    setApplicant(3, "DpsHigh-Area52", "DAMAGER", 3200)
    setApplicant(4, "DpsMid-Area52", "DAMAGER", 2900)
    setApplicant(5, "DpsLow-Area52", "DAMAGER", 2700)
    SQ.Applicants.ScanApplicants()
    proposal = SQ.Applicants.GetProposedGroup()
    assertEquals(proposal.complete, true, "group applicant can complete proposal")
    assertEquals(#proposal.invitees, 3, "group applicant invite count is per application")
    assertEquals(proposal.slots[1].candidate.applicantID, 10, "group applicant fills tank slot")
    assertEquals(proposal.slots[2].candidate.applicantID, 10, "group applicant fills healer slot")
    assertEquals(proposal.invitees[1].applicantID, 10, "proposal invites queued group once")
    assertEquals(SQ.Applicants.ExecuteProposedGroup(), true, "proposal with queued group executes")
    assertEquals(#calls, 3, "queued group proposal call count")
    assertEquals(calls[1].applicantID, 10, "queued group invited once")
    assertEquals(calls[2].applicantID, 3, "queued group proposal invites top dps")
    assertEquals(calls[3].applicantID, 4, "queued group proposal invites second dps")

    resetState()
    setApplicantGroup(10, {
        makeMember("LowTank-Area52", "TANK", 100),
        makeMember("HealerGroup-Area52", "HEALER", 3050),
    })
    setApplicant(1, "TankOnly-Area52", "TANK", 3100)
    setApplicant(2, "HealerOnly-Area52", "HEALER", 3000)
    setApplicant(3, "DpsHigh-Area52", "DAMAGER", 3200)
    setApplicant(4, "DpsMid-Area52", "DAMAGER", 2900)
    SQ.Applicants.ScanApplicants()
    proposal = SQ.Applicants.GetProposedGroup()
    assertEquals(proposal.complete, true, "failing group applicant is excluded")
    assertEquals(calls[1], nil, "failing group applicant is not auto-invited")
    assertEquals(proposal.invitees[1].applicantID, 1, "proposal uses passing solo tank")

    resetState()
    currentRoles.party1 = "TANK"
    setApplicant(1, "Healer-Area52", "HEALER", 3000)
    setApplicant(2, "DpsOne-Area52", "DAMAGER", 3100)
    setApplicant(3, "DpsTwo-Area52", "DAMAGER", 3000)
    SQ.Applicants.ScanApplicants()
    proposal = SQ.Applicants.GetProposedGroup()
    assertEquals(#proposal.invitees, 3, "proposal accounts for existing tank")
    assertEquals(proposal.invitees[1].role, "HEALER", "proposal fills healer after existing tank")
    assertEquals(proposal.invitees[2].name, "DpsOne-Area52", "proposal fills first dps after existing tank")
    assertEquals(proposal.invitees[3].name, "DpsTwo-Area52", "proposal fills second dps after existing tank")

    resetState()
    SoloQSettings.composition.requireBloodlust = true
    setApplicant(1, "Tank-Area52", "TANK", 3100, "WARRIOR")
    setApplicant(2, "Healer-Area52", "HEALER", 3000, "PRIEST")
    setApplicant(3, "DpsHigh-Area52", "DAMAGER", 3200, "WARRIOR")
    setApplicant(4, "DpsMid-Area52", "DAMAGER", 3100, "WARRIOR")
    setApplicant(5, "MageLust-Area52", "DAMAGER", 2700, "MAGE")
    SQ.Applicants.ScanApplicants()
    proposal = SQ.Applicants.GetProposedGroup()
    assertEquals(proposal.complete, true, "bloodlust requirement can complete proposal")
    assertEquals(proposal.utility.hasBloodlust, true, "proposal includes bloodlust")
    assertEquals(proposal.invitees[4].applicantID, 5, "lower score lust class is selected")

    resetState()
    SoloQSettings.composition.requireBattleRes = true
    setApplicant(1, "Tank-Area52", "TANK", 3100, "WARRIOR")
    setApplicant(2, "PriestHigh-Area52", "HEALER", 3200, "PRIEST")
    setApplicant(3, "DruidRez-Area52", "HEALER", 2800, "DRUID")
    setApplicant(4, "DpsOne-Area52", "DAMAGER", 3100, "WARRIOR")
    setApplicant(5, "DpsTwo-Area52", "DAMAGER", 3000, "WARRIOR")
    SQ.Applicants.ScanApplicants()
    proposal = SQ.Applicants.GetProposedGroup()
    assertEquals(proposal.complete, true, "battle res requirement can complete proposal")
    assertEquals(proposal.utility.hasBattleRes, true, "proposal includes battle res")
    assertEquals(proposal.invitees[2].applicantID, 3, "lower score battle res class is selected")

    resetState()
    SoloQSettings.composition.requireBloodlust = true
    currentClasses.player = "MAGE"
    setApplicant(1, "Tank-Area52", "TANK", 3100, "WARRIOR")
    setApplicant(2, "Healer-Area52", "HEALER", 3000, "PRIEST")
    setApplicant(3, "DpsHigh-Area52", "DAMAGER", 3200, "WARRIOR")
    setApplicant(4, "DpsMid-Area52", "DAMAGER", 3100, "WARRIOR")
    SQ.Applicants.ScanApplicants()
    proposal = SQ.Applicants.GetProposedGroup()
    assertEquals(proposal.complete, true, "current player utility satisfies bloodlust requirement")
    assertEquals(proposal.invitees[4].applicantID, 4, "proposal keeps higher dps when current group has lust")

    resetState()
    SoloQSettings.composition.requireBloodlust = true
    setApplicant(1, "Tank-Area52", "TANK", 3100, "WARRIOR")
    setApplicant(2, "Healer-Area52", "HEALER", 3000, "PRIEST")
    setApplicant(3, "DpsOne-Area52", "DAMAGER", 3100, "WARRIOR")
    setApplicant(4, "DpsTwo-Area52", "DAMAGER", 3000, "WARRIOR")
    SQ.Applicants.ScanApplicants()
    proposal = SQ.Applicants.GetProposedGroup()
    assertEquals(proposal.complete, false, "proposal is incomplete when required utility is missing")
    assertEquals(proposal.roleComplete, true, "utility failure still has required roles")
    assertEquals(proposal.utility.hasBloodlust, false, "missing bloodlust is reported")
    assertEquals(SQ.Applicants.ExecuteProposedGroup(), false, "missing utility proposal does not execute")
    assertEquals(SQ.lastStatus, "Proposed group is missing required utility.", "missing utility status")

    resetState()
    setApplicant(1, "TankOnly-Area52", "TANK", 3100)
    SQ.Applicants.ScanApplicants()
    proposal = SQ.Applicants.GetProposedGroup()
    assertEquals(proposal.complete, false, "proposal is incomplete when required roles are missing")
    assertEquals(SQ.Applicants.ExecuteProposedGroup(), false, "incomplete proposal does not execute")
    assertEquals(#calls, 0, "incomplete proposal invite count")

    resetState()
    applicants[1].numMembers = 2
    SQ.Applicants.ScanApplicants()
    assertEquals(#calls, 0, "incomplete multi-member applicant is not invited")

    resetState()
    activityInfo.isMythicPlusActivity = false
    SQ.Applicants.ScanApplicants()
    assertEquals(#calls, 0, "non-mplus listing ignored")
    activityInfo.isMythicPlusActivity = true

    resetState()
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_BLOCKED", "SoloQ", "SomeOtherProtectedAction")
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_FORBIDDEN", "SoloQ", "SomeOtherProtectedAction")
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_BLOCKED", "SoloQ", "SomeOtherProtectedAction")
    assertEquals(SoloQSettings.enabled, true, "soloq non-lfg blocked actions keep enabled")

    resetState()
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_BLOCKED", "OtherAddon", "C_LFGList.InviteApplicant")
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_FORBIDDEN", "OtherAddon", "C_LFGList.DeclineApplicant")
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_BLOCKED", "OtherAddon", "C_LFGList.InviteApplicant")
    assertEquals(SoloQSettings.enabled, true, "other addon lfg blocked actions keep enabled")

    resetState()
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_BLOCKED", "SoloQ", "C_LFGList.InviteApplicant")
    assertEquals(#calls, 0, "blocked action event does not scan applicants")
    assertEquals(SoloQSettings.enabled, true, "first blocked action keeps enabled")
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_FORBIDDEN", "SoloQ", "C_LFGList.DeclineApplicant")
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_BLOCKED", "SoloQ", "C_LFGList.InviteApplicant")
    assertEquals(SoloQSettings.enabled, false, "third blocked action disables")
    SQ.Applicants.ExecuteAction(1, { action = SQ.Rules.ACTION_INVITE })

    resetState()
    C_LFGList.InviteApplicant = function()
        SQ.Applicants.OnEvent(nil, "ADDON_ACTION_BLOCKED", "SoloQ", "UNKNOWN()")
    end
    SQ.Applicants.ScanApplicants()
    assertEquals(SoloQSettings.enabled, true, "unknown blocked action keeps enabled before limit")
    SQ.Applicants.ScanApplicants()
    SQ.Applicants.ScanApplicants()
    assertEquals(SoloQSettings.enabled, true, "scanner avoids unknown blocked invite path")
    C_LFGList.InviteApplicant = function(applicantID)
        calls[#calls + 1] = { action = "invite", applicantID = applicantID }
    end
    SQ.Applicants.ExecuteAction(1, { action = SQ.Rules.ACTION_INVITE })

    resetState()
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_BLOCKED", "OtherAddon", "OtherAddon.DoThing")
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_FORBIDDEN", "OtherAddon", "OtherAddon.DoThing")
    SQ.Applicants.OnEvent(nil, "ADDON_ACTION_BLOCKED", "OtherAddon", "OtherAddon.DoThing")
    assertEquals(SoloQSettings.enabled, true, "unrelated blocked actions keep enabled")
    SQ.Applicants.ExecuteAction(1, { action = SQ.Rules.ACTION_INVITE })

    resetState()
    C_LFGList.InviteApplicant = function()
        error("blocked action")
    end
    SQ.Applicants.ExecuteAction(1, { action = SQ.Rules.ACTION_INVITE })
    assertEquals(SoloQSettings.enabled, true, "first action error keeps enabled")
    SQ.Applicants.ResetSession()
    SQ.Applicants.ExecuteAction(1, { action = SQ.Rules.ACTION_INVITE })
    SQ.Applicants.ResetSession()
    SQ.Applicants.ExecuteAction(1, { action = SQ.Rules.ACTION_INVITE })
    assertEquals(SoloQSettings.enabled, false, "third action error disables")

    print("PASS tests/run_applicants_tests.lua")
end

run()
