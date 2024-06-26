{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.nvim;
in
{
  options.modules.nvim = {
    enable = mkEnableOption "nvim";
  };
  config = mkIf cfg.enable {

    modules.persistence.directories = [
      ".local/share/nvim"
      ".config/github-copilot"
    ];

    programs.nixvim = {
      enable = true;

      extraConfigLua = ''
          -- remove trailing whitespace on save
          vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
            pattern = { '*' },
            command = [[%s/\s\+$//e]],
          })

          vim.api.nvim_create_autocmd({ 'FileType' }, {
            pattern = { 'help' },
            command = [[wincmd L]],
          })

          -- highlight yanked stuff
          local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
          vim.api.nvim_create_autocmd('TextYankPost', {
            callback = function()
              vim.highlight.on_yank()
            end,
            group = highlight_group,
            pattern = '*',
          })

        require('orgmode').setup({
          org_agenda_files = {'~/Sync/org/*'},
          org_default_notes_file = '~/Sync/org/refile.org',
        })

        require('org-bullets').setup({})

        require('dap.ext.vscode').load_launchjs()

        local dap, dapui = require("dap"), require("dapui")
        dap.listeners.before.attach.dapui_config = function()
          dapui.open()
        end
        dap.listeners.before.launch.dapui_config = function()
          dapui.open()
        end
        dap.listeners.before.event_terminated.dapui_config = function()
          dapui.close()
        end
        dap.listeners.before.event_exited.dapui_config = function()
          dapui.close()
        end
      '';

      editorconfig.enable = true;

      # https://nix-community.github.io/nixvim/plugins/telescope/index.html
      plugins = {
        indent-blankline = {
          enable = true;
          settings.scope.enabled = false;
        };
        gitsigns.enable = true;
        mini = {
          enable = true;
          modules = {
            starter = { };
            pairs = { };
            surround = { };
            ai = { };
          };
        };
        comment.enable = true;
        sleuth.enable = true;
        project-nvim.enable = true;
        markdown-preview = {
          enable = true;
          settings = {
            theme = "light";
          };
        };
        which-key.enable = true;
        copilot-lua = {
          enable = true;
          panel.enabled = false;
          suggestion.enabled = false;
        };
        floaterm = {
          enable = true;
          width = 150;
          height = 40;
          title = "";
          opener = "edit";
        };
        harpoon = {
          enable = true;
          enableTelescope = true;
          enterOnSendcmd = true;
          keymapsSilent = true;
        };

        copilot-cmp.enable = true;
        cmp = {
          enable = true;
          settings = {
            mapping = {
              "<C-Space>" = "cmp.mapping.complete()";
              "<C-d>" = "cmp.mapping.scroll_docs(-4)";
              "<C-e>" = "cmp.mapping.close()";
              "<C-f>" = "cmp.mapping.scroll_docs(4)";
              "<CR>" = "cmp.mapping.confirm({ select = true })";
              "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
              "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
            };
            sources = [
              { name = "copilot"; }
              { name = "nvim_lsp"; }
              { name = "nvim_lsp_signature_help"; }
              { name = "buffer"; }
            ];
          };
        };

        telescope = {
          enable = true;
          enabledExtensions = [ "dap" ];
          settings = {
            pickers = {
              find_command = [
                "rg"
                "--files"
                "--hidden"
                "-g"
                "!.git"
              ];
            };
          };
        };

        lsp = {
          enable = true;
          keymaps = {
            silent = true;
            diagnostic = {
              gan = "goto_next";
              gap = "goto_prev";
            };
            lspBuf = {
              K = "hover";
              gr = "references";
              gd = "definition";
              gt = "type_definition";
              gR = "rename";
            };
          };
          servers = {
            pyright.enable = true;
            tsserver.enable = true;
            dockerls.enable = true;
            docker-compose-language-service.enable = true;
            yamlls.enable = true;
            jsonls.enable = true;
            nil-ls.enable = true;
            gopls.enable = true;
            emmet-ls.enable = true;
          };
        };
        cmp-nvim-lsp.enable = true;

        treesitter = {
          enable = true;
          ensureInstalled = [
            "bash"
            "html"
            "javascript"
            "json"
            "kotlin"
            "lua"
            "markdown_inline"
            "nix"
            "python"
            "query"
            "regex"
            "terraform"
            "tsx"
            "typescript"
            "vim"
            "yaml"
            "org"
            "c"
          ];
        };
        undotree.enable = true;

        dap = {
          enable = true;
          signs = {
            dapBreakpoint = {
              text = "●";
              texthl = "DapBreakpoint";
            };
            dapBreakpointCondition = {
              text = "●";
              texthl = "DapBreakpointCondition";
            };
            dapLogPoint = {
              text = "◆";
              texthl = "DapLogPoint";
            };
          };
          extensions = {
            dap-python = {
              enable = true;
            };
            dap-ui = {
              enable = true;
              floating.mappings = {
                close = [
                  "<ESC>"
                  "q"
                ];
              };
              layouts = [
                {
                  elements = [
                    {
                      id = "scopes";
                      size = 0.25;
                    }
                    {
                      id = "breakpoints";
                      size = 0.25;
                    }
                    {
                      id = "stacks";
                      size = 0.25;
                    }
                    {
                      id = "watches";
                      size = 0.25;
                    }
                  ];
                  position = "left";
                  size = 50;
                }
                {
                  elements = [
                    {
                      id = "console";
                      size = 1;
                    }
                  ];
                  position = "right";
                  size = 75;
                }
              ];
            };
            dap-virtual-text = {
              enable = true;
            };
          };
        };
        oil = {
          enable = true;
          settings = {
            columns = [ "icon" ];
            view_options.show_hidden = true;
            win_options.signcolumn = "yes";
            skip_confirm_for_simple_edits = true;
            prompt_save_on_select_new_entry = false;
          };
        };
      };

      extraPlugins = with pkgs.vimPlugins; [
        orgmode
        vimspector
        (pkgs.vimUtils.buildVimPlugin {
          pname = "org-bullets";
          version = "2024-02-21";
          src = pkgs.fetchFromGitHub {
            owner = "akinsho";
            repo = "org-bullets.nvim";
            rev = "3623e86e0fa6d07f45042f7207fc333c014bf167";
            sha256 = "sha256-aIEe1dgUmDzu9kl33JCNcgyfp8DymURltH0HcZfph0Y=";
          };
        })
        (pkgs.vimUtils.buildVimPlugin {
          pname = "telescope-dap.nvim";
          version = "2024-01-08";
          src = pkgs.fetchFromGitHub {
            owner = "nvim-telescope";
            repo = "telescope-dap.nvim";
            rev = "8c88d9716c91eaef1cdea13cb9390d8ef447dbfe";
            sha256 = "sha256-P+ioBtupRvB3wcGKm77Tf/51k6tXKxJd176uupeW6v0=";
          };
        })
        (pkgs.vimUtils.buildVimPlugin {
          pname = "nvim-lspimport";
          version = "2024-03-10";
          src = pkgs.fetchFromGitHub {
            owner = "stevanmilic";
            repo = "nvim-lspimport";
            rev = "9c1c61a5020faeb1863bb66eb4b2a9107e641876";
            sha256 = "sha256-GIeuvGltgilFkYnKvsVYSogqQhDo1xcORy5jVtTz2cE=";
          };
        })
      ];

      keymaps = [
        {
          mode = [
            "n"
            "v"
          ];
          key = "<leader>";
          action = "<Nop>";
          options = {
            silent = true;
          };
        }

        {
          mode = [ "n" ];
          key = "k";
          action = "v:count == 0 ? 'gk' : 'k'";
          options = {
            expr = true;
            silent = true;
          };
        }
        {
          mode = [ "n" ];
          key = "j";
          action = "v:count == 0 ? 'gj' : 'j'";
          options = {
            expr = true;
            silent = true;
          };
        }

        {
          mode = [ "v" ];
          key = "<";
          action = "<gv";
          options = {
            noremap = true;
          };
        }
        {
          mode = [ "v" ];
          key = ">";
          action = ">gv";
          options = {
            noremap = true;
          };
        }

        {
          mode = [ "v" ];
          key = "J";
          action = ":m '>+1<cr>gv=gv";
          options = {
            noremap = true;
          };
        }
        {
          mode = [ "v" ];
          key = "K";
          action = ":m '<-2<cr>gv=gv";
          options = {
            noremap = true;
          };
        }

        {
          mode = [ "n" ];
          key = "<leader>ww";
          action = ":w<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>we";
          action = ":wq<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>q";
          action = ":q!<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>wv";
          action = ":vs<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>wh";
          action = "<C-w>h";
        }
        {
          mode = [ "n" ];
          key = "<leader>wj";
          action = "<C-w>j";
        }
        {
          mode = [ "n" ];
          key = "<leader>wk";
          action = "<C-w>k";
        }
        {
          mode = [ "n" ];
          key = "<leader>wl";
          action = "<C-w>l";
        }
        {
          mode = [ "n" ];
          key = "<leader>s";
          action = ":%s//g<Left><Left>";
        }
        {
          mode = [ "x" ];
          key = "p";
          action = "P";
          options = {
            noremap = true;
          };
        }

        {
          mode = [ "n" ];
          key = "<leader>mp";
          action = "<cmd>MarkdownPreview<cr>";
        }

        {
          mode = [
            "n"
            "t"
          ];
          key = "<leader>;";
          action = "<cmd>FloatermToggle<cr>";
        }

        {
          mode = [
            "n"
            "t"
          ];
          key = "<leader>,";
          action = "<cmd>FloatermToggle<cr>";
        }

        {
          mode = [ "n" ];
          key = "<leader>v";
          action = "<cmd>FloatermNew --autoclose=2 lazygit<cr>";
        }

        {
          mode = [ "n" ];
          key = "<leader>n";
          action = "<cmd>lua require('harpoon.mark').add_file()<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>i";
          action = "<cmd>lua require('harpoon.ui').toggle_quick_menu()<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>h";
          action = "<cmd>lua require('harpoon.ui').nav_file(1)<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>j";
          action = "<cmd>lua require('harpoon.ui').nav_file(2)<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>k";
          action = "<cmd>lua require('harpoon.ui').nav_file(3)<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>l";
          action = "<cmd>lua require('harpoon.ui').nav_file(4)<cr>";
        }

        {
          mode = [ "n" ];
          key = "<leader><leader>";
          action = "<cmd>Telescope find_files<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>g";
          action = "<cmd>Telescope live_grep<cr>";
        }

        {
          mode = [ "n" ];
          key = "<leader>u";
          action = "<cmd>UndotreeToggle<cr>";
        }

        {
          mode = [ "n" ];
          key = "<leader>dd";
          action = "<cmd>Telescope dap configurations<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>dr";
          action = "<cmd>lua require('dap').run_last()<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>dc";
          action = "<cmd>lua require('dap').continue()<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>dt";
          action = "<cmd>lua require('dap').toggle_breakpoint()<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>de";
          action = "<cmd>lua require('dap').repl.open()<cr>";
        }
        {
          mode = [
            "n"
            "v"
          ];
          key = "<leader>dk";
          action = "<cmd>lua require('dap.ui.widgets').hover()<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>dq";
          action = "<cmd>lua require('dap').terminate()<cr>";
        }
        {
          mode = [ "n" ];
          key = "<leader>f";
          action = "<cmd>Oil<cr>";
        }
        {

          mode = [ "n" ];
          key = "gi";
          action = "<cmd>lua require('lspimport').import()<cr>";
        }
      ];

      globals = {
        mapleader = " ";
      };

      opts = {
        # Set highlight on search
        hlsearch = false;
        incsearch = true;

        # Make line numbers default
        number = false;
        relativenumber = false;

        # Enable mouse mode
        mouse = "a";

        # Enable break indent
        breakindent = true;

        # Save undo history
        swapfile = false;
        backup = false;
        undodir = config.xdg.stateHome + "/nvim/undodir";
        undofile = true;

        # Case insensitive searching UNLESS /C or capital in search
        ignorecase = true;
        smartcase = true;

        # Decrease update time
        updatetime = 50;

        signcolumn = "yes";

        # Remove UI bloat
        showcmd = false;
        cmdheight = 0;
        laststatus = 0;

        splitright = true; # Vertical split to the right

        # Always center the cursor
        scrolloff = 999;

        # Use system clipboard
        clipboard = "unnamedplus";

        # Set prettier colors
        termguicolors = true;

        # Set completeopt to have a better completion experience
        completeopt = "menuone,noselect";
        conceallevel = 1;
      };
    };
  };
}
