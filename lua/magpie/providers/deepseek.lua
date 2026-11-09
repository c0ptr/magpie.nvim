local util = require("magpie.util")

local M = {}

-- 告诉模型目标语言的名字，比 "zh-CN" 这种代码更稳
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

local function build_system_prompt(options)
    local target = lang_names[options.target_lang] or options.target_lang
    local source = options.source_lang == "auto" and "" or
    (" from " .. (lang_names[options.source_lang] or options.source_lang))
    return "You are a translation engine. Translate the user's text"
        .. source .. " into " .. target .. ". "
        .. "Output only the translation, with no explanations, quotes or notes. "
        .. "If the input is a single word, give its most common meanings separated by semicolons, "
        .. "with part of speech abbreviations like n. v. adj."
end

function M.translate(text, options, callback)
    local cfg = options.deepseek
    if not cfg.api_key then
        callback(nil, "DeepSeek 需要 api_key（或环境变量 DEEPSEEK_API_KEY）")
        return
    end

    local body = {
        model = cfg.model,
        messages = {
            { role = "system", content = build_system_prompt(options) },
            { role = "user",   content = text },
        },
        temperature = cfg.temperature,
        stream = false,
    }
    -- 需要关闭思考模式来提速时，在配置里加 extra_body
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
            callback(nil, err)
            return
        end

        local data, decode_error = util.decode_json(stdout, "DeepSeek")
        if not data then
            callback(nil, decode_error)
            return
        end

        -- 401 余额不足、模型名错误等都会走这里
        if type(data.error) == "table" then
            callback(nil, "DeepSeek 错误：" .. tostring(data.error.message))
            return
        end

        local choice = data.choices and data.choices[1]
        local content = choice and choice.message and choice.message.content
        if type(content) ~= "string" or util.trim(content) == "" then
            callback(nil, "DeepSeek 没有返回结果")
            return
        end

        -- 大模型不返回源语言检测结果，沿用配置值
        callback({
            translation = util.trim(content),
            detected_source_lang = options.source_lang,
        }, nil)
    end)
end

return M
