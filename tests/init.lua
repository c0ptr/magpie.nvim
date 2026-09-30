vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.swapfile = false
vim.cmd("runtime plugin/word-translate.lua")
assert(vim.fn.exists(":WordTranslate") == 2, "WordTranslate command should be registered")

local function assert_equal(expected, actual, message)
  if expected ~= actual then
    error(message or string.format("expected %s, got %s", vim.inspect(expected), vim.inspect(actual)))
  end
end

local selection = require("word-translate.selection")
local buffer = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "A hello-world example" })
vim.api.nvim_win_set_cursor(0, { 1, 3 })
assert_equal("hello-world", selection.word_under_cursor(), "cursor word should include hyphens")
assert_equal("example", selection.word_at_position(0, 0, 15), "position word should be found")
assert_equal(nil, selection.word_at_position(0, 0, 1), "spaces are not words")

local original_system = vim.system
vim.system = function(_, _, callback)
  callback({
    code = 0,
    stdout = '[[["你好","hello",null,null,10]],null,"en"]',
    stderr = "",
  })
  return {}
end

local google = require("word-translate.providers.google")
local google_result
google.translate("hello", {
  source_lang = "auto",
  target_lang = "zh-CN",
  google = { endpoint = "https://example.test", timeout_ms = 1000 },
}, function(result, err)
  assert_equal(nil, err)
  google_result = result
end)
assert(vim.wait(1000, function()
  return google_result ~= nil
end), "Google callback timed out")
assert_equal("你好", google_result.translation)
assert_equal("en", google_result.detected_source_lang)

local cloud_google_result
vim.system = function(_, _, callback)
  callback({
    code = 0,
    stdout = '{"data":{"translations":[{"translatedText":"你好","detectedSourceLanguage":"en"}]}}',
    stderr = "",
  })
  return {}
end
google.translate("hello", {
  source_lang = "auto",
  target_lang = "zh-CN",
  google = {
    endpoint = "https://example.test/public",
    cloud_endpoint = "https://example.test/cloud",
    api_key = "test-key",
    timeout_ms = 1000,
  },
}, function(result, err)
  assert_equal(nil, err)
  cloud_google_result = result
end)
assert(vim.wait(1000, function()
  return cloud_google_result ~= nil
end), "Google Cloud callback timed out")
assert_equal("你好", cloud_google_result.translation)
assert_equal("en", cloud_google_result.detected_source_lang)

local bing = require("word-translate.providers.bing")
local bing_result
vim.system = function(_, _, callback)
  callback({
    code = 0,
    stdout = '[{"detectedLanguage":{"language":"en"},"translations":[{"text":"你好","to":"zh-Hans"}]}]',
    stderr = "",
  })
  return {}
end
bing.translate("hello", {
  source_lang = "auto",
  target_lang = "zh-Hans",
  bing = { endpoint = "https://example.test", api_key = "test-key", timeout_ms = 1000 },
}, function(result, err)
  assert_equal(nil, err)
  bing_result = result
end)
assert(vim.wait(1000, function()
  return bing_result ~= nil
end), "Bing callback timed out")
assert_equal("你好", bing_result.translation)
assert_equal("en", bing_result.detected_source_lang)

local ui = require("word-translate.ui")
local options = require("word-translate.config").build({
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

local translate = require("word-translate")
vim.system = function(_, _, callback)
  callback({
    code = 0,
    stdout = '[[["你好","hello",null,null,10]],null,"en"]',
    stderr = "",
  })
  return {}
end
translate.setup({
  hover = { enabled = false },
  mouse_selection = { enabled = false },
  dictionary = { enabled = false },
  google = { api_key = "" },
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
print("word-translate tests passed")
vim.cmd("quitall!")
