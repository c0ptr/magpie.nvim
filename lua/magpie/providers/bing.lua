local util = require("magpie.util")

local M = {}

local function endpoint(base, source_lang, target_lang)
    local parameters = { "api-version=3.0", "to=" .. util.url_encode(target_lang) }
    if source_lang ~= "auto" then
        table.insert(parameters, "from=" .. util.url_encode(source_lang))
    end
    return base:gsub("/$", "") .. "/translate?" .. table.concat(parameters, "&")
end

function M.translate(text, options, callback)
    local config = options.bing
    if not config.api_key or config.api_key == "" then
        callback(nil, "Bing/Azure Translator requires `bing.api_key` or $AZURE_TRANSLATOR_KEY")
        return
    end

    local args = {
        "curl",
        "--silent",
        "--show-error",
        "--fail-with-body",
        "--location",
        "--max-time",
        util.timeout_seconds(config.timeout_ms),
        "--request",
        "POST",
        endpoint(config.endpoint, options.source_lang, options.target_lang),
        "--header",
        "Content-Type: application/json; charset=UTF-8",
        "--header",
        "Ocp-Apim-Subscription-Key: " .. config.api_key,
        "--data-raw",
        vim.json.encode({ { Text = text } }),
    }
    if config.region and config.region ~= "" then
        table.insert(args, "--header")
        table.insert(args, "Ocp-Apim-Subscription-Region: " .. config.region)
    end

    util.run_curl(args, function(body, request_error)
        if request_error then
            callback(nil, "Bing/Azure Translator request failed: " .. request_error)
            return
        end

        local payload, decode_error = util.decode_json(body, "Bing/Azure Translator")
        if not payload then
            callback(nil, decode_error)
            return
        end

        local item = payload[1]
        local translation = item and item.translations and item.translations[1]
        if type(translation) ~= "table" or type(translation.text) ~= "string" then
            callback(nil, "Bing/Azure Translator returned no translated text")
            return
        end

        callback({
            translation = translation.text,
            detected_source_lang = item.detectedLanguage and item.detectedLanguage.language or options.source_lang,
        })
    end)
end

return M
