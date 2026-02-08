local java_filetypes = { 'java' }
local cache = {}
local sync_running = {}
local JDT_SETTING_CLASSPATH_ENTRIES = 'org.eclipse.jdt.ls.core.classpathEntries'

local function truthy(name)
  local v = vim.env[name]
  return v and ({ ['1'] = true, ['true'] = true, ['yes'] = true, ['on'] = true })[v:lower()] or false
end

local function read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and type(lines) == 'table' and table.concat(lines, '\n') or ''
end

local function split_words(s)
  return (s and s ~= '') and vim.split(s, '%s+', { trimempty = true }) or {}
end

local function normalize_slashes(path)
  if not path or path == '' then
    return nil
  end
  return path:gsub('\\', '/')
end

local function list_generated_source_dirs(root)
  local seen = {}
  local out = {}
  local patterns = {
    root .. '/**/target/generated-sources/**/src/main/java',
    root .. '/**/target/generated-sources/**/src/generated/java',
    root .. '/**/target/generated-sources/**/java',
  }

  for _, pattern in ipairs(patterns) do
    local matches = vim.fn.glob(pattern, true, true)
    if type(matches) == 'table' then
      for _, dir in ipairs(matches) do
        if vim.fn.isdirectory(dir) == 1 then
          local normalized = vim.fs.normalize(dir)
          if not seen[normalized] then
            seen[normalized] = true
            table.insert(out, normalized)
          end
        end
      end
    end
  end

  table.sort(out)
  return out
end

local function list_generated_source_dirs_for_buffer(root, bufnr)
  bufnr = bufnr or 0
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == '' then
    return {}, nil
  end

  local module_root = vim.fs.root(bufname, { 'pom.xml' }) or root
  if not module_root or module_root == '' then
    return {}, nil
  end
  module_root = vim.fs.normalize(module_root)

  local out = {}
  for _, dir in ipairs(list_generated_source_dirs(root)) do
    if dir == module_root or dir:find(module_root .. '/', 1, true) == 1 then
      table.insert(out, dir)
    end
  end

  return out, module_root
end

local function request_project_classpath_entries(client, bufnr, uri, cb)
  client.request('workspace/executeCommand', {
    command = 'java.project.getSettings',
    arguments = { uri, { JDT_SETTING_CLASSPATH_ENTRIES } },
  }, function(err, result)
    if err then
      cb(err, nil)
      return
    end
    local entries = nil
    if type(result) == 'table' then
      entries = result[JDT_SETTING_CLASSPATH_ENTRIES] or result.classpathEntries
    end
    if type(entries) ~= 'table' then
      cb('java.project.getSettings did not return classpath entries', nil)
      return
    end
    cb(nil, entries)
  end, bufnr)
end

local function infer_module_prefix(classpath_entries, module_root)
  local module_name = module_root and vim.fs.basename(module_root) or nil
  local fallback = module_name and module_name ~= '' and ('/' .. module_name .. '/') or '/'

  for _, entry in ipairs(classpath_entries) do
    if type(entry) == 'table' and tonumber(entry.kind) == 3 then
      local path = normalize_slashes(entry.path)
      if path and path ~= '' then
        local prefix = path:match('^(%/[^/]+/)')
        if prefix then
          return prefix
        end
      end
    end
  end

  return fallback
end

local function ensure_generated_sources_on_classpath(root, bufnr)
  if truthy 'JDTLS_DISABLE_GENERATED_SOURCE_PATCH' then
    return
  end

  bufnr = bufnr or 0
  local dirs, module_root = list_generated_source_dirs_for_buffer(root, bufnr)
  if vim.tbl_isempty(dirs) or not module_root then
    return
  end

  local uri = vim.uri_from_bufnr(bufnr)
  for _, client in ipairs(vim.lsp.get_clients { name = 'jdtls' }) do
    if client and client.config and client.config.root_dir == root then
      request_project_classpath_entries(client, bufnr, uri, function(err, classpath_entries)
        if err or type(classpath_entries) ~= 'table' or vim.tbl_isempty(classpath_entries) then
          return
        end

        local new_entries = vim.deepcopy(classpath_entries)
        local module_prefix = infer_module_prefix(new_entries, module_root)
        local existing = {}
        for _, entry in ipairs(new_entries) do
          if type(entry) == 'table' and tonumber(entry.kind) == 3 then
            local path = normalize_slashes(entry.path)
            if path then
              existing[path] = true
            end
          end
        end

        local added = false
        for _, dir in ipairs(dirs) do
          local rel = normalize_slashes(vim.fs.relpath(dir, module_root))
          local entry_path = rel and (module_prefix .. rel:gsub('^/', '')) or nil
          if rel and entry_path and rel ~= '' and not rel:find('^%.%./') and not existing[entry_path] then
            table.insert(new_entries, {
              kind = 3,
              path = entry_path,
              output = nil,
              attributes = {},
            })
            existing[entry_path] = true
            added = true
          end
        end

        if not added then
          return
        end

        client.request('workspace/executeCommand', {
          command = 'java.project.updateClassPaths',
          arguments = {
            uri,
            {
              classpathEntries = new_entries,
            },
          },
        }, function(update_err)
          if update_err then
            local message = update_err.message or vim.inspect(update_err)
            vim.notify('[java3] updateClassPaths failed: ' .. message, vim.log.levels.WARN)
            return
          end
          client.request('workspace/executeCommand', {
            command = 'java.project.import',
            arguments = {},
          }, function() end, bufnr)
          client.request('workspace/executeCommand', {
            command = 'java.project.refreshDiagnostics',
            arguments = {},
          }, function() end, bufnr)
        end, bufnr)
      end)
    end
  end
end

local function detect_root(file)
  local mode = (vim.env.JDTLS_ROOT_MODE or 'auto'):lower()
  local project_root = vim.fs.root(file, { '.mvn', 'mvnw' })
  local module_root = vim.fs.root(file, { 'pom.xml' })
  if mode == 'module' then
    return module_root or project_root or vim.fs.root(file, { '.git' })
  end
  return project_root or module_root or vim.fs.root(file, { '.git' })
end

local function detect_settings_xml(root)
  local explicit = vim.env.JDTLS_SETTINGS_XML
  if explicit and explicit ~= '' and vim.fn.filereadable(explicit) == 1 then
    return explicit
  end
  local dir = root
  while dir and dir ~= '' do
    local p1, p2 = dir .. '/settings.xml', dir .. '/.mvn/settings.xml'
    if vim.fn.filereadable(p1) == 1 then
      return p1
    end
    if vim.fn.filereadable(p2) == 1 then
      return p2
    end
    local parent = vim.fs.dirname(dir)
    if not parent or parent == dir then
      break
    end
    dir = parent
  end
  local fallback = vim.fn.expand '~/.m2/settings.xml'
  return vim.fn.filereadable(fallback) == 1 and fallback or nil
end

local function first_tag(content, patterns)
  for _, p in ipairs(patterns) do
    local v = content:match(p)
    if v and v ~= '' then
      return v
    end
  end
  return nil
end

local function java_major(version)
  local n = tonumber((version or ''):match '^(%d+)')
  if not n then
    return 17
  end
  if n == 1 then
    return tonumber((version or ''):match '^1%.(%d+)') or 8
  end
  return n
end

local function detect_java_home(major)
  if vim.env.JDTLS_JAVA_HOME and vim.fn.isdirectory(vim.env.JDTLS_JAVA_HOME) == 1 then
    return vim.env.JDTLS_JAVA_HOME
  end
  if vim.fn.executable '/usr/libexec/java_home' == 1 then
    local out = vim.fn.systemlist { '/usr/libexec/java_home', '-v', tostring(major) }
    if vim.v.shell_error == 0 and out[1] and vim.fn.isdirectory(out[1]) == 1 then
      return out[1]
    end
  end
  if vim.env.JAVA_HOME and vim.fn.isdirectory(vim.env.JAVA_HOME) == 1 then
    return vim.env.JAVA_HOME
  end
  return nil
end

local function detect_global_settings()
  local m2_home = vim.env.M2_HOME or vim.env.MAVEN_HOME
  if not m2_home or m2_home == '' then
    return nil
  end
  local p = m2_home .. '/conf/settings.xml'
  return vim.fn.filereadable(p) == 1 and p or nil
end

local function detect_local_repo(settings_content)
  if vim.env.MAVEN_REPO_LOCAL and vim.fn.isdirectory(vim.env.MAVEN_REPO_LOCAL) == 1 then
    return vim.fs.normalize(vim.env.MAVEN_REPO_LOCAL)
  end
  local repo = settings_content:match('<localRepository>%s*(.-)%s*</localRepository>')
  if repo and repo ~= '' then
    repo = vim.fn.expand(repo:gsub('${user.home}', vim.fn.expand '~'))
    if vim.fn.isdirectory(repo) == 1 then
      return vim.fs.normalize(repo)
    end
  end
  local fallback = vim.fs.normalize(vim.fn.expand '~/.m2/repository')
  return vim.fn.isdirectory(fallback) == 1 and fallback or nil
end

local function detect_lombok(local_repo)
  local explicit = vim.env.JDTLS_LOMBOK_JAR
  if explicit and explicit ~= '' and vim.fn.filereadable(explicit) == 1 then
    return explicit
  end
  if not local_repo then
    return nil
  end
  local jars = vim.fn.glob(local_repo .. '/org/projectlombok/lombok/*/lombok-*.jar', true, true)
  if type(jars) ~= 'table' or vim.tbl_isempty(jars) then
    return nil
  end
  table.sort(jars)
  return jars[#jars]
end

local function build_cache(root)
  if cache[root] then
    return cache[root]
  end

  local settings_xml = detect_settings_xml(root)
  local settings = settings_xml and read_file(settings_xml) or ''
  local pom = read_file(root .. '/pom.xml')
  local version_patterns = {
    '<maven%.compiler%.release>%s*([%d%.]+)%s*</maven%.compiler%.release>',
    '<maven%.compiler%.source>%s*([%d%.]+)%s*</maven%.compiler%.source>',
    '<java%.version>%s*([%d%.]+)%s*</java%.version>',
    '<jdk%.version>%s*([%d%.]+)%s*</jdk%.version>',
    '<release>%s*([%d%.]+)%s*</release>',
    '<source>%s*([%d%.]+)%s*</source>',
  }

  local major = java_major(vim.env.JDTLS_JAVA_VERSION or first_tag(settings, version_patterns) or first_tag(pom, version_patterns) or '17')
  local local_repo = detect_local_repo(settings)
  local args = vim.env.JDTLS_MAVEN_IMPORT_ARGUMENTS
  if not args or args == '' then
    local parts = {}
    if local_repo then
      table.insert(parts, '-Dmaven.repo.local=' .. local_repo)
    end
    if vim.env.JDTLS_MAVEN_PROFILES and vim.env.JDTLS_MAVEN_PROFILES ~= '' then
      table.insert(parts, '-P' .. vim.env.JDTLS_MAVEN_PROFILES:gsub('%s+', ''))
    end
    if vim.env.JDTLS_MAVEN_IMPORT_APPEND_ARGUMENTS and vim.env.JDTLS_MAVEN_IMPORT_APPEND_ARGUMENTS ~= '' then
      vim.list_extend(parts, split_words(vim.env.JDTLS_MAVEN_IMPORT_APPEND_ARGUMENTS))
    end
    args = table.concat(parts, ' ')
  end

  local c = {
    settings_xml = settings_xml,
    global_settings_xml = detect_global_settings(),
    java_major = major,
    java_home = detect_java_home(major),
    local_repo = local_repo,
    lombok_jar = detect_lombok(local_repo),
    maven_offline = truthy 'JDTLS_MAVEN_OFFLINE' or truthy 'MAVEN_OFFLINE',
    import_args = args,
  }
  cache[root] = c
  return c
end

local function project_key(root, c)
  local seed = table.concat({
    vim.fs.normalize(root),
    tostring(c.java_major),
    tostring(c.settings_xml or ''),
    tostring(c.local_repo or ''),
    tostring(c.import_args or ''),
  }, '|')
  return vim.fs.basename(root) .. '-' .. vim.fn.sha256(seed):sub(1, 10)
end

local function resolve_cmd(config_dir, workspace_dir, c)
  local java_bin = vim.env.JDTLS_JAVA_BIN
  if not java_bin or java_bin == '' then
    local from_home = c.java_home and (c.java_home .. '/bin/java') or nil
    java_bin = (from_home and vim.fn.executable(from_home) == 1) and from_home or vim.fn.exepath 'java'
  end
  if java_bin == '' then
    java_bin = 'java'
  end

  local jdtls_bin = (vim.env.JDTLS_BIN and vim.fn.executable(vim.env.JDTLS_BIN) == 1) and vim.env.JDTLS_BIN or vim.fn.exepath 'jdtls'
  local xms, xmx = vim.env.JDTLS_XMS or '1g', vim.env.JDTLS_XMX or '4g'
  local with_lombok = not truthy 'JDTLS_DISABLE_LOMBOK_AGENT'

  if jdtls_bin ~= '' then
    local cmd = {
      jdtls_bin,
      '--java-executable=' .. java_bin,
      '--jvm-arg=-Xms' .. xms,
      '--jvm-arg=-Xmx' .. xmx,
      '-configuration',
      config_dir,
      '-data',
      workspace_dir,
    }
    if with_lombok and c.lombok_jar then
      table.insert(cmd, 4, '--jvm-arg=-javaagent:' .. c.lombok_jar)
    end
    return cmd, 'jdtls-bin'
  end

  local home = vim.env.JDTLS_HOME
  if not home or home == '' or vim.fn.isdirectory(home) ~= 1 then
    return nil, nil
  end
  local launcher = vim.fn.glob(home .. '/plugins/org.eclipse.equinox.launcher_*.jar', true, true)[1]
    or vim.fn.glob(home .. '/plugins/org.eclipse.equinox.launcher.jar', true, true)[1]
  local os_cfg = vim.fn.has 'macunix' == 1 and 'config_mac' or (vim.fn.has 'win32' == 1 and 'config_win' or 'config_linux')
  local os_cfg_dir = home .. '/' .. os_cfg
  if not launcher or launcher == '' or vim.fn.isdirectory(os_cfg_dir) ~= 1 then
    return nil, nil
  end

  local cmd = {
    java_bin,
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=WARN',
    '-Xms' .. xms,
    '-Xmx' .. xmx,
    '--add-modules=ALL-SYSTEM',
    '--add-opens',
    'java.base/java.util=ALL-UNNAMED',
    '--add-opens',
    'java.base/java.lang=ALL-UNNAMED',
    '-jar',
    launcher,
    '-configuration',
    os_cfg_dir,
    '-data',
    workspace_dir,
  }
  if with_lombok and c.lombok_jar then
    table.insert(cmd, 9, '-javaagent:' .. c.lombok_jar)
  end
  return cmd, 'jdtls-home'
end

local function build_settings(base, c)
  local s = vim.deepcopy(base or {})
  s.java = s.java or {}
  s.java.configuration = s.java.configuration or {}
  s.java.configuration.updateBuildConfiguration = 'automatic'
  s.java.configuration.maven = s.java.configuration.maven or {}
  if c.settings_xml then
    s.java.configuration.maven.userSettings = c.settings_xml
  end
  if c.global_settings_xml then
    s.java.configuration.maven.globalSettings = c.global_settings_xml
  end
  s.java.configuration.runtimes = s.java.configuration.runtimes or {}
  if c.java_home and #s.java.configuration.runtimes == 0 then
    s.java.configuration.runtimes = { {
      name = 'JavaSE-' .. tostring(c.java_major),
      path = c.java_home,
      default = true,
    } }
  end

  s.java.import = s.java.import or {}
  s.java.import.maven = s.java.import.maven or {}
  s.java.import.maven.enabled = true
  s.java.import.maven.disableTestClasspathFlag = false
  if c.settings_xml then
    s.java.import.maven.userSettings = c.settings_xml
  end
  if c.global_settings_xml then
    s.java.import.maven.globalSettings = c.global_settings_xml
  end
  if c.import_args and c.import_args ~= '' then
    s.java.import.maven.arguments = c.import_args
  end
  s.java.import.maven.offline = { enabled = c.maven_offline }
  s.java.import.gradle = { enabled = false }
  s.java.errors = { incompleteClasspath = { severity = 'error' } }
  return s
end

local function capabilities()
  local caps = vim.lsp.protocol.make_client_capabilities()
  local ok, blink = pcall(require, 'blink.cmp')
  if ok and blink.get_lsp_capabilities then
    caps = blink.get_lsp_capabilities(caps)
  end
  return caps
end

local function refresh(root, bufnr)
  bufnr = bufnr or 0
  for _, client in ipairs(vim.lsp.get_clients { name = 'jdtls' }) do
    if client and client.config and client.config.root_dir == root then
      client.request('workspace/executeCommand', { command = 'java.project.import', arguments = {} }, function() end, bufnr)
      client.request('workspace/executeCommand', { command = 'java.project.refreshDiagnostics', arguments = {} }, function() end, bufnr)
      client.request('java/projectConfigurationUpdate', { uri = vim.uri_from_bufnr(bufnr) }, function() end, bufnr)
    end
  end
  vim.defer_fn(function()
    ensure_generated_sources_on_classpath(root, bufnr)
  end, 300)
end

local function maven_sync(root, c, force)
  if sync_running[root] then
    vim.notify('[java3] Maven sync already running.', vim.log.levels.INFO)
    return
  end

  local cmd, mvnw = {}, root .. '/mvnw'
  if vim.fn.executable(mvnw) == 1 then
    table.insert(cmd, mvnw)
  elseif vim.fn.executable 'mvn' == 1 then
    table.insert(cmd, 'mvn')
  else
    vim.notify('[java3] Maven executable not found (`mvnw` or `mvn`).', vim.log.levels.ERROR)
    return
  end

  if c.settings_xml then
    vim.list_extend(cmd, { '-s', c.settings_xml })
  end
  if c.global_settings_xml then
    vim.list_extend(cmd, { '-gs', c.global_settings_xml })
  end
  if c.local_repo then
    table.insert(cmd, '-Dmaven.repo.local=' .. c.local_repo)
  end
  if c.maven_offline then
    table.insert(cmd, '-o')
  end
  if force then
    table.insert(cmd, '-U')
  end

  vim.list_extend(cmd, split_words(vim.env.JDTLS_MAVEN_SYNC_FLAGS or '-DskipTests -DskipITs -Dmaven.test.skip=true'))
  local goals = split_words(vim.env.JDTLS_MAVEN_SYNC_GOALS or 'generate-sources')
  vim.list_extend(cmd, vim.tbl_isempty(goals) and { 'generate-sources' } or goals)

  if not vim.system then
    vim.notify('[java3] vim.system is required for :JdtMavenSync.', vim.log.levels.ERROR)
    return
  end

  sync_running[root] = true
  vim.notify('[java3] Running: ' .. table.concat(cmd, ' '), vim.log.levels.INFO)
  vim.system(cmd, { cwd = root, text = true }, function(result)
    vim.schedule(function()
      sync_running[root] = nil
      if result.code == 0 then
        vim.notify('[java3] Maven sync finished. Refreshing JDTLS...', vim.log.levels.INFO)
        refresh(root, 0)
        return
      end
      local text = (result.stderr and result.stderr ~= '') and result.stderr or (result.stdout or '')
      local lines, start = vim.split(text, '\n', { trimempty = true }), 1
      if #lines > 10 then
        start = #lines - 9
      end
      vim.notify('[java3] Maven sync failed.\n' .. table.concat(vim.list_slice(lines, start, #lines), '\n'), vim.log.levels.ERROR)
    end)
  end)
end

return {
  {
    'nvim-treesitter/nvim-treesitter',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, 'java') then
        table.insert(opts.ensure_installed, 'java')
      end
    end,
  },
  {
    'mfussenegger/nvim-jdtls',
    ft = java_filetypes,
    dependencies = {
      'neovim/nvim-lspconfig',
      'saghen/blink.cmp',
    },
    opts = { settings = {} },
    config = function(_, opts)
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

        local c = build_cache(root)
        local key = project_key(root, c)
        local config_dir = vim.fn.stdpath 'cache' .. '/jdtls/' .. key .. '/config'
        local workspace_dir = vim.fn.stdpath 'cache' .. '/jdtls/' .. key .. '/workspace'
        vim.fn.mkdir(config_dir, 'p')
        vim.fn.mkdir(workspace_dir, 'p')

        local cmd, cmd_source = resolve_cmd(config_dir, workspace_dir, c)
        if not cmd then
          vim.notify('[java3] jdtls not found. Set JDTLS_BIN/JDTLS_HOME or install `jdtls` in PATH.', vim.log.levels.WARN)
          return
        end

        local cfg = {
          cmd = cmd,
          root_dir = root,
          settings = build_settings(opts.settings, c),
          capabilities = capabilities(),
        }
        if type(opts.jdtls) == 'table' then
          cfg = vim.tbl_deep_extend('force', cfg, opts.jdtls)
        end

        vim.g.ba_jdtls_last = {
          root_dir = root,
          settings_xml = c.settings_xml,
          local_repo = c.local_repo,
          maven_import_arguments = c.import_args,
          java_major = c.java_major,
          java_home = c.java_home,
          lombok_jar = c.lombok_jar,
          cmd_source = cmd_source,
          workspace_dir = workspace_dir,
        }

        require('jdtls').start_or_attach(cfg)
        vim.defer_fn(function()
          ensure_generated_sources_on_classpath(root, bufnr)
        end, 700)
      end

      local group = vim.api.nvim_create_augroup('ba-java3-jdtls', { clear = true })
      vim.api.nvim_create_autocmd('FileType', { group = group, pattern = java_filetypes, callback = attach })

      if vim.fn.exists ':JdtlsStatus' == 0 then
        vim.api.nvim_create_user_command('JdtlsStatus', function()
          vim.notify(vim.inspect(vim.g.ba_jdtls_last or {}), vim.log.levels.INFO)
        end, { desc = 'Show jdtls status' })
      end

      if vim.fn.exists ':JdtMavenSync' == 0 then
        vim.api.nvim_create_user_command('JdtMavenSync', function(command_opts)
          local file = vim.api.nvim_buf_get_name(0)
          local root = (file ~= '') and detect_root(file) or nil
          if not root then
            vim.notify('[java3] Cannot sync: no Java root detected.', vim.log.levels.WARN)
            return
          end
          maven_sync(root, build_cache(root), command_opts.bang)
        end, {
          bang = true,
          desc = 'Run Maven generate-sources for current root (! adds -U)',
        })
      end

      if vim.fn.exists ':JdtProjectsRefresh' == 0 then
        vim.api.nvim_create_user_command('JdtProjectsRefresh', function()
          local file = vim.api.nvim_buf_get_name(0)
          local root = (file ~= '') and detect_root(file) or nil
          if not root then
            vim.notify('[java3] Cannot refresh: no Java root detected.', vim.log.levels.WARN)
            return
          end
          refresh(root, 0)
          vim.notify('[java3] Triggered JDTLS refresh.', vim.log.levels.INFO)
        end, { desc = 'Refresh JDTLS import/build for current root' })
      end

      attach()
    end,
  },
}
