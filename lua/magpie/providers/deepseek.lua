local chat = require("magpie.providers.chat")

local M = {}

function M.translate(text, options, callback)
    return chat.translate("deepseek", text, options, callback)
end

function M.translate_stream(text, options, on_delta, callback)
    return chat.translate_stream("deepseek", text, options, on_delta, callback)
end

return M
