vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.swapfile = false
vim.cmd("runtime plugin/magpie.lua")
assert(vim.fn.exists(":Magpie") == 2, "Magpie command should be registered")

local function assert_equal(expected, actual, message)
  if expected ~= actual then
    error(message or string.format("expected %s, got %s", vim.inspect(expected), vim.inspect(actual)))
  end
end

local selection = require("magpie.selection")
local buffer = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "A hello-world example" })
vim.api.nvim_win_set_cursor(0, { 1, 3 })
assert_equal("hello-world", selection.word_under_cursor(), "cursor word should include hyphens")
assert_equal("example", selection.word_at_position(0, 0, 15), "position word should be found")
assert_equal(nil, selection.word_at_position(0, 0, 1), "spaces are not words")

local original_system = vim.system

local chatgpt = require("magpie.providers.chatgpt")
local chatgpt_result
vim.system = function(_, _, callback)
  callback({
    code = 0,
    stdout = '{"choices":[{"message":{"content":"你好"}}]}',
    stderr = "",
  })
  return {}
end
chatgpt.translate("hello", {
  source_lang = "auto",
  target_lang = "zh-CN",
  chatgpt = { endpoint = "https://example.test", model = "gpt-4o-mini", api_key = "test-key", timeout_ms = 1000 },
}, function(result, err)
  assert_equal(nil, err)
  chatgpt_result = result
end)
assert(vim.wait(1000, function()
  return chatgpt_result ~= nil
end), "ChatGPT callback timed out")
assert_equal("你好", chatgpt_result.translation)

local copilot = require("magpie.providers.copilot")
local copilot_result
copilot.translate("hello", {
  source_lang = "auto",
  target_lang = "zh-CN",
  copilot = { endpoint = "https://example.test", model = "gpt-4o", api_key = "test-key", timeout_ms = 1000 },
}, function(result, err)
  assert_equal(nil, err)
  copilot_result = result
end)
assert(vim.wait(1000, function()
  return copilot_result ~= nil
end), "Copilot callback timed out")
assert_equal("你好", copilot_result.translation)

local gemini = require("magpie.providers.gemini")
local gemini_result
vim.system = function(_, _, callback)
  callback({
    code = 0,
    stdout = '{"candidates":[{"content":{"parts":[{"text":"你好"}]}}]}',
    stderr = "",
  })
  return {}
end
gemini.translate("hello", {
  source_lang = "auto",
  target_lang = "zh-CN",
  gemini = { endpoint = "https://example.test", model = "gemini-2.5-flash", api_key = "test-key", timeout_ms = 1000 },
}, function(result, err)
  assert_equal(nil, err)
  gemini_result = result
end)
assert(vim.wait(1000, function()
  return gemini_result ~= nil
end), "Gemini callback timed out")
assert_equal("你好", gemini_result.translation)

local deepseek = require("magpie.providers.deepseek")
local deepseek_result
vim.system = function(_, _, callback)
  callback({
    code = 0,
    stdout = '{"choices":[{"message":{"content":"你好"}}]}',
    stderr = "",
  })
  return {}
end
deepseek.translate("hello", {
  source_lang = "auto",
  target_lang = "zh-CN",
  deepseek = { api_key = "test-key", timeout_ms = 1000 },
}, function(result, err)
  assert_equal(nil, err)
  deepseek_result = result
end)
assert(vim.wait(1000, function()
  return deepseek_result ~= nil
end), "DeepSeek callback timed out")
assert_equal("你好", deepseek_result.translation)

local youdao = require("magpie.providers.youdao")
local youdao_result
vim.system = function(_, _, callback)
  callback({
    code = 0,
    stdout = '{"errorCode":"0","translation":["你好"],"l":"en2zh-CHS"}',
    stderr = "",
  })
  return {}
end
youdao.translate("hello", {
  source_lang = "auto",
  target_lang = "zh-CN",
  youdao = { endpoint = "https://example.test", app_key = "test-key", app_secret = "test-secret", timeout_ms = 1000 },
}, function(result, err)
  assert_equal(nil, err)
  youdao_result = result
end)
assert(vim.wait(1000, function()
  return youdao_result ~= nil
end), "Youdao callback timed out")
assert_equal("你好", youdao_result.translation)
assert_equal("en", youdao_result.detected_source_lang)

local config_module = require("magpie.config")
local built, build_error = pcall(config_module.build, { hover = { delay_ms = -1 } })
assert_equal(false, built, "negative hover.delay_ms should be rejected")
assert(type(build_error) == "string" and build_error:match("hover.delay_ms") ~= nil, "error should name the invalid option")
assert_equal("youdao", config_module.build({ provider = "youdao" }).provider, "youdao provider should be accepted")

local ui = require("magpie.ui")
local options = require("magpie.config").build({
  hover = { enabled = false },
  mouse_selection = { enabled = false },
})
ui.show_result({ text = "hello", phonetic = "/həˈləʊ/", translation = "你好" }, nil, options)
assert(ui.is_open(), "result should be displayed in a floating window")
ui.show_result({ text = "hello", phonetic = "/həˈləʊ/", translation = "你好" }, {
  window = 0,
  row = 0,
  column = 0,
}, options)
assert(ui.is_open(), "result should update to a buffer-relative floating window")
ui.close()
assert(not ui.is_open(), "floating window should close")

local translate = require("magpie")
vim.system = function(_, _, callback)
  callback({
    code = 0,
    stdout = '{"choices":[{"message":{"content":"你好"}}]}',
    stderr = "",
  })
  return {}
end
translate.setup({
  hover = { enabled = false },
  mouse_selection = { enabled = false },
  dictionary = { enabled = false },
  local_dictionary = { enabled = false },
  cache = { persist = false },
  stream = { enabled = false },
  chatgpt = { api_key = "test-key" },
})
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "hello world" })
vim.cmd("normal! 0v4l")
translate.translate_visual()
assert_equal("n", vim.fn.mode(), "Visual translation should leave Visual mode")
assert(vim.wait(1000, function()
  return ui.is_open()
end), "Visual translation should open a result window")
translate.close()

vim.system = original_system
local util_module = require("magpie.util")
assert_equal("hello world", util_module.normalize_text("  hello   world  "), "normalize_text should trim and collapse whitespace")

local dict_module = require("magpie.dict")
assert(dict_module.size() >= 1000, "local dictionary should bundle at least 1000 words")
local hello_entry = dict_module.lookup("hello")
assert(hello_entry and hello_entry.zh ~= "", "hello should be in the local dictionary")
assert(hello_entry.ipa and hello_entry.ipa:match("^/") ~= nil, "hello should carry IPA")
assert(dict_module.lookup("python") and dict_module.lookup("python").zh ~= "", "python should be in the local dictionary")
assert(dict_module.lookup("git") and dict_module.lookup("git").zh ~= "", "git should be in the local dictionary")
assert(dict_module.lookup("c++") and dict_module.lookup("c++").zh ~= "", "c++ should be in the local dictionary")

-- Offline local-dictionary lookup must never touch the network.
vim.system = function()
  error("network must not be used for local dictionary hits")
end
ui.close()
translate.setup({
  hover = { enabled = false },
  mouse_selection = { enabled = false },
  local_dictionary = { enabled = true },
  cache = { persist = false },
})
translate.translate("hello", {})
assert(ui.is_open(), "local dictionary hit should open a result window")
assert(translate.last_result and translate.last_result.translation ~= "" and translate.last_result.translation ~= "hello", "local hit should fill a translation")

-- User dictionary entries override the bundled dictionary.
local user_file = vim.fn.tempname()
vim.fn.writefile({ "neovimtest\t测试词条" }, user_file)
translate.setup({
  hover = { enabled = false },
  mouse_selection = { enabled = false },
  local_dictionary = { enabled = true, user_file = user_file },
  cache = { persist = false },
})
ui.close()
translate.translate("neovimtest", {})
assert(translate.last_result and translate.last_result.translation == "测试词条", "user dictionary entries should be honored")

-- In-flight dedup: the same text translated twice while the first request
-- is pending must spawn only one process.
local system_calls = 0
local pending_system_callback
vim.system = function(_, _, callback)
  system_calls = system_calls + 1
  pending_system_callback = callback
  return { kill = function() end }
end
translate.setup({
  hover = { enabled = false },
  mouse_selection = { enabled = false },
  dictionary = { enabled = false },
  local_dictionary = { enabled = false },
  cache = { persist = false },
  stream = { enabled = false },
  chatgpt = { api_key = "test-key" },
})
ui.close()
translate.translate("dedup target", {})
translate.translate("dedup target", {})
assert_equal(1, system_calls, "second identical trigger should join the in-flight request")
local previous_result = translate.last_result
pending_system_callback({
  code = 0,
  stdout = '{"choices":[{"message":{"content":"去重"}}]}',
  stderr = "",
})
assert(vim.wait(1000, function()
  return translate.last_result ~= previous_result
end), "joined request should deliver the result")
assert_equal("去重", translate.last_result.translation)

-- Starting a new translation for different text kills the stale request.
local killed = 0
vim.system = function(_, _, _)
  system_calls = system_calls + 1
  return { kill = function() killed = killed + 1 end }
end
translate.translate("first target", {})
translate.translate("second target", {})
assert_equal(1, killed, "the stale in-flight request should be killed")

-- Streaming: LLM providers emit chunks that are rendered progressively.
vim.system = function(_, opts, cb)
  opts.stdout(nil, 'data: {"choices":[{"delta":{"content":"你"}}]}\n\n')
  opts.stdout(nil, 'data: {"choices":[{"delta":{"content":"好"}}]}\n\n')
  opts.stdout(nil, "data: [DONE]\n\n")
  cb({ code = 0, stderr = "" })
  return { kill = function() end }
end
translate.setup({
  hover = { enabled = false },
  mouse_selection = { enabled = false },
  dictionary = { enabled = false },
  local_dictionary = { enabled = false },
  cache = { persist = false },
  stream = { enabled = true },
  chatgpt = { api_key = "test-key" },
})
ui.close()
translate.last_result = nil
translate.translate("stream target", {})
assert(vim.wait(1000, function()
  return translate.last_result ~= nil and translate.last_result.translation == "你好"
end), "streaming request should deliver the accumulated translation")

-- ===========================================================================
-- v0.3: comment translation
-- ===========================================================================
local comments = require("magpie.comments")

local function comment_options(overrides)
  local comment_translation = {
    enabled = true,
    mode = "manual",
    use_treesitter = false,
    debounce_ms = 0,
  }
  for key, value in pairs(overrides or {}) do
    comment_translation[key] = value
  end
  return {
    provider = "chatgpt",
    hover = { enabled = false },
    mouse_selection = { enabled = false },
    dictionary = { enabled = false },
    local_dictionary = { enabled = false },
    cache = { persist = false },
    stream = { enabled = false },
    chatgpt = { api_key = "test-key" },
    keymaps = { normal = false, visual = false, comment = false, comments = false },
    comment_translation = comment_translation,
  }
end

local function new_comment_buffer(filetype, lines)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].filetype = filetype
  if filetype == "lua" then
    vim.bo[buf].commentstring = "-- %s"
  elseif filetype == "c" then
    vim.bo[buf].commentstring = "// %s"
  elseif filetype == "html" then
    vim.bo[buf].commentstring = "<!-- %s -->"
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(buf)
  return buf
end

local function mock_translation(content)
  local calls = { count = 0 }
  vim.system = function(_, opts, callback)
    if type(opts) == "function" then
      callback = opts
    end
    calls.count = calls.count + 1
    local text = type(content) == "function" and content(calls.count) or content
    callback({
      code = 0,
      stdout = vim.json.encode({ choices = { { message = { content = text } } } }),
      stderr = "",
    })
    return { kill = function() end }
  end
  return calls
end

local function lines_of(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function wait_for(predicate, message)
  assert(vim.wait(2000, predicate, 20), message or "timed out waiting for condition")
end

-- util helpers
util_module = util_module or require("magpie.util")
assert(util_module.has_chinese("中文注释"), "has_chinese should detect Han characters")
assert(not util_module.has_chinese("plain English"), "has_chinese should ignore Latin text")
assert(not util_module.has_chinese("こんにちは"), "has_chinese should not classify Kana as Chinese")
assert_equal("first\nsecond", util_module.normalize_block(" first \n  second  "), "normalize_block should keep line structure")

-- config validation and list replacement
local comment_config_module = require("magpie.config")
local bad_mode_ok = pcall(comment_config_module.build, { comment_translation = { mode = "sometimes" } })
assert_equal(false, bad_mode_ok, "invalid comment_translation.mode should be rejected")
local bad_batch_ok, bad_batch_error = pcall(comment_config_module.build, { comment_translation = { max_batch = 0 } })
assert_equal(false, bad_batch_ok, "max_batch below 1 should be rejected")
assert(
  type(bad_batch_error) == "string" and bad_batch_error:match("max_batch") ~= nil,
  "the validation error should name max_batch"
)
local custom_lists = comment_config_module.build({
  comment_translation = { exclude_filetypes = { "lua" }, skip_patterns = { "magic" } },
})
assert_equal(1, #custom_lists.comment_translation.exclude_filetypes, "exclude_filetypes should replace the default list")
assert_equal("lua", custom_lists.comment_translation.exclude_filetypes[1])
assert_equal(1, #custom_lists.comment_translation.skip_patterns, "skip_patterns should replace the default list")

-- custom provider prompt
local prompt_body
vim.system = function(args, opts, callback)
  if type(opts) == "function" then
    callback = opts
  end
  for index, value in ipairs(args) do
    if value == "-d" then
      prompt_body = vim.json.decode(args[index + 1])
    end
  end
  callback({
    code = 0,
    stdout = '{"choices":[{"message":{"content":"ok"}}]}',
    stderr = "",
  })
  return { kill = function() end }
end
local chatgpt_provider = require("magpie.providers.chatgpt")
local prompt_done = false
chatgpt_provider.translate("hello", {
  source_lang = "zh",
  target_lang = "en",
  chatgpt = { endpoint = "https://example.test", model = "test", api_key = "test-key", timeout_ms = 1000 },
}, function(_, err)
  assert_equal(nil, err)
  prompt_done = true
end, "CUSTOM COMMENT PROMPT")
wait_for(function()
  return prompt_done
end, "custom prompt request timed out")
assert_equal("CUSTOM COMMENT PROMPT", prompt_body.messages[1].content, "the provider should receive the custom prompt")

-- fallback comment detection (all common styles)
translate.setup(comment_options())
local c_buffer = new_comment_buffer("c", {
  "// 行注释",
  "int x = 1; // 行尾",
  "/* 块注释 */",
  "/*",
  " * 多行一",
  " * 多行二",
  " */",
  "#include <stdio.h>",
})
local detected = comments.detect(c_buffer)
assert_equal(4, #detected, "C detection should find four comments")
local detected_texts = {}
for _, comment in ipairs(detected) do
  detected_texts[comment.text] = comment
end
assert(detected_texts["行注释"] and detected_texts["行注释"].kind == "line", "line comment should be detected")
assert(detected_texts["行尾"] and detected_texts["行尾"].kind == "line", "inline line comment should be detected")
assert(detected_texts["块注释"] and detected_texts["块注释"].kind == "block", "single-line block should be detected")
assert(detected_texts["多行一\n多行二"] and detected_texts["多行一\n多行二"].kind == "block", "multi-line block should be detected")

local lua_buffer = new_comment_buffer("lua", {
  "-- 行",
  'local s = "-- 不是注释"',
  "--[[",
  " 块",
  "]]",
})
detected = comments.detect(lua_buffer)
assert_equal(2, #detected, "Lua detection should ignore comment markers inside strings")
assert_equal("行", detected[1].text)
assert_equal("块", detected[2].text)

local html_buffer = new_comment_buffer("html", { "<!-- 中文 HTML -->" })
detected = comments.detect(html_buffer)
assert_equal(1, #detected, "HTML block comments should be detected")
assert_equal("中文 HTML", detected[1].text)

-- Tree-sitter detection is used when a parser is available.
local tree_ok, tree_parser = pcall(vim.treesitter.get_parser, c_buffer)
if tree_ok and tree_parser then
  translate.setup(comment_options({ use_treesitter = true }))
  local tree_detected = comments.detect(c_buffer)
  assert_equal(4, #tree_detected, "tree-sitter detection should find the same C comments")
  local tree_texts = {}
  for _, comment in ipairs(tree_detected) do
    tree_texts[comment.text] = true
  end
  assert(tree_texts["行注释"] and tree_texts["块注释"], "tree-sitter should preserve comment text")
end

-- inline comment replacement preserves code and indentation
translate.setup(comment_options())
local inline_calls = mock_translation("English inline note")
local inline_buffer = new_comment_buffer("lua", { "local value = 1 -- 中文内联翻译" })
local inline_line = lines_of(inline_buffer)[1]
vim.api.nvim_win_set_cursor(0, { 1, #inline_line - 1 })
translate.translate_comment()
wait_for(function()
  return lines_of(inline_buffer)[1] == "local value = 1 -- English inline note"
end, "inline comment translation did not apply: " .. vim.inspect(lines_of(inline_buffer)))
assert_equal(1, inline_calls.count, "one comment should use one request")

-- reverse direction: English comments can be translated into Chinese
translate.setup(comment_options({ target_lang = "zh-CN" }))
mock_translation("反向翻译结果")
local reverse_buffer = new_comment_buffer("lua", { "-- English reverse comment", "local reverse_code = 1" })
vim.api.nvim_win_set_cursor(0, { 1, 5 })
translate.translate_comment()
wait_for(function()
  return lines_of(reverse_buffer)[1] == "-- 反向翻译结果"
end, "reverse comment translation did not apply: " .. vim.inspect(lines_of(reverse_buffer)))

-- a translation is its own undo block
translate.setup(comment_options())
mock_translation("Undoable english")
local undo_buffer = new_comment_buffer("lua", { "-- 中文撤销测试", "local undo_code = 1" })
vim.api.nvim_win_set_cursor(0, { 1, 4 })
translate.translate_comment()
wait_for(function()
  return lines_of(undo_buffer)[1] == "-- Undoable english"
end, "undo test translation did not apply: " .. vim.inspect(lines_of(undo_buffer)))
vim.cmd("silent undo")
assert_equal("-- 中文撤销测试", lines_of(undo_buffer)[1], "one undo should restore the source comment")
assert_equal("local undo_code = 1", lines_of(undo_buffer)[2], "undo must not affect the surrounding code")

-- multi-line line comments keep one line per translated line
translate.setup(comment_options())
mock_translation("First translated line\nSecond translated line")
local multi_buffer = new_comment_buffer("lua", { "-- 中文多行甲", "-- 中文多行乙", "local after = 2" })
vim.api.nvim_win_set_cursor(0, { 2, 3 })
translate.translate_comment()
wait_for(function()
  return lines_of(multi_buffer)[1] == "-- First translated line"
end, "multi-line comment translation did not apply: " .. vim.inspect(lines_of(multi_buffer)))
assert_equal("-- Second translated line", lines_of(multi_buffer)[2], "the second line should keep its marker")
assert_equal("local after = 2", lines_of(multi_buffer)[3], "code after the comment must not change")
assert(comments.detect(multi_buffer)[1], "the translated comment should still be detectable")

-- block comments keep their decoration
translate.setup(comment_options())
mock_translation("Block line one\nBlock line two")
local block_buffer = new_comment_buffer("c", {
  "/*",
  " * 中文块甲",
  " * 中文块乙",
  " */",
  "int after_block;",
})
vim.api.nvim_win_set_cursor(0, { 2, 5 })
translate.translate_comment()
wait_for(function()
  return lines_of(block_buffer)[2] == " * Block line one"
end, "block comment translation did not apply: " .. vim.inspect(lines_of(block_buffer)))
assert_equal("/*", lines_of(block_buffer)[1], "the opening marker should be preserved")
assert_equal(" * Block line two", lines_of(block_buffer)[3], "the middle decoration should be preserved")
assert_equal(" */", lines_of(block_buffer)[4], "the closing marker should be preserved")
assert_equal("int after_block;", lines_of(block_buffer)[5], "code after the block must not change")

-- single-line block comments inline with code
translate.setup(comment_options())
mock_translation("Inline block translated")
local inline_block_buffer = new_comment_buffer("c", { "int a = 1; /* 中文内联块 */ int b = 2;" })
vim.api.nvim_win_set_cursor(0, { 1, 15 })
translate.translate_comment()
wait_for(function()
  return lines_of(inline_block_buffer)[1] == "int a = 1; /* Inline block translated */ int b = 2;"
end, "inline block translation did not apply: " .. vim.inspect(lines_of(inline_block_buffer)))

-- a different line count collapses the comment safely
translate.setup(comment_options())
mock_translation("One short line")
local collapse_buffer = new_comment_buffer("lua", { "-- 中文折叠甲", "-- 中文折叠乙", "local keep = 3" })
vim.api.nvim_win_set_cursor(0, { 1, 3 })
translate.translate_comment()
wait_for(function()
  return lines_of(collapse_buffer)[1] == "-- One short line"
end, "line-count mismatch should collapse to one line: " .. vim.inspect(lines_of(collapse_buffer)))
assert_equal("local keep = 3", lines_of(collapse_buffer)[2], "code after a collapsed comment must be preserved")

-- batch all comments uses one request and applies every translation
translate.setup(comment_options())
local batch_calls = { count = 0 }
vim.system = function(_, opts, callback)
  if type(opts) == "function" then
    callback = opts
  end
  batch_calls.count = batch_calls.count + 1
  callback({
    code = 0,
    stdout = vim.json.encode({
      choices = { { message = { content = "Batch first\n" .. comments.DELIMITER .. "\nBatch second" } } },
    }),
    stderr = "",
  })
  return { kill = function() end }
end
local batch_buffer = new_comment_buffer("lua", {
  "-- 中文批量甲",
  "local batch_a = 1",
  "-- 中文批量乙",
  "local batch_b = 2",
})
translate.translate_comments()
wait_for(function()
  local current = lines_of(batch_buffer)
  return current[1] == "-- Batch first" and current[3] == "-- Batch second"
end, "batch translation did not apply: " .. vim.inspect(lines_of(batch_buffer)))
assert_equal(1, batch_calls.count, "batch translation should use one request")

-- a mismatched batch response falls back to individual requests
translate.setup(comment_options())
local fallback_calls = { count = 0 }
vim.system = function(_, opts, callback)
  if type(opts) == "function" then
    callback = opts
  end
  fallback_calls.count = fallback_calls.count + 1
  local content
  if fallback_calls.count == 1 then
    content = "No delimiter here"
  elseif fallback_calls.count == 2 then
    content = "Fallback alpha"
  else
    content = "Fallback beta"
  end
  callback({
    code = 0,
    stdout = vim.json.encode({ choices = { { message = { content = content } } } }),
    stderr = "",
  })
  return { kill = function() end }
end
local fallback_buffer = new_comment_buffer("lua", {
  "-- 中文回退甲",
  "local fallback_a = 1",
  "-- 中文回退乙",
  "local fallback_b = 2",
})
translate.translate_comments()
wait_for(function()
  local current = lines_of(fallback_buffer)
  return current[1] == "-- Fallback alpha" and current[3] == "-- Fallback beta"
end, "batch fallback did not apply: " .. vim.inspect(lines_of(fallback_buffer)))
assert_equal(3, fallback_calls.count, "one batch request plus two fallback requests expected")

-- automatic mode translates on InsertLeave
translate.setup(comment_options({ mode = "auto" }))
mock_translation("Auto translated")
local auto_buffer = new_comment_buffer("lua", { "-- 中文自动事件", "local auto_value = 1" })
vim.api.nvim_win_set_cursor(0, { 1, 3 })
vim.cmd("doautocmd InsertLeave")
wait_for(function()
  return lines_of(auto_buffer)[1] == "-- Auto translated"
end, "auto mode should translate after InsertLeave: " .. vim.inspect(lines_of(auto_buffer)))

-- auto mode remembers rows edited during the insert session, so a comment
-- written before continuing with code is still translated
translate.setup(comment_options({ mode = "auto" }))
local session_calls = mock_translation("Comment before code")
local session_buffer = new_comment_buffer("lua", { "-- 中文先写注释", "local session_code = 1" })
vim.api.nvim_win_set_cursor(0, { 1, 3 })
vim.cmd("doautocmd InsertEnter")
vim.cmd("doautocmd TextChangedI")
vim.api.nvim_win_set_cursor(0, { 2, 5 })
vim.cmd("doautocmd TextChangedI")
vim.cmd("doautocmd InsertLeave")
wait_for(function()
  return lines_of(session_buffer)[1] == "-- Comment before code"
end, "auto mode should translate comments touched earlier in the insert session: "
  .. vim.inspect(lines_of(session_buffer)))
assert_equal(1, session_calls.count, "the insert session should send one comment request")

-- editing code on a different line does not rewrite an unrelated Chinese comment
translate.setup(comment_options({ mode = "auto" }))
local untouched_calls = mock_translation("must not be used")
local untouched_buffer = new_comment_buffer("lua", {
  "-- 中文已有注释",
  "local untouched_a = 1",
  "local untouched_b = 2",
})
vim.api.nvim_win_set_cursor(0, { 3, 5 })
vim.cmd("doautocmd InsertEnter")
vim.cmd("doautocmd TextChangedI")
vim.cmd("doautocmd InsertLeave")
vim.wait(200, function()
  return untouched_calls.count > 0
end, 10)
assert_equal(0, untouched_calls.count, "auto mode should ignore comments on untouched rows")
assert_equal("-- 中文已有注释", lines_of(untouched_buffer)[1], "the unrelated comment must stay unchanged")

-- manual mode never translates automatically
translate.setup(comment_options({ mode = "manual" }))
local unexpected_request = false
vim.system = function()
  unexpected_request = true
  error("manual mode must not translate automatically")
end
local manual_buffer = new_comment_buffer("lua", { "-- 中文手动模式", "local manual_value = 1" })
vim.api.nvim_win_set_cursor(0, { 1, 3 })
comments._auto_translate_now(manual_buffer)
vim.wait(150, function()
  return unexpected_request
end, 10)
assert_equal(false, unexpected_request, "manual mode should not translate automatically")
assert_equal("-- 中文手动模式", lines_of(manual_buffer)[1])

-- non-target comments and tool directives are ignored
translate.setup(comment_options())
local ignored_calls = mock_translation("should not be used")
new_comment_buffer("lua", { "-- already English", "local one = 1" })
vim.api.nvim_win_set_cursor(0, { 1, 3 })
translate.translate_comment()
vim.wait(100, function()
  return ignored_calls.count > 0
end, 10)
assert_equal(0, ignored_calls.count, "English comments should not be translated")

translate.setup(comment_options())
local directive_calls = mock_translation("should not be used")
new_comment_buffer("lua", { "-- eslint-disable 中文指令", "local two = 2" })
vim.api.nvim_win_set_cursor(0, { 1, 3 })
translate.translate_comment()
vim.wait(100, function()
  return directive_calls.count > 0
end, 10)
assert_equal(0, directive_calls.count, "tool directives should be skipped")

-- quickfix listing and mode API
translate.setup(comment_options())
new_comment_buffer("lua", { "-- 中文检查甲", "local check_a = 1", "-- 中文检查乙" })
local count = translate.check_comments({ open = false })
assert_equal(2, count, "check_comments should find both comments")
assert_equal(2, #vim.fn.getqflist(), "check_comments should populate the quickfix list")

assert_equal("manual", translate.comment_mode(), "comment_mode should report the configured mode")
translate.set_comment_mode("auto")
assert_equal("auto", translate.comment_mode(), "set_comment_mode should switch to auto")
translate.set_comment_mode("manual")
assert_equal("manual", translate.comment_mode(), "set_comment_mode should switch back to manual")
assert_equal(2, vim.fn.exists(":MagpieCommentMode"), "the MagpieCommentMode command should exist")

print("magpie tests passed")
vim.cmd("quitall!")
