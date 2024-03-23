{ config, lib, pkgs, ... }: {
  programs.nixvim = {
    enable = true;
    options = {
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
    '';

    plugins = {
      comment-nvim.enable = true;
      
      lualine.enable = true;
    
      lsp = {
        enable = true;
        servers = {
          # webdev
          tsserver.enable = true;
          tailwindcss.enable = true;
          eslint.enable = true;
          html.enable = true;
          cssls.enable = true;

          bashls.enable = true;


          ccls.enable = true;

          dockerls.enable = true;

          jsonls.enable = true;

          ltex.enable = true;
          texlab.enable = true;

          nil_ls.enable = true;

          pylsp.enable = true;

        };
      };

      markdown-preview.enable = true;

      nvim-autopairs = {
	enable = true;
	checkTs = true; # use TreeSitter
      };

      nvim-colorizer.enable = true;

      project-nvim.enable = true;

      quickmath.enable = true;

      rainbow-delimiters.enable = true;

      telescope = {
	enable = true;
	extensions.project-nvim.enable = true;
      };

      treesitter = {
	enable = true;
	indent = true;
      };
      cmp-treesitter.enable = true;

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
    ];

    extraConfigLua = ''
      require("headlines").setup {
	markdown = {
	  query = vim.treesitter.query.parse_query(
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
	  query = vim.treesitter.query.parse_query(
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
	  query = vim.treesitter.query.parse_query(
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
	  query = vim.treesitter.query.parse_query(
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
