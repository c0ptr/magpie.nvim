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

function M.check()
    vim.health.start("Magpie")
    check_version()
    check_curl()

    check_provider("google", "GOOGLE_TRANSLATE_API_KEY", true)
    check_provider("bing", "AZURE_TRANSLATOR_KEY", false)
    check_provider("deepseek", "DEEPSEEK_API_KEY", false)
    check_provider("youdao", "YOUDAO_APP_KEY", false)
    check_provider("youdao", "YOUDAO_APP_SECRET", false)
end

return M
