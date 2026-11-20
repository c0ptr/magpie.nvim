local engine = require("magpie.engine")
local util = require("magpie.util")
local chat = require("magpie.providers.chat")

local M = {}

M.DELIMITER = "@@MAGPIE@@"

local state = {
    options = nil,
    augroup = nil,
    tokens = {},
    detect_cache = {},
    insert_marks = {},
    last_write = {},
}

local apply_namespace = vim.api.nvim_create_namespace("magpie-comment-apply")
local insert_namespace = vim.api.nvim_create_namespace("magpie-comment-insert")

-- Closing delimiters are matched after the opening delimiter.  Lua long
-- brackets (--[[ ... ]], --[=[ ... ]=]) are handled separately.
local BLOCK_PAIRS = {
    { open = "/*", close = "*/" },
    { open = "<!--", close = "-->" },
    { open = "{-", close = "-}" },
    { open = "(*", close = "*)" },
    { open = "#[", close = "]#" },
    { open = "#|", close = "|#" },
    { open = "%{", close = "%}" },
    { open = "<#", close = "#>" },
    { open = "=begin", close = "=end" },
    { open = "=pod", close = "=cut" },
}

local LINE_SYNTAX = {
    ada = { "--" },
    awk = { "#" },
    batch = { "rem" },
    bash = { "#" },
    c = { "//" },
    clojure = { ";" },
    cmake = { "#" },
    cobol = { "*" },
    cpp = { "//" },
    cs = { "//" },
    crystal = { "#" },
    cuda = { "//" },
    d = { "//" },
    dart = { "//" },
    dockerfile = { "#" },
    dosini = { "#", ";" },
    dosbatch = { "rem" },
    elixir = { "#" },
    elm = { "--" },
    erlang = { "%" },
    fish = { "#" },
    fortran = { "!" },
    fsharp = { "//" },
    go = { "//" },
    graphql = { "#" },
    groovy = { "//" },
    hcl = { "#", "//" },
    haskell = { "--" },
    ini = { "#", ";" },
    java = { "//" },
    julia = { "#" },
    javascript = { "//" },
    javascriptreact = { "//" },
    json5 = { "//" },
    kotlin = { "//" },
    less = { "//" },
    lisp = { ";" },
    lua = { "--" },
    make = { "#" },
    matlab = { "%" },
    nim = { "#" },
    nix = { "#" },
    objc = { "//" },
    octave = { "%", "#" },
    perl = { "#" },
    powershell = { "#" },
    php = { "//", "#" },
    proto = { "//" },
    python = { "#" },
    r = { "#" },
    ruby = { "#" },
    rust = { "//" },
    scala = { "//" },
    scheme = { ";" },
    scss = { "//" },
    sh = { "#" },
    solidity = { "//" },
    sql = { "--" },
    swift = { "//" },
    terraform = { "#", "//" },
    tex = { "%" },
    toml = { "#" },
    typescript = { "//" },
    typescriptreact = { "//" },
    vb = { "'" },
    vba = { "'" },
    vhdl = { "--" },
    v = { "//" },
    vim = { '"' },
    yaml = { "#" },
    zig = { "//" },
    zsh = { "#" },
}

local BLOCK_SYNTAX = {
    c = { { "/*", "*/" } },
    cpp = { { "/*", "*/" } },
    cs = { { "/*", "*/" } },
    css = { { "/*", "*/" } },
    cuda = { { "/*", "*/" } },
    d = { { "/*", "*/" } },
    dart = { { "/*", "*/" } },
    elm = { { "{-", "-}" } },
    fsharp = { { "(*", "*)" } },
    go = { { "/*", "*/" } },
    hcl = { { "/*", "*/" } },
    groovy = { { "/*", "*/" } },
    haskell = { { "{-", "-}" } },
    html = { { "<!--", "-->" } },
    java = { { "/*", "*/" } },
    julia = { { "#=", "=#" } },
    javascript = { { "/*", "*/" } },
    javascriptreact = { { "/*", "*/" } },
    json5 = { { "/*", "*/" } },
    kotlin = { { "/*", "*/" } },
    less = { { "/*", "*/" } },
    lisp = { { "#|", "|#" } },
    lua = { { "--[[", "]]" } },
    matlab = { { "%{", "%}" } },
    nim = { { "#[", "]#" } },
    nix = { { "/*", "*/" } },
    objc = { { "/*", "*/" } },
    ocaml = { { "(*", "*)" } },
    pascal = { { "{", "}" }, { "(*", "*)" } },
    php = { { "/*", "*/" } },
    powershell = { { "<#", "#>" } },
    proto = { { "/*", "*/" } },
    ruby = { { "=begin", "=end" } },
    rust = { { "/*", "*/" } },
    solidity = { { "/*", "*/" } },
    scala = { { "/*", "*/" } },
    scheme = { { "#|", "|#" } },
    scss = { { "/*", "*/" } },
    sql = { { "/*", "*/" } },
    swift = { { "/*", "*/" } },
    terraform = { { "/*", "*/" } },
    typescript = { { "/*", "*/" } },
    typescriptreact = { { "/*", "*/" } },
    v = { { "/*", "*/" } },
    vue = { { "<!--", "-->" } },
    xml = { { "<!--", "-->" } },
}

local DIRECTIVE_WORDS = {
    rem = true,
    ["rem."] = true,
    dnl = true,
    ["nb."] = true,
}

local syntax_for

local function notify(message, level)
    util.notify("Magpie: " .. message, level or vim.log.levels.INFO)
end

local function lua_long_pair(text)
    local equals = text:match("^%-%-%[(=*)%[")
    if not equals then
        return nil
    end
    return { open = "--[" .. equals .. "[", close = "]" .. equals .. "]" }
end

local function detect_block(lines)
    if #lines == 0 then
        return nil
    end
    local first = (lines[1] or ""):gsub("^%s+", "")
    local last = (lines[#lines] or ""):gsub("%s+$", "")

    local long_pair = lua_long_pair(first)
    if long_pair and last:sub(-#long_pair.close) == long_pair.close then
        return long_pair
    end

    for _, pair in ipairs(BLOCK_PAIRS) do
        if first:sub(1, #pair.open) == pair.open and last:sub(-#pair.close) == pair.close then
            return pair
        end
    end
    return nil
end

local function strip_line_marker(line, forced)
    local indent = line:match("^%s*") or ""
    local rest = line:sub(#indent + 1)

    if forced then
        if rest:sub(1, #forced) ~= forced then
            return nil
        end
        local tail = rest:sub(#forced + 1)
        local spaces = tail:match("^%s*") or ""
        return {
            offset = #indent + #forced + #spaces,
            marker = forced,
            gutter = indent .. forced .. spaces,
        }
    end

    local marker = rest:match("^%p+")
    if marker and marker ~= "" then
        local tail = rest:sub(#marker + 1)
        local spaces = tail:match("^%s*") or ""
        return {
            offset = #indent + #marker + #spaces,
            marker = marker,
            gutter = indent .. marker .. spaces,
        }
    end

    local word = rest:match("^(%a+%.?)")
    if word and DIRECTIVE_WORDS[word:lower()] then
        local tail = rest:sub(#word + 1)
        local spaces = tail:match("^%s*") or ""
        if spaces ~= "" or tail == "" then
            return {
                offset = #indent + #word + #spaces,
                marker = word,
                gutter = indent .. word .. spaces,
            }
        end
    end
    return nil
end

local function strip_block_open(line, pair)
    local open_position = line:find(pair.open, 1, true)
    if not open_position then
        return nil
    end
    if line:sub(1, open_position - 1):match("%S") then
        return nil
    end

    local tail = line:sub(open_position + #pair.open)
    local decoration = tail:match("^([!*]+)") or ""
    local after_decoration = tail:sub(#decoration + 1)
    local spaces = after_decoration:match("^%s*") or ""
    return open_position - 1 + #pair.open + #decoration + #spaces
end

local function strip_block_middle(line)
    local indent = line:match("^%s*") or ""
    local rest = line:sub(#indent + 1)
    local decoration = ""
    if rest:match("^%*%s") or rest == "*" then
        decoration = rest:match("^%*%s?") or "*"
    elseif rest:match("^!%s") or rest == "!" then
        decoration = rest:match("^!%s?") or "!"
    end
    return #indent + #decoration
end

local function content_end_for_line(line, close_position)
    local index = close_position - 1
    while index > 0 and line:sub(index, index):match("%s") do
        index = index - 1
    end
    return index
end

local function build_comment(bufnr, start_row, start_col, end_row, end_col, hint)
    hint = hint or {}
    local ok, lines = pcall(vim.api.nvim_buf_get_text, bufnr, start_row, start_col, end_row, end_col, {})
    if not ok or type(lines) ~= "table" or #lines == 0 then
        return nil
    end

    local pair = hint.pair or (hint.kind == "line" and nil or detect_block(lines))
    local kind = pair and "block" or "line"
    local spans, contents, gutters = {}, {}, {}
    local open_prefix, close_suffix
    local marker

    if kind == "block" then
        for index, line in ipairs(lines) do
            local line_start = index == 1 and start_col or 0
            local content_start, content_end

            if #lines == 1 then
                content_start = strip_block_open(line, pair)
                if not content_start then
                    return nil
                end
                local close_position = line:find(pair.close, content_start + 1, true)
                if not close_position then
                    return nil
                end
                content_end = content_end_for_line(line, close_position)
                open_prefix = open_prefix or line:sub(1, content_start)
                close_suffix = line:sub(content_end + 1)
            elseif index == 1 then
                content_start = strip_block_open(line, pair)
                if not content_start then
                    return nil
                end
                content_end = #line
                while content_end > content_start and line:sub(content_end, content_end):match("%s") do
                    content_end = content_end - 1
                end
                open_prefix = line:sub(1, content_start)
            elseif index == #lines then
                local close_position = line:find(pair.close, 1, true)
                if not close_position then
                    return nil
                end
                content_start = strip_block_middle(line)
                content_end = content_end_for_line(line, close_position)
                if content_start > content_end then
                    content_start = content_end
                end
                close_suffix = line:sub(content_end + 1)
            else
                content_start = strip_block_middle(line)
                content_end = #line
                while content_end > content_start and line:sub(content_end, content_end):match("%s") do
                    content_end = content_end - 1
                end
            end

            content_start = math.max(0, math.min(content_start, #line))
            content_end = math.max(content_start, math.min(content_end, #line))
            spans[index] = {
                row = start_row + index - 1,
                start_col = line_start + content_start,
                end_col = line_start + content_end,
            }
            contents[index] = line:sub(content_start + 1, content_end)
            gutters[index] = line:sub(1, content_start)
        end
        marker = pair.open
        open_prefix = open_prefix or (lines[1] or "")
        close_suffix = close_suffix or ""
    else
        for index, line in ipairs(lines) do
            local parsed = strip_line_marker(line, hint.marker)
            if not parsed then
                if hint.marker then
                    return nil
                end
                parsed = { offset = 0, marker = "", gutter = "" }
            end
            local line_start = index == 1 and start_col or 0
            local content_start = math.min(parsed.offset, #line)
            local content_end = #line
            while content_end > content_start and line:sub(content_end, content_end):match("%s") do
                content_end = content_end - 1
            end
            spans[index] = {
                row = start_row + index - 1,
                start_col = line_start + content_start,
                end_col = line_start + content_end,
            }
            contents[index] = line:sub(content_start + 1, content_end)
            gutters[index] = line:sub(1, content_start)
            marker = marker or parsed.marker
        end
    end

    local core_start, core_end
    for index = 1, #contents do
        if util.trim(contents[index]) ~= "" then
            if not core_start then
                core_start = index
            end
            core_end = index
        end
    end
    if not core_start then
        return nil
    end

    local core_spans, core_contents = {}, {}
    for index = core_start, core_end do
        table.insert(core_spans, spans[index])
        table.insert(core_contents, contents[index])
    end

    return {
        bufnr = bufnr,
        start_row = start_row,
        start_col = start_col,
        end_row = end_row,
        end_col = end_col,
        kind = kind,
        marker = marker,
        gutter = gutters[core_start] or gutters[1] or "",
        open_prefix = open_prefix,
        close_suffix = close_suffix,
        spans = core_spans,
        text = table.concat(core_contents, "\n"),
    }
end

local query_cache = {}

local function queries_for(language)
    if query_cache[language] ~= nil then
        return query_cache[language] or nil
    end

    local queries = {}
    for _, node_type in ipairs({ "comment", "line_comment", "block_comment", "doc_comment", "multiline_comment" }) do
        local ok, query = pcall(vim.treesitter.query.parse, language, "((" .. node_type .. ") @comment)")
        if ok and query then
            table.insert(queries, query)
        end
    end
    query_cache[language] = #queries > 0 and queries or false
    return #queries > 0 and queries or nil
end

local function range_key(range)
    return table.concat({ range.start_row, range.start_col, range.end_row, range.end_col }, ":")
end

local function tree_ranges(bufnr)
    if not state.options.comment_translation.use_treesitter then
        return nil
    end
    local _, syntax_block_pairs = syntax_for(bufnr)
    if not vim.treesitter or not vim.treesitter.get_parser then
        return nil
    end

    local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
    if not ok_parser or not parser then
        return nil
    end
    local ok_parse = pcall(parser.parse, parser)
    if not ok_parse then
        return nil
    end

    local ranges = {}
    local seen = {}

    local function collect(tree, language_tree)
        local ok_lang, language = pcall(language_tree.lang, language_tree)
        if not ok_lang or not language then
            return
        end
        local queries = queries_for(language)
        if not queries then
            return
        end
        local root = tree:root()
        for _, query in ipairs(queries) do
            local ok_iter = pcall(function()
                for _, node in query:iter_captures(root, bufnr) do
                    local start_row, start_col, end_row, end_col = node:range()
                    if start_row and end_row and start_row <= end_row then
                        local ok_text, text = pcall(
                            vim.api.nvim_buf_get_text,
                            bufnr,
                            start_row,
                            start_col,
                            end_row,
                            end_col,
                            {}
                        )
                        if ok_text and type(text) == "table" and #text > 0 then
                            local pair = detect_block(text)
                            if not pair and syntax_block_pairs then
                                local first_text = (text[1] or ""):gsub("^%s+", "")
                                local last_text = (text[#text] or ""):gsub("%s+$", "")
                                for _, candidate in ipairs(syntax_block_pairs) do
                                    if
                                        first_text:sub(1, #candidate.open) == candidate.open
                                        and last_text:sub(-#candidate.close) == candidate.close
                                    then
                                        pair = candidate
                                        break
                                    end
                                end
                            end
                            local kind = pair and "block" or "line"
                            local marker
                            if kind == "line" then
                                local parsed = strip_line_marker(text[1])
                                marker = parsed and parsed.marker or nil
                            end
                            local before = vim.api.nvim_buf_get_text(
                                bufnr,
                                start_row,
                                0,
                                start_row,
                                start_col,
                                {}
                            )[1] or ""
                            local key = table.concat({ start_row, start_col, end_row, end_col }, ":")
                            if not seen[key] then
                                seen[key] = true
                                table.insert(ranges, {
                                    start_row = start_row,
                                    start_col = start_col,
                                    end_row = end_row,
                                    end_col = end_col,
                                    kind = kind,
                                    pair = pair,
                                    marker = marker,
                                    full_line = not before:match("%S"),
                                })
                            end
                        end
                    end
                end
            end)
            if not ok_iter then
                return
            end
        end
    end

    local ok_walk = pcall(function()
        if parser.for_each_tree then
            parser:for_each_tree(collect)
        else
            local language = parser:lang()
            for _, tree in ipairs(parser:parse()) do
                collect(tree, {
                    lang = function()
                        return language
                    end,
                })
            end
        end
    end)
    if not ok_walk or #ranges == 0 then
        return nil
    end
    return ranges
end

syntax_for = function(bufnr)
    local filetype = vim.bo[bufnr].filetype
    local commentstring = vim.bo[bufnr].commentstring or ""
    local line_markers, block_pairs = {}, {}

    local marker_position = commentstring:find("%%s")
    if marker_position then
        local prefix = commentstring:sub(1, marker_position - 1):gsub("%s+$", "")
        local suffix = commentstring:sub(marker_position + 2):gsub("^%s+", "")
        if prefix ~= "" then
            if suffix == "" then
                table.insert(line_markers, prefix)
            else
                table.insert(block_pairs, { open = prefix, close = suffix })
            end
        end
    end

    for _, marker in ipairs(LINE_SYNTAX[filetype] or {}) do
        local exists = false
        for _, candidate in ipairs(line_markers) do
            if candidate == marker then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(line_markers, marker)
        end
    end

    for _, pair in ipairs(BLOCK_SYNTAX[filetype] or {}) do
        local exists = false
        for _, candidate in ipairs(block_pairs) do
            if candidate.open == pair[1] and candidate.close == pair[2] then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(block_pairs, { open = pair[1], close = pair[2] })
        end
    end

    table.sort(line_markers, function(left, right)
        return #left > #right
    end)
    table.sort(block_pairs, function(left, right)
        return #left.open > #right.open
    end)
    return line_markers, block_pairs
end

local function line_marker_match(rest, marker)
    if rest:sub(1, #marker) ~= marker then
        return false
    end
    if marker:match("^%a") then
        local next_character = rest:sub(#marker + 1, #marker + 1)
        return next_character == "" or next_character:match("%s")
    end
    return true
end

local function block_start(rest, block_pairs)
    local long_pair = lua_long_pair(rest)
    if long_pair then
        return long_pair
    end
    for _, pair in ipairs(block_pairs) do
        if rest:sub(1, #pair.open) == pair.open then
            return pair
        end
    end
    return nil
end

local function find_block_end(lines, start_index, start_column, pair)
    local line = lines[start_index]
    local close_position = line:find(pair.close, start_column + #pair.open + 1, true)
    if close_position then
        return start_index, close_position + #pair.close - 1
    end
    for index = start_index + 1, #lines do
        close_position = lines[index]:find(pair.close, 1, true)
        if close_position then
            return index, close_position + #pair.close - 1
        end
    end
    return nil
end

local function find_inline_block(line, block_pairs)
    for _, pair in ipairs(block_pairs) do
        local index = 1
        local quote = nil
        while index <= #line do
            local character = line:sub(index, index)
            if quote then
                if character == "\\" then
                    index = index + 2
                elseif character == quote then
                    quote = nil
                    index = index + 1
                else
                    index = index + 1
                end
            elseif character == '"' or character == "'" or character == "`" then
                quote = character
                index = index + 1
            elseif line:sub(index, index + #pair.open - 1) == pair.open then
                local close_position = line:find(pair.close, index + #pair.open, true)
                if close_position then
                    return index - 1, pair, close_position + #pair.close - 1
                end
                index = index + 1
            else
                index = index + 1
            end
        end
    end
    return nil
end

local function find_inline_marker(line, markers)
    for _, marker in ipairs(markers) do
        -- A quote is both a string delimiter and a comment marker in several
        -- languages (Vimscript, Visual Basic).  Without a syntax tree, treating
        -- it as an inline comment would corrupt strings, so only detect it at
        -- the start of a line (handled by fallback_ranges' line branch).
        if marker:sub(1, 1) ~= '"' and marker:sub(1, 1) ~= "'" then
            local index = 1
            local quote = nil
            while index <= #line do
                local character = line:sub(index, index)
                if quote then
                    if character == "\\" then
                        index = index + 2
                    elseif character == quote then
                        quote = nil
                        index = index + 1
                    else
                        index = index + 1
                    end
                elseif character == '"' or character == "'" or character == "`" then
                    quote = character
                    index = index + 1
                elseif
                    line:sub(index, index + #marker - 1) == marker
                    and (index == 1 or line:sub(index - 1, index - 1):match("%s"))
                    and line_marker_match(line:sub(index), marker)
                then
                    return index
                else
                    index = index + 1
                end
            end
        end
    end
    return nil
end

local function fallback_ranges(bufnr)
    local line_markers, block_pairs = syntax_for(bufnr)
    if #line_markers == 0 and #block_pairs == 0 then
        return {}
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local ranges = {}
    local index = 1

    while index <= #lines do
        local line = lines[index]
        local indent, rest = line:match("^(%s*)(.*)$")
        local row = index - 1

        if row == 0 and rest:sub(1, 2) == "#!" then
            index = index + 1
        else
            local pair = block_start(rest, block_pairs)
            local end_index, end_col

            if pair then
                end_index, end_col = find_block_end(lines, index, #indent, pair)
            end

            if pair and not end_index then
                -- An incomplete block comment is being typed; do not mistake it
                -- for a line comment (Lua's --[[ is the common case).
                index = index + 1
            elseif pair and end_index then
                table.insert(ranges, {
                    start_row = row,
                    start_col = #indent,
                    end_row = end_index - 1,
                    end_col = end_col,
                    kind = "block",
                    pair = pair,
                    full_line = true,
                })
                index = end_index + 1
            else
                local matched_marker
                local punctuation = rest:match("^%p+")
                if punctuation then
                    for _, marker in ipairs(line_markers) do
                        if punctuation:sub(1, #marker) == marker and line_marker_match(rest, marker) then
                            matched_marker = punctuation
                            break
                        end
                    end
                else
                    for _, marker in ipairs(line_markers) do
                        if marker:match("^%a") and line_marker_match(rest, marker) then
                            matched_marker = marker
                            break
                        end
                    end
                end

                if matched_marker then
                    local last_index = index
                    local last_line = line
                    local candidate = index + 1
                    while candidate <= #lines do
                        local next_line = lines[candidate]
                        local next_indent, next_rest = next_line:match("^(%s*)(.*)$")
                        local next_marker = next_rest:match("^%p+") or next_rest:match("^(%a+%.?)")
                        if
                            next_indent ~= indent
                            or next_marker ~= matched_marker
                            or not line_marker_match(next_rest, matched_marker)
                        then
                            break
                        end
                        if block_start(next_rest, block_pairs) then
                            break
                        end
                        last_index = candidate
                        last_line = next_line
                        candidate = candidate + 1
                    end
                    table.insert(ranges, {
                        start_row = row,
                        start_col = #indent,
                        end_row = last_index - 1,
                        end_col = #last_line,
                        kind = "line",
                        marker = matched_marker,
                        full_line = true,
                    })
                    index = last_index + 1
                else
                    local block_column, inline_pair, block_end_column = find_inline_block(line, block_pairs)
                    local inline_position = find_inline_marker(line, line_markers)
                    local line_column = inline_position and (inline_position - 1) or nil

                    if block_column and inline_pair and (not line_column or block_column < line_column) then
                        table.insert(ranges, {
                            start_row = row,
                            start_col = block_column,
                            end_row = row,
                            end_col = block_end_column,
                            kind = "block",
                            pair = inline_pair,
                            full_line = false,
                        })
                    elseif line_column then
                        table.insert(ranges, {
                            start_row = row,
                            start_col = line_column,
                            end_row = row,
                            end_col = #line,
                            kind = "line",
                            marker = nil,
                            full_line = false,
                        })
                    end
                    index = index + 1
                end
            end
        end
    end
    return ranges
end

local function merge_line_ranges(ranges)
    table.sort(ranges, function(left, right)
        if left.start_row ~= right.start_row then
            return left.start_row < right.start_row
        end
        if left.start_col ~= right.start_col then
            return left.start_col < right.start_col
        end
        if left.end_row ~= right.end_row then
            return left.end_row > right.end_row
        end
        return left.end_col > right.end_col
    end)

    local unique = {}
    local seen = {}
    for _, range in ipairs(ranges) do
        local key = range_key(range)
        if not seen[key] then
            seen[key] = true
            table.insert(unique, range)
        end
    end

    local merged = {}
    for _, range in ipairs(unique) do
        local previous = merged[#merged]
        if
            previous
            and previous.kind == "line"
            and range.kind == "line"
            and previous.marker
            and range.marker
            and previous.marker == range.marker
            and previous.full_line
            and range.full_line
            and previous.start_col == range.start_col
            and previous.end_row + 1 == range.start_row
        then
            previous.end_row = range.end_row
            previous.end_col = range.end_col
        else
            table.insert(merged, range)
        end
    end
    return merged
end

local function detect(bufnr)
    if not state.options then
        return {}
    end
    local ranges = tree_ranges(bufnr)
    if not ranges or #ranges == 0 then
        ranges = fallback_ranges(bufnr)
    end
    ranges = merge_line_ranges(ranges)

    local comments = {}
    for _, range in ipairs(ranges) do
        local comment = build_comment(
            bufnr,
            range.start_row,
            range.start_col,
            range.end_row,
            range.end_col,
            { kind = range.kind, marker = range.marker, pair = range.pair }
        )
        if comment then
            table.insert(comments, comment)
        end
    end

    table.sort(comments, function(left, right)
        if left.start_row ~= right.start_row then
            return left.start_row < right.start_row
        end
        return left.start_col < right.start_col
    end)
    return comments
end

function M.detect(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
        return {}
    end
    return detect(bufnr)
end

local function detect_cached(bufnr)
    local tick = vim.api.nvim_buf_get_changedtick(bufnr)
    local filetype = vim.bo[bufnr].filetype
    local commentstring = vim.bo[bufnr].commentstring
    local cached = state.detect_cache[bufnr]
    if
        cached
        and cached.tick == tick
        and cached.filetype == filetype
        and cached.commentstring == commentstring
    then
        return cached.comments
    end
    local comments = detect(bufnr)
    state.detect_cache[bufnr] = {
        tick = tick,
        filetype = filetype,
        commentstring = commentstring,
        comments = comments,
    }
    return comments
end

local function target_language()
    return state.options.comment_translation.target_lang
end

local function target_source_language()
    local source = state.options.comment_translation.source_lang
    local target = target_language():lower()
    if source and source ~= "auto" then
        return source
    end
    if target:match("^en") then
        return "zh"
    elseif target:match("^zh") then
        return "en"
    end
    return "auto"
end

local function is_target_text(text)
    local target = target_language():lower()
    if target:match("^en") then
        return util.has_chinese(text)
    elseif target:match("^zh") then
        return not util.has_chinese(text) and util.has_latin(text)
    end
    return util.has_chinese(text)
end

local function skip_reason(text)
    local options = state.options.comment_translation
    if #text > options.max_chars then
        return "comment is too long"
    end
    local lowered = text:lower()
    for _, pattern in ipairs(options.skip_patterns or {}) do
        local ok, found = pcall(string.find, lowered, pattern)
        if ok and found then
            return "comment contains a tool directive"
        end
    end
    return nil
end

local function candidate(comment)
    if not comment.text or util.trim(comment.text) == "" then
        return false
    end
    if not is_target_text(comment.text) then
        return false
    end
    return skip_reason(comment.text) == nil
end

local function comment_contains(comment, row, column)
    if row < comment.start_row or row > comment.end_row then
        return false
    end
    if row == comment.start_row and column < comment.start_col then
        return false
    end
    if row == comment.end_row and column > comment.end_col then
        return false
    end
    return true
end

local function find_at_cursor(comments, row, column)
    for _, comment in ipairs(comments) do
        if comment_contains(comment, row, column) then
            return comment
        end
    end

    local same_line = {}
    for _, comment in ipairs(comments) do
        if row >= comment.start_row and row <= comment.end_row then
            table.insert(same_line, comment)
        end
    end
    if #same_line == 1 then
        return same_line[1]
    end
    return nil
end

local function collect(bufnr, options)
    options = options or {}
    local comments = detect_cached(bufnr)
    local result = {}

    for _, comment in ipairs(comments) do
        local include = true
        if options.cursor then
            include = find_at_cursor({ comment }, options.cursor.row, options.cursor.column) ~= nil
        end
        if include and options.range then
            include = comment.end_row >= options.range[1] and comment.start_row <= options.range[2]
        end
        if include then
            if options.include_skipped then
                if comment.text and is_target_text(comment.text) then
                    table.insert(result, comment)
                end
            elseif candidate(comment) then
                table.insert(result, comment)
            end
        end
    end
    return result
end

local function selection_range()
    local start_position = vim.fn.getpos("v")
    local end_position = vim.fn.getpos(".")
    local first, last = start_position[2], end_position[2]
    if first > last then
        first, last = last, first
    end
    return { first - 1, last - 1 }
end

local function language_label(code)
    local labels = {
        zh = "Chinese",
        ["zh-CN"] = "Chinese (Simplified)",
        ["zh-TW"] = "Chinese (Traditional)",
        en = "English",
        ja = "Japanese",
        ko = "Korean",
        fr = "French",
        de = "German",
        es = "Spanish",
        ru = "Russian",
    }
    return labels[code] or chat.language_name(code)
end

local function single_prompt(line_count)
    local source_code = target_source_language()
    local source = source_code == "auto" and "the comment's original language" or language_label(source_code)
    local target = language_label(target_language())
    return "You are a precise translator for source-code comments. Translate the natural-language "
        .. "text of one code comment from " .. source .. " into " .. target .. ". "
        .. "Rules: (1) Output only the translated text: no comment markers, no backticks, "
        .. "no code fences, no explanations. "
        .. "(2) The input has " .. line_count .. " line(s). Output exactly " .. line_count
        .. " line(s) of plain text, preserving blank lines. "
        .. "(3) Keep code identifiers, file paths, URLs, inline code, and tags such as TODO, "
        .. "FIXME, NOTE, @param, @return, @throws, :param and :return unchanged. "
        .. "(4) Use concise, natural language appropriate for a code comment. Do not add new information."
end

local function batch_prompt(block_count, delimiter)
    local source_code = target_source_language()
    local source = source_code == "auto" and "their original language" or language_label(source_code)
    local target = language_label(target_language())
    return "You translate source-code comments. The user message contains " .. block_count
        .. " separate comment blocks separated by a line that is exactly: " .. delimiter .. "\n"
        .. "Translate each block from " .. source .. " into " .. target .. ". Rules: "
        .. "(1) Output exactly " .. block_count
        .. " blocks in the same order, separated by a line that is exactly " .. delimiter
        .. ", with no other text. "
        .. "(2) Inside each block preserve the original number of lines and blank lines. "
        .. "(3) Output only translated text: no comment markers, no code fences, no explanations. "
        .. "(4) Keep code identifiers, file paths, URLs, inline code, and tags such as TODO, "
        .. "FIXME, NOTE, @param, @return, @throws, :param and :return unchanged."
end

local function split_translation(translation)
    local text = translation:gsub("\r\n", "\n"):gsub("\r", "\n")
    text = text:gsub("^%s*```[%w_%-%+%.]*%s*\n", "")
    text = text:gsub("\n```%s*$", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return {}
    end
    local lines = vim.split(text, "\n", { plain = true, trimempty = false })
    for index, line in ipairs(lines) do
        lines[index] = util.trim(line)
    end
    return lines
end

local function sanitize_line(line, comment)
    line = util.trim(line)
    if line == "" then
        return ""
    end

    line = line:gsub("^`(.-)`$", "%1")
    if comment.kind == "line" and comment.marker and comment.marker ~= "" then
        local marker_pattern = util.escape_pattern(comment.marker)
        if comment.marker:match("^%a") then
            line = line:gsub("^" .. marker_pattern .. "%s+", "")
        else
            line = line:gsub("^" .. marker_pattern .. "%s?", "")
        end
    elseif comment.kind == "block" then
        if comment.open_prefix then
            line = line:gsub("^" .. util.escape_pattern(comment.open_prefix), "")
        end
        line = line:gsub("^%*%s?", "")
        if comment.close_suffix and comment.close_suffix ~= "" then
            line = line:gsub("%s?" .. util.escape_pattern(comment.close_suffix) .. "$", "")
        end
    end
    return util.trim(line)
end

local function collapse_text(comment, lines)
    local joined = util.trim(table.concat(lines, " "))
    if joined == "" then
        return nil
    end

    if comment.kind == "line" then
        local gutter = comment.gutter or ""
        if gutter ~= "" and not gutter:match("%s$") then
            gutter = gutter .. " "
        end
        return gutter .. joined
    end

    local prefix = comment.open_prefix or ""
    local suffix = comment.close_suffix or ""
    if prefix ~= "" and not prefix:match("%s$") then
        prefix = prefix .. " "
    end
    if suffix ~= "" and not suffix:match("^%s") then
        suffix = " " .. suffix
    end
    return prefix .. joined .. suffix
end

local function apply_comment(comment, translation, break_undo, join_undo)
    local lines = split_translation(translation)
    for index, line in ipairs(lines) do
        lines[index] = sanitize_line(line, comment)
    end
    while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
    end
    while #lines > 0 and lines[1] == "" do
        table.remove(lines, 1)
    end
    if #lines == 0 then
        return false, "empty translation"
    end

    local normalized_source = util.normalize_block(comment.text)
    local normalized_translation = util.normalize_block(table.concat(lines, "\n"))
    if normalized_source == normalized_translation then
        return false, "translation is identical to the source"
    end

    local bufnr = comment.bufnr
    if break_undo then
        -- Setting 'undolevels' (even to the same value) closes the current
        -- undo block, so one `u` reverts only the translation instead of the
        -- user's previous typing.  Do this only when an edit is guaranteed.
        local undo_levels = vim.bo[bufnr].undolevels
        pcall(function()
            vim.bo[bufnr].undolevels = undo_levels
        end)
    elseif join_undo then
        -- A batch is one undo step: join this comment to the previous one.
        pcall(vim.cmd, "undojoin")
    end

    local core = comment.spans
    if #lines == #core then
        local first_edit = true
        for index = #core, 1, -1 do
            if not first_edit then
                pcall(vim.cmd, "undojoin")
            end
            first_edit = false
            local span = core[index]
            vim.api.nvim_buf_set_text(bufnr, span.row, span.start_col, span.row, span.end_col, { lines[index] })
        end
    else
        local collapsed = collapse_text(comment, lines)
        if not collapsed then
            return false, "empty translation"
        end
        vim.api.nvim_buf_set_text(
            bufnr,
            comment.start_row,
            comment.start_col,
            comment.end_row,
            comment.end_col,
            { collapsed }
        )
    end
    return true
end

local function report_error(message)
    local options = state.options.comment_translation
    if options.notify == "never" then
        return
    end
    notify("comment translation failed: " .. tostring(message), vim.log.levels.WARN)
end

local function report_success(count)
    if state.options.comment_translation.notify == "always" and count > 0 then
        notify(string.format("translated %d comment(s)", count), vim.log.levels.INFO)
    end
end

local function restore_cursor(bufnr, mark, at_line_end, window)
    if not mark or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    local ok, position = pcall(vim.api.nvim_buf_get_extmark_by_id, bufnr, apply_namespace, mark, {})
    if ok and position and position[1] then
        if
            window
            and vim.api.nvim_win_is_valid(window)
            and vim.api.nvim_win_get_buf(window) == bufnr
        then
            local line = vim.api.nvim_buf_get_lines(bufnr, position[1], position[1] + 1, false)[1] or ""
            local column = at_line_end and #line or math.min(position[2], #line)
            pcall(vim.api.nvim_win_set_cursor, window, { position[1] + 1, column })
        end
    end
    pcall(vim.api.nvim_buf_del_extmark, bufnr, apply_namespace, mark)
end

local function translate_one(item, options, results, errors, callback)
    local prompt = single_prompt(#item.comment.spans)
    engine.request(item.comment.text, options, {
        flavor = "comment:v1",
        prompt = prompt,
        channel = "comment:" .. item.comment.bufnr,
        cancel_previous = false,
        stream = false,
    }, function(response, request_error)
        if request_error then
            table.insert(errors, request_error)
        elseif type(response) == "table" and type(response.translation) == "string" then
            local lines = split_translation(response.translation)
            if #lines == 0 then
                table.insert(errors, "empty translation")
            else
                results[item.index] = response.translation
            end
        else
            table.insert(errors, "empty translation")
        end
        callback()
    end)
end

local function choose_delimiter(items)
    local delimiter = M.DELIMITER
    for _, item in ipairs(items) do
        if item.comment.text:find(delimiter, 1, true) then
            delimiter = "@@MAGPIE_" .. util.hash_hex(table.concat({ item.comment.text, tostring(#items) }, "\n")) .. "@@"
            break
        end
    end
    return delimiter
end

local function make_batches(items)
    local options = state.options.comment_translation
    local batches, current = {}, {}
    local size = 0
    local limit = math.max(2000, options.max_chars * 2)
    for _, item in ipairs(items) do
        local item_size = #item.comment.text
        if #current > 0 and (#current >= options.max_batch or size + item_size > limit) then
            table.insert(batches, current)
            current = {}
            size = 0
        end
        table.insert(current, item)
        size = size + item_size
    end
    if #current > 0 then
        table.insert(batches, current)
    end
    return batches
end

local function translate_batch(chunk, options, results, errors, callback)
    local delimiter = choose_delimiter(chunk)
    local parts = {}
    for _, item in ipairs(chunk) do
        table.insert(parts, item.comment.text)
    end
    local batch_text = table.concat(parts, "\n" .. delimiter .. "\n")
    local prompt = batch_prompt(#chunk, delimiter)

    engine.request(batch_text, options, {
        flavor = "comment:v1",
        prompt = prompt,
        channel = "comment-batch:" .. chunk[1].comment.bufnr,
        cancel_previous = false,
        stream = false,
        cache = false,
    }, function(response, request_error)
        local translated = type(response) == "table" and response.translation or nil
        local split = translated and vim.split(translated, delimiter, { plain = true }) or {}
        if request_error or #split ~= #chunk then
            -- Fall back to individual requests.  Do not record the batch error
            -- yet: a successful per-comment retry should not surface a warning.
            local index = 1
            local function next_item()
                if index > #chunk then
                    callback()
                    return
                end
                local item = chunk[index]
                index = index + 1
                translate_one(item, options, results, errors, next_item)
            end
            next_item()
            return
        end

        for index, item in ipairs(chunk) do
            local translation = split[index]
            if type(translation) == "string" and util.trim(translation) ~= "" then
                results[item.index] = translation
                engine.remember(item.comment.text, options, "comment:v1", {
                    translation = translation,
                    detected_source_lang = options.source_lang,
                })
            else
                table.insert(errors, "empty translation in batch")
            end
        end
        callback()
    end)
end

function M._translate(comments, context)
    context = context or {}
    if #comments == 0 then
        return
    end
    local ct = state.options.comment_translation
    local bufnr = comments[1].bufnr
    local tick = vim.api.nvim_buf_get_changedtick(bufnr)
    local options = vim.tbl_deep_extend("force", {}, state.options, {
        source_lang = target_source_language(),
        target_lang = ct.target_lang,
    })

    local results, errors, pending = {}, {}, {}
    for index, comment in ipairs(comments) do
        local cached = engine.get(comment.text, options, "comment:v1")
        if cached and type(cached.translation) == "string" and util.trim(cached.translation) ~= "" then
            results[index] = cached.translation
        else
            table.insert(pending, { index = index, comment = comment })
        end
    end

    local current_window = vim.api.nvim_get_current_win()
    local cursor_mark
    local at_line_end = false
    if vim.api.nvim_get_current_buf() == bufnr and vim.api.nvim_win_is_valid(current_window) then
        local cursor = vim.api.nvim_win_get_cursor(current_window)
        local mark_row, mark_column = cursor[1] - 1, cursor[2]
        local gravity = false
        if context.origin == "auto" and #comments == 1 then
            local comment = comments[1]
            if comment_contains(comment, mark_row, mark_column) then
                mark_row = comment.end_row
                mark_column = comment.end_col
                gravity = true
                at_line_end = true
            end
        end
        local line = vim.api.nvim_buf_get_lines(bufnr, mark_row, mark_row + 1, false)[1] or ""
        mark_column = math.min(mark_column, #line)
        cursor_mark = vim.api.nvim_buf_set_extmark(bufnr, apply_namespace, mark_row, mark_column, {
            right_gravity = gravity,
        })
    end

    local finished = false
    local function finish()
        if finished then
            return
        end
        finished = true
        if not vim.api.nvim_buf_is_valid(bufnr) then
            return
        end
        if vim.api.nvim_buf_get_changedtick(bufnr) ~= tick then
            if context.origin ~= "auto" then
                report_error("the buffer changed while translating")
            end
            restore_cursor(bufnr, cursor_mark, at_line_end, current_window)
            return
        end
        if not state.options or not state.options.comment_translation.enabled then
            restore_cursor(bufnr, cursor_mark, at_line_end, current_window)
            return
        end

        local last_write = state.last_write[bufnr]
        local write_race = not vim.bo[bufnr].modified
            and last_write ~= nil
            and last_write.tick == tick
            and (vim.uv.hrtime() - last_write.time) < 30 * 1000000000

        local applied = 0
        for index = #comments, 1, -1 do
            local translation = results[index]
            if translation then
                local ok, success, reason = pcall(
                    apply_comment,
                    comments[index],
                    translation,
                    applied == 0,
                    applied > 0
                )
                if not ok then
                    table.insert(errors, "failed to apply translation")
                elseif success then
                    applied = applied + 1
                elseif reason ~= "translation is identical to the source" then
                    table.insert(errors, reason or "could not apply translation")
                end
            end
        end

        restore_cursor(bufnr, cursor_mark, at_line_end, current_window)
        if applied > 0 and write_race and ct.notify ~= "never" then
            notify("comment translated after the last write; write the buffer again to save it", vim.log.levels.WARN)
        end
        if #errors > 0 then
            report_error(errors[1])
        end
        report_success(applied)
    end

    if #pending == 0 then
        finish()
        return
    end
    if #pending == 1 then
        translate_one(pending[1], options, results, errors, finish)
        return
    end

    local batches = make_batches(pending)
    local batch_index = 1
    local function next_batch()
        if batch_index > #batches then
            finish()
            return
        end
        local batch = batches[batch_index]
        batch_index = batch_index + 1
        translate_batch(batch, options, results, errors, next_batch)
    end
    next_batch()
end

function M.eligible(bufnr, options)
    options = options or {}
    local ct = state.options and state.options.comment_translation
    if not ct then
        return false
    end
    if not ct.enabled and not options.ignore_enabled then
        return false
    end
    if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
        return false
    end
    if vim.bo[bufnr].buftype ~= "" or not vim.bo[bufnr].modifiable or vim.bo[bufnr].binary then
        return false
    end

    local filetype = vim.bo[bufnr].filetype
    if filetype ~= "" then
        for _, excluded in ipairs(ct.exclude_filetypes or {}) do
            if filetype == excluded then
                return false
            end
        end
    end
    if ct.filetypes and #ct.filetypes > 0 then
        if filetype == "" then
            return false
        end
        for _, allowed in ipairs(ct.filetypes) do
            if filetype == allowed then
                return true
            end
        end
        return false
    end
    return true
end

function M.auto_enabled()
    local ct = state.options and state.options.comment_translation
    return ct ~= nil and ct.enabled and ct.mode == "auto"
end

function M.mode()
    local ct = state.options and state.options.comment_translation
    if not ct or not ct.enabled then
        return "off"
    end
    return ct.mode
end

local function clear_insert_marks(bufnr)
    local marks = state.insert_marks[bufnr]
    if not marks then
        return
    end
    for _, mark in ipairs(marks.ids) do
        pcall(vim.api.nvim_buf_del_extmark, bufnr, insert_namespace, mark)
    end
    state.insert_marks[bufnr] = nil
end

local function take_insert_rows(bufnr)
    local marks = state.insert_marks[bufnr]
    local rows = {}
    if not marks then
        return rows
    end
    for _, mark in ipairs(marks.ids) do
        local ok, position = pcall(vim.api.nvim_buf_get_extmark_by_id, bufnr, insert_namespace, mark, {})
        if ok and position and position[1] then
            rows[position[1]] = true
        end
        pcall(vim.api.nvim_buf_del_extmark, bufnr, insert_namespace, mark)
    end
    state.insert_marks[bufnr] = nil
    return rows
end

local function register_autocmds()
    if state.augroup then
        pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
    end
    state.augroup = vim.api.nvim_create_augroup("MagpieCommentTranslation", { clear = true })
    if not state.options or not state.options.comment_translation.enabled then
        for bufnr in pairs(state.insert_marks) do
            clear_insert_marks(bufnr)
        end
        return
    end

    vim.api.nvim_create_autocmd("BufWipeout", {
        group = state.augroup,
        callback = function(args)
            state.tokens[args.buf] = nil
            state.detect_cache[args.buf] = nil
            state.last_write[args.buf] = nil
            clear_insert_marks(args.buf)
        end,
    })
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = state.augroup,
        callback = function(args)
            if not vim.api.nvim_buf_is_valid(args.buf) then
                return
            end
            state.last_write[args.buf] = {
                tick = vim.api.nvim_buf_get_changedtick(args.buf),
                time = vim.uv.hrtime(),
            }
        end,
    })

    if not M.auto_enabled() then
        for bufnr in pairs(state.insert_marks) do
            clear_insert_marks(bufnr)
        end
        return
    end

    vim.api.nvim_create_autocmd("InsertEnter", {
        group = state.augroup,
        callback = function()
            M._on_insert_enter()
        end,
    })
    vim.api.nvim_create_autocmd("InsertLeave", {
        group = state.augroup,
        callback = function()
            M._on_insert_leave()
        end,
    })
    vim.api.nvim_create_autocmd("TextChangedI", {
        group = state.augroup,
        callback = function()
            M._on_text_changed_i()
        end,
    })
end

function M.setup(options)
    for bufnr in pairs(state.insert_marks) do
        clear_insert_marks(bufnr)
    end
    state.options = options
    state.tokens = {}
    state.detect_cache = {}
    state.last_write = {}
    register_autocmds()
end

function M.set_mode(mode)
    if not state.options then
        return "off"
    end
    local ct = state.options.comment_translation
    mode = util.trim(tostring(mode or "")):lower()

    if mode == "" then
        local label = ct.enabled and ct.mode or "off"
        notify("comment translation mode: " .. label .. " (target: " .. ct.target_lang .. ")")
        return label
    end
    if mode == "toggle" then
        mode = (ct.enabled and ct.mode == "auto") and "manual" or "auto"
    end
    if mode ~= "auto" and mode ~= "manual" and mode ~= "off" then
        notify("unknown comment mode: " .. mode .. " (use auto, manual, toggle or off)", vim.log.levels.ERROR)
        return M.mode()
    end

    -- Changing modes invalidates any debounce timers from the old mode.
    for bufnr, token in pairs(state.tokens) do
        state.tokens[bufnr] = token + 1
    end

    if mode == "off" then
        ct.enabled = false
        register_autocmds()
        notify("comment translation disabled")
        return "off"
    end
    ct.enabled = true
    ct.mode = mode
    register_autocmds()
    notify("comment translation mode: " .. mode)
    return mode
end

function M._on_insert_enter()
    local bufnr = vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    -- Invalidate a debounce timer from the previous insert session and start
    -- tracking the rows touched in this one.
    state.tokens[bufnr] = (state.tokens[bufnr] or 0) + 1
    clear_insert_marks(bufnr)
end

function M._on_text_changed_i()
    if not M.auto_enabled() then
        return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    if not M.eligible(bufnr) then
        return
    end
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local marks = state.insert_marks[bufnr]
    if not marks then
        marks = { ids = {}, rows = {} }
        state.insert_marks[bufnr] = marks
    end
    if marks.rows[row] then
        return
    end
    local ok, mark = pcall(vim.api.nvim_buf_set_extmark, bufnr, insert_namespace, row, 0, {
        right_gravity = true,
    })
    if ok and mark then
        marks.rows[row] = true
        table.insert(marks.ids, mark)
    end
end

function M._on_insert_leave()
    if not M.auto_enabled() then
        return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    if not M.eligible(bufnr) then
        return
    end

    local rows = take_insert_rows(bufnr)
    if vim.api.nvim_win_is_valid(0) and vim.api.nvim_win_get_buf(0) == bufnr then
        local cursor = vim.api.nvim_win_get_cursor(0)
        rows[cursor[1] - 1] = true
    end

    local token = (state.tokens[bufnr] or 0) + 1
    state.tokens[bufnr] = token
    local tick = vim.api.nvim_buf_get_changedtick(bufnr)
    local delay = math.max(0, state.options.comment_translation.debounce_ms)
    vim.defer_fn(function()
        if state.tokens[bufnr] ~= token or not M.auto_enabled() then
            return
        end
        if not vim.api.nvim_buf_is_valid(bufnr) then
            return
        end
        if vim.api.nvim_get_current_buf() ~= bufnr then
            return
        end
        if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
            return
        end
        if vim.api.nvim_buf_get_changedtick(bufnr) ~= tick then
            return
        end
        M._auto_translate_now(bufnr, rows)
    end, delay)
end

function M._auto_translate_now(bufnr, rows)
    if not M.auto_enabled() or not M.eligible(bufnr) then
        return
    end
    local window = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_buf(window) ~= bufnr then
        return
    end

    local comments = detect_cached(bufnr)
    local selected = {}
    if rows and next(rows) then
        for _, comment in ipairs(comments) do
            local touched = false
            for row = comment.start_row, comment.end_row do
                if rows[row] then
                    touched = true
                    break
                end
            end
            if touched and candidate(comment) then
                table.insert(selected, comment)
            end
        end
    else
        local cursor = vim.api.nvim_win_get_cursor(window)
        local comment = find_at_cursor(comments, cursor[1] - 1, cursor[2])
        if comment and candidate(comment) then
            table.insert(selected, comment)
        end
    end

    if #selected == 0 then
        return
    end
    M._translate(selected, { origin = "auto" })
end

local function no_comment_message()
    local target = target_language():lower()
    if target:match("^en") then
        return "no Chinese comment to translate"
    elseif target:match("^zh") then
        return "no English comment to translate"
    end
    return "no comment to translate"
end

function M.translate_at_cursor(context)
    context = context or {}
    local ct = state.options and state.options.comment_translation
    if not ct or not ct.enabled then
        notify("comment translation is disabled", vim.log.levels.WARN)
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    if not M.eligible(bufnr) then
        notify("comment translation is not enabled for this buffer", vim.log.levels.WARN)
        return
    end

    local comments
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
        local range = selection_range()
        vim.cmd("normal! <Esc>")
        comments = collect(bufnr, { range = range })
    elseif context.range then
        comments = collect(bufnr, { range = context.range })
    else
        local cursor = vim.api.nvim_win_get_cursor(0)
        comments = collect(bufnr, { cursor = { row = cursor[1] - 1, column = cursor[2] } })
    end

    if #comments == 0 then
        notify(no_comment_message(), vim.log.levels.WARN)
        return
    end
    M._translate(comments, { origin = context.origin or "manual" })
end

function M.translate_buffer()
    local ct = state.options and state.options.comment_translation
    if not ct or not ct.enabled then
        notify("comment translation is disabled", vim.log.levels.WARN)
        return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    if not M.eligible(bufnr) then
        notify("comment translation is not enabled for this buffer", vim.log.levels.WARN)
        return
    end

    local comments = collect(bufnr, {})
    if #comments == 0 then
        notify(no_comment_message(), vim.log.levels.WARN)
        return
    end
    M._translate(comments, { origin = "buffer" })
end

function M.check(options)
    options = options or {}
    local bufnr = vim.api.nvim_get_current_buf()
    if not state.options or not M.eligible(bufnr, { ignore_enabled = true }) then
        notify("comment checking is not available for this buffer", vim.log.levels.WARN)
        return 0
    end

    local comments = collect(bufnr, { include_skipped = true })
    local items = {}
    for _, comment in ipairs(comments) do
        local reason = skip_reason(comment.text)
        local summary = util.trim((comment.text:gsub("\n", " ")))
        if vim.fn.strchars(summary) > 100 then
            summary = vim.fn.strcharpart(summary, 0, 100) .. "…"
        end
        table.insert(items, {
            bufnr = bufnr,
            lnum = comment.start_row + 1,
            col = comment.start_col + 1,
            text = reason and ("[skip: " .. reason .. "] " .. summary) or summary,
            type = "I",
        })
    end

    vim.fn.setqflist({}, " ", { title = "Magpie comments", items = items })
    if #items == 0 then
        notify("no comments found in this buffer", vim.log.levels.INFO)
    else
        notify(string.format("%d comment(s) found", #items), vim.log.levels.INFO)
        if options.open ~= false then
            pcall(vim.cmd, "copen")
        end
    end
    return #items
end

function M._prompt(line_count)
    return single_prompt(line_count)
end

function M._batch_prompt(block_count, delimiter)
    return batch_prompt(block_count, delimiter)
end

return M
