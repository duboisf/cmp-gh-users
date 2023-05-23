# GitHub User Completion :fire::rocket:

Complete GitHub organization usernames directly from Neovim! Offering seamless autocompletion using [nvim-cmp](https://github.com/hrsh7th/nvim-cmp), it's fueled by the GitHub CLI and packed with features to enhance your coding experience. :zap::star:

## :star: Features

- :rocket: Integrates with `nvim-cmp` for seamless completion within Neovim.
- :gear: Automatically detects the GitHub org by inspecting the `origin` git remote of the current working directory.
- :mag_right: Caches the GitHub API responses for fast and efficient access.
- :racing_car: Loads asynchronously at startup to avoid slowing down Neovim.
- :watch: Refreshes cached items after they expire, ensuring the data is always up-to-date.
- :floppy_disk: Asynchronously persists the cache to the filesystem.
- :file_folder: Activates and triggers only on certain filetypes for focused performance.
- :cop: Uses `gh` (GitHub's CLI) to simplify authentication.

## :wrench: Prerequisites

- [Neovim](https://github.com/neovim/neovim) (0.9 or later) :pencil2:
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) :clipboard:
- [GitHub CLI (gh)](https://github.com/cli/cli#installation) :octocat:

## :floppy_disk: Installation

**With [lazy.nvim](https://github.com/folke/lazy.nvim):**

```lua
    {
        'duboisf/cmp-gh-users',
        opts = {
          -- your configuration comes here, these are the defaults
          cache = {
            -- The maximum age of a cache item in seconds
            max_age = 12 * 60 * 60, -- 12 hours
            -- The path to the cache file
            path = vim.fn.stdpath("cache") .. "/cmp-gh-users.json",
          },
          -- Filetypes to enable this source for
          filetypes = { "gitcommit", "markdown" },
          -- The minimum vim log level to log, see `:help vim.log.levels`
          log_level = vim.log.levels.WARN,
        }
    }
```

The default configuration should be fine and work out-of-the-box.

:information_source: Run `:checkhealth cmp-gh-users` to ensure everything is working properly.

## :gear: Setup with nvim-cmp

**For `init.lua`:**

```lua
local cmp = require('cmp')

cmp.setup({
  -- your other cmp configuration comes here
  sources = {
    -- your other cmp sources come here
    { name = 'gh_users' }
  }
})
```

## :books: Usage

Just start typing a username in Neovim in any of the configured filetypes, and the plugin will provide autocompletion suggestions from your GitHub organization's members.

## :handshake: Contributing

We love contributions! :heart: Open an issue if you have any suggestions or found a bug. All your awesome ideas are welcome!

## :memo: License

This project is licensed under the terms of the MIT license. See [LICENSE](LICENSE) for more details.
