local addonName, SQ = ...
SQ = SQ or {}

local Rules = {}
SQ.Rules = Rules

Rules.INVITE = "INVITE"
Rules.DECLINE = "DECLINE"
Rules.IGNORE = "IGNORE"

Rules.ACTION_INVITE = Rules.INVITE
Rules.ACTION_DECLINE = Rules.DECLINE
Rules.ACTION_IGNORE = Rules.IGNORE

local ROLE_LABELS = {
    TANK = "Tank",
    HEALER = "Healer",
    DAMAGER = "DPS",
}

local function result(action, reason, role, score, minScore)
    return {
        action = action,
        reason = reason,
        role = role,
        score = score,
        minScore = minScore,
    }
end

local function countTrue(...)
    local count = 0
    for i = 1, select("#", ...) do
        if select(i, ...) then
            count = count + 1
        end
    end
    return count
end

function Rules.ResolveRole(member)
    if not member then
        return nil
    end

    if member.assignedRole == "TANK" or member.assignedRole == "HEALER" or member.assignedRole == "DAMAGER" then
        return member.assignedRole
    end

    if countTrue(member.tank, member.healer, member.damage) ~= 1 then
        return nil
    end

    if member.tank then
        return "TANK"
    end
    if member.healer then
        return "HEALER"
    end
    if member.damage then
        return "DAMAGER"
    end

    return nil
end

function Rules.Evaluate(context, applicant, settings)
    if not settings or not settings.enabled then
        return result(Rules.ACTION_IGNORE, "Addon disabled.")
    end
    if not context or not context.isRetail then
        return result(Rules.ACTION_IGNORE, "Retail client required.")
    end
    if not context.hasActiveEntry then
        return result(Rules.ACTION_IGNORE, "No active listing.")
    end
    if not context.isLeader then
        return result(Rules.ACTION_IGNORE, "Player is not group leader.")
    end
    if not context.isMythicPlus then
        return result(Rules.ACTION_IGNORE, "Active listing is not Mythic+.")
    end
    if not applicant then
        return result(Rules.ACTION_IGNORE, "Applicant data unavailable.")
    end
    if applicant.status ~= "applied" then
        return result(Rules.ACTION_IGNORE, "Applicant is not pending.")
    end
    if applicant.numMembers ~= 1 then
        return result(Rules.ACTION_IGNORE, "Group applicants are manual review only.")
    end

    local member = applicant.member
    local role = Rules.ResolveRole(member)
    if not role then
        return result(Rules.ACTION_DECLINE, "Declined: ambiguous applicant role.")
    end

    local score = tonumber(member and member.dungeonScore) or 0
    local minScore = tonumber(settings.minScore) or 0
    local label = ROLE_LABELS[role] or role

    if score >= minScore then
        return result(Rules.ACTION_INVITE, string.format("Invited: %s %d >= %d.", label, score, minScore), role, score, minScore)
    end

    return result(Rules.ACTION_DECLINE, string.format("Declined: %s %d < %d.", label, score, minScore), role, score, minScore)
end
