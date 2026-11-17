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
vim.system = function(_, _, callback)
  system_calls = system_calls + 1
  return { kill = function() killed = killed + 1 end }
end
translate.translate("first target", {})
translate.translate("second target", {})
assert_equal(1, killed, "the stale in-flight request should be killed")

print("magpie tests passed")
vim.cmd("quitall!")
