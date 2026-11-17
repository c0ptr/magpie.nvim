local chat = require("magpie.providers.chat")

local M = {}

function M.translate(text, options, callback)
    return chat.translate("copilot", text, options, callback)
end

function M.translate_stream(text, options, on_delta, callback)
    return chat.translate_stream("copilot", text, options, on_delta, callback)
end

return M
