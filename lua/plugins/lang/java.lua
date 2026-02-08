return {
  {
    'mfussenegger/nvim-jdtls',
    ft = 'java',
    config = function()
      local home = os.getenv 'HOME'
      local mason_path = vim.fn.stdpath 'data' .. '/mason/packages/jdtls'
      local jdtls_path = mason_path

      -- ============================================================================
      -- 1. ROBUST PATH FINDING (Lombok & JDTLS)
      -- ============================================================================

      -- Helper: Find Lombok JAR (Checks Mason, then Maven Local Repo)
      local function get_lombok_jar()
        -- Check Mason (sometimes included)
        local mason_lombok = vim.fn.glob(mason_path .. '/lombok.jar')
        if mason_lombok ~= '' then
          return mason_lombok
        end

        -- Check Standard Maven Local Repo (~/.m2)
        local lombok_version = '1.18.36' -- fallback version
        local m2_lombok = vim.fn.glob(home .. '/.m2/repository/org/projectlombok/lombok/*/lombok-*.jar', true, true)

        -- Return the latest version found in .m2
        if m2_lombok and #m2_lombok > 0 then
          return m2_lombok[#m2_lombok] -- usually the last one is the latest
        end

        return nil
      end

      -- Helper: Find JDTLS Launcher JAR
      local function get_launcher_jar()
        local launchers = vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar', true, true)
        if launchers and #launchers > 0 then
          return launchers[1]
        end
        return nil
      end

      -- Helper: Determine OS Configuration Directory
      local function get_config_dir()
        if vim.fn.has 'macunix' == 1 then
          return jdtls_path .. '/config_mac'
        elseif vim.fn.has 'win32' == 1 then
          return jdtls_path .. '/config_win'
        else
          return jdtls_path .. '/config_linux'
        end
      end

      -- ============================================================================
      -- 2. COMMAND CONSTRUCTION (The Fix)
      -- ============================================================================

      local launcher_jar = get_launcher_jar()
      local config_dir = get_config_dir()
      local lombok_jar = get_lombok_jar()
      local workspace_dir = vim.fn.stdpath 'cache' .. '/jdtls-workspace/' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t')

      -- Validation: Verify we found everything needed to launch
      if not launcher_jar or vim.fn.filereadable(launcher_jar) == 0 then
        vim.notify('JDTLS Launcher JAR not found in: ' .. jdtls_path, vim.log.levels.ERROR)
        return
      end

      -- The Java Command
      local cmd = {
        'java',

        -- JVM Settings
        '-Declipse.application=org.eclipse.jdt.ls.core.id1',
        '-Dosgi.bundles.defaultStartLevel=4',
        '-Declipse.product=org.eclipse.jdt.ls.core.product',
        '-Dlog.protocol=true',
        '-Dlog.level=ALL',
        '-Xms1g',
        '-Xmx2g',

        -- [CRITICAL FIX] Disable Develocity / Gradle Enterprise Extensions
        -- This prevents the "OutOfScopeException" crash during import
        '-Dgradle.scan.disabled=true',
        '-Ddevelocity.scan.disabled=true',
        '-Dskip.gradle.scan=true',

        -- Java 17+ Requirements
        '--add-modules=ALL-SYSTEM',
        '--add-opens',
        'java.base/java.util=ALL-UNNAMED',
        '--add-opens',
        'java.base/java.lang=ALL-UNNAMED',
      }

      -- Inject Lombok Agent if found
      if lombok_jar then
        table.insert(cmd, '-javaagent:' .. lombok_jar)
      else
        vim.notify('Lombok JAR not found. Lombok support will be disabled.', vim.log.levels.WARN)
      end

      -- Finalize Command
      vim.list_extend(cmd, {
        '-jar',
        launcher_jar,
        '-configuration',
        config_dir,
        '-data',
        workspace_dir,
      })

      -- ============================================================================
      -- 3. LSP SETUP (Capabilities & Handlers)
      -- ============================================================================

      local on_attach = function(client, bufnr)
        -- Enable debugger if available
        if pcall(require, 'jdtls') then
          require('jdtls').setup_dap { hotcodereplace = 'auto' }
          require('jdtls.dap').setup_dap_main_class_configs()
        end

        -- Standard Keymaps (Optional - add your own here)
        local opts = { buffer = bufnr }
        vim.keymap.set('n', '<leader>jo', "<Cmd>lua require'jdtls'.organize_imports()<CR>", opts)
        vim.keymap.set('n', '<leader>jtc', "<Cmd>lua require'jdtls'.test_class()<CR>", opts)
        vim.keymap.set('n', '<leader>jtm', "<Cmd>lua require'jdtls'.test_nearest_method()<CR>", opts)
      end

      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- Start the Server
      require('jdtls').start_or_attach {
        cmd = cmd,
        root_dir = require('jdtls.setup').find_root { '.git', 'mvnw', 'gradlew', 'pom.xml' },
        settings = {
          java = {
            eclipse = { downloadSources = true },
            configuration = { updateBuildConfiguration = 'interactive' },
            maven = { downloadSources = true },
            implementationsCodeLens = { enabled = true },
            referencesCodeLens = { enabled = true },
            inlayHints = { parameterNames = { enabled = 'all' } },
            signatureHelp = { enabled = true },
            contentProvider = { preferred = 'fernflower' }, -- Use standard decompiler
            sources = {
              organizeImports = {
                starThreshold = 9999,
                staticStarThreshold = 9999,
              },
            },
          },
        },
        capabilities = capabilities,
        on_attach = on_attach,
        flags = {
          allow_incremental_sync = true,
        },
        init_options = {
          bundles = {}, -- You can add debug/test adapter bundles here later
        },
      }
    end,
  },
}
