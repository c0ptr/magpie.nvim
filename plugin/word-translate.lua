if vim.g.loaded_word_translate == 1 then
  return
end
vim.g.loaded_word_translate = 1

vim.api.nvim_create_user_command("WordTranslate", function(command)
  require("word-translate").translate_from_command(command.args)
end, {
  nargs = "?",
  desc = "Translate text, a Visual selection, or the word under the cursor",
})

vim.api.nvim_create_user_command("WordTranslateClose", function()
  require("word-translate").close()
end, {
  desc = "Close the word-translate floating window",
})
