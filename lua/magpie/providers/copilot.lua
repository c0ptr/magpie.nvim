local chat = require("magpie.providers.chat")

local M = {}

function M.translate(text, options, callback, prompt)
    return chat.translate("copilot", text, options, callback, prompt)
end

function M.translate_stream(text, options, on_delta, callback, prompt)
    return chat.translate_stream("copilot", text, options, on_delta, callback, prompt)
end

return M
