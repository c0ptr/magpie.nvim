local M = {}

local function check_version()
    if vim.fn.has("nvim-0.10") == 1 then
        vim.health.ok("Neovim version is supported")
    else
        vim.health.error("Magpie requires Neovim 0.10 or newer")
    end
end

local function check_curl()
    if vim.fn.executable("curl") == 1 then
        vim.health.ok("`curl` is available")
    else
        vim.health.error("`curl` is not on $PATH; Magpie needs it for network requests")
    end
end

local function check_local_dictionary()
    local ok, size = pcall(function()
        return require("magpie.dict").size()
    end)
    if not ok then
        vim.health.error("local dictionary failed to load")
    elseif size > 0 then
        vim.health.ok(string.format("local dictionary: %d bundled words", size))
    else
        vim.health.warn("local dictionary is empty")
    end
end

local function check_provider(name, env, optional)
    local value = vim.env[env]
    if value and value ~= "" then
        vim.health.ok(string.format("%s provider: %s is set", name, env))
    elseif optional then
        vim.health.info(string.format("%s provider: %s is not set (optional)", name, env))
    else
        vim.health.info(string.format("%s provider: %s is not set (needed to use this provider)", name, env))
    end
end

local function check_comment_translation()
    local ok, magpie = pcall(require, "magpie")
    if not ok or not magpie._configured or not magpie._config then
        vim.health.info("comment translation: `require(\"magpie\").setup()` has not run yet")
    else
        local config = magpie._config.comment_translation
        if not config.enabled then
            vim.health.info("comment translation is disabled")
        else
            vim.health.ok(string.format("comment translation mode: %s (target: %s)", config.mode, config.target_lang))
        end
    end
    if vim.treesitter and vim.treesitter.get_parser then
        vim.health.ok("tree-sitter is available (used for precise comment detection)")
    else
        vim.health.info("tree-sitter is unavailable; commentstring-based detection is used")
    end
end

function M.check()
    vim.health.start("Magpie")
    check_version()
    check_curl()
    check_local_dictionary()
    check_comment_translation()

    check_provider("chatgpt", "OPENAI_API_KEY", false)
    check_provider("copilot", "GITHUB_TOKEN", false)
    check_provider("gemini", "GEMINI_API_KEY", false)
    check_provider("deepseek", "DEEPSEEK_API_KEY", false)
    check_provider("youdao", "YOUDAO_APP_KEY", false)
    check_provider("youdao", "YOUDAO_APP_SECRET", false)
end

return M
