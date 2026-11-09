local M = {}

local data

local function load()
    if not data then
        data = require("magpie.dict.data")
    end
    return data
end

function M.lookup(word)
    local entry = load()[word]
    if type(entry) ~= "table" then
        return nil
    end
    return entry
end

function M.size()
    local count = 0
    for _ in pairs(load()) do
        count = count + 1
    end
    return count
end

return M
