local M = {}

local data
local user_entries = {}

local function load()
    if not data then
        data = require("magpie.dict.data")
    end
    return data
end

-- Load user entries from `path`. Lines are `word<TAB>zh` or
-- `word<TAB>pos<TAB>ipa<TAB>zh`; blank lines and lines starting with # are
-- ignored. User entries override the bundled dictionary.
function M.load_user(path)
    user_entries = {}
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok or type(lines) ~= "table" then
        return
    end
    for _, line in ipairs(lines) do
        local trimmed = (line:gsub("^%s*(.-)%s*$", "%1"))
        if trimmed ~= "" and not trimmed:match("^#") then
            local parts = vim.split(trimmed, "\t", { plain = true })
            local word = parts[1] and parts[1]:lower()
            if word and parts[2] and parts[2] ~= "" then
                if #parts >= 4 then
                    user_entries[word] = { pos = parts[2], ipa = parts[3], zh = parts[4] }
                else
                    user_entries[word] = { pos = nil, ipa = nil, zh = parts[2] }
                end
            end
        end
    end
end

function M.lookup(word)
    local entry = user_entries[word]
    if entry then
        return entry
    end
    local bundled = load()[word]
    if type(bundled) ~= "table" then
        return nil
    end
    return bundled
end

function M.size()
    local count = 0
    for _ in pairs(load()) do
        count = count + 1
    end
    return count
end

return M
