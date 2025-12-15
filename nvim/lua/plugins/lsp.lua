return {
	-- LSP Configuration
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			-- Setup Mason
			require("mason").setup({
				ui = {
					border = "rounded",
					icons = {
						package_installed = "✓",
						package_pending = "➜",
						package_uninstalled = "✗",
					},
				},
			})

			-- Setup Mason LSP
			require("mason-lspconfig").setup({
				ensure_installed = {
					"eslint", -- ESLint
					"intelephense", -- PHP
					"bashls", -- Bash
					"rust_analyzer", -- Rust
				},
				automatic_installation = true,
			})

			-- Capabilities for autocompletion
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- On attach function for keymaps
			local on_attach = function(client, bufnr)
				local opts = { buffer = bufnr, silent = true }

				vim.keymap.set(
					"n",
					"gd",
					vim.lsp.buf.definition,
					vim.tbl_extend("force", opts, { desc = "Go to definition" })
				)
				vim.keymap.set(
					"n",
					"gD",
					vim.lsp.buf.declaration,
					vim.tbl_extend("force", opts, { desc = "Go to declaration" })
				)
				vim.keymap.set(
					"n",
					"gi",
					vim.lsp.buf.implementation,
					vim.tbl_extend("force", opts, { desc = "Go to implementation" })
				)
				vim.keymap.set(
					"n",
					"gr",
					vim.lsp.buf.references,
					vim.tbl_extend("force", opts, { desc = "Go to references" })
				)
				vim.keymap.set(
					"n",
					"K",
					vim.lsp.buf.hover,
					vim.tbl_extend("force", opts, { desc = "Hover documentation" })
				)
				vim.keymap.set(
					"n",
					"<leader>ca",
					vim.lsp.buf.code_action,
					vim.tbl_extend("force", opts, { desc = "Code action" })
				)
				vim.keymap.set(
					"n",
					"<leader>rn",
					vim.lsp.buf.rename,
					vim.tbl_extend("force", opts, { desc = "Rename" })
				)
				vim.keymap.set(
					"n",
					"<leader>d",
					vim.diagnostic.open_float,
					vim.tbl_extend("force", opts, { desc = "Show diagnostics" })
				)
				vim.keymap.set(
					"n",
					"[d",
					vim.diagnostic.goto_prev,
					vim.tbl_extend("force", opts, { desc = "Previous diagnostic" })
				)
				vim.keymap.set(
					"n",
					"]d",
					vim.diagnostic.goto_next,
					vim.tbl_extend("force", opts, { desc = "Next diagnostic" })
				)
			end

			-- Common server configuration
			local default_config = {
				capabilities = capabilities,
				on_attach = on_attach,
			}

			-- -- TypeScript/JavaScript/React
			-- vim.lsp.config(
			-- 	"ts_ls",
			-- 	vim.tbl_extend("force", default_config, {
			-- 		settings = {
			-- 			typescript = {
			-- 				inlayHints = {
			-- 					includeInlayParameterNameHints = "all",
			-- 					includeInlayFunctionParameterTypeHints = true,
			-- 				},
			-- 			},
			-- 			javascript = {
			-- 				inlayHints = {
			-- 					includeInlayParameterNameHints = "all",
			-- 					includeInlayFunctionParameterTypeHints = true,
			-- 				},
			-- 			},
			-- 		},
			-- 	})
			-- )

			-- ESLint
			vim.lsp.config(
				"eslint",
				vim.tbl_extend("force", default_config, {
					on_attach = function(client, bufnr)
						on_attach(client, bufnr)
						-- Auto-fix on save
						vim.api.nvim_create_autocmd("BufWritePre", {
							buffer = bufnr,
							command = "EslintFixAll",
						})
					end,
				})
			)

			-- PHP (Intelephense)
			vim.lsp.config(
				"intelephense",
				vim.tbl_extend("force", default_config, {
					settings = {
						intelephense = {
							files = {
								maxSize = 5000000,
							},
						},
					},
				})
			)

			-- Bash
			vim.lsp.config("bashls", default_config)

			-- Go
			vim.lsp.config(
				"gopls",
				vim.tbl_extend("force", default_config, {
					settings = {
						gopls = {
							analyses = {
								unusedparams = true,
							},
							staticcheck = true,
							gofumpt = true,
						},
					},
				})
			)

			-- Rust
			vim.lsp.config(
				"rust_analyzer",
				vim.tbl_extend("force", default_config, {
					settings = {
						["rust-analyzer"] = {
							checkOnSave = {
								command = "clippy",
							},
							cargo = {
								allFeatures = true,
							},
						},
					},
				})
			)

			-- Lua
			vim.lsp.config(
				"lua_ls",
				vim.tbl_extend("force", default_config, {
					settings = {
						Lua = {
							runtime = {
								version = "LuaJIT",
							},
							diagnostics = {
								globals = { "vim" }, -- Recognize 'vim' global
							},
							workspace = {
								library = {
									vim.env.VIRTUAL_RUNTIME,
									"${3rd}/luv/library",
								},
								checkThirdParty = false,
							},
							telemetry = {
								enable = false,
							},
						},
					},
				})
			)

			-- Enable the LSP servers when their filetypes are detected
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
				callback = function()
					vim.lsp.enable("ts_ls")
					vim.lsp.enable("eslint")
				end,
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "php",
				callback = function()
					vim.lsp.enable("intelephense")
				end,
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "sh", "bash" },
				callback = function()
					vim.lsp.enable("bashls")
				end,
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "go",
				callback = function()
					vim.lsp.enable("gopls")
				end,
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "rust",
				callback = function()
					vim.lsp.enable("rust_analyzer")
				end,
			})

			-- Diagnostic configuration
			vim.diagnostic.config({
				virtual_text = true,
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = {
					border = "rounded",
					source = "always",
				},
			})

			-- Diagnostic signs
			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
				vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
			end
		end,
	},

	-- Mason tool installer
	{
		"williamboman/mason.nvim",
		build = ":MasonUpdate",
	},

	-- Mason LSP config bridge
	{
		"williamboman/mason-lspconfig.nvim",
	},
}
