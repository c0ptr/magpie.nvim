local util = require("magpie.util")
local chat = require("magpie.providers.chat")

local M = {}

local function require_key(cfg)
    if not cfg.api_key or cfg.api_key == "" then
        return nil, "Gemini 需要 api_key（或环境变量 GEMINI_API_KEY）"
    end
    return true
end

local function build_body(cfg, text, options, prompt)
    return {
        systemInstruction = { parts = { { text = prompt or chat.system_prompt(options) } } },
        contents = { { parts = { { text = text } } } },
        generationConfig = { temperature = cfg.temperature },
    }
end

local function build_args(cfg, body)
    local args = {
        "curl", "-sS",
        "--location",
        "--max-time", util.timeout_seconds(cfg.timeout_ms),
        "-H", "Content-Type: application/json",
    }
    if cfg.proxy then
        vim.list_extend(args, { "-x", cfg.proxy })
    end
    local url = cfg.endpoint:gsub("/$", "") .. "/" .. cfg.model
        .. ":generateContent?key=" .. util.url_encode(cfg.api_key)
    vim.list_extend(args, { "-d", vim.json.encode(body), url })
    return args
end

local function collect_parts(data)
    local candidate = data.candidates and data.candidates[1]
    local parts = candidate and candidate.content and candidate.content.parts
    local pieces = {}
    if type(parts) == "table" then
        for _, part in ipairs(parts) do
            if type(part.text) == "string" then
                table.insert(pieces, part.text)
            end
        end
    end
    return table.concat(pieces)
end

function M.translate(text, options, callback, prompt)
    local cfg = options.gemini
    local ok, err = require_key(cfg)
    if not ok then
        callback(nil, err)
        return nil
    end

    return util.run_curl(build_args(cfg, build_body(cfg, text, options, prompt)), function(stdout, request_error)
        if request_error then
            callback(nil, "Gemini 请求失败：" .. request_error)
            return
        end

        local data, decode_error = util.decode_json(stdout, "Gemini")
        if not data then
            callback(nil, decode_error)
            return
        end

        if type(data.error) == "table" then
            callback(nil, "Gemini 错误：" .. tostring(data.error.message))
            return
        end

        local content = collect_parts(data)
        if content == "" then
            callback(nil, "Gemini 没有返回结果")
            return
        end

        callback({
            translation = util.trim(content),
            detected_source_lang = options.source_lang,
        }, nil)
    end)
end

function M.translate_stream(text, options, on_delta, callback, prompt)
    local cfg = options.gemini
    local ok, err = require_key(cfg)
    if not ok then
        callback(nil, err)
        return nil
    end

    local buffer = ""
    local full = ""
    local server_error = nil

    local function on_chunk(chunk)
        buffer = buffer .. chunk
        while true do
            local newline = buffer:find("\n")
            if not newline then
                break
            end
            local line = buffer:sub(1, newline - 1):gsub("^%s*(.-)%s*$", "%1")
            buffer = buffer:sub(newline + 1)
            if line:sub(1, 6) == "data: " then
                local data = util.decode_json(line:sub(7), "Gemini")
                if type(data) == "table" and type(data.error) == "table" then
                    server_error = "Gemini 错误：" .. tostring(data.error.message)
                elseif type(data) == "table" then
                    local delta = collect_parts(data)
                    if delta ~= "" then
                        full = full .. delta
                        on_delta(delta)
                    end
                end
            end
        end
    end

    return util.run_curl_stream(build_args(cfg, build_body(cfg, text, options, prompt)), on_chunk, function(_, request_error)
        if request_error then
            callback(nil, "Gemini 请求失败：" .. request_error)
            return
        end
        if buffer:match("%S") then
            on_chunk("\n")
        end
        if server_error then
            callback(nil, server_error)
            return
        end
        if util.trim(full) == "" then
            callback(nil, "Gemini 没有返回结果")
            return
        end
        callback({
            translation = util.trim(full),
            detected_source_lang = options.source_lang,
        }, nil)
    end)
end

return M
