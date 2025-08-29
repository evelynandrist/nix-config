{ config, lib, pkgs, ... }: {
  home.packages = with pkgs; [
    ripgrep
    # Linters
    commitlint
    eslint_d
    golangci-lint
    hadolint
    html-tidy
    luajitPackages.luacheck
    markdownlint-cli
    nodePackages.jsonlint
    pylint
    ruff
    shellcheck
    vale
    yamllint
  ];
  programs.nixvim = {
    enable = true;
    nixpkgs.config = {
      allowUnfree = true;
    };
    opts = {
      number = true;
      relativenumber = true;

      shiftwidth = 2;
    };

    globals.mapleader = " ";

    keymaps = [
      {
        action = "<cmd>Telescope live_grep<CR>";
        key = "<leader>g";
      }
      {
        action = "<cmd>Telescope find_files<CR>";
        key = "<leader>ff";
      }
      {
	action = "<cmd>Telescope buffers<CR>";
	key = "<leader>fb";
      }
      {
	action = "<cmd>Telescope help_tags<CR>";
	key = "<leader>fh";
      }
      {
	action = ":if &modifiable && !&readonly && &modified <CR> :write<CR> :endif<CR>:bnext<CR>";
	key = "<tab>";
	options = {
	  silent = true;
	};
      }
      {
	action = ":if &modifiable && !&readonly && &modified <CR> :write<CR> :endif<CR>:bprevious<CR>";
	key = "<s-tab>";
	options = {
	  silent = true;
	};
      }
    ];

    colorschemes.catppuccin = {
      enable = true;
    };

    extraConfigVim = ''
      "remember some stuff
      set history=100
      set undolevels=1000
      set undofile
      set undodir=~/.vim/.undoFiles
      set viminfo='100,f1 "save the marks and jumps after close

      syntax on
      filetype plugin on
      set hidden

      let g:himalaya_folder_picker = 'telescope'
      let g:himalaya_folder_picker_telescope_preview = 1
    '';

    plugins = {
      bufferline.enable = true;

      comment.enable = true;

      copilot-vim.enable = true;
      
      lualine.enable = true;

      neo-tree.enable = true;
    
      lsp = {
        enable = true;
        servers = {
          # webdev
          ts_ls.enable = true;
          tailwindcss.enable = true;
          eslint.enable = true;
          html.enable = true;
          cssls.enable = true;

          bashls.enable = true;

          ccls.enable = true;

          dockerls.enable = true;

	  # golangci-lint-ls.enable = true;
	  gopls.enable = true;

	  java_language_server.enable = true;

          jsonls.enable = true;

          ltex.enable = true;
          texlab.enable = true;

          nil_ls.enable = true;

          pylsp.enable = true;

        };
      };

      lint = {
	enable = true;
	lintersByFt = {
	  c = ["clangtidy"];
	  cpp = ["clangtidy"];
	  css = ["eslint_d"];
	  gitcommit = ["commitlint"];
	  go = ["golangcilint"];
	  javascript = ["eslint_d"];
	  javascriptreact = ["eslint_d"];
	  json = ["jsonlint"];
	  lua = ["luacheck"];
	  markdownlint = ["markdownlint"];
	  nix = ["nix"];
	  python = ["ruff"];
	  sh = ["shellcheck"];
	  typescript = ["eslint_d"];
	  typescriptreact = ["eslint_d"];
	  yaml = ["yamllint"];
	};
      };

      markdown-preview.enable = true;

      nvim-autopairs = {
	enable = true;
	settings.check_ts = true; # use TreeSitter
      };

      nvim-colorizer.enable = true;

      project-nvim = {
	enable = true;
	enableTelescope = true;
      };

      quickmath.enable = true;

      rainbow-delimiters.enable = true;

      telescope.enable = true;

      treesitter = {
	enable = true;
	settings.indent.enable = true;
      };
      cmp-treesitter.enable = true;

      web-devicons.enable = true;

      which-key.enable = true;

      cmp = {
        enable = true;
        autoEnableSources = true;

        settings = {
          sources = [
            { name = "nvim_lsp"; }
            { name = "path"; }
            { name = "buffer"; }
          ];
          mapping = {
            "<CR>" = "cmp.mapping.confirm({ select = true })";
          };
        };
      };
    };

    extraPlugins = [
      pkgs.vimPlugins."headlines-nvim"
      pkgs.vimPlugins."kmonad-vim"
      pkgs.vimPlugins."himalaya-vim"
    ];

    extraConfigLua = ''
    -- Linting function
      local lint = require("lint")
      local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      	group = lint_augroup,
      	callback = function()
      		lint.try_lint()
      	end,
      })

    local lint_progress = function()
    local linters = require("lint").get_running()
    if #linters == 0 then
    		return "󰦕"
    end
    	return "󱉶 " .. table.concat(linters, ", ")
    end

      vim.keymap.set("n", "<leader>l", function()
      	lint.try_lint()
      end, { desc = "Trigger linting for current file" })



      require("headlines").setup {
	markdown = {
	  query = vim.treesitter.query.parse(
	    "markdown",
            [[
	      (atx_heading [
		(atx_h1_marker)
		(atx_h2_marker)
		(atx_h3_marker)
		(atx_h4_marker)
		(atx_h5_marker)
		(atx_h6_marker)
	      ] @headline)

	      (thematic_break) @dash

	      (fenced_code_block) @codeblock

	      (block_quote_marker) @quote
	      (block_quote (paragraph (inline (block_continuation) @quote)))
	      (block_quote (paragraph (block_continuation) @quote))
	      (block_quote (block_continuation) @quote)
            ]]
	  ),
	  headline_highlights = { "Headline" },
	  bullet_highlights = {
            "@text.title.1.marker.markdown",
            "@text.title.2.marker.markdown",
            "@text.title.3.marker.markdown",
            "@text.title.4.marker.markdown",
            "@text.title.5.marker.markdown",
            "@text.title.6.marker.markdown",
	  },
	  bullets = { "◉", "○", "✸", "✿" },
	  codeblock_highlight = "CodeBlock",
	  dash_highlight = "Dash",
	  dash_string = "-",
	  quote_highlight = "Quote",
	  quote_string = "┃",
	  fat_headlines = true,
	  fat_headline_upper_string = "▃",
	  fat_headline_lower_string = "🬂",
	},
	rmd = {
	  query = vim.treesitter.query.parse(
            "markdown",
            [[
	      (atx_heading [
		(atx_h1_marker)
		(atx_h2_marker)
		(atx_h3_marker)
		(atx_h4_marker)
		(atx_h5_marker)
		(atx_h6_marker)
	      ] @headline)

	      (thematic_break) @dash

	      (fenced_code_block) @codeblock

	      (block_quote_marker) @quote
	      (block_quote (paragraph (inline (block_continuation) @quote)))
	      (block_quote (paragraph (block_continuation) @quote))
	      (block_quote (block_continuation) @quote)
            ]]
	  ),
	  treesitter_language = "markdown",
	  headline_highlights = { "Headline" },
	  bullet_highlights = {
            "@text.title.1.marker.markdown",
            "@text.title.2.marker.markdown",
            "@text.title.3.marker.markdown",
            "@text.title.4.marker.markdown",
            "@text.title.5.marker.markdown",
            "@text.title.6.marker.markdown",
	  },
	  bullets = { "◉", "○", "✸", "✿" },
	  codeblock_highlight = "CodeBlock",
	  dash_highlight = "Dash",
	  dash_string = "-",
	  quote_highlight = "Quote",
	  quote_string = "┃",
	  fat_headlines = true,
	  fat_headline_upper_string = "▃",
	  fat_headline_lower_string = "🬂",
	},
	norg = {
	  query = vim.treesitter.query.parse(
            "norg",
            [[
	      [
		(heading1_prefix)
		(heading2_prefix)
		(heading3_prefix)
		(heading4_prefix)
		(heading5_prefix)
		(heading6_prefix)
	      ] @headline

	      (weak_paragraph_delimiter) @dash
	      (strong_paragraph_delimiter) @doubledash

	      ([(ranged_tag
		  name: (tag_name) @_name
		  (#eq? @_name "code")
                )
                (ranged_verbatim_tag
		  name: (tag_name) @_name
		  (#eq? @_name "code")
	      )] @codeblock (#offset! @codeblock 0 0 1 0))

	      (quote1_prefix) @quote
            ]]
	  ),
	  headline_highlights = { "Headline" },
	  bullet_highlights = {
            "@neorg.headings.1.prefix",
            "@neorg.headings.2.prefix",
            "@neorg.headings.3.prefix",
            "@neorg.headings.4.prefix",
            "@neorg.headings.5.prefix",
            "@neorg.headings.6.prefix",
	  },
	  bullets = { "◉", "○", "✸", "✿" },
	  codeblock_highlight = "CodeBlock",
	  dash_highlight = "Dash",
	  dash_string = "-",
	  doubledash_highlight = "DoubleDash",
	  doubledash_string = "=",
	  quote_highlight = "Quote",
	  quote_string = "┃",
	  fat_headlines = true,
	  fat_headline_upper_string = "▃",
	  fat_headline_lower_string = "🬂",
	},
	org = {
	  query = vim.treesitter.query.parse(
	    "org",
	    [[
	      (headline (stars) @headline)

	      (
		(expr) @dash
		(#match? @dash "^-----+$")
	      )

	      (block
		name: (expr) @_name
		(#match? @_name "(SRC|src)")
	      ) @codeblock

	      (paragraph . (expr) @quote
		(#eq? @quote ">")
	      )
            ]]
	  ),
	  headline_highlights = { "Headline" },
	  bullet_highlights = {
            "@org.headline.level1",
            "@org.headline.level2",
            "@org.headline.level3",
            "@org.headline.level4",
            "@org.headline.level5",
            "@org.headline.level6",
            "@org.headline.level7",
            "@org.headline.level8",
	  },
	  bullets = { "◉", "○", "✸", "✿" },
	  codeblock_highlight = "CodeBlock",
	  dash_highlight = "Dash",
	  dash_string = "-",
	  quote_highlight = "Quote",
	  quote_string = "┃",
	  fat_headlines = true,
	  fat_headline_upper_string = "▃",
	  fat_headline_lower_string = "🬂",
	},
      }
    '';
  };
}
