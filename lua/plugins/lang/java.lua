---@type string[]
local java_filetypes = { 'java' }

---@class JavaCacheEntry
---@field settings_xml string|nil
---@field global_settings_xml string|nil
---@field java_major integer
---@field java_home string|nil
---@field local_repo string|nil
---@field lombok_jar string|nil
---@field maven_offline boolean
---@field import_args string
---@field dap_bundles string[]
---@field dap_bundle_source string|nil

---@type table<string, JavaCacheEntry>
local cache = {}
---@type table<string, boolean>
local sync_running = {}
---@type table<string, boolean>
local dap_setup_done = {}
---@type table<string, boolean>
local dap_warned = {}
---@type boolean
local neotest_warned = false

---@param name string
---@return boolean
local function truthy(name)
  local v = vim.env[name]
  return v and ({ ['1'] = true, ['true'] = true, ['yes'] = true, ['on'] = true })[v:lower()] or false
end

---@param path string
---@return string
local function read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and type(lines) == 'table' and table.concat(lines, '\n') or ''
end

---@param s string|nil
---@return string[]
local function split_words(s)
  return (s and s ~= '') and vim.split(s, '%s+', { trimempty = true }) or {}
end

---@param list string[]
---@param value string|nil
local function append_unique(list, value)
  if not value or value == '' then
    return
  end
  for _, item in ipairs(list) do
    if item == value then
      return
    end
  end
  table.insert(list, value)
end

---@param expr string
---@return string
local function expand_path(expr)
  local expanded = vim.fn.expand(expr)
  if type(expanded) == 'table' then
    return expanded[1] or ''
  end
  return expanded
end

---@param file string
---@return string|nil
local function detect_root(file)
  local mode = (vim.env.JDTLS_ROOT_MODE or 'auto'):lower()
  local project_root = vim.fs.root(file, { '.mvn', 'mvnw' })
  local module_root = vim.fs.root(file, { 'pom.xml' })
  if mode == 'module' then
    return module_root or project_root or vim.fs.root(file, { '.git' })
  end
  return project_root or module_root or vim.fs.root(file, { '.git' })
end

---@param root string
---@return string|nil
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
  local fallback = expand_path '~/.m2/settings.xml'
  return vim.fn.filereadable(fallback) == 1 and fallback or nil
end

---@param content string
---@param patterns string[]
---@return string|nil
local function first_tag(content, patterns)
  for _, p in ipairs(patterns) do
    local v = content:match(p)
    if v and v ~= '' then
      return v
    end
  end
  return nil
end

---@param version string|nil
---@return integer
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

---@param major integer
---@return string|nil
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

---@return string|nil
local function detect_global_settings()
  local m2_home = vim.env.M2_HOME or vim.env.MAVEN_HOME
  if not m2_home or m2_home == '' then
    return nil
  end
  local p = m2_home .. '/conf/settings.xml'
  return vim.fn.filereadable(p) == 1 and p or nil
end

---@param settings_content string
---@return string|nil
local function detect_local_repo(settings_content)
  if vim.env.MAVEN_REPO_LOCAL and vim.fn.isdirectory(vim.env.MAVEN_REPO_LOCAL) == 1 then
    return vim.fs.normalize(vim.env.MAVEN_REPO_LOCAL)
  end
  local repo = settings_content:match '<localRepository>%s*(.-)%s*</localRepository>'
  if repo and repo ~= '' then
    repo = expand_path(repo:gsub('${user.home}', expand_path '~'))
    if vim.fn.isdirectory(repo) == 1 then
      return vim.fs.normalize(repo)
    end
  end
  local fallback = vim.fs.normalize(expand_path '~/.m2/repository')
  return vim.fn.isdirectory(fallback) == 1 and fallback or nil
end

---@param local_repo string|nil
---@return string|nil
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

---@return string|nil
local function detect_neotest_junit_jar()
  local explicit = vim.env.NEOTEST_JAVA_JUNIT_JAR
  if explicit and explicit ~= '' then
    local expanded = vim.fs.normalize(expand_path(explicit))
    if vim.fn.filereadable(expanded) == 1 then
      return expanded
    end
  end

  local data_home = (vim.env.XDG_DATA_HOME and vim.env.XDG_DATA_HOME ~= '') and vim.env.XDG_DATA_HOME or expand_path '~/.local/share'
  local nvim_data_home = vim.fs.normalize(vim.fn.stdpath 'data')
  local mason_packages = nvim_data_home .. '/mason/packages'
  local maven_repos = {}
  append_unique(maven_repos, vim.fs.normalize(expand_path '~/.m2/repository'))
  if vim.env.MAVEN_REPO_LOCAL and vim.env.MAVEN_REPO_LOCAL ~= '' then
    append_unique(maven_repos, vim.fs.normalize(expand_path(vim.env.MAVEN_REPO_LOCAL)))
  end
  local import_args = vim.env.JDTLS_MAVEN_IMPORT_ARGUMENTS
  local import_repo = import_args and import_args:match '%-Dmaven%.repo%.local=([^%s]+)' or nil
  if import_repo and import_repo ~= '' then
    append_unique(maven_repos, vim.fs.normalize(expand_path(import_repo)))
  end

  local matches = {}
  extend_with_glob(matches, data_home .. '/java-test/junit-platform-console-standalone-*.jar')
  extend_with_glob(matches, data_home .. '/java-test/**/junit-platform-console-standalone-*.jar')
  extend_with_glob(matches, nvim_data_home .. '/neotest-java/junit-platform-console-standalone-*.jar')
  extend_with_glob(matches, nvim_data_home .. '/neotest-java/**/junit-platform-console-standalone-*.jar')
  extend_with_glob(matches, mason_packages .. '/java-test/junit-platform-console-standalone-*.jar')
  extend_with_glob(matches, mason_packages .. '/java-test/**/junit-platform-console-standalone-*.jar')
  for _, repo in ipairs(maven_repos) do
    extend_with_glob(matches, repo .. '/org/junit/platform/junit-platform-console-standalone/*/junit-platform-console-standalone-*.jar')
  end
  matches = dedupe_files(matches)
  if vim.tbl_isempty(matches) then
    return nil
  end
  table.sort(matches)
  return matches[#matches]
end

local excluded_test_bundles = {
  ['com.microsoft.java.test.runner-jar-with-dependencies.jar'] = true,
  ['jacocoagent.jar'] = true,
}

---@param debug_dir string|nil
---@return string|nil
local function pick_debug_bundle(debug_dir)
  if not debug_dir or debug_dir == '' or vim.fn.isdirectory(debug_dir) ~= 1 then
    return nil
  end
  local matches = {}
  extend_with_glob(matches, debug_dir .. '/**/com.microsoft.java.debug.plugin-*.jar')
  matches = dedupe_files(matches)
  if vim.tbl_isempty(matches) then
    return nil
  end
  table.sort(matches)
  return matches[#matches]
end

---@param test_dir string|nil
---@return string[]
local function collect_test_bundles(test_dir)
  if not test_dir or test_dir == '' or vim.fn.isdirectory(test_dir) ~= 1 then
    return {}
  end
  local matches, bundles = {}, {}
  extend_with_glob(matches, test_dir .. '/**/*.jar')
  for _, jar in ipairs(dedupe_files(matches)) do
    if not excluded_test_bundles[vim.fs.basename(jar)] then
      table.insert(bundles, jar)
    end
  end
  return bundles
end

---@param debug_dir string|nil
---@param test_dir string|nil
---@return string[]|nil
local function collect_dap_bundles_from_dirs(debug_dir, test_dir)
  local debug_bundle = pick_debug_bundle(debug_dir)
  if not debug_bundle then
    return nil
  end
  local bundles = { debug_bundle }
  vim.list_extend(bundles, collect_test_bundles(test_dir))
  return dedupe_files(bundles)
end

---@return { name: string, debug_dir: string, test_dir: string }[]
local function bundle_sources()
  local sources = {}

  ---@param name string
  ---@param debug_dir string|nil
  ---@param test_dir string|nil
  local function add(name, debug_dir, test_dir)
    if not debug_dir or debug_dir == '' or not test_dir or test_dir == '' then
      return
    end
    table.insert(sources, {
      name = name,
      debug_dir = vim.fs.normalize(debug_dir),
      test_dir = vim.fs.normalize(test_dir),
    })
  end

  add('env-dirs', vim.env.JDTLS_JAVA_DEBUG_DIR, vim.env.JDTLS_JAVA_TEST_DIR)
  if vim.env.JDTLS_DAP_BUNDLES_ROOT and vim.env.JDTLS_DAP_BUNDLES_ROOT ~= '' then
    local root = vim.fs.normalize(vim.env.JDTLS_DAP_BUNDLES_ROOT)
    add('env-root', root .. '/java-debug', root .. '/java-test')
  end
  local data_home = (vim.env.XDG_DATA_HOME and vim.env.XDG_DATA_HOME ~= '') and vim.env.XDG_DATA_HOME or expand_path '~/.local/share'
  add('xdg-data-home', data_home .. '/java-debug', data_home .. '/java-test')
  local mason = vim.fn.stdpath 'data' .. '/mason/packages'
  add('mason', mason .. '/java-debug-adapter', mason .. '/java-test')
  return sources
end

---@return string[], string|nil
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
    return dedupe_files(bundles), 'JDTLS_DAP_BUNDLES'
  end

  for _, source in ipairs(bundle_sources()) do
    local bundles = collect_dap_bundles_from_dirs(source.debug_dir, source.test_dir)
    if bundles and not vim.tbl_isempty(bundles) then
      return bundles, source.name
    end
  end
  return {}, nil
end

---@param cfg table
---@param bundles string[]
local function apply_dap_bundles(cfg, bundles)
  if vim.tbl_isempty(bundles) then
    return
  end
  cfg.init_options = type(cfg.init_options) == 'table' and cfg.init_options or {}
  local existing = type(cfg.init_options.bundles) == 'table' and cfg.init_options.bundles or {}
  local merged = {}
  vim.list_extend(merged, existing)
  vim.list_extend(merged, bundles)
  cfg.init_options.bundles = dedupe_files(merged)
end

---@param root string
---@param bundles string[]
local function setup_dap(root, bundles)
  local key = root ~= '' and root or '__global__'
  if dap_setup_done[key] then
    return
  end
  if vim.tbl_isempty(bundles) then
    if not dap_warned[key] then
      dap_warned[key] = true
      vim.notify(
        '[java3] Java DAP bundles not found. Place VS Code jars under ~/.local/share/java-debug and ~/.local/share/java-test, or set JDTLS_DAP_BUNDLES/JDTLS_DAP_BUNDLES_ROOT.',
        vim.log.levels.WARN
      )
    end
    return
  end

  local ok_jdtls, jdtls = pcall(require, 'jdtls')
  if not ok_jdtls then
    return
  end
  local ok_setup = pcall(jdtls.setup_dap, { hotcodereplace = 'auto' })
  local ok_main = pcall(function()
    require('jdtls.dap').setup_dap_main_class_configs()
  end)
  if ok_setup and ok_main then
    dap_setup_done[key] = true
    return
  end
  if not dap_warned[key] then
    dap_warned[key] = true
    vim.notify('[java3] Failed to initialize Java DAP integration.', vim.log.levels.WARN)
  end
end

---@param root string
---@return JavaCacheEntry
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
  local dap_bundles, dap_bundle_source = detect_dap_bundles()
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
    dap_bundles = dap_bundles,
    dap_bundle_source = dap_bundle_source,
  }
  cache[root] = c
  return c
end

---@param root string
---@param c JavaCacheEntry
---@return string
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

---@param config_dir string
---@param workspace_dir string
---@param c JavaCacheEntry
---@return string[]|nil, string|nil
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

  -- Disable Develocity/scan integrations for stable imports.
  local develocity_flags = {
    '-Dgradle.scan.disabled=true',
    '-Ddevelocity.scan.disabled=true',
  }

  if jdtls_bin ~= '' then
    local cmd = {
      jdtls_bin,
      '--java-executable=' .. java_bin,
      '--jvm-arg=-Xms' .. xms,
      '--jvm-arg=-Xmx' .. xmx,
    }
    for _, flag in ipairs(develocity_flags) do
      table.insert(cmd, '--jvm-arg=' .. flag)
    end
    vim.list_extend(cmd, {
      '-configuration',
      config_dir,
      '-data',
      workspace_dir,
    })

    if with_lombok and c.lombok_jar then
      -- Keep the agent close to the JVM arguments for predictable startup order.
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
    develocity_flags[1],
    develocity_flags[2],
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
    -- Keep the java agent before module/open flags.
    table.insert(cmd, 9, '-javaagent:' .. c.lombok_jar)
  end
  return cmd, 'jdtls-home'
end

---@param base table|nil
---@param c JavaCacheEntry
---@return table
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
  s.java.format = s.java.format or {}
  s.java.format.enabled = true
  s.java.import.maven.offline = { enabled = c.maven_offline }
  s.java.import.gradle = { enabled = false }
  s.java.errors = { incompleteClasspath = { severity = 'error' } }
  return s
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

---@param client table
---@param method string
---@param bufnr integer
---@return boolean
local function client_supports_method(client, method, bufnr)
  if client:supports_method(method, bufnr) then
    return true
  end
  -- Neovim 0.10 may expect an options table here; test integer and table call signatures.
  local ok, supported = pcall(client.supports_method, client, method, { bufnr = bufnr })
  return ok and supported or false
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
---@param c JavaCacheEntry
---@param force boolean
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
  ---@param result { code: integer, stdout: string|nil, stderr: string|nil }
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
      opts = opts or {}
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, 'java') then
        table.insert(opts.ensure_installed, 'java')
      end
    end,
  },
  {
    'nvim-neotest/neotest',
    lazy = true,
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      {
        'sergii-dudar/neotest-java', -- FIXME: return back rcasia/neotest-java after bug is fixed
        ft = java_filetypes,
        dependencies = {
          'mfussenegger/nvim-jdtls',
          'mfussenegger/nvim-dap',
        },
      },
    },
    opts = {
      adapters = {
        ['neotest-java'] = {
          incremental_build = true,
          test_classname_patterns = {
            '^Test.*$',
            '^.*Tests?$',
            '^.*IT$',
            '^.*Spec$',
            '^.*$',
          },
        },
      },
    },
    config = function(_, opts)
      opts = opts or {}
      local adapter_specs = type(opts.adapters) == 'table' and opts.adapters or {}
      local junit_jar = detect_neotest_junit_jar()
      if not vim.tbl_islist(adapter_specs) then
        if junit_jar then
          local existing = type(adapter_specs['neotest-java']) == 'table' and adapter_specs['neotest-java'] or {}
          adapter_specs['neotest-java'] = vim.tbl_deep_extend('force', existing, { junit_jar = junit_jar })
        else
          adapter_specs['neotest-java'] = nil
        end
      end
      local adapters = {}

      ---@param module any
      ---@param adapter_opts table|nil
      ---@return any|nil
      local function make_adapter(module, adapter_opts)
        local mt = type(module) == 'table' and getmetatable(module) or nil
        local is_callable_table = mt and type(mt.__call) == 'function'
        if type(module) == 'function' or is_callable_table then
          local ok_adapter, adapter = pcall(module, adapter_opts or {})
          return ok_adapter and adapter or nil
        end
        if type(module) == 'table' and type(module.setup) == 'function' then
          local ok_adapter, adapter = pcall(module.setup, adapter_opts or {})
          if ok_adapter and adapter then
            return adapter
          end
          local ok_method, adapter_method = pcall(module.setup, module, adapter_opts or {})
          return ok_method and adapter_method or nil
        end
        if type(module) == 'table' and type(module.adapter) == 'function' then
          local ok_adapter, adapter = pcall(module.adapter, adapter_opts or {})
          if ok_adapter and adapter then
            return adapter
          end
          local ok_method, adapter_method = pcall(module.adapter, module, adapter_opts or {})
          return ok_method and adapter_method or nil
        end
        return module
      end

      if vim.tbl_islist(adapter_specs) then
        adapters = adapter_specs
      else
        for name, adapter_opts in pairs(adapter_specs) do
          local ok_module, module = pcall(require, name)
          if ok_module then
            local adapter = make_adapter(module, adapter_opts)
            if adapter then
              table.insert(adapters, adapter)
            end
          end
        end
      end

      if not junit_jar and not neotest_warned then
        neotest_warned = true
        vim.schedule(function()
          vim.notify(
            '[java3] neotest-java disabled: junit-platform-console-standalone JAR not found. Set NEOTEST_JAVA_JUNIT_JAR or place the JAR under ~/.local/share/nvim/neotest-java, ~/.local/share/nvim/mason/packages/java-test, ~/.m2/repository, or ~/.local/share/java-test.',
            vim.log.levels.WARN
          )
        end)
      end

      opts.adapters = adapters
      require('neotest').setup(opts)
    end,
  },
  -- {
  --   'mason-org/mason.nvim',
  --   optional = true,
  --   event = 'VeryLazy',
  --   opts = function(_, opts)
  --     opts = opts or {}
  --     opts.ensure_installed = opts.ensure_installed or {}
  --     for _, pkg in ipairs { 'jdtls', 'java-debug-adapter', 'java-test' } do
  --       if not vim.tbl_contains(opts.ensure_installed, pkg) then
  --         table.insert(opts.ensure_installed, pkg)
  --       end
  --     end
  --     return opts
  --   end,
  -- },
  {
    'mfussenegger/nvim-jdtls',
    ft = java_filetypes,
    dependencies = {
      'neovim/nvim-lspconfig',
      'saghen/blink.cmp',
      'mfussenegger/nvim-dap',
    },
    opts = { settings = {} },
    config = function(_, opts)
      opts = opts or {}
      opts.settings = type(opts.settings) == 'table' and opts.settings or {}
      local dap_bundles_by_root = {}

      ---@param client table
      ---@param bufnr integer
      local function on_attach(client, bufnr)
        vim.keymap.set('n', '<leader>gt', function()
          require('neotest').run.run()
        end, {
          buffer = bufnr,
          desc = 'Java: Test nearest (neotest)',
        })
        vim.keymap.set('n', '<leader>gT', function()
          require('neotest').run.run(vim.fn.expand '%:p')
        end, {
          buffer = bufnr,
          desc = 'Java: Test class/file (neotest)',
        })
        vim.keymap.set('n', '<leader>dt', function()
          require('neotest').run.run { strategy = 'dap' }
        end, {
          buffer = bufnr,
          desc = 'Java: Debug nearest test (neotest)',
        })
        local root = (client and client.config and client.config.root_dir) or ''
        setup_dap(root, dap_bundles_by_root[root] or {})
        if type(opts.jdtls) == 'table' and type(opts.jdtls.on_attach) == 'function' then
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
          on_attach = on_attach,
        }
        if type(opts.jdtls) == 'table' then
          local user_jdtls = vim.deepcopy(opts.jdtls)
          user_jdtls.on_attach = nil
          cfg = vim.tbl_deep_extend('force', cfg, user_jdtls)
        end
        apply_dap_bundles(cfg, c.dap_bundles)
        local cfg_bundles = (type(cfg.init_options) == 'table' and type(cfg.init_options.bundles) == 'table') and cfg.init_options.bundles or c.dap_bundles
        dap_bundles_by_root[root] = cfg_bundles

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
          dap_bundle_source = c.dap_bundle_source,
          dap_bundle_count = #cfg_bundles,
          dap_bundles = cfg_bundles,
        }

        require('jdtls').start_or_attach(cfg)
      end

      local group = vim.api.nvim_create_augroup('ba-java3-jdtls', { clear = true })
      vim.api.nvim_create_autocmd('FileType', { group = group, pattern = java_filetypes, callback = attach })

      if vim.fn.exists ':JdtlsStatus' == 0 then
        vim.api.nvim_create_user_command('JdtlsStatus', function()
          vim.notify(vim.inspect(vim.g.ba_jdtls_last or {}), vim.log.levels.INFO)
        end, { desc = 'Show jdtls status' })
      end

      if vim.fn.exists ':JdtMavenSync' == 0 then
        ---@param command_opts { bang: boolean }
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

      if vim.fn.exists ':JdtNeotestJavaJar' == 0 then
        vim.api.nvim_create_user_command('JdtNeotestJavaJar', function()
          local jar = detect_neotest_junit_jar()
          if jar then
            vim.notify('[java3] neotest-java junit jar: ' .. jar, vim.log.levels.INFO)
          else
            vim.notify('[java3] neotest-java junit jar: not found', vim.log.levels.WARN)
          end
        end, { desc = 'Show detected neotest-java JUnit standalone jar' })
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
