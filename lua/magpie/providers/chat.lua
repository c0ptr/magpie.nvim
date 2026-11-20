local util = require("magpie.util")

local M = {}

local lang_names = {
    zh = "简体中文",
    ["zh-CN"] = "简体中文",
    ["zh-TW"] = "繁體中文",
    en = "English",
    ja = "日本語",
    ko = "한국어",
    fr = "Français",
    de = "Deutsch",
    es = "Español",
    ru = "Русский",
}

function M.language_name(code)
    return lang_names[code] or code
end

function M.system_prompt(options)
    local target = M.language_name(options.target_lang)
    local source = options.source_lang == "auto" and ""
        or (" from " .. M.language_name(options.source_lang))
    return "You are a translation engine. Translate the user's text"
        .. source .. " into " .. target .. ". "
        .. "Output only the translation, with no explanations, quotes or notes. "
        .. "If the input is a single word, give its most common meanings separated by semicolons, "
        .. "with part of speech abbreviations like n. v. adj."
end

local function require_key(cfg, name)
    if not cfg.api_key or cfg.api_key == "" then
        return nil, name .. " 需要 api_key（或环境变量 " .. (cfg.env or "API_KEY") .. "）"
    end
    return true
end

local function build_args(cfg, body)
    local args = {
        "curl", "-sS",
        "--location",
        "--max-time", util.timeout_seconds(cfg.timeout_ms),
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer " .. cfg.api_key,
    }
    if cfg.proxy then
        vim.list_extend(args, { "-x", cfg.proxy })
    end
    vim.list_extend(args, { "-d", vim.json.encode(body), cfg.endpoint })
    return args
end

local function build_body(cfg, text, options, stream, prompt)
    local body = {
        model = cfg.model,
        messages = {
            { role = "system", content = prompt or M.system_prompt(options) },
            { role = "user", content = text },
        },
        temperature = cfg.temperature,
        stream = stream,
    }
    if cfg.extra_body then
        body = vim.tbl_extend("force", body, cfg.extra_body)
    end
    return body
end

function M.translate(name, text, options, callback, prompt)
    local cfg = options[name]
    local ok, err = require_key(cfg, name)
    if not ok then
        callback(nil, err)
        return nil
    end

    return util.run_curl(build_args(cfg, build_body(cfg, text, options, false, prompt)), function(stdout, err_msg)
        if err_msg then
            callback(nil, name .. " 请求失败：" .. err_msg)
            return
        end

        local data, decode_error = util.decode_json(stdout, name)
        if not data then
            callback(nil, decode_error)
            return
        end

        if type(data.error) == "table" then
            callback(nil, name .. " 错误：" .. tostring(data.error.message))
            return
        end

        local choice = data.choices and data.choices[1]
        local content = choice and choice.message and choice.message.content
        if type(content) ~= "string" or util.trim(content) == "" then
            callback(nil, name .. " 没有返回结果")
            return
        end

        callback({
            translation = util.trim(content),
            detected_source_lang = options.source_lang,
        }, nil)
    end)
end

function M.translate_stream(name, text, options, on_delta, callback, prompt)
    local cfg = options[name]
    local ok, err = require_key(cfg, name)
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
                local payload = line:sub(7)
                if payload ~= "[DONE]" then
                    local data = util.decode_json(payload, name)
                    if type(data) == "table" and type(data.error) == "table" then
                        server_error = name .. " 错误：" .. tostring(data.error.message)
                    elseif type(data) == "table" then
                        local choice = data.choices and data.choices[1]
                        local delta = choice and choice.delta and choice.delta.content
                        if type(delta) == "string" and delta ~= "" then
                            full = full .. delta
                            on_delta(delta)
                        end
                    end
                end
            end
        end
    end

    return util.run_curl_stream(build_args(cfg, build_body(cfg, text, options, true, prompt)), on_chunk, function(_, request_error)
        if request_error then
            callback(nil, name .. " 请求失败：" .. request_error)
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
            callback(nil, name .. " 没有返回结果")
            return
        end
        callback({
            translation = util.trim(full),
            detected_source_lang = options.source_lang,
        }, nil)
    end)
end

return M
