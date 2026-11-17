local util = require("magpie.util")
local chat = require("magpie.providers.chat")

local M = {}

function M.translate(text, options, callback)
    local cfg = options.gemini
    if not cfg.api_key or cfg.api_key == "" then
        callback(nil, "Gemini 需要 api_key（或环境变量 GEMINI_API_KEY）")
        return nil
    end

    local body = {
        systemInstruction = { parts = { { text = chat.system_prompt(options) } } },
        contents = { { parts = { { text = text } } } },
        generationConfig = { temperature = cfg.temperature },
    }

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

    return util.run_curl(args, function(stdout, err)
        if err then
            callback(nil, "Gemini 请求失败：" .. err)
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
        local content = table.concat(pieces)
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

return M
