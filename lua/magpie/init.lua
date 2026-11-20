local config_module = require("magpie.config")
local comments = require("magpie.comments")
local dictionary = require("magpie.providers.dictionary")
local engine = require("magpie.engine")
local selection = require("magpie.selection")
local ui = require("magpie.ui")
local util = require("magpie.util")
local dict = require("magpie.dict")

local M = {
    _configured = false,
    _request_id = 0,
    _hover_id = 0,
    last_result = nil,
    version = "0.3.0",
}

local mouse_move = vim.api.nvim_replace_termcodes("<MouseMove>", true, false, true)
local left_release = vim.api.nvim_replace_termcodes("<LeftRelease>", true, false, true)
local input_namespace = vim.api.nvim_create_namespace("magpie-input")
local saved_mousemoveevent

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

local function should_lookup_ipa(text, options)
    if not options.dictionary.enabled or not util.is_english_word(text) then
        return false
    end
    local source = options.source_lang:lower()
    return source == "auto" or source:match("^en") ~= nil
end

local function local_lookup(text, options)
    if not options.local_dictionary.enabled or text:find("%s") then
        return nil
    end
    if not options.target_lang:lower():match("^zh") then
        return nil
    end
    return dict.lookup(text:lower())
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

    local comment_config = M._config.comment_translation
    if comment_config.enabled then
        if M._config.keymaps.comment then
            vim.keymap.set("n", M._config.keymaps.comment, function()
                M.translate_comment()
            end, { desc = "Translate code comment" })
            vim.keymap.set("x", M._config.keymaps.comment, function()
                M.translate_comment()
            end, { desc = "Translate code comments in selection" })
        end
        if M._config.keymaps.comments then
            vim.keymap.set("n", M._config.keymaps.comments, function()
                M.translate_comments()
            end, { desc = "Translate all Chinese comments in buffer" })
        end
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
        -- so existing user mappings keep receiving the mouse event too. Remember
        -- the previous value and restore it when hover is disabled.
        if saved_mousemoveevent == nil then
            saved_mousemoveevent = vim.o.mousemoveevent
        end
        vim.o.mousemoveevent = true
    elseif saved_mousemoveevent ~= nil then
        vim.o.mousemoveevent = saved_mousemoveevent
        saved_mousemoveevent = nil
    end

    if M._config.hover.enabled or M._config.mouse_selection.enabled then
        vim.on_key(M._on_input, input_namespace)
    else
        vim.on_key(nil, input_namespace)
    end
end

local function configure_highlights()
    vim.api.nvim_set_hl(0, "MagpieLabel", { default = true, link = "Title" })
end

function M.setup(options)
    M._config = config_module.build(options)
    M._configured = true
    configure_highlights()
    apply_keymaps()
    configure_input_handler()
    comments.setup(M._config)
    engine.configure(M._config)
    if M._config.local_dictionary.enabled and M._config.local_dictionary.user_file then
        dict.load_user(M._config.local_dictionary.user_file)
    end
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
    text = util.normalize_text(text or "")
    if text == "" then
        util.notify("No text to translate", vim.log.levels.WARN)
        return
    end

    local options = vim.tbl_deep_extend("force", {}, M._config, {
        source_lang = context.source_lang or M._config.source_lang,
        target_lang = context.target_lang or M._config.target_lang,
    })
    if not engine.has_provider(options.provider) then
        util.notify("Unknown translation provider: " .. tostring(options.provider), vim.log.levels.ERROR)
        return
    end

    M._request_id = M._request_id + 1
    local request_id = M._request_id

    local cached = engine.get(text, options, "word")
    if cached then
        M.last_result = cached
        ui.show_result(cached, context.anchor, options)
        return
    end

    local entry = local_lookup(text, options)
    if entry then
        local result = {
            text = text,
            phonetic = entry.ipa,
            translation = entry.zh,
            detected_source_lang = "en",
        }
        engine.remember(text, options, "word", result)
        M.last_result = result
        ui.show_result(result, context.anchor, options)
        return
    end

    local ipa_pending = should_lookup_ipa(text, options)
    local ipa_ready = not ipa_pending
    local ipa_value = nil
    local result = nil

    local function show_result()
        if request_id ~= M._request_id or not result then
            return
        end
        if ipa_pending and not ipa_ready then
            result.phonetic = "查询中…"
        end
        M.last_result = result
        ui.show_result(result, context.anchor, options)
    end

    if ipa_pending then
        dictionary.lookup(text, options, function(phonetic)
            if request_id ~= M._request_id then
                return
            end
            ipa_ready = true
            ipa_value = phonetic
            if result then
                result.phonetic = phonetic or "—"
                show_result()
            end
        end)
    end

    ui.show_loading(context.anchor, options)

    local streamed = ""
    local last_ui = 0
    engine.request(text, options, {
        flavor = "word",
        channel = "popup",
        cancel_previous = true,
        stream = options.stream.enabled,
        on_delta = function(delta)
            if request_id ~= M._request_id then
                return
            end
            streamed = streamed .. delta
            local now = math.floor(vim.uv.hrtime() / 1000000)
            if now - last_ui >= 80 then
                last_ui = now
                ui.show_result({
                    text = text,
                    phonetic = "查询中…",
                    translation = streamed,
                    detected_source_lang = options.source_lang,
                }, context.anchor, options)
            end
        end,
    }, function(response, translate_error)
        if request_id ~= M._request_id then
            return
        end
        if translate_error then
            ui.close()
            local hint = ""
            if
                options.local_dictionary.enabled
                and util.is_english_word(text)
                and options.target_lang:lower():match("^zh")
            then
                hint = "（该词不在本地词库中）"
            end
            util.notify(translate_error .. hint, vim.log.levels.ERROR)
            return
        end

        result = {
            text = text,
            phonetic = ipa_ready and (ipa_value or "—") or "查询中…",
            translation = response.translation,
            detected_source_lang = response.detected_source_lang or options.source_lang,
        }
        show_result()
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

function M.translate_comment(context)
    ensure_setup()
    return comments.translate_at_cursor(context)
end

function M.translate_comments()
    ensure_setup()
    return comments.translate_buffer()
end

function M.check_comments(options)
    ensure_setup()
    return comments.check(options)
end

function M.comment_mode()
    ensure_setup()
    return comments.mode()
end

function M.set_comment_mode(mode)
    ensure_setup()
    return comments.set_mode(mode)
end

function M.close()
    M._request_id = M._request_id + 1
    ui.close()
end

return M
