local util = require("magpie.util")

local M = {}

local lang_names = {
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

function M.system_prompt(options)
    local target = lang_names[options.target_lang] or options.target_lang
    local source = options.source_lang == "auto" and "" or
        (" from " .. (lang_names[options.source_lang] or options.source_lang))
    return "You are a translation engine. Translate the user's text"
        .. source .. " into " .. target .. ". "
        .. "Output only the translation, with no explanations, quotes or notes. "
        .. "If the input is a single word, give its most common meanings separated by semicolons, "
        .. "with part of speech abbreviations like n. v. adj."
end

-- Shared OpenAI-compatible chat-completions transport (ChatGPT, Copilot, ...).
function M.translate(name, text, options, callback)
    local cfg = options[name]
    if not cfg.api_key or cfg.api_key == "" then
        callback(nil, name .. " 需要 api_key（或环境变量 " .. (cfg.env or "API_KEY") .. "）")
        return nil
    end

    local body = {
        model = cfg.model,
        messages = {
            { role = "system", content = M.system_prompt(options) },
            { role = "user", content = text },
        },
        temperature = cfg.temperature,
        stream = false,
    }
    if cfg.extra_body then
        body = vim.tbl_extend("force", body, cfg.extra_body)
    end

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

    return util.run_curl(args, function(stdout, err)
        if err then
            callback(nil, name .. " 请求失败：" .. err)
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

return M
