local config_module = require("word-translate.config")
local dictionary = require("word-translate.providers.dictionary")
local bing = require("word-translate.providers.bing")
local google = require("word-translate.providers.google")
local selection = require("word-translate.selection")
local ui = require("word-translate.ui")
local util = require("word-translate.util")
local deepseek = require("word-translate.providers.deepseek")


local M = {
    _configured = false,
    _request_id = 0,
    _hover_id = 0,
    _cache = {},
    _cache_order = {},
}

local providers = {
    google = google,
    bing = bing,
    deepseek = deepseek,
}

local mouse_move = vim.api.nvim_replace_termcodes("<MouseMove>", true, false, true)
local left_release = vim.api.nvim_replace_termcodes("<LeftRelease>", true, false, true)
local input_namespace = vim.api.nvim_create_namespace("word-translate-input")

local function anchor_from_mouse()
    local position = vim.fn.getmousepos()
    if position.winid and position.winid ~= 0 and vim.api.nvim_win_is_valid(position.winid) then
        return {
            window = position.winid,
            row = math.max(0, position.line - 1),
            column = math.max(0, position.column - 1),
        }
    end
end

local function cache_key(text, options)
    return table.concat({ options.provider, options.source_lang, options.target_lang, text }, "\31")
end

local function remember(key, result)
    local cache = M._config.cache
    if cache.max_entries == 0 then
        return
    end

    if not M._cache[key] then
        table.insert(M._cache_order, key)
    end
    M._cache[key] = result

    while #M._cache_order > cache.max_entries do
        local oldest = table.remove(M._cache_order, 1)
        M._cache[oldest] = nil
    end
end

local function active_visual_mode()
    local mode = vim.fn.mode()
    return mode == "v" or mode == "V" or mode == "\22"
end

local function apply_keymaps()
    if M._config.keymaps.normal then
        vim.keymap.set("n", M._config.keymaps.normal, function()
            M.translate_cursor()
        end, { desc = "Translate word under cursor" })
    end
    if M._config.keymaps.visual then
        vim.keymap.set("x", M._config.keymaps.visual, function()
            M.translate_visual()
        end, { desc = "Translate Visual selection" })
    end
end

function M._on_input(character)
    if character == mouse_move and M._config.hover.enabled then
        M._hover_id = M._hover_id + 1
        local hover_id = M._hover_id
        -- vim.on_key can run in a fast event. Update request state immediately,
        -- but defer floating-window changes to Neovim's scheduled context.
        M._request_id = M._request_id + 1
        local close_request_id = M._request_id
        vim.schedule(function()
            if close_request_id == M._request_id then
                ui.close()
            end
        end)

        vim.defer_fn(function()
            local mode = vim.api.nvim_get_mode().mode
            if hover_id ~= M._hover_id or not M._config.hover.enabled or mode ~= "n" then
                return
            end

            local anchor = anchor_from_mouse()
            if not anchor then
                return
            end
            local text = selection.word_at_position(anchor.window, anchor.row, anchor.column)
            if text then
                M.translate(text, { anchor = anchor, origin = "hover" })
            end
        end, M._config.hover.delay_ms)
        return
    end

    if character == left_release and M._config.mouse_selection.enabled then
        vim.schedule(function()
            if active_visual_mode() then
                M.translate_visual({ anchor = anchor_from_mouse(), origin = "mouse-selection" })
            end
        end)
    end
end

local function configure_input_handler()
    if M._config.hover.enabled then
        -- Required for <MouseMove> events. We use vim.on_key instead of a mapping,
        -- so existing user mappings keep receiving the mouse event too.
        vim.o.mousemoveevent = true
    end

    if M._config.hover.enabled or M._config.mouse_selection.enabled then
        vim.on_key(M._on_input, input_namespace)
    else
        vim.on_key(nil, input_namespace)
    end
end

local function configure_highlights()
    vim.api.nvim_set_hl(0, "WordTranslateLabel", { default = true, link = "Title" })
end

function M.setup(options)
    M._config = config_module.build(options)
    M._configured = true
    configure_highlights()
    apply_keymaps()
    configure_input_handler()
    return M
end

local function ensure_setup()
    if not M._configured then
        M.setup({})
    end
end

function M.translate(text, context)
    ensure_setup()
    context = context or {}
    text = util.trim(text or "")
    if text == "" then
        util.notify("No text to translate", vim.log.levels.WARN)
        return
    end

    local options = vim.tbl_deep_extend("force", {}, M._config, {
        source_lang = context.source_lang or M._config.source_lang,
        target_lang = context.target_lang or M._config.target_lang,
    })
    local provider = providers[options.provider]
    if not provider then
        util.notify("Unknown translation provider: " .. tostring(options.provider), vim.log.levels.ERROR)
        return
    end

    M._request_id = M._request_id + 1
    local request_id = M._request_id
    local key = cache_key(text, options)
    local cached = M._cache[key]
    if cached then
        ui.show_result(cached, context.anchor, options)
        return
    end

    ui.show_loading(context.anchor, options)
    provider.translate(text, options, function(response, translate_error)
        if request_id ~= M._request_id then
            return
        end
        if translate_error then
            ui.close()
            util.notify(translate_error, vim.log.levels.ERROR)
            return
        end

        local detected = response.detected_source_lang or options.source_lang
        local should_lookup_ipa = options.dictionary.enabled
            and util.is_english_word(text)
            and (options.source_lang:lower():match("^en") ~= nil or detected:lower():match("^en") ~= nil)
        local result = {
            text = text,
            phonetic = should_lookup_ipa and "查询中…" or "—",
            translation = response.translation,
            detected_source_lang = detected,
        }
        remember(key, result)
        ui.show_result(result, context.anchor, options)

        if not should_lookup_ipa then
            return
        end

        dictionary.lookup(text, options, function(phonetic)
            result.phonetic = phonetic or "—"
            if request_id == M._request_id then
                ui.show_result(result, context.anchor, options)
            end
        end)
    end)
end

function M.translate_cursor()
    ensure_setup()
    local text = selection.word_under_cursor(0)
    if not text then
        util.notify("No English word under cursor", vim.log.levels.WARN)
        return
    end
    M.translate(text, { origin = "cursor" })
end

function M.translate_visual(context)
    ensure_setup()
    if not active_visual_mode() then
        util.notify("Make a Visual selection first", vim.log.levels.WARN)
        return
    end

    local text = selection.visual_text()
    if not text or text == "" then
        util.notify("No selected text to translate", vim.log.levels.WARN)
        return
    end

    vim.cmd("normal! <Esc>")
    M.translate(text, context or { origin = "visual" })
end

function M.translate_from_command(text)
    ensure_setup()
    if text and util.trim(text) ~= "" then
        M.translate(text, { origin = "command" })
    elseif active_visual_mode() then
        M.translate_visual()
    else
        M.translate_cursor()
    end
end

function M.close()
    M._request_id = M._request_id + 1
    ui.close()
end

return M
