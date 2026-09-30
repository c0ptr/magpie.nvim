local util = require("word-translate.util")

local M = {}

function M.lookup(word, options, callback)
  local config = options.dictionary
  if not config.enabled or not util.is_english_word(word) then
    callback(nil)
    return
  end

  local url = config.endpoint:gsub("/$", "") .. "/" .. util.url_encode(word:lower())
  local args = {
    "curl",
    "--silent",
    "--show-error",
    "--fail",
    "--location",
    "--max-time",
    util.timeout_seconds(config.timeout_ms),
    url,
  }

  util.run_curl(args, function(body, request_error)
    if request_error then
      callback(nil)
      return
    end

    local payload = util.decode_json(body, "dictionary")
    local item = type(payload) == "table" and payload[1] or nil
    if type(item) ~= "table" then
      callback(nil)
      return
    end

    for _, phonetic in ipairs(item.phonetics or {}) do
      if type(phonetic.text) == "string" and phonetic.text ~= "" then
        callback(phonetic.text)
        return
      end
    end
    callback(type(item.phonetic) == "string" and item.phonetic or nil)
  end)
end

return M
