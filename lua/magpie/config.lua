local M = {}

M.defaults = {
    source_lang = "auto",
    target_lang = "zh-CN",
    provider = "chatgpt",

    stream = {
        enabled = true,
    },

    keymaps = {
        normal = "<leader>tw",
        visual = "<leader>tw",
        comment = "<leader>tc",
        comments = "<leader>tC",
    },

    -- Translate comments while writing code (v0.3).  Manual mode only
    -- translates when you ask; auto mode also translates the comment under the
    -- cursor when you leave Insert mode.
    comment_translation = {
        enabled = true,
        mode = "manual", -- "manual" | "auto"
        target_lang = "en",
        source_lang = "auto",
        filetypes = nil, -- nil = every filetype with comment syntax
        exclude_filetypes = {
            "checkhealth",
            "diff",
            "gitcommit",
            "gitrebase",
            "help",
            "lspinfo",
            "man",
            "markdown",
            "neo-tree",
            "notify",
            "noice",
            "NvimTree",
            "prompt",
            "qf",
            "snacks_dashboard",
            "text",
        },
        use_treesitter = true,
        debounce_ms = 500,
        max_batch = 6,
        max_chars = 3000,
        notify = "on_error", -- "always" | "on_error" | "never"
        skip_patterns = {
            "eslint%-disable",
            "eslint%-enable",
            "@ts%-ignore",
            "@ts%-expect%-error",
            "noqa",
            "nolint",
            "type:%s*ignore",
            "go:generate",
            "go:build",
            "go:embed",
            "^%+build",
            "SPDX%-License%-Identifier",
            "^vim:",
            "^vi:",
            "^ex:",
        },
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
        env = "DEEPSEEK_API_KEY",
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
        user_file = nil,
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
    local comment_translation = options.comment_translation
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
        local_dictionary_user_file = { options.local_dictionary.user_file, "string" },
        stream_enabled = { options.stream.enabled, "boolean" },
        ui_max_width = { options.ui.max_width, "number" },
        comment_translation_enabled = { comment_translation.enabled, "boolean" },
        comment_translation_mode = {
            comment_translation.mode,
            function(value)
                return value == "manual" or value == "auto"
            end,
            "'manual' or 'auto'",
        },
        comment_translation_target_lang = { comment_translation.target_lang, "string" },
        comment_translation_source_lang = { comment_translation.source_lang, "string" },
        comment_translation_debounce = { comment_translation.debounce_ms, "number" },
        comment_translation_max_batch = { comment_translation.max_batch, "number" },
        comment_translation_max_chars = { comment_translation.max_chars, "number" },
        comment_translation_use_treesitter = { comment_translation.use_treesitter, "boolean" },
        comment_translation_notify = {
            comment_translation.notify,
            function(value)
                return value == "always" or value == "on_error" or value == "never"
            end,
            "'always', 'on_error' or 'never'",
        },
        comment_translation_filetypes = { comment_translation.filetypes, "table", true },
        comment_translation_exclude = { comment_translation.exclude_filetypes, "table" },
        comment_translation_skip_patterns = { comment_translation.skip_patterns, "table" },
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
    if comment_translation.debounce_ms < 0 then
        error("Magpie: comment_translation.debounce_ms must not be negative")
    end
    if comment_translation.max_batch < 1 then
        error("Magpie: comment_translation.max_batch must be at least 1")
    end
    if comment_translation.max_chars < 1 then
        error("Magpie: comment_translation.max_chars must be at least 1")
    end
end

function M.build(options)
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), options or {})

    -- `tbl_deep_extend` merges list values by index.  A user-provided list
    -- must replace the default list instead of being extended by it.
    if type(options) == "table" and type(options.comment_translation) == "table" then
        if options.comment_translation.filetypes ~= nil then
            merged.comment_translation.filetypes = vim.deepcopy(options.comment_translation.filetypes)
        end
        if options.comment_translation.exclude_filetypes ~= nil then
            merged.comment_translation.exclude_filetypes = vim.deepcopy(options.comment_translation.exclude_filetypes)
        end
        if options.comment_translation.skip_patterns ~= nil then
            merged.comment_translation.skip_patterns = vim.deepcopy(options.comment_translation.skip_patterns)
        end
    end

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
    if merged.local_dictionary.user_file == nil or merged.local_dictionary.user_file == "" then
        merged.local_dictionary.user_file = vim.fn.stdpath("config") .. "/magpie-dict.txt"
    end
    validate(merged)
    return merged
end

return M
