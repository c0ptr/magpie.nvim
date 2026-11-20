local util = require("magpie.util")
local chatgpt = require("magpie.providers.chatgpt")
local copilot = require("magpie.providers.copilot")
local deepseek = require("magpie.providers.deepseek")
local gemini = require("magpie.providers.gemini")
local youdao = require("magpie.providers.youdao")

local M = {}

local providers = {
    chatgpt = chatgpt,
    copilot = copilot,
    deepseek = deepseek,
    gemini = gemini,
    youdao = youdao,
}

local state = {
    cache = {},
    order = {},
    in_flight = {},
    disk = { loaded = false, path = nil, entries = {}, save_pending = false },
    save_autocmd = false,
}

local function remember(key, result, options)
    local max_entries = options.cache.max_entries
    if max_entries == 0 then
        return
    end

    if not state.cache[key] then
        table.insert(state.order, key)
    end
    state.cache[key] = result

    while #state.order > max_entries do
        local oldest = table.remove(state.order, 1)
        state.cache[oldest] = nil
    end
end

local function disk_load(options)
    if not options.cache.persist or not options.cache.dir or options.cache.dir == "" then
        return
    end
    if state.disk.loaded and state.disk.path == options.cache.dir then
        return
    end

    state.disk.loaded = true
    state.disk.path = options.cache.dir
    state.disk.entries = {}
    local ok, lines = pcall(vim.fn.readfile, state.disk.path .. "/cache.json")
    if not ok or type(lines) ~= "table" then
        return
    end
    local payload = util.decode_json(table.concat(lines, "\n"), "cache")
    if type(payload) ~= "table" or type(payload.entries) ~= "table" then
        return
    end
    for key, entry in pairs(payload.entries) do
        if type(entry) == "table" and type(entry.result) == "table" then
            state.disk.entries[key] = { result = entry.result, ts = entry.ts or 0 }
        end
    end
end

local function disk_save()
    if not state.disk.loaded or state.disk.path == nil then
        return
    end

    local payload = { version = 2, entries = {} }
    for key, entry in pairs(state.disk.entries) do
        payload.entries[key] = entry
    end
    vim.fn.mkdir(state.disk.path, "p")
    local file, open_error = io.open(state.disk.path .. "/cache.json", "w")
    if not file then
        util.notify("Magpie: cannot write disk cache: " .. tostring(open_error), vim.log.levels.WARN)
        return
    end
    file:write(vim.json.encode(payload))
    file:close()
end

local function disk_schedule_save()
    if state.disk.save_pending then
        return
    end
    state.disk.save_pending = true
    vim.defer_fn(function()
        state.disk.save_pending = false
        disk_save()
    end, 3000)
end

local function disk_remember(key, result, options)
    if not options.cache.persist or not state.disk.loaded or options.cache.max_disk_entries == 0 then
        return
    end

    if state.disk.entries[key] then
        state.disk.entries[key] = { result = result, ts = os.time() }
        disk_schedule_save()
        return
    end

    local count = 0
    for _ in pairs(state.disk.entries) do
        count = count + 1
    end
    if count >= options.cache.max_disk_entries then
        local oldest_key, oldest_ts = nil, nil
        for candidate_key, entry in pairs(state.disk.entries) do
            if oldest_ts == nil or entry.ts < oldest_ts then
                oldest_key, oldest_ts = candidate_key, entry.ts
            end
        end
        state.disk.entries[oldest_key] = nil
    end
    state.disk.entries[key] = { result = result, ts = os.time() }
    disk_schedule_save()
end

local function cache_key(text, options, flavor)
    local normalized
    if flavor and flavor ~= "word" then
        -- Comment blocks keep their line structure: a cached translation with a
        -- different number of lines could not be applied without reflowing.
        normalized = util.normalize_block(text)
    else
        normalized = util.normalize_text(text)
        if util.is_english_word(normalized) then
            normalized = normalized:lower()
        end
    end

    local provider_settings = options[options.provider] or {}
    local parts = {
        options.provider,
        options.source_lang,
        options.target_lang,
        util.hash_hex(vim.inspect(provider_settings)),
        normalized,
    }
    if flavor and flavor ~= "word" then
        table.insert(parts, 1, flavor)
    end
    return table.concat(parts, "\31")
end

local function raw_get(key, options)
    local cached = state.cache[key]
    if cached then
        return cached
    end

    if options.cache.persist then
        disk_load(options)
        local entry = state.disk.entries[key]
        if entry then
            remember(key, entry.result, options)
            return entry.result
        end
    end
    return nil
end

function M.has_provider(name)
    return providers[name] ~= nil
end

function M.cache_key(text, options, flavor)
    return cache_key(text, options, flavor)
end

function M.get(text, options, flavor)
    local key = cache_key(text, options, flavor)
    return raw_get(key, options), key
end

function M.remember(text, options, flavor, result)
    local key = cache_key(text, options, flavor)
    remember(key, result, options)
    disk_remember(key, result, options)
end

function M.configure(options)
    if options.cache.persist and not state.save_autocmd then
        state.save_autocmd = true
        vim.api.nvim_create_autocmd("VimLeavePre", {
            once = true,
            callback = function()
                disk_save()
            end,
        })
    end
end

-- Run one translation request.
--
-- spec.flavor            cache namespace ("word" by default)
-- spec.prompt            optional system prompt for LLM providers
-- spec.channel           requests in the same channel cancel each other
-- spec.cancel_previous   cancel other in-flight requests in the channel
-- spec.stream            false disables streaming for this request
-- spec.cache             false skips the cache (used for batched requests)
-- spec.on_delta          streaming callback
function M.request(text, options, spec, callback)
    spec = spec or {}
    local flavor = spec.flavor or "word"
    local key = cache_key(text, options, flavor)
    local use_cache = spec.cache ~= false

    if use_cache then
        local cached = raw_get(key, options)
        if cached then
            callback(cached, nil)
            return
        end
    end

    local pending = state.in_flight[key]
    if pending then
        table.insert(pending.callbacks, callback)
        return
    end

    local channel = spec.channel or "default"
    if spec.cancel_previous then
        for other_key, entry in pairs(state.in_flight) do
            if entry.channel == channel and other_key ~= key then
                if entry.handle and entry.handle.kill then
                    pcall(entry.handle.kill, entry.handle)
                end
                state.in_flight[other_key] = nil
            end
        end
    end

    local provider = providers[options.provider]
    if not provider then
        callback(nil, "Unknown translation provider: " .. tostring(options.provider))
        return
    end

    pending = { callbacks = { callback }, channel = channel, handle = nil }
    state.in_flight[key] = pending

    local function finish(result, request_error)
        if state.in_flight[key] ~= pending then
            return
        end
        state.in_flight[key] = nil
        if result and use_cache then
            remember(key, result, options)
            disk_remember(key, result, options)
        end
        for _, cb in ipairs(pending.callbacks) do
            cb(result, request_error)
        end
    end

    local streaming = spec.stream ~= false
        and options.stream
        and options.stream.enabled
        and provider.translate_stream ~= nil

    if streaming then
        pending.handle = provider.translate_stream(text, options, function(delta)
            if state.in_flight[key] == pending and spec.on_delta then
                spec.on_delta(delta)
            end
        end, finish, spec.prompt)
    else
        pending.handle = provider.translate(text, options, finish, spec.prompt)
    end
end

return M
