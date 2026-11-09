local config_module = require("magpie.config")
local dictionary = require("magpie.providers.dictionary")
local bing = require("magpie.providers.bing")
local google = require("magpie.providers.google")
local selection = require("magpie.selection")
local ui = require("magpie.ui")
local util = require("magpie.util")
local deepseek = require("magpie.providers.deepseek")
local youdao = require("magpie.providers.youdao")
local dict = require("magpie.dict")


local M = {
    _configured = false,
    _request_id = 0,
    _hover_id = 0,
    _cache = {},
    _cache_order = {},
    last_result = nil,
}

local providers = {
    google = google,
    bing = bing,
    deepseek = deepseek,
    youdao = youdao,
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

local function cache_key(text, options)
    -- Normalize single words to lowercase so "Hello " and "hello" share an
    -- entry; hash the provider settings instead of storing them raw.
    local normalized = util.normalize_text(text)
    if util.is_english_word(normalized) then
        normalized = normalized:lower()
    end
    return table.concat({
        options.provider,
        options.source_lang,
        options.target_lang,
        util.hash_hex(vim.inspect(options[options.provider] or {})),
        normalized,
    }, "\31")
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

local in_flight = {}
local disk_cache = { loaded = false, path = nil, entries = {}, save_pending = false }

local function disk_cache_load(options)
    if not options.cache.persist or (disk_cache.loaded and disk_cache.path == options.cache.dir) then
        return
    end
    disk_cache.loaded = true
    disk_cache.path = options.cache.dir
    disk_cache.entries = {}
    local ok, lines = pcall(vim.fn.readfile, disk_cache.path .. "/cache.json")
    if not ok or type(lines) ~= "table" then
        return
    end
    local payload = util.decode_json(table.concat(lines, "\n"), "cache")
    if type(payload) ~= "table" or type(payload.entries) ~= "table" then
        return
    end
    for key, entry in pairs(payload.entries) do
        if type(entry) == "table" and type(entry.result) == "table" then
            disk_cache.entries[key] = { result = entry.result, ts = entry.ts or 0 }
        end
    end
end

local function disk_cache_save()
    if not disk_cache.loaded or disk_cache.path == nil then
        return
    end
    local payload = { version = 1, entries = {} }
    for key, entry in pairs(disk_cache.entries) do
        payload.entries[key] = entry
    end
    vim.fn.mkdir(disk_cache.path, "p")
    local file, open_error = io.open(disk_cache.path .. "/cache.json", "w")
    if not file then
        util.notify("Magpie: cannot write disk cache: " .. tostring(open_error), vim.log.levels.WARN)
        return
    end
    file:write(vim.json.encode(payload))
    file:close()
end

local function disk_cache_schedule_save()
    if disk_cache.save_pending then
        return
    end
    disk_cache.save_pending = true
    vim.defer_fn(function()
        disk_cache.save_pending = false
        disk_cache_save()
    end, 3000)
end

local function disk_cache_remember(key, result, options)
    if not options.cache.persist or not disk_cache.loaded then
        return
    end
    if disk_cache.entries[key] then
        disk_cache.entries[key] = { result = result, ts = os.time() }
        disk_cache_schedule_save()
        return
    end
    local count = 0
    for _ in pairs(disk_cache.entries) do
        count = count + 1
    end
    if count >= options.cache.max_disk_entries then
        local oldest_key, oldest_ts = nil, nil
        for candidate_key, entry in pairs(disk_cache.entries) do
            if oldest_ts == nil or entry.ts < oldest_ts then
                oldest_key, oldest_ts = candidate_key, entry.ts
            end
        end
        disk_cache.entries[oldest_key] = nil
    end
    disk_cache.entries[key] = { result = result, ts = os.time() }
    disk_cache_schedule_save()
end

local function should_lookup_ipa(text, options)
    if not options.dictionary.enabled or not util.is_english_word(text) then
        return false
    end
    local source = options.source_lang:lower()
    return source == "auto" or source:match("^en") ~= nil
end

local function local_lookup(text, options)
    if not options.local_dictionary.enabled or not util.is_english_word(text) then
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
    if M._config.cache.persist then
        vim.api.nvim_create_autocmd("VimLeavePre", {
            once = true,
            callback = function()
                disk_cache_save()
            end,
        })
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
    local provider = providers[options.provider]
    if not provider then
        util.notify("Unknown translation provider: " .. tostring(options.provider), vim.log.levels.ERROR)
        return
    end

    M._request_id = M._request_id + 1
    local request_id = M._request_id
    local key = cache_key(text, options)

    local cached = M._cache[key]
    if not cached and options.cache.persist then
        disk_cache_load(options)
        local disk_entry = disk_cache.entries[key]
        if disk_entry then
            cached = disk_entry.result
            remember(key, cached)
        end
    end
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
        remember(key, result)
        disk_cache_remember(key, result, options)
        M.last_result = result
        ui.show_result(result, context.anchor, options)
        return
    end

    local function complete(result, translate_error)
        if request_id ~= M._request_id then
            return
        end
        if translate_error then
            ui.close()
            local hint = ""
            if options.local_dictionary.enabled
                and util.is_english_word(text)
                and options.target_lang:lower():match("^zh") then
                hint = "（该词不在本地词库中）"
            end
            util.notify(translate_error .. hint, vim.log.levels.ERROR)
            return
        end
        M.last_result = result
        ui.show_result(result, context.anchor, options)
    end

    local pending = in_flight[key]
    if pending then
        table.insert(pending.callbacks, complete)
        return
    end

    for other_key, pending_entry in pairs(in_flight) do
        if pending_entry.handle then
            pcall(pending_entry.handle.kill, pending_entry.handle)
        end
        if pending_entry.handle_ipa then
            pcall(pending_entry.handle_ipa.kill, pending_entry.handle_ipa)
        end
        in_flight[other_key] = nil
    end

    pending = { callbacks = { complete } }
    in_flight[key] = pending

    ui.show_loading(context.anchor, options)

    local provider_done = false
    local ipa_pending = should_lookup_ipa(text, options)
    local ipa_done = not ipa_pending
    local result = nil
    local translate_error = nil

    local function try_finish()
        if not provider_done or not ipa_done or in_flight[key] ~= pending then
            return
        end
        in_flight[key] = nil
        for _, cb in ipairs(pending.callbacks) do
            cb(result, translate_error)
        end
    end

    local function on_ipa(phonetic)
        if result and request_id == M._request_id then
            result.phonetic = phonetic or "—"
            ui.show_result(result, context.anchor, options)
        end
        ipa_done = true
        try_finish()
    end

    local function on_provider(response, provider_error)
        if provider_error then
            translate_error = provider_error
        else
            result = {
                text = text,
                phonetic = ipa_pending and "查询中…" or "—",
                translation = response.translation,
                detected_source_lang = response.detected_source_lang or options.source_lang,
            }
            remember(key, result)
            disk_cache_remember(key, result, options)
            if ipa_pending then
                ui.show_result(result, context.anchor, options)
            end
        end
        provider_done = true
        try_finish()
    end

    if ipa_pending then
        pending.handle_ipa = dictionary.lookup(text, options, on_ipa)
    end
    pending.handle = provider.translate(text, options, on_provider)
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
