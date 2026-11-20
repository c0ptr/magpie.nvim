local chat = require("magpie.providers.chat")

local M = {}

function M.translate(text, options, callback, prompt)
    return chat.translate("deepseek", text, options, callback, prompt)
end

function M.translate_stream(text, options, on_delta, callback, prompt)
    return chat.translate_stream("deepseek", text, options, on_delta, callback, prompt)
end

return M
