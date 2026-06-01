local files = {
    "tests/run_rules_tests.lua",
    "tests/run_init_tests.lua",
    "tests/run_listing_tests.lua",
    "tests/run_applicants_tests.lua",
    "tests/run_ui_tests.lua",
}

for _, path in ipairs(files) do
    local ok, err = pcall(function()
        local chunk = assert(loadfile(path))
        chunk()
    end)
    if not ok then
        error(path .. " failed: " .. tostring(err), 0)
    end
end

print("PASS tests/run_all.lua")
