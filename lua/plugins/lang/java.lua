return {
  {
    'mfussenegger/nvim-jdtls',
    ft = 'java',
    config = function()
      -- ============================================================================
      -- 1. ROBUST PATH FINDING (System First -> Mason Fallback)
      -- ============================================================================

      -- Attempt 1: Check system PATH (e.g. /usr/bin/jdtls, brew, etc.)
      local jdtls_bin = vim.fn.exepath 'jdtls'

      -- Attempt 2: Check Mason (only if system binary is missing)
      if jdtls_bin == '' then
        local mason_bin = vim.fn.stdpath 'data' .. '/mason/bin/jdtls'
        if vim.fn.executable(mason_bin) == 1 then
          jdtls_bin = mason_bin
        end
      end

      -- Fail gracefully if absolutely nothing is found
      if jdtls_bin == '' then
        vim.notify('JDTLS executable not found in PATH or Mason.', vim.log.levels.ERROR)
        return
      end

      -- ============================================================================
      -- 2. THE FIX: Inject Disable Flags via Environment Variable
      -- ============================================================================
      -- We set JAVA_TOOL_OPTIONS within the Neovim process.
      -- Any child process (like JDTLS) will inherit this.
      -- The JVM reads this variable automatically at startup.
      local disable_flags = ' -Dgradle.scan.disabled=true -Ddevelocity.scan.disabled=true -Dskip.gradle.scan=true'
      local current_opts = vim.env.JAVA_TOOL_OPTIONS or ''

      -- Only append if not already present to avoid infinite growth on reloads
      if not string.find(current_opts, 'gradle.scan.disabled') then
        vim.env.JAVA_TOOL_OPTIONS = current_opts .. disable_flags
      end

      -- ============================================================================
      -- 3. LOMBOK DISCOVERY (M2 -> Mason -> Local)
      -- ============================================================================
      local lombok_jar = nil
      local paths_to_check = {
        -- Check local Maven repo (most likely place for devs)
        vim.fn.glob(os.getenv 'HOME' .. '/.m2/repository/org/projectlombok/lombok/*/lombok-*.jar', true, true),
        -- Check Mason package path
        vim.fn.glob(vim.fn.stdpath 'data' .. '/mason/packages/jdtls/lombok.jar', true, true),
      }

      for _, path_list in ipairs(paths_to_check) do
        if type(path_list) == 'table' and #path_list > 0 then
          -- Use the last one (usually highest version in .m2)
          lombok_jar = path_list[#path_list]
          break
        elseif type(path_list) == 'string' and path_list ~= '' then
          lombok_jar = path_list
          break
        end
      end

      -- ============================================================================
      -- 4. SERVER CONFIGURATION
      -- ============================================================================
      local home = os.getenv 'HOME'
      local workspace_dir = vim.fn.stdpath 'cache' .. '/jdtls-workspace/' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t')

      local cmd = { jdtls_bin }

      -- Add Lombok agent to the command if found
      -- Note: Even though we set JAVA_TOOL_OPTIONS, adding the agent explicitly
      -- to the command args is often safer for the wrapper script to handle properly.
      if lombok_jar then
        table.insert(cmd, '--jvm-arg=-javaagent:' .. lombok_jar)
      end

      vim.list_extend(cmd, {
        '-data',
        workspace_dir,
      })

      -- Capabilities
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      local on_attach = function(client, bufnr)
        if pcall(require, 'jdtls') then
          require('jdtls').setup_dap { hotcodereplace = 'auto' }
        end
      end

      require('jdtls').start_or_attach {
        cmd = cmd,
        root_dir = require('jdtls.setup').find_root { '.git', 'mvnw', 'gradlew', 'pom.xml' },
        settings = {
          java = {
            eclipse = { downloadSources = true },
            maven = { downloadSources = true },
            configuration = { updateBuildConfiguration = 'interactive' },
            signatureHelp = { enabled = true },
            contentProvider = { preferred = 'fernflower' },
          },
        },
        capabilities = capabilities,
        on_attach = on_attach,
      }
    end,
  },
}
