return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#0b0f1a',
				base01 = '#0b0f1a',
				base02 = '#a59496',
				base03 = '#a59496',
				base04 = '#ffe9ec',
				base05 = '#fff6f7',
				base06 = '#fff6f7',
				base07 = '#fff6f7',
				base08 = '#ff7a7c',
				base09 = '#ff7a7c',
				base0A = '#ff687c',
				base0B = '#9fff83',
				base0C = '#ffafba',
				base0D = '#ff687c',
				base0E = '#ff8393',
				base0F = '#ff8393',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#a59496',
				fg = '#fff6f7',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#ff687c',
				fg = '#0b0f1a',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#a59496' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#ffafba', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#ff8393',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#ff687c',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#ff687c',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#ffafba',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#9fff83',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#ffe9ec' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#ffe9ec' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#a59496',
				italic = true
			})

			local current_file_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
			if not _G._matugen_theme_watcher then
				local uv = vim.uv or vim.loop
				_G._matugen_theme_watcher = uv.new_fs_event()
				_G._matugen_theme_watcher:start(current_file_path, {}, vim.schedule_wrap(function()
					local new_spec = dofile(current_file_path)
					if new_spec and new_spec[1] and new_spec[1].config then
						new_spec[1].config()
						print("Theme reload")
					end
				end))
			end
		end
	}
}
