# Magpie.nvim · v0.3

[中文文档](README.zh-CN.md) | [English](README.md)

轻量、无第三方依赖的 Neovim 翻译插件。可翻译光标下的单词、可视模式选中的文本或直接提供的文本，并在原生浮动窗口中展示原文、发音和译文。

v0.3 新增**代码注释翻译**：在写注释时，可将中文注释自动翻译为英文，也可以按需手动翻译；反向翻译同样受支持。若安装了相应的 Tree-sitter 解析器，插件会通过语法节点识别注释；否则使用 `commentstring` 和内置注释标记回退机制。

![Neovim](https://img.shields.io/badge/Neovim-%3E%3D0.10-57A143?logo=neovim&logoColor=white)
![Version](https://img.shields.io/badge/version-0.3-blue)

## 功能特性

- **代码注释翻译（v0.3）**
  - `manual` 模式：翻译光标下的注释、可视选区中的注释或缓冲区中的全部注释。
  - `auto` 模式：退出插入模式后翻译本次插入会话中涉及的注释，支持防抖和过期缓冲区保护。
  - 优先使用 Tree-sitter 识别注释，并提供通用的 `commentstring` 回退方案。
  - 保留注释标记、缩进、块注释装饰（`/*`、`*`、`*/`）、行内注释、TODO/FIXME 标签和代码标识符。
  - 自动跳过 ESLint、TypeScript、NoQA、NoLint、SPDX 和 Vim modeline 等工具指令。
  - `:MagpieComments` 可批量翻译多个注释。
  - `:MagpieCommentMode` 可在运行时切换翻译模式。
- 支持 ChatGPT、Copilot、Gemini、DeepSeek 和有道（均需相应密钥）。
- 内置约 2000 个常用英语单词和约 300 个编程术语（含 IPA 和中文释义），离线即可快速翻译。
- 查询顺序：内存缓存 → 磁盘缓存 → 本地词典 → 网络请求。
- 支持翻译光标下的单词、可视选区或鼠标指向的单词。
- 使用不获得焦点的原生浮动窗口，在光标或鼠标旁显示。
- 单词翻译时，IPA 查询与翻译请求并行执行。
- 对进行中的请求去重，并取消过期请求。
- 支持流式渲染翻译结果。
- 支持通过配置文件添加用户词典。
- 磁盘缓存跨会话持久保存，并使用标准化缓存键。
- 所有请求均为异步，不阻塞编辑器。
- 提供 `:checkhealth magpie` 诊断命令。

## 环境要求

- Neovim 0.10 或更高版本。
- 网络翻译和发音功能要求系统中可使用 `curl`。
- 所选翻译服务需具备网络访问权限和有效凭据。
- Tree-sitter 解析器为可选组件，但能提高注释识别准确度。

## 安装

### lazy.nvim

```lua
{
  "c0ptr/magpie.nvim",
  main = "magpie",
  event = "VeryLazy",
  opts = {},
}
```

`opts = {}` 会自动调用 `require("magpie").setup({})`。默认会在普通和可视模式安装 `<leader>tw` 映射，在普通模式和可视模式安装注释翻译相关映射。

若需自行配置映射，可关闭内置映射：

```lua
{
  "c0ptr/magpie.nvim",
  main = "magpie",
  event = "VeryLazy",
  opts = {
    keymaps = {
      normal = false,
      visual = false,
      comment = false,
      comments = false,
    },
  },
}
```

## 使用方式

| 操作 | 结果 |
| --- | --- |
| 普通模式下按 `<leader>tw` | 翻译光标下的单词 |
| 可视模式下按 `<leader>tw` | 翻译选中的文本 |
| 普通模式下按 `<leader>tc` | 翻译光标下的注释 |
| 可视模式下按 `<leader>tc` | 翻译选区中的注释 |
| 普通模式下按 `<leader>tC` | 翻译缓冲区中所有可翻译的注释 |
| 将鼠标悬停在单词上 | 停留片刻后自动翻译（默认启用） |
| 拖动鼠标创建可视选区 | 松开鼠标后翻译（默认启用） |
| `:Magpie [text]` | 翻译指定文本；省略参数时翻译当前选区或光标下的单词 |
| `:MagpieComment` | 翻译光标下的注释，也可指定行范围 |
| `:MagpieComments` | 批量翻译缓冲区中的所有可翻译注释 |
| `:MagpieCommentMode [auto\|manual\|toggle\|off]` | 查看或切换注释翻译模式 |
| `:MagpieCommentsCheck` | 将可翻译注释列入 quickfix 列表 |
| `:MagpieClose` | 关闭结果窗口 |

终端 Neovim 中需要设置 `set mouse=a` 才能使用鼠标交互。悬停功能使用 `vim.on_key`，并在启用时设置 `mousemoveevent`；它不会替代现有鼠标移动映射。

## 注释翻译

注释翻译默认以 `manual` 模式启用，因此不会主动改写文件。可通过以下选项启用自动翻译：

```lua
require("magpie").setup({
  comment_translation = {
    mode = "auto", -- 离开插入模式后翻译本次会话涉及的注释
  },
})
```

自动模式会在退出插入模式后翻译本次插入会话涉及的注释块（包括光标所在注释）。例如先写注释、按回车继续写代码时，插件仍会翻译刚写的注释。自动模式不会改写整个缓冲区。如果请求进行时缓冲区发生变化，翻译结果会因位置已过期而被丢弃。

翻译为异步操作：离开插入模式后立即保存时，应等待翻译完成后再次保存。若翻译结果恰好在保存后到达，插件会发出提醒。

### 什么会被识别为注释？

- 安装对应解析器后，可识别 `comment`、`line_comment`、`block_comment`、`doc_comment` 和 `multiline_comment` 节点。
- 未安装解析器时，使用 `commentstring` 和常见注释标记表，包括：
  `//`、`#`、`--`、`;`、`%`、`"`、`'`、`rem`、`!`、`*`、`/* */`、
  `<!-- -->`、`{- -}`、`(* *)`、`--[[ ]]`、`#[ ]#`、`#| |#`、
  `%{ %}`、`<# #>`、`=begin/=end` 等。
- 支持行尾注释、多行行注释块和块注释。识别只针对注释；行中的代码不会被改写。Tree-sitter 同时可以可靠排除字符串和文档字符串。

内置回退机制可覆盖大多数 Neovim 文件类型。安装 Tree-sitter 解析器可提高 Rust、Java、Vue、Markdown 代码块等语言的识别准确度，并减少字符串误识别。

未安装解析器时，回退扫描器只理解常见字符串和注释标记。Python 三引号字符串、Lua 长括号和 shell heredoc 中的注释样式文本可能被误认为注释。建议为常用语言安装解析器。

### 会保留哪些内容？

插件只替换注释中的自然语言内容，不改动注释标记、缩进、块装饰和周围代码。每次翻译均为独立撤销块，因此一次 `u` 可恢复源注释，而不会撤销最近的输入。

若译文行数与源注释不同，注释会折叠为单行以避免破坏文件结构。提示词会保留 `TODO`、`FIXME`、`NOTE`、行内代码、URL 和标识符。

以下工具指令默认跳过：`eslint-disable`、`@ts-ignore`、`noqa`、`nolint`、`type: ignore`、`go:generate`、SPDX 许可证声明和 Vim modeline。Shebang 也会被忽略。

### 反向翻译

`target_lang` 控制翻译方向。默认将中文注释翻译为英文；设为 `"zh-CN"` 可将英文注释翻译为中文：

```lua
require("magpie").setup({
  comment_translation = {
    mode = "manual",
    target_lang = "zh-CN",
  },
})
```

### 注释翻译选项

```lua
require("magpie").setup({
  keymaps = {
    comment = "<leader>tc",
    comments = "<leader>tC",
  },

  comment_translation = {
    enabled = true,
    mode = "manual",
    target_lang = "en",
    source_lang = "auto",
    filetypes = nil,
    exclude_filetypes = {
      "checkhealth", "diff", "gitcommit", "gitrebase", "help", "lspinfo",
      "man", "markdown", "neo-tree", "notify", "noice", "NvimTree",
      "prompt", "qf", "snacks_dashboard", "text",
    },
    use_treesitter = true,
    debounce_ms = 500,
    max_batch = 6,
    max_chars = 3000,
    notify = "on_error",
    skip_patterns = {
      "eslint%-disable", "eslint%-enable",
      "@ts%-ignore", "@ts%-expect%-error",
      "noqa", "nolint", "type:%s*ignore",
      "go:generate", "go:build", "go:embed", "^%+build",
      "SPDX%-License%-Identifier", "^vim:", "^vi:", "^ex:",
    },
  },
})
```

`comment` 和 `comments` 位于顶层 `keymaps` 表中，与 `normal`、`visual` 并列。设为 `false` 可禁用相应映射。

模式可在不重启 Neovim 的情况下切换：

```vim
:MagpieCommentMode          " 显示当前模式
:MagpieCommentMode auto     " 启用自动翻译
:MagpieCommentMode manual   " 仅按需翻译
:MagpieCommentMode toggle   " 在自动和手动模式间切换
:MagpieCommentMode off      " 禁用注释翻译
```

可在状态栏中显示当前模式，例如配合 lualine：

```lua
{
  function()
    return "magpie:" .. require("magpie").comment_mode()
  end
}
```

### 隐私与限制

注释会发送到已配置的翻译服务。若注释可能包含密钥或敏感信息，可设置 `comment_translation.enabled = false` 或运行 `:MagpieCommentMode off`。

自动模式只发送包含中文（或反向模式中的英文）的注释，不会上传整个缓冲区。超长注释会按 `max_chars` 被跳过；不支持注释语法且无法识别文件类型的内容不会处理。

## 快速开始

1. 安装插件（见上文）。
2. 获取所选服务的 API Key。
3. 将密钥导出为环境变量，例如 `export OPENAI_API_KEY=sk-...`，也可直接写入 Neovim 配置。
4. 将鼠标悬停在单词上、按 `<leader>tw` 或运行 `:Magpie hello world` 即可开始使用。内置词典中的单词无需密钥也可翻译。

## 配置

调用 `require("magpie").setup()` 时可传入以下任意选项；未设置的键会使用默认值。密钥也可通过环境变量提供，无需写入配置文件。

```lua
require("magpie").setup({
  source_lang = "auto",
  target_lang = "zh-CN",
  provider = "chatgpt",

  keymaps = {
    normal = "<leader>tw",
    visual = "<leader>tw",
    comment = "<leader>tc",
    comments = "<leader>tC",
  },

  comment_translation = {
    enabled = true,
    mode = "manual",
    target_lang = "en",
    source_lang = "auto",
    filetypes = nil,
    exclude_filetypes = {
      "checkhealth", "diff", "gitcommit", "gitrebase", "help", "lspinfo",
      "man", "markdown", "neo-tree", "notify", "noice", "NvimTree",
      "prompt", "qf", "snacks_dashboard", "text",
    },
    use_treesitter = true,
    debounce_ms = 500,
    max_batch = 6,
    max_chars = 3000,
    notify = "on_error",
  },

  hover = {
    enabled = true,
    delay_ms = 550,
  },
  mouse_selection = { enabled = true },

  ui = {
    border = "rounded",
    max_width = 72,
    min_width = 30,
    winblend = 0,
    title = " 翻译 ",
  },

  cache = {
    max_entries = 100,
    persist = true,
    max_disk_entries = 500,
    dir = nil,
  },

  local_dictionary = {
    enabled = true,
    user_file = nil,
  },
  stream = { enabled = true },

  dictionary = {
    enabled = true,
    endpoint = "https://api.dictionaryapi.dev/api/v2/entries/en",
    timeout_ms = 5000,
  },

  chatgpt = {
    api_key = vim.env.OPENAI_API_KEY,
    model = "gpt-4o-mini",
    temperature = 0.2,
    extra_body = nil,
    proxy = nil,
    endpoint = "https://api.openai.com/v1/chat/completions",
    timeout_ms = 30000,
  },

  copilot = {
    api_key = vim.env.GITHUB_TOKEN,
    model = "gpt-4o",
    temperature = 0.2,
    extra_body = nil,
    proxy = nil,
    endpoint = "https://api.githubcopilot.com/chat/completions",
    timeout_ms = 30000,
  },

  gemini = {
    api_key = vim.env.GEMINI_API_KEY,
    model = "gemini-2.5-flash",
    temperature = 0.2,
    proxy = nil,
    endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
    timeout_ms = 30000,
  },

  deepseek = {
    api_key = vim.env.DEEPSEEK_API_KEY,
    model = "deepseek-flash",
    temperature = 0.2,
    extra_body = nil,
    proxy = nil,
    endpoint = "https://api.deepseek.com/chat/completions",
    timeout_ms = 30000,
  },

  youdao = {
    app_key = vim.env.YOUDAO_APP_KEY,
    app_secret = vim.env.YOUDAO_APP_SECRET,
    proxy = nil,
    endpoint = "https://openapi.youdao.com/api",
    timeout_ms = 10000,
  },
})
```

### 配置示例

最简配置（ChatGPT，通过环境变量读取密钥，其他选项使用默认值）：

```lua
require("magpie").setup({})
```

写作时自动将中文注释翻译为英文：

```lua
require("magpie").setup({
  provider = "deepseek",
  comment_translation = { mode = "auto", target_lang = "en" },
})
```

仅启用手动注释翻译，关闭悬停和鼠标选区翻译：

```lua
require("magpie").setup({
  comment_translation = { mode = "manual" },
  hover = { enabled = false },
  mouse_selection = { enabled = false },
})
```

使用 Copilot，并关闭悬停和鼠标选区功能：

```lua
require("magpie").setup({
  provider = "copilot",
  copilot = { api_key = vim.env.GITHUB_TOKEN, model = "gpt-4o" },
  hover = { enabled = false },
  mouse_selection = { enabled = false },
})
```

仅离线模式（使用内置词典和磁盘缓存，不查询 IPA）：

```lua
require("magpie").setup({
  local_dictionary = { enabled = true },
  dictionary = { enabled = false },
  comment_translation = { enabled = false },
})
```

不在词典中的单词会提示错误，而不会发起翻译请求。

持久缓存默认保存在 `stdpath("data")/magpie/` 下。可通过 `hover = { enabled = false }` 和 `mouse_selection = { enabled = false }` 关闭自动鼠标功能。

## 翻译服务与凭据

建议通过环境变量提供密钥，不要把密钥写入配置仓库。Magpie 会读取相应环境变量；下方也列出了等价的 Lua 配置。

### ChatGPT

设置 `OPENAI_API_KEY` 或 `CHATGPT_API_KEY`：

```lua
require("magpie").setup({
  provider = "chatgpt",
  chatgpt = {
    api_key = vim.env.OPENAI_API_KEY,
  },
})
```

### Copilot

需要具有 Copilot 访问权限的 GitHub Token（OAuth Token 或包含 Copilot Chat 权限的精细 PAT）。设置 `GITHUB_TOKEN` 或 `COPILOT_API_KEY`：

```lua
require("magpie").setup({
  provider = "copilot",
  copilot = {
    api_key = vim.env.GITHUB_TOKEN,
  },
})
```

### Gemini

设置 `GEMINI_API_KEY`：

```lua
require("magpie").setup({
  provider = "gemini",
  gemini = {
    api_key = vim.env.GEMINI_API_KEY,
  },
})
```

### DeepSeek

设置 `DEEPSEEK_API_KEY`。DeepSeek 通过 Chat Completions API 翻译，因此响应时间可能较长：

```lua
require("magpie").setup({
  provider = "deepseek",
  deepseek = {
    api_key = vim.env.DEEPSEEK_API_KEY,
    extra_body = { thinking = { type = "disabled" } },
  },
})
```

### 有道

在[有道智云开放平台](https://ai.youdao.com/)创建凭据，并设置 `YOUDAO_APP_KEY` 和 `YOUDAO_APP_SECRET`：

```lua
require("magpie").setup({
  provider = "youdao",
  youdao = {
    app_key = vim.env.YOUDAO_APP_KEY,
    app_secret = vim.env.YOUDAO_APP_SECRET,
  },
})
```

## 离线词典与发音

Magpie 内置约 2000 个最常用英语单词及约 300 个编程术语（包括语言、框架、工具和概念；含 IPA 和中文释义），会在发起网络请求前进行检查。

词表来源：[hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords)，许可证为 MIT。默认目标语言为 `"zh-CN"` 时，插件会在内存缓存、磁盘缓存和本地词典中依次查找，然后才联系所选翻译服务。

内置词典可离线覆盖支持的单词。可通过 `local_dictionary = { enabled = false }` 禁用。单个英语单词的 IPA 会通过免费的 Dictionary API 单独查询；不可用时显示为 `—`，整句文本不提供 IPA。

### 用户词典

创建 `~/.config/nvim/magpie-dict.txt`，或设置 `local_dictionary.user_file`。每行一个词条；用户词条会覆盖内置词典，并可离线使用：

```txt
kubernetes	Kubernetes（容器编排平台）
alias	别名
```

单词可包含 `+ # . -`。重启 Neovim 或再次运行 `require("magpie").setup()` 后会重新加载文件。

## IPA 说明

翻译服务不一定会可靠提供 IPA。对于单个英语单词，插件会通过免费的 Dictionary API 并行查询 IPA；若无结果或输入为整句文本，IPA 字段会显示为 `—`。

## Lua 公共 API

```lua
local magpie = require("magpie")

magpie.translate("A clear mind", { target_lang = "zh-CN" })
magpie.translate_cursor()
magpie.translate_visual()
magpie.translate_from_command("hello")
magpie.close()
magpie.last_result

magpie.translate_comment()
magpie.translate_comment({ range = { 4, 9 } })
magpie.translate_comments()
magpie.check_comments({ open = false })
magpie.comment_mode()
magpie.set_comment_mode("auto")
magpie.version
```

## 健康检查与测试

运行 `:checkhealth magpie` 可检查 Neovim 版本、`curl`、内置词典、服务凭据和注释翻译模式。

无网络测试套件：

```sh
nvim --headless --clean -i NONE -u tests/init.lua
```

CI 在 Neovim 0.10 至 nightly 版本上运行测试。使用仓库内置配置运行 [stylua](https://github.com/JohnnyMorganz/StyLua) 格式化。

计划中的功能见 [ROADMAP.md](ROADMAP.md)，版本记录见 [CHANGELOG.md](CHANGELOG.md)。

## 许可证

MIT
