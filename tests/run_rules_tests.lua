local SQ = {}

local function loadRules()
    local chunk = assert(loadfile("Rules.lua"))
    chunk("SoloQ", SQ)
end

local function assertEquals(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local function baseSettings()
    return {
        enabled = true,
        minScore = 2700,
    }
end

local function baseContext()
    return {
        isRetail = true,
        hasActiveEntry = true,
        isLeader = true,
        isMythicPlus = true,
    }
end

local function applicant(fields)
    local value = {
        applicantID = 42,
        status = "applied",
        numMembers = 1,
        member = {
            name = "Tester-Area52",
            assignedRole = "DAMAGER",
            tank = false,
            healer = false,
            damage = true,
            dungeonScore = 2700,
        },
    }
    for key, fieldValue in pairs(fields or {}) do
        if key == "member" then
            for memberKey, memberValue in pairs(fieldValue) do
                value.member[memberKey] = memberValue
            end
        else
            value[key] = fieldValue
        end
    end
    return value
end

local function run()
    loadRules()
    local Rules = assert(SQ.Rules, "SQ.Rules missing")
    assertEquals(Rules.INVITE, "INVITE", "invite alias exists")
    assertEquals(Rules.DECLINE, "DECLINE", "decline alias exists")
    assertEquals(Rules.IGNORE, "IGNORE", "ignore alias exists")
    assertEquals(Rules.ACTION_INVITE, Rules.INVITE, "invite action alias matches")
    assertEquals(Rules.ACTION_DECLINE, Rules.DECLINE, "decline action alias matches")
    assertEquals(Rules.ACTION_IGNORE, Rules.IGNORE, "ignore action alias matches")

    local result = Rules.Evaluate(baseContext(), applicant(), baseSettings())
    assertEquals(result.action, "INVITE", "dps score passes")

    result = Rules.Evaluate(baseContext(), applicant({ member = { dungeonScore = 2500 } }), baseSettings())
    assertEquals(result.action, "DECLINE", "dps score fails")

    result = Rules.Evaluate(baseContext(), applicant({ member = { assignedRole = "TANK", tank = true, damage = false, dungeonScore = 2699 } }), baseSettings())
    assertEquals(result.action, "DECLINE", "tank score fails")

    result = Rules.Evaluate(baseContext(), applicant({ member = { assignedRole = "TANK", tank = true, damage = false, dungeonScore = 2700 } }), baseSettings())
    assertEquals(result.action, "INVITE", "tank score equals threshold")

    result = Rules.Evaluate(baseContext(), applicant({ member = { assignedRole = "HEALER", healer = true, damage = false, dungeonScore = 2701 } }), baseSettings())
    assertEquals(result.action, "INVITE", "healer score passes")

    result = Rules.Evaluate(baseContext(), applicant({ member = { assignedRole = false, healer = true, damage = false, dungeonScore = 2700 } }), baseSettings())
    assertEquals(result.action, "INVITE", "single role flag infers role")

    result = Rules.Evaluate(baseContext(), applicant({ numMembers = 2 }), baseSettings())
    assertEquals(result.action, "IGNORE", "multi-member applicant ignored")

    result = Rules.Evaluate(baseContext(), applicant({ member = { assignedRole = false, tank = true, healer = false, damage = true } }), baseSettings())
    assertEquals(result.action, "DECLINE", "ambiguous role declines")

    result = Rules.Evaluate(baseContext(), applicant({ member = { dungeonScore = false } }), baseSettings())
    assertEquals(result.action, "DECLINE", "missing score treated as zero")

    local app = applicant()
    app.member.dungeonScore = nil
    result = Rules.Evaluate(baseContext(), app, baseSettings())
    assertEquals(result.action, "DECLINE", "nil score treated as zero")

    local context = baseContext()
    context.isRetail = false
    result = Rules.Evaluate(context, applicant(), baseSettings())
    assertEquals(result.action, "IGNORE", "non-retail ignored")

    context = baseContext()
    context.hasActiveEntry = false
    result = Rules.Evaluate(context, applicant(), baseSettings())
    assertEquals(result.action, "IGNORE", "no active listing ignored")

    context = baseContext()
    context.isLeader = false
    result = Rules.Evaluate(context, applicant(), baseSettings())
    assertEquals(result.action, "IGNORE", "not leader ignored")

    context = baseContext()
    context.isMythicPlus = false
    result = Rules.Evaluate(context, applicant(), baseSettings())
    assertEquals(result.action, "IGNORE", "non-mplus ignored")

    result = Rules.Evaluate(baseContext(), applicant({ status = "invited" }), baseSettings())
    assertEquals(result.action, "IGNORE", "non-applied ignored")

    local settings = baseSettings()
    settings.enabled = false
    result = Rules.Evaluate(baseContext(), applicant(), settings)
    assertEquals(result.action, "IGNORE", "disabled addon ignored")

    print("PASS tests/run_rules_tests.lua")
end

run()
