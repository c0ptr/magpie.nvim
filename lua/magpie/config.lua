local M = {}

M.defaults = {
    source_lang = "auto",
    target_lang = "zh-CN",
    provider = "google",

    keymaps = {
        normal = "<leader>tw",
        visual = "<leader>tw",
    },

    hover = {
        enabled = true,
        delay_ms = 550,
    },

    mouse_selection = {
        enabled = true,
    },

    deepseek = {
        endpoint = "https://api.deepseek.com/chat/completions",
        api_key = nil,
        model = "deepseek-flash",
        temperature = 0.2,
        extra_body = nil,
        proxy = nil,
        timeout_ms = 30000,
    },
    google = {
        endpoint = "https://translate.googleapis.com/translate_a/single",
        cloud_endpoint = "https://translation.googleapis.com/language/translate/v2",
        api_key = nil,
        timeout_ms = 10000,
    },

    bing = {
        endpoint = "https://api.cognitive.microsofttranslator.com",
        api_key = nil,
        region = nil,
        timeout_ms = 10000,
    },

    youdao = {
        endpoint = "https://openapi.youdao.com/api",
        app_key = nil,
        app_secret = nil,
        proxy = nil,
        timeout_ms = 10000,
    },

    dictionary = {
        enabled = true,
        endpoint = "https://api.dictionaryapi.dev/api/v2/entries/en",
        timeout_ms = 5000,
    },

    cache = {
        max_entries = 100,
    },

    ui = {
        border = "rounded",
        max_width = 72,
        min_width = 30,
        winblend = 0,
        title = " 翻译 ",
    },
}

local function validate(options)
    vim.validate({
        source_lang = { options.source_lang, "string" },
        target_lang = { options.target_lang, "string" },
        provider = {
            options.provider,
            function(value)
                return value == "deepseek" or value == "google" or value == "bing" or value == "youdao"
            end,
            "'google', 'deepseek', 'bing' or 'youdao'",
        },
        hover_delay = { options.hover.delay_ms, "number" },
        cache_size = { options.cache.max_entries, "number" },
        ui_max_width = { options.ui.max_width, "number" },
    })

    if options.hover.delay_ms < 0 then
        error("Magpie: hover.delay_ms must not be negative")
    end
    if options.cache.max_entries < 0 then
        error("Magpie: cache.max_entries must not be negative")
    end
end

function M.build(options)
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), options or {})

    -- Keep secrets out of the default table and make environment configuration
    -- convenient for lazy.nvim users.
    merged.bing.api_key = merged.bing.api_key or vim.env.AZURE_TRANSLATOR_KEY
    merged.bing.region = merged.bing.region or vim.env.AZURE_TRANSLATOR_REGION
    merged.google.api_key = merged.google.api_key or vim.env.GOOGLE_TRANSLATE_API_KEY
    merged.deepseek.api_key = merged.deepseek.api_key or vim.env.DEEPSEEK_API_KEY
    merged.youdao.app_key = merged.youdao.app_key or vim.env.YOUDAO_APP_KEY
    merged.youdao.app_secret = merged.youdao.app_secret or vim.env.YOUDAO_APP_SECRET
    validate(merged)
    return merged
end

return M
