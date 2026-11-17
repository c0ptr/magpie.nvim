local M = {}

M.defaults = {
    source_lang = "auto",
    target_lang = "zh-CN",
    provider = "chatgpt",

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
    chatgpt = {
        endpoint = "https://api.openai.com/v1/chat/completions",
        api_key = nil,
        model = "gpt-4o-mini",
        temperature = 0.2,
        extra_body = nil,
        proxy = nil,
        timeout_ms = 30000,
        env = "OPENAI_API_KEY",
    },

    copilot = {
        endpoint = "https://api.githubcopilot.com/chat/completions",
        api_key = nil,
        model = "gpt-4o",
        temperature = 0.2,
        extra_body = nil,
        proxy = nil,
        timeout_ms = 30000,
        env = "GITHUB_TOKEN",
    },

    gemini = {
        endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
        api_key = nil,
        model = "gemini-2.5-flash",
        temperature = 0.2,
        proxy = nil,
        timeout_ms = 30000,
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

    local_dictionary = {
        enabled = true,
    },

    cache = {
        max_entries = 100,
        persist = true,
        max_disk_entries = 500,
        dir = nil,
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
                return value == "chatgpt" or value == "copilot" or value == "gemini" or value == "deepseek" or value == "youdao"
            end,
            "'chatgpt', 'copilot', 'gemini', 'deepseek' or 'youdao'",
        },
        hover_delay = { options.hover.delay_ms, "number" },
        cache_size = { options.cache.max_entries, "number" },
        cache_disk_size = { options.cache.max_disk_entries, "number" },
        cache_persist = { options.cache.persist, "boolean" },
        local_dictionary_enabled = { options.local_dictionary.enabled, "boolean" },
        ui_max_width = { options.ui.max_width, "number" },
    })

    if options.hover.delay_ms < 0 then
        error("Magpie: hover.delay_ms must not be negative")
    end
    if options.cache.max_entries < 0 then
        error("Magpie: cache.max_entries must not be negative")
    end
    if options.cache.max_disk_entries < 0 then
        error("Magpie: cache.max_disk_entries must not be negative")
    end
end

function M.build(options)
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), options or {})

    -- Keep secrets out of the default table and make environment configuration
    -- convenient for lazy.nvim users.
    merged.chatgpt.api_key = merged.chatgpt.api_key or vim.env.OPENAI_API_KEY or vim.env.CHATGPT_API_KEY
    merged.copilot.api_key = merged.copilot.api_key or vim.env.GITHUB_TOKEN or vim.env.COPILOT_API_KEY
    merged.gemini.api_key = merged.gemini.api_key or vim.env.GEMINI_API_KEY
    merged.deepseek.api_key = merged.deepseek.api_key or vim.env.DEEPSEEK_API_KEY
    merged.youdao.app_key = merged.youdao.app_key or vim.env.YOUDAO_APP_KEY
    merged.youdao.app_secret = merged.youdao.app_secret or vim.env.YOUDAO_APP_SECRET
    if merged.cache.dir == nil or merged.cache.dir == "" then
        merged.cache.dir = vim.fn.stdpath("data") .. "/magpie"
    end
    validate(merged)
    return merged
end

return M
