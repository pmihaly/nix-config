{
  pkgs,
  lib,
  config,
  inputs,
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

    home.packages = [
      inputs.cr.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    modules.persistence.directories = [
      ".local/share/nvim"
      ".local/share/db-ui"
    ];
    programs.bash.sessionVariables.EDITOR = getExe config.programs.nixvim.build.package;

    # plugins.lsp.servers.rust_analyzer.installCargo = true

    programs.nixvim = {
      enable = true;
      nixpkgs.source = inputs.nixpkgs;
      colorschemes.nord.enable = true;
      opts = {
        # Remove UI bloat
        showcmd = false;
        cmdheight = 0;
        laststatus = 0;

        # Keep the sign column allocated, so an lsp warning turning up does not
        # shove every line one character to the right
        signcolumn = "yes";

        # Invisible split separators
        fillchars = "vert: ,horiz: ,horizup: ,horizdown: ,vertleft: ,vertright: ,verthoriz: ";

        # Always center the cursor
        scrolloff = 999;

        # A new split lands where you are heading, and neovim moves you into it
        splitright = true;
        splitbelow = true;

        # Use system clipboard
        clipboard = "unnamedplus";
      };

      keymaps = [
        # Pasting over a selection keeps the register, instead of yanking what got replaced
        {
          mode = [ "x" ];
          key = "p";
          action = "P";
          options = {
            noremap = true;
          };
        }
      ];

      # scrolloff centers in-core with no lag, but gives up in the first and
      # last half screen - neovim won't scroll past either end of the buffer
      # for it. Only there, drop scrolloff and scroll by hand: past EOF that
      # is just <C-e>, and at BOF virtual lines padded above line 1 give
      # something to scroll into. Every step is relative to where the view
      # already is, so a cursor that is centered costs nothing -
      # stay-centered.nvim instead re-centers on every single move, which
      # buys an extra redraw per keypress everywhere.
      extraConfigLua = ''
        local ns = vim.api.nvim_create_namespace('center_cursor')
        local zoned = {}
        local up = vim.keycode('<C-y>')
        local down = vim.keycode('<C-e>')

        -- Virtual filler above line 1, so there is something to scroll into at the
        -- top. Only ever grows: a window that got taller needs more of it. Edits can
        -- drag the mark off the first line - splitting line 1 hands it to the new
        -- second line, and the filler with it, straight into the middle of the buffer
        -- - so check where it ended up, not just that it exists. Returns true when it
        -- had to (re)place the filler, which is not laid out until the next redraw.
        local function pad_top(buf, lines)
          local mark = vim.api.nvim_buf_get_extmark_by_id(buf, ns, 1, { details = true })
          if mark[1] == 0 and mark[2] == 0 and mark[3] and #mark[3].virt_lines >= lines then
            return false
          end

          local virt = {}
          for _ = 1, lines do
            virt[#virt + 1] = { { ''', 'NonText' } }
          end
          vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
            id = 1,
            virt_lines = virt,
            virt_lines_above = true,
            right_gravity = false, -- typing at the start of line 1 must not push it along
          })
          return true
        end

        -- Move the view one line towards the top of the buffer, or back down again.
        -- One line at a time, because a wrapped line is worth more than one screen row
        -- and a bigger step would overshoot.
        local function scroll_one(towards_top)
          if vim.startswith(vim.fn.mode(), 'i') then
            -- :normal! would leave insert mode for a moment, and come back with the
            -- cursor a column to its left, so shift the view by hand instead. topfill
            -- is how much of the filler above line 1 is on screen.
            local view = vim.fn.winsaveview()
            if towards_top and view.topline > 1 then
              view.topline = view.topline - 1
            elseif towards_top then
              view.topfill = view.topfill + 1
            elseif view.topfill > 0 then
              view.topfill = view.topfill - 1
            else
              view.topline = view.topline + 1
            end
            vim.fn.winrestview(view)
          else
            vim.cmd('normal! 1' .. (towards_top and up or down))
          end
        end

        -- Line-sized steps can straddle the middle rather than land on it, so stop as
        -- soon as a step stops bringing the cursor closer.
        local function scroll_to_middle(win, half)
          if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_get_current_win() ~= win then
            return
          end

          local cursor = vim.api.nvim_win_get_cursor(win)
          local closest = math.huge
          for _ = 1, half + 2 do
            local off = half - vim.fn.winline()
            if off == 0 or math.abs(off) >= closest then
              break -- centered, or as close as this window can get
            end
            closest = math.abs(off)
            scroll_one(off > 0)
          end

          -- scrolling shoves the cursor along rather than let it leave the window, and
          -- a cursor that centering moved is a keypress that did nothing
          local moved = vim.api.nvim_win_get_cursor(win)
          if moved[1] ~= cursor[1] or moved[2] ~= cursor[2] then
            vim.api.nvim_win_set_cursor(win, cursor)
          end
        end

        -- Filler that was just placed is not scrollable yet, and a view set before it
        -- is laid out gets thrown away on the next redraw. Hand the scroll back to the
        -- loop until it sticks.
        local function scroll_when_laid_out(win, half, tries)
          vim.schedule(function()
            scroll_to_middle(win, half)
            if tries > 1 and vim.fn.winline() ~= half then
              scroll_when_laid_out(win, half, tries - 1)
            end
          end)
        end

        local function hand_back_scrolloff(win)
          if zoned[win] then
            vim.wo[win].scrolloff = -1 -- back to the global value
            zoned[win] = false
          end
        end

        local function center_at_edges()
          local win = vim.api.nvim_get_current_win()

          -- a terminal belongs pinned to its last line, everything else - help,
          -- quickfix, scratch - reads like a file and centers like one
          if vim.bo.buftype == 'terminal' or vim.bo.buftype == 'prompt' then
            hand_back_scrolloff(win)
            return
          end

          local half = math.floor(vim.api.nvim_win_get_height(win) / 2)
          if half < 1 then
            return
          end

          local line = vim.fn.line('.')
          if line - 1 > half and vim.fn.line('$') - line >= half then
            hand_back_scrolloff(win)
            return
          end

          if not zoned[win] then
            vim.wo[win].scrolloff = 0
            zoned[win] = true
          end

          if pad_top(vim.api.nvim_get_current_buf(), half) then
            scroll_when_laid_out(win, half, 3)
          else
            scroll_to_middle(win, half)
          end
        end

        -- cleared, so re-sourcing this config replaces these instead of piling
        -- a second copy on top
        local group = vim.api.nvim_create_augroup('center_cursor', { clear = true })

        vim.api.nvim_create_autocmd({
          'CursorMoved',
          'CursorMovedI',
          'BufWinEnter',
          'WinEnter',
          'VimResized',
        }, { group = group, callback = center_at_edges })

        vim.api.nvim_create_autocmd('WinClosed', {
          group = group,
          callback = function(args)
            zoned[tonumber(args.match)] = nil
          end,
        })
      '';
      plugins = {
        lsp = {
          enable = true;
          servers = {
            # https://nix-community.github.io/nixvim/plugins/lsp/servers/ada_ls/index.html
            zuban = {
              enable = true; # python
              rootMarkers = [ "pyproject.toml" ];
            };
            nixd.enable = true;
            gopls.enable = true;
            vtsls.enable = true; # typescript
            rust_analyzer = {
              enable = true;
              installCargo = true;
              installRustc = true;
            };
          };
        };
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
              { name = "nvim_lsp"; }
              { name = "nvim_lsp_signature_help"; }
              { name = "buffer"; }
            ];
          };
        };
      };
    };
  };
}
