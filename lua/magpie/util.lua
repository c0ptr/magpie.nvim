local M = {}

function M.notify(message, level)
    vim.notify(message, level or vim.log.levels.INFO, { title = "Magpie" })
end

function M.trim(text)
    return (text:gsub("^%s*(.-)%s*$", "%1"))
end

function M.normalize_text(text)
    return (M.trim(text):gsub("%s+", " "))
end

-- djb2 hash, 32-bit, lowercase hex; used for cache-key fingerprints.
function M.hash_hex(text)
    local hash = 5381
    for i = 1, #text do
        hash = (hash * 33 + string.byte(text, i)) % 4294967296
    end
    return string.format("%08x", math.floor(hash))
end

function M.is_english_word(text)
    return text:match("^[A-Za-z][A-Za-z'%-]*$") ~= nil
end

function M.url_encode(text)
    return (text:gsub("[^%w%-%._~]", function(character)
        return string.format("%%%02X", string.byte(character))
    end))
end

function M.decode_json(text, context)
    local ok, decoded = pcall(vim.json.decode, text)
    if ok then
        return decoded
    end
    return nil, string.format("Could not parse %s response: %s", context, decoded)
end

function M.run_curl(args, callback)
    if vim.fn.executable("curl") ~= 1 then
        callback(nil, "`curl` is required. Install curl and make it available on $PATH.")
        return nil
    end

    return vim.system(args, { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                local detail = M.trim(result.stderr or "")
                if detail == "" then
                    detail = M.trim(result.stdout or "")
                end
                callback(nil, detail ~= "" and detail or ("curl exited with code " .. result.code))
                return
            end
            callback(result.stdout or "", nil)
        end)
    end)
end

function M.timeout_seconds(timeout_ms)
    return string.format("%.3f", math.max(1, timeout_ms) / 1000)
end

return M
