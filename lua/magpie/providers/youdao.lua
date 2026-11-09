local util = require("magpie.util")

local M = {}

-- 有道的语言代码和你配置里的不一样
local lang_map = {
    ["zh-CN"] = "zh-CHS",
    ["zh-TW"] = "zh-CHT",
    zh = "zh-CHS",
}

local function map_lang(lang)
    return lang_map[lang] or lang
end

-- v3 签名里的 input：超过 20 个字符时取 前10 + 长度 + 后10（按字符，不是字节）
local function sign_input(q)
    local n = vim.fn.strchars(q)
    if n <= 20 then
        return q
    end
    return vim.fn.strcharpart(q, 0, 10) .. n .. vim.fn.strcharpart(q, n - 10, 10)
end

function M.translate(text, options, callback)
    local cfg = options.youdao
    if not cfg.app_key or not cfg.app_secret then
        callback(nil, "有道翻译需要 app_key 和 app_secret（或环境变量 YOUDAO_APP_KEY / YOUDAO_APP_SECRET）")
        return
    end

    local salt = string.format("%d%04d", vim.uv.hrtime(), math.random(0, 9999))
    local curtime = tostring(os.time())
    local sign = vim.fn.sha256(cfg.app_key .. sign_input(text) .. salt .. curtime .. cfg.app_secret)

    local args = {
        "curl", "-sS",
        "--location",
        "--max-time", util.timeout_seconds(cfg.timeout_ms),
    }
    if cfg.proxy then
        vim.list_extend(args, { "-x", cfg.proxy })
    end
    vim.list_extend(args, {
        "--data-urlencode", "q=" .. text,
        "--data-urlencode", "from=" .. map_lang(options.source_lang),
        "--data-urlencode", "to=" .. map_lang(options.target_lang),
        "--data-urlencode", "appKey=" .. cfg.app_key,
        "--data-urlencode", "salt=" .. salt,
        "--data-urlencode", "sign=" .. sign,
        "--data-urlencode", "signType=v3",
        "--data-urlencode", "curtime=" .. curtime,
        cfg.endpoint,
    })

    util.run_curl(args, function(stdout, err)
        if err then
            callback(nil, err)
            return
        end

        local data, decode_error = util.decode_json(stdout, "Youdao")
        if not data then
            callback(nil, decode_error)
            return
        end

        -- 有道用 errorCode 表示业务错误，"0" 才是成功
        if tostring(data.errorCode) ~= "0" then
            callback(nil, "有道翻译错误，errorCode=" .. tostring(data.errorCode)
                .. "（到有道智云文档查错误码）")
            return
        end

        local translation = data.translation and table.concat(data.translation, "\n")
        if not translation or translation == "" then
            callback(nil, "有道翻译没有返回结果")
            return
        end

        -- data.l 形如 "en2zh-CHS"
        local detected = type(data.l) == "string" and data.l:match("^(.-)2") or nil
        callback({ translation = translation, detected_source_lang = detected }, nil)
    end)
end

return M
