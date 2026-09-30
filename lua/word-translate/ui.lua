local M = {}

local namespace = vim.api.nvim_create_namespace("word-translate-ui")
local state = { buffer = nil, window = nil }

local function valid_window()
    return state.window and vim.api.nvim_win_is_valid(state.window)
end

local function valid_buffer()
    return state.buffer and vim.api.nvim_buf_is_valid(state.buffer)
end

local function display_width(text)
    return vim.fn.strdisplaywidth(text)
end

local function wrap_line(prefix, value, width)
    local result = {}
    local indent = string.rep(" ", display_width(prefix))
    local line = prefix
    local line_width = display_width(line)

    local characters = vim.fn.strchars(value)
    for index = 0, characters - 1 do
        local character = vim.fn.strcharpart(value, index, 1)
        local character_width = math.max(1, display_width(character))
        if line_width + character_width > width and line_width > display_width(prefix) then
            table.insert(result, line)
            line = indent
            line_width = display_width(line)
        end
        line = line .. character
        line_width = line_width + character_width
    end
    table.insert(result, line)
    return result
end

local function build_field(lines, highlights, label, value, width)
    local first = true
    for _, source_line in ipairs(vim.split(value, "\n", { plain = true, trimempty = false })) do
        local prefix = first and (label .. ": ") or string.rep(" ", display_width(label) + 2)
        local wrapped = wrap_line(prefix, source_line, width)
        for _, line in ipairs(wrapped) do
            local row = #lines
            table.insert(lines, line)
            if first then
                table.insert(highlights, { row = row, end_col = #label })
            end
            first = false
        end
    end
end

local function render(lines, highlights, anchor, config)
    local widest = 1
    for _, line in ipairs(lines) do
        widest = math.max(widest, display_width(line))
    end

    local max_width = math.max(1, math.min(config.ui.max_width, vim.o.columns - 4))
    local min_width = math.min(config.ui.min_width, max_width)
    local width = math.max(min_width, math.min(widest, max_width))
    local height = math.max(1, math.min(#lines, vim.o.lines - 4))

    if not valid_buffer() then
        state.buffer = vim.api.nvim_create_buf(false, true)
        vim.bo[state.buffer].bufhidden = "wipe"
        vim.bo[state.buffer].filetype = "word-translate"
    end

    vim.bo[state.buffer].modifiable = true
    vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(state.buffer, namespace, 0, -1)
    for _, highlight in ipairs(highlights) do
        vim.api.nvim_buf_set_extmark(state.buffer, namespace, highlight.row, 0, {
            end_col = highlight.end_col,
            hl_group = "WordTranslateLabel",
        })
    end
    vim.bo[state.buffer].modifiable = false

    local window_config
    if anchor and anchor.window and vim.api.nvim_win_is_valid(anchor.window) then
        window_config = {
            relative = "win",
            win = anchor.window,
            bufpos = { anchor.row, anchor.column },
            row = 1,
            col = 0,
            anchor = "NW",
            width = width,
            height = height,
        }
    else
        window_config = {
            relative = "cursor",
            row = 1,
            col = 0,
            anchor = "NW",
            width = width,
            height = height,
        }
    end

    window_config.border = config.ui.border
    window_config.title = config.ui.title
    window_config.title_pos = "center"
    window_config.style = "minimal"
    window_config.focusable = false
    window_config.mouse = false
    window_config.zindex = 45

    if valid_window() then
        vim.api.nvim_win_set_config(state.window, window_config)
    else
        state.window = vim.api.nvim_open_win(state.buffer, false, window_config)
    end

    vim.wo[state.window].winblend = config.ui.winblend
    vim.wo[state.window].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:FloatTitle"
    vim.wo[state.window].wrap = false
end

function M.show_loading(anchor, config)
    render({ "正在翻译…" }, {}, anchor, config)
end

function M.show_result(result, anchor, config)
    local max_width = math.max(1, math.min(config.ui.max_width, vim.o.columns - 4))
    local lines, highlights = {}, {}
    build_field(lines, highlights, "原文", result.text, max_width)
    build_field(lines, highlights, "音标", result.phonetic or "—", max_width)
    build_field(lines, highlights, "翻译", result.translation, max_width)
    render(lines, highlights, anchor, config)
end

function M.close()
    if valid_window() then
        vim.api.nvim_win_close(state.window, true)
    end
    state.window = nil
    state.buffer = nil
end

function M.is_open()
    return valid_window()
end

return M
