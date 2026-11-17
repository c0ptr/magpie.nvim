local chat = require("magpie.providers.chat")

local M = {}

function M.translate(text, options, callback)
    return chat.translate("chatgpt", text, options, callback)
end

return M
