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
  };
}
