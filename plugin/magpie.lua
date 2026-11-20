if vim.g.loaded_magpie == 1 then
  return
end
vim.g.loaded_magpie = 1

vim.api.nvim_create_user_command("Magpie", function(command)
  require("magpie").translate_from_command(command.args)
end, {
  nargs = "?",
  desc = "Translate text, a Visual selection, or the word under the cursor",
})

vim.api.nvim_create_user_command("MagpieClose", function()
  require("magpie").close()
end, {
  desc = "Close the Magpie floating window",
})

vim.api.nvim_create_user_command("MagpieComment", function(command)
  local context
  if command.range > 0 then
    context = { range = { command.line1 - 1, command.line2 - 1 }, origin = "range" }
  end
  require("magpie").translate_comment(context)
end, {
  range = true,
  desc = "Translate the code comment under the cursor or in the given range",
})

vim.api.nvim_create_user_command("MagpieComments", function()
  require("magpie").translate_comments()
end, {
  desc = "Translate all translatable comments in the current buffer",
})

vim.api.nvim_create_user_command("MagpieCommentMode", function(command)
  require("magpie").set_comment_mode(command.args)
end, {
  nargs = "?",
  complete = function()
    return { "auto", "manual", "toggle", "off" }
  end,
  desc = "Show or set the comment translation mode",
})

vim.api.nvim_create_user_command("MagpieCommentsCheck", function()
  require("magpie").check_comments({ open = true })
end, {
  desc = "List translatable comments in the quickfix list",
})
