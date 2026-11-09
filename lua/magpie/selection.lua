local util = require("magpie.util")

local M = {}

local function word_at(line, column)
    -- Neovim columns are zero-based byte offsets, while Lua string indexes are
    -- one-based byte offsets. The translation target is English, so byte-based
    -- matching is sufficient and avoids splitting a multibyte character.
    local cursor = column + 1
    for start_index, word in line:gmatch("()([A-Za-z][A-Za-z'%-]*)") do
        local end_index = start_index + #word - 1
        if cursor >= start_index and cursor <= end_index then
            return word
        end
    end
end

function M.word_under_cursor(window)
    window = window or 0
    if not vim.api.nvim_win_is_valid(window) then
        return nil
    end

    local buffer = vim.api.nvim_win_get_buf(window)
    local cursor = vim.api.nvim_win_get_cursor(window)
    local line = vim.api.nvim_buf_get_lines(buffer, cursor[1] - 1, cursor[1], false)[1] or ""
    return word_at(line, cursor[2])
end

function M.word_at_position(window, row, column)
    if not vim.api.nvim_win_is_valid(window) or row < 0 or column < 0 then
        return nil
    end

    local buffer = vim.api.nvim_win_get_buf(window)
    local line = vim.api.nvim_buf_get_lines(buffer, row, row + 1, false)[1] or ""
    return word_at(line, column)
end

function M.visual_text()
    local mode = vim.fn.mode()
    if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
        return nil
    end

    local lines = vim.fn.getregion(vim.fn.getpos("."), vim.fn.getpos("v"), { type = mode })
    return util.trim(table.concat(lines, "\n"))
end

return M
