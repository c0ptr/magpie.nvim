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
