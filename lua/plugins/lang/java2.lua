local java_filetypes = { 'java' }

local excluded_test_bundles = {
  ['com.microsoft.java.test.runner-jar-with-dependencies.jar'] = true,
  ['jacocoagent.jar'] = true,
}

local sync_running = {}
local dap_setup_done = {}
local warned = {}

---@param s string|nil
---@return string[]
local function split_words(s)
  return (s and s ~= '') and vim.split(s, '%s+', { trimempty = true }) or {}
end

---@param paths string[]
---@return string[]
local function dedupe_files(paths)
  local out, seen = {}, {}
  for _, path in ipairs(paths or {}) do
    if path and path ~= '' then
      local normalized = vim.fs.normalize(path)
      if vim.fn.filereadable(normalized) == 1 and not seen[normalized] then
        seen[normalized] = true
        table.insert(out, normalized)
      end
    end
  end
  return out
end

---@param out string[]
---@param pattern string
local function extend_with_glob(out, pattern)
  local matches = vim.fn.glob(pattern, true, true)
  if type(matches) ~= 'table' then
    return
  end
  for _, path in ipairs(matches) do
    if path and path ~= '' then
      table.insert(out, path)
    end
  end
end

---@param file string
---@return string|nil
local function detect_root(file)
  return vim.fs.root(file, {
    '.mvn',
    'mvnw',
    'pom.xml',
    'build.gradle',
    'build.gradle.kts',
    'settings.gradle',
    'settings.gradle.kts',
    '.git',
  })
end

---@param root string
---@return string
local function project_key(root)
  return vim.fs.basename(root) .. '-' .. vim.fn.sha256(vim.fs.normalize(root)):sub(1, 10)
end

---@param cands string[]
---@return string|nil
local function first_executable(cands)
  for _, cand in ipairs(cands) do
    if cand and cand ~= '' and vim.fn.executable(cand) == 1 then
      return cand
    end
  end
  return nil
end

---@return string|nil
local function detect_java_bin()
  local java_home = vim.env.JDTLS_JAVA_HOME or vim.env.JAVA_HOME
  local home_java = (java_home and java_home ~= '') and (java_home .. '/bin/java') or nil
  return first_executable {
    vim.env.JDTLS_JAVA_BIN,
    home_java,
    vim.fn.exepath 'java',
  }
end

---@return string|nil, string|nil
local function detect_jdtls_bin()
  if vim.env.JDTLS_BIN and vim.env.JDTLS_BIN ~= '' and vim.fn.executable(vim.env.JDTLS_BIN) == 1 then
    return vim.env.JDTLS_BIN, 'JDTLS_BIN'
  end
  local from_path = vim.fn.exepath 'jdtls'
  if from_path ~= '' then
    return from_path, 'PATH:jdtls'
  end
  for _, cand in ipairs {
    vim.fn.expand '~/.local/bin/jdtls',
    '/opt/homebrew/bin/jdtls',
    '/usr/local/bin/jdtls',
  } do
    if vim.fn.executable(cand) == 1 then
      return cand, 'common-bin:' .. cand
    end
  end
  local home = vim.env.JDTLS_HOME
  local home_bin = (home and home ~= '') and (home .. '/bin/jdtls') or nil
  if home_bin and vim.fn.executable(home_bin) == 1 then
    return home_bin, 'JDTLS_HOME/bin/jdtls'
  end
  local mason_root = vim.fn.stdpath 'data' .. '/mason'
  local mason_bin = mason_root .. '/bin/jdtls'
  if vim.fn.executable(mason_bin) == 1 then
    return mason_bin, 'mason/bin/jdtls'
  end
  local mason_pkg_bin = mason_root .. '/packages/jdtls/bin/jdtls'
  if vim.fn.executable(mason_pkg_bin) == 1 then
    return mason_pkg_bin, 'mason/packages/jdtls/bin/jdtls'
  end
  local mason_pkg = mason_root .. '/packages/jdtls/jdtls'
  if vim.fn.executable(mason_pkg) == 1 then
    return mason_pkg, 'mason/packages/jdtls/jdtls'
  end
  return nil, nil
end

---@return string[]
local function detect_dap_bundles()
  local explicit = vim.env.JDTLS_DAP_BUNDLES
  if explicit and explicit ~= '' then
    local bundles = {}
    local separator = vim.fn.has 'win32' == 1 and ';' or ':'
    for _, item in ipairs(vim.split(explicit, separator, { trimempty = true })) do
      if vim.fn.filereadable(item) == 1 then
        table.insert(bundles, item)
      elseif vim.fn.isdirectory(item) == 1 then
        extend_with_glob(bundles, item .. '/**/*.jar')
      else
        extend_with_glob(bundles, item)
      end
    end
    return dedupe_files(bundles)
  end

  local bundles = {}
  local mason = vim.fn.stdpath 'data' .. '/mason/packages'
  extend_with_glob(bundles, mason .. '/java-debug-adapter/**/com.microsoft.java.debug.plugin-*.jar')
  extend_with_glob(bundles, mason .. '/java-test/**/*.jar')

  local root = vim.env.JDTLS_DAP_BUNDLES_ROOT
  if root and root ~= '' then
    extend_with_glob(bundles, root .. '/java-debug/**/com.microsoft.java.debug.plugin-*.jar')
    extend_with_glob(bundles, root .. '/java-test/**/*.jar')
  end

  local filtered = {}
  for _, jar in ipairs(dedupe_files(bundles)) do
    if not excluded_test_bundles[vim.fs.basename(jar)] then
      table.insert(filtered, jar)
    end
  end
  return filtered
end

---@param config_dir string
---@param workspace_dir string
---@return string[]|nil, string|nil, string|nil
local function build_cmd(config_dir, workspace_dir)
  local java_bin = detect_java_bin()
  if not java_bin then
    return nil, nil, 'java-not-found'
  end
  local jdtls_bin, jdtls_source = detect_jdtls_bin()
  if not jdtls_bin then
    return nil, nil, 'jdtls-not-found'
  end

  local jvm_args = split_words(vim.env.JDTLS_JVM_ARGS)
  if vim.tbl_isempty(jvm_args) then
    jvm_args = {
      '-Xms1g',
      '-Xmx2g',
      '-Dgradle.scan.disabled=true',
      '-Ddevelocity.scan.disabled=true',
    }
  end

  local cmd = {
    jdtls_bin,
    '--java-executable=' .. java_bin,
  }

  local lombok_jar = vim.env.JDTLS_LOMBOK_JAR
  if lombok_jar and lombok_jar ~= '' and vim.fn.filereadable(lombok_jar) == 1 then
    table.insert(cmd, '--jvm-arg=-javaagent:' .. lombok_jar)
  end

  for _, arg in ipairs(jvm_args) do
    table.insert(cmd, '--jvm-arg=' .. arg)
  end

  vim.list_extend(cmd, {
    '-configuration',
    config_dir,
    '-data',
    workspace_dir,
  })

  return cmd, jdtls_source, nil
end

---@param root string
---@param bundles string[]
local function setup_dap(root, bundles)
  local key = root ~= '' and root or '__global__'
  if dap_setup_done[key] then
    return
  end
  if vim.tbl_isempty(bundles) then
    if not warned[key .. ':dap-empty'] then
      warned[key .. ':dap-empty'] = true
      vim.notify('[java2] Java debug bundles not found (mason java-debug-adapter/java-test).', vim.log.levels.WARN)
    end
    return
  end

  local ok_jdtls, jdtls = pcall(require, 'jdtls')
  if not ok_jdtls then
    return
  end
  local ok_setup = pcall(jdtls.setup_dap, { hotcodereplace = 'auto', config_overrides = {} })
  local ok_main = pcall(function()
    require('jdtls.dap').setup_dap_main_class_configs()
  end)
  if ok_setup and ok_main then
    dap_setup_done[key] = true
    return
  end

  if not warned[key .. ':dap-init'] then
    warned[key .. ':dap-init'] = true
    vim.notify('[java2] Failed to initialize Java DAP integration.', vim.log.levels.WARN)
  end
end

---@param client table
---@param method string
---@param bufnr integer
---@return boolean
local function client_supports_method(client, method, bufnr)
  return client:supports_method(method, bufnr)
end

---@param root string
---@param bufnr integer|nil
local function refresh(root, bufnr)
  bufnr = bufnr or 0
  for _, client in ipairs(vim.lsp.get_clients { name = 'jdtls' }) do
    if client and client.config and client.config.root_dir == root then
      if client_supports_method(client, 'workspace/executeCommand', bufnr) then
        client:request('workspace/executeCommand', { command = 'java.project.import', arguments = {} }, nil, bufnr)
        client:request('workspace/executeCommand', { command = 'java.project.refreshDiagnostics', arguments = {} }, nil, bufnr)
      end
      if client_supports_method(client, 'java/projectConfigurationUpdate', bufnr) then
        client:request('java/projectConfigurationUpdate', { uri = vim.uri_from_bufnr(bufnr) }, nil, bufnr)
      end
    end
  end
end

---@param root string
---@param force boolean
local function maven_sync(root, force)
  if sync_running[root] then
    vim.notify('[java2] Maven sync already running.', vim.log.levels.INFO)
    return
  end

  local cmd = {}
  local mvnw = root .. '/mvnw'
  if vim.fn.executable(mvnw) == 1 then
    table.insert(cmd, mvnw)
  elseif vim.fn.executable 'mvn' == 1 then
    table.insert(cmd, 'mvn')
  else
    vim.notify('[java2] Maven executable not found (`mvnw` or `mvn`).', vim.log.levels.ERROR)
    return
  end

  if force then
    table.insert(cmd, '-U')
  end

  vim.list_extend(cmd, split_words(vim.env.JDTLS_MAVEN_SYNC_FLAGS or '-DskipTests -DskipITs -Dmaven.test.skip=true'))
  local goals = split_words(vim.env.JDTLS_MAVEN_SYNC_GOALS or 'generate-sources')
  vim.list_extend(cmd, vim.tbl_isempty(goals) and { 'generate-sources' } or goals)

  if not vim.system then
    vim.notify('[java2] vim.system is required for :JdtMavenSync.', vim.log.levels.ERROR)
    return
  end

  sync_running[root] = true
  vim.notify('[java2] Running: ' .. table.concat(cmd, ' '), vim.log.levels.INFO)
  ---@param result { code: integer, stdout: string|nil, stderr: string|nil }
  vim.system(cmd, { cwd = root, text = true }, function(result)
    vim.schedule(function()
      sync_running[root] = nil
      if result.code == 0 then
        vim.notify('[java2] Maven sync finished. Refreshing JDTLS...', vim.log.levels.INFO)
        refresh(root, 0)
        return
      end
      local text = (result.stderr and result.stderr ~= '') and result.stderr or (result.stdout or '')
      local lines, start = vim.split(text, '\n', { trimempty = true }), 1
      if #lines > 10 then
        start = #lines - 9
      end
      vim.notify('[java2] Maven sync failed.\n' .. table.concat(vim.list_slice(lines, start, #lines), '\n'), vim.log.levels.ERROR)
    end)
  end)
end

---@return table
local function capabilities()
  local caps = vim.lsp.protocol.make_client_capabilities()
  local ok, blink = pcall(require, 'blink.cmp')
  if ok and blink.get_lsp_capabilities then
    caps = blink.get_lsp_capabilities(caps)
  end
  return caps
end

---@param settings table|nil
---@return table
local function build_settings(settings)
  return vim.tbl_deep_extend('force', {
    java = {
      configuration = {
        updateBuildConfiguration = 'interactive',
      },
      format = { enabled = true },
      import = {
        gradle = { enabled = true },
        maven = { enabled = true },
      },
      referencesCodeLens = { enabled = true },
      implementationsCodeLens = { enabled = true },
      signatureHelp = { enabled = true },
      errors = { incompleteClasspath = { severity = 'warning' } },
    },
  }, settings or {})
end

---@param module any
---@param adapter_opts table|nil
---@return any|nil
local function materialize_adapter(module, adapter_opts)
  local mt = type(module) == 'table' and getmetatable(module) or nil
  local is_callable_table = mt and type(mt.__call) == 'function'
  if type(module) == 'function' or is_callable_table then
    local ok_adapter, adapter = pcall(module, adapter_opts or {})
    return ok_adapter and adapter or nil
  end
  if type(module) == 'table' and type(module.setup) == 'function' then
    local ok_adapter, adapter = pcall(module.setup, adapter_opts or {})
    return ok_adapter and adapter or nil
  end
  if type(module) == 'table' and type(module.adapter) == 'function' then
    local ok_adapter, adapter = pcall(module.adapter, adapter_opts or {})
    return ok_adapter and adapter or nil
  end
  return module
end

---@param adapter_specs table
---@return table
local function normalize_adapters(adapter_specs)
  if vim.islist(adapter_specs) then
    return adapter_specs
  end
  local adapters = {}
  for name, adapter_opts in pairs(adapter_specs or {}) do
    local ok_module, module = pcall(require, name)
    if ok_module then
      local adapter = materialize_adapter(module, adapter_opts)
      if adapter then
        table.insert(adapters, adapter)
      end
    end
  end
  return adapters
end

return {
  {
    'nvim-treesitter/nvim-treesitter',
    opts = function(_, opts)
      opts = opts or {}
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, 'java') then
        table.insert(opts.ensure_installed, 'java')
      end
    end,
  },
  {
    'mason-org/mason.nvim',
    optional = true,
    event = 'VeryLazy',
    opts = function(_, opts)
      opts = opts or {}
      opts.ensure_installed = opts.ensure_installed or {}
      for _, pkg in ipairs { 'jdtls', 'java-debug-adapter', 'java-test' } do
        if not vim.tbl_contains(opts.ensure_installed, pkg) then
          table.insert(opts.ensure_installed, pkg)
        end
      end
      return opts
    end,
  },
  {
    'nvim-neotest/neotest',
    optional = true,
    dependencies = {
      {
        'sergii-dudar/neotest-java',
        ft = java_filetypes,
      },
    },
    opts = function(_, opts)
      opts = opts or {}
      if vim.islist(opts.adapters) then
        return opts
      end
      opts.adapters = type(opts.adapters) == 'table' and opts.adapters or {}
      local existing = type(opts.adapters['neotest-java']) == 'table' and opts.adapters['neotest-java'] or {}
      opts.adapters['neotest-java'] = vim.tbl_deep_extend('force', {
        incremental_build = true,
      }, existing)
      return opts
    end,
    config = function(_, opts)
      opts = opts or {}
      opts.adapters = normalize_adapters(type(opts.adapters) == 'table' and opts.adapters or {})
      require('neotest').setup(opts)
    end,
  },
  {
    'mfussenegger/nvim-jdtls',
    ft = java_filetypes,
    dependencies = {
      'neovim/nvim-lspconfig',
      'saghen/blink.cmp',
      'mfussenegger/nvim-dap',
    },
    opts = {
      settings = {},
      jdtls = {},
    },
    config = function(_, opts)
      opts = opts or {}
      opts.settings = type(opts.settings) == 'table' and opts.settings or {}
      opts.jdtls = type(opts.jdtls) == 'table' and opts.jdtls or {}

      local bundles_by_root = {}

      ---@param client table
      ---@param bufnr integer
      local function on_attach(client, bufnr)
        local map = function(lhs, rhs, desc)
          vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = desc })
        end

        local ok_jdtls, jdtls = pcall(require, 'jdtls')
        if ok_jdtls then
          map('<leader>jo', jdtls.organize_imports, 'Java: Organize imports')
          map('<leader>jv', jdtls.extract_variable, 'Java: Extract variable')
          map('<leader>jc', jdtls.extract_constant, 'Java: Extract constant')
          map('<leader>jm', function()
            jdtls.extract_method(true)
          end, 'Java: Extract method')
          map('<leader>jt', jdtls.test_nearest_method, 'Java: Test nearest method')
          map('<leader>jT', jdtls.test_class, 'Java: Test class')
        end

        map('<leader>gt', function()
          require('neotest').run.run()
        end, 'Java: Test nearest (neotest)')
        map('<leader>gT', function()
          require('neotest').run.run(vim.fn.expand '%:p')
        end, 'Java: Test class/file (neotest)')
        map('<leader>dt', function()
          require('neotest').run.run { strategy = 'dap' }
        end, 'Java: Debug nearest test (neotest)')

        local root = (client and client.config and client.config.root_dir) or ''
        if root ~= '' then
          setup_dap(root, bundles_by_root[root] or {})
        end
        if type(opts.jdtls.on_attach) == 'function' then
          opts.jdtls.on_attach(client, bufnr)
        end
      end

      local function attach()
        if vim.bo.filetype ~= 'java' then
          return
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local file = vim.api.nvim_buf_get_name(bufnr)
        if file == '' then
          return
        end

        local root = detect_root(file)
        if not root then
          return
        end

        local key = project_key(root)
        local base_dir = vim.fn.stdpath 'cache' .. '/jdtls/' .. key
        local config_dir = base_dir .. '/config'
        local workspace_dir = base_dir .. '/workspace'
        vim.fn.mkdir(config_dir, 'p')
        vim.fn.mkdir(workspace_dir, 'p')

        local cmd, cmd_source, cmd_error = build_cmd(config_dir, workspace_dir)
        if not cmd then
          if cmd_error == 'java-not-found' and not warned['java-missing'] then
            warned['java-missing'] = true
            vim.notify('[java2] Java runtime not found. Set JDTLS_JAVA_BIN/JDTLS_JAVA_HOME/JAVA_HOME or add java to PATH.', vim.log.levels.WARN)
          elseif cmd_error == 'jdtls-not-found' and not warned['jdtls-missing'] then
            warned['jdtls-missing'] = true
            vim.notify('[java2] jdtls not found. Set JDTLS_BIN, JDTLS_HOME, add jdtls to PATH, or install via Mason.', vim.log.levels.WARN)
          end
          return
        end

        local bundles = detect_dap_bundles()
        local cfg = {
          cmd = cmd,
          root_dir = root,
          settings = build_settings(opts.settings),
          capabilities = capabilities(),
          on_attach = on_attach,
          init_options = {
            bundles = bundles,
          },
        }

        local user_jdtls = vim.deepcopy(opts.jdtls)
        user_jdtls.on_attach = nil
        cfg = vim.tbl_deep_extend('force', cfg, user_jdtls)
        bundles_by_root[root] = (type(cfg.init_options) == 'table' and type(cfg.init_options.bundles) == 'table') and cfg.init_options.bundles or bundles

        vim.g.ba_jdtls_last = {
          root_dir = root,
          workspace_dir = workspace_dir,
          cmd_source = cmd_source,
          cmd = cfg.cmd,
          dap_bundle_count = #bundles_by_root[root],
          dap_bundles = bundles_by_root[root],
        }

        require('jdtls').start_or_attach(cfg)
      end

      local group = vim.api.nvim_create_augroup('ba-java2-jdtls', { clear = true })
      vim.api.nvim_create_autocmd('FileType', { group = group, pattern = java_filetypes, callback = attach })

      local function create_user_command_once(name, rhs, command_opts)
        if vim.fn.exists(':' .. name) == 0 then
          vim.api.nvim_create_user_command(name, rhs, command_opts)
        end
      end

      local function root_from_current_buffer()
        local file = vim.api.nvim_buf_get_name(0)
        return (file ~= '') and detect_root(file) or nil
      end

      create_user_command_once('JdtlsStatus', function()
        vim.notify(vim.inspect(vim.g.ba_jdtls_last or {}), vim.log.levels.INFO)
      end, { desc = 'Show jdtls status' })

      create_user_command_once('JdtProjectsRefresh', function()
        local root = root_from_current_buffer()
        if not root then
          vim.notify('[java2] Cannot refresh: no Java root detected.', vim.log.levels.WARN)
          return
        end
        refresh(root, 0)
        vim.notify('[java2] Triggered JDTLS refresh.', vim.log.levels.INFO)
      end, { desc = 'Refresh JDTLS import/build for current root' })

      ---@param command_opts { bang: boolean }
      create_user_command_once('JdtMavenSync', function(command_opts)
        local root = root_from_current_buffer()
        if not root then
          vim.notify('[java2] Cannot sync: no Java root detected.', vim.log.levels.WARN)
          return
        end
        maven_sync(root, command_opts.bang)
      end, {
        bang = true,
        desc = 'Run Maven generate-sources for current root (! adds -U)',
      })

      attach()
    end,
  },
}
