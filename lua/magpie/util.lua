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

-- CJK Unified Ideographs (U+4E00-U+9FFF) and Extension A (U+3400-U+3FFF)
-- encoded as UTF-8.  The lead-byte checks are deliberately conservative: they
-- only cover ranges that are Han characters, not Hiragana/Katakana/Hangul.
function M.has_chinese(text)
    return text:find("[\227][\144-\191]") ~= nil
        or text:find("[\228-\233][\128-\191]") ~= nil
end

function M.has_latin(text)
    return text:match("[A-Za-z]") ~= nil
end

-- Normalize a multiline block for cache keys: trim every line, collapse runs
-- of whitespace inside a line, and keep the line structure intact.
function M.normalize_block(text)
    local lines = vim.split((text:gsub("\r\n", "\n"):gsub("\r", "\n")), "\n", { plain = true })
    for index, line in ipairs(lines) do
        lines[index] = (line:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1"))
    end
    return table.concat(lines, "\n")
end

function M.escape_pattern(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
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

-- Stream curl output line by line. on_chunk receives text chunks; callback
-- fires once at completion with (nil, nil) on success or (nil, error).
function M.run_curl_stream(args, on_chunk, callback)
    if vim.fn.executable("curl") ~= 1 then
        callback(nil, "`curl` is required. Install curl and make it available on $PATH.")
        return nil
    end

    return vim.system(args, {
        text = true,
        stdout = function(_, chunk)
            if type(chunk) == "string" and chunk ~= "" then
                vim.schedule(function()
                    on_chunk(chunk)
                end)
            end
        end,
        stderr = true,
    }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                local detail = M.trim(result.stderr or "")
                callback(nil, detail ~= "" and detail or ("curl exited with code " .. result.code))
                return
            end
            callback(nil, nil)
        end)
    end)
end

function M.timeout_seconds(timeout_ms)
    return string.format("%.3f", math.max(1, timeout_ms) / 1000)
end

return M
