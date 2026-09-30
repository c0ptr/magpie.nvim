local util = require("word-translate.util")

local M = {}

local function decode_public_response(body, options, callback)
  local payload, decode_error = util.decode_json(body, "Google Translate")
  if not payload then
    callback(nil, decode_error)
    return
  end

  local pieces = {}
  for _, segment in ipairs(payload[1] or {}) do
    if type(segment) == "table" and type(segment[1]) == "string" then
      table.insert(pieces, segment[1])
    end
  end

  local translated = table.concat(pieces)
  if translated == "" then
    callback(nil, "Google Translate returned no translated text")
    return
  end

  callback({
    translation = translated,
    detected_source_lang = type(payload[3]) == "string" and payload[3] or options.source_lang,
  })
end

local function translate_with_public_endpoint(text, options, callback)
  local config = options.google
  local args = {
    "curl",
    "--silent",
    "--show-error",
    "--fail-with-body",
    "--location",
    "--max-time",
    util.timeout_seconds(config.timeout_ms),
    "--get",
    config.endpoint,
    "--data-urlencode",
    "client=gtx",
    "--data-urlencode",
    "sl=" .. options.source_lang,
    "--data-urlencode",
    "tl=" .. options.target_lang,
    "--data-urlencode",
    "dt=t",
    "--data-urlencode",
    "q=" .. text,
  }

  util.run_curl(args, function(body, request_error)
    if request_error then
      if request_error:match("429") then
        callback(nil, "Google's public endpoint is rate limited. Try again later or configure google.api_key for Google Cloud Translation.")
        return
      end
      callback(nil, "Google Translate request failed: " .. request_error)
      return
    end
    decode_public_response(body, options, callback)
  end)
end

local function translate_with_cloud_api(text, options, callback)
  local config = options.google
  local request = {
    q = { text },
    target = options.target_lang,
    format = "text",
  }
  if options.source_lang ~= "auto" then
    request.source = options.source_lang
  end

  local args = {
    "curl",
    "--silent",
    "--show-error",
    "--fail-with-body",
    "--location",
    "--max-time",
    util.timeout_seconds(config.timeout_ms),
    "--request",
    "POST",
    config.cloud_endpoint .. "?key=" .. util.url_encode(config.api_key),
    "--header",
    "Content-Type: application/json; charset=UTF-8",
    "--data-raw",
    vim.json.encode(request),
  }

  util.run_curl(args, function(body, request_error)
    if request_error then
      callback(nil, "Google Cloud Translation request failed: " .. request_error)
      return
    end

    local payload, decode_error = util.decode_json(body, "Google Cloud Translation")
    if not payload then
      callback(nil, decode_error)
      return
    end
    local translation = payload.data and payload.data.translations and payload.data.translations[1]
    if type(translation) ~= "table" or type(translation.translatedText) ~= "string" then
      callback(nil, "Google Cloud Translation returned no translated text")
      return
    end

    callback({
      translation = translation.translatedText,
      detected_source_lang = translation.detectedSourceLanguage or options.source_lang,
    })
  end)
end

function M.translate(text, options, callback)
  if options.google.api_key and options.google.api_key ~= "" then
    translate_with_cloud_api(text, options, callback)
    return
  end
  translate_with_public_endpoint(text, options, callback)
end

return M
