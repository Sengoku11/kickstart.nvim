local java_filetypes = { 'java' }

local project_cache = {}
local maven_sync_state = {}

local function env_truthy(name)
  local value = vim.env[name]
  if not value then
    return false
  end
  value = value:lower()
  return value == '1' or value == 'true' or value == 'yes' or value == 'on'
end

local function read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then
    return nil
  end
  return table.concat(lines, '\n')
end

local function each_parent_dir(start_dir, cb)
  if not start_dir or start_dir == '' then
    return false
  end

  local dir = vim.fs.normalize(start_dir)
  while dir and dir ~= '' do
    if cb(dir) then
      return true
    end

    local parent = vim.fs.dirname(dir)
    if not parent or parent == dir then
      break
    end
    dir = parent
  end

  return false
end

local function split_words(value)
  if not value or value == '' then
    return {}
  end
  return vim.split(value, '%s+', { trimempty = true })
end

local function split_csv(value)
  if not value or value == '' then
    return {}
  end
  local out = {}
  for _, item in ipairs(vim.split(value, ',', { trimempty = true })) do
    local trimmed = vim.trim(item)
    if trimmed ~= '' then
      table.insert(out, trimmed)
    end
  end
  return out
end

local function append_unique(list, value)
  if not value or value == '' then
    return
  end
  for _, v in ipairs(list) do
    if v == value then
      return
    end
  end
  table.insert(list, value)
end

local function list_contains_prefix(list, prefix)
  if not list or not prefix then
    return false
  end
  for _, value in ipairs(list) do
    if type(value) == 'string' and value:find(prefix, 1, true) == 1 then
      return true
    end
  end
  return false
end

local function extend_or_override(base, override)
  if type(override) == 'table' then
    return vim.tbl_deep_extend('force', base, override)
  end

  if type(override) == 'function' then
    local ok, result = pcall(override, vim.deepcopy(base))
    if ok and type(result) == 'table' then
      return vim.tbl_deep_extend('force', base, result)
    end
  end

  return base
end

local function root_markers()
  local lsp_config = vim.lsp and vim.lsp.config or nil
  local markers = lsp_config and lsp_config.jdtls and lsp_config.jdtls.root_markers
  if type(markers) == 'table' and #markers > 0 then
    return markers
  end

  return {
    '.git',
    'mvnw',
    'gradlew',
    'pom.xml',
    'build.gradle',
    'build.gradle.kts',
  }
end

local function detect_maven_project_root(path)
  local module_root = vim.fs.root(path, { 'pom.xml' })
  if not module_root then
    return nil, nil
  end

  local project_root = module_root
  each_parent_dir(vim.fs.dirname(module_root), function(dir)
    local pom = dir .. '/pom.xml'
    if vim.fn.filereadable(pom) ~= 1 then
      return false
    end

    local content = read_file(pom)
    if not content then
      return false
    end

    local rel_module = vim.fs.relpath(dir, project_root)
    if not rel_module or rel_module == '' then
      return false
    end
    rel_module = rel_module:gsub('\\', '/')

    local has_modules = false
    local contains_current = false
    for modules_block in content:gmatch '<modules>(.-)</modules>' do
      has_modules = true
      for module in modules_block:gmatch '<module>%s*(.-)%s*</module>' do
        local normalized = vim.trim(module):gsub('\\', '/')
        if normalized == rel_module or rel_module:find(normalized .. '/', 1, true) == 1 then
          contains_current = true
          break
        end
      end
      if contains_current then
        break
      end
    end

    if has_modules and contains_current then
      project_root = dir
    end

    return false
  end)

  return project_root, module_root
end

local function detect_maven_tooling_root(path)
  local file_dir = vim.fs.dirname(path)
  local tooling_root = nil
  each_parent_dir(file_dir, function(dir)
    if vim.fn.isdirectory(dir .. '/.mvn') == 1 or vim.fn.filereadable(dir .. '/mvnw') == 1 then
      tooling_root = dir
    end
    return false
  end)
  return tooling_root
end

local function detect_root_dir(path)
  local root_mode = (vim.env.JDTLS_ROOT_MODE or 'auto'):lower()
  local project_root, module_root = detect_maven_project_root(path)
  local tooling_root = detect_maven_tooling_root(path)
  local fallback_module_root = module_root or vim.fs.root(path, {
    'pom.xml',
    'build.gradle',
    'build.gradle.kts',
  })

  if root_mode == 'project' or root_mode == 'repo' then
    if project_root then
      return project_root
    end
    if tooling_root and vim.fn.filereadable(tooling_root .. '/pom.xml') == 1 then
      return tooling_root
    end
    if fallback_module_root then
      return fallback_module_root
    end
    if tooling_root then
      return tooling_root
    end
  elseif root_mode == 'module' then
    if fallback_module_root then
      return fallback_module_root
    end
    if project_root then
      return project_root
    end
    if tooling_root then
      return tooling_root
    end
  else
    if project_root then
      return project_root
    end
    if tooling_root and vim.fn.filereadable(tooling_root .. '/pom.xml') == 1 then
      return tooling_root
    end
    if fallback_module_root then
      return fallback_module_root
    end
    if tooling_root then
      return tooling_root
    end
  end

  return vim.fs.root(path, root_markers())
end

local function detect_settings_xml(root_dir)
  local explicit = vim.env.JDTLS_SETTINGS_XML
  if explicit and explicit ~= '' and vim.fn.filereadable(explicit) == 1 then
    return explicit
  end

  local discovered = nil
  each_parent_dir(root_dir, function(dir)
    local project_settings = dir .. '/settings.xml'
    if vim.fn.filereadable(project_settings) == 1 then
      discovered = project_settings
      return true
    end

    local mvn_settings = dir .. '/.mvn/settings.xml'
    if vim.fn.filereadable(mvn_settings) == 1 then
      discovered = mvn_settings
      return true
    end

    return false
  end)

  if discovered then
    return discovered
  end

  local fallback = vim.fn.expand '~/.m2/settings.xml'
  if vim.fn.filereadable(fallback) == 1 then
    return fallback
  end

  return nil
end

local function infer_java_version_from_settings(settings_xml)
  if not settings_xml then
    return nil
  end

  local content = read_file(settings_xml)
  if not content then
    return nil
  end

  local tag_patterns = {
    '<maven%.compiler%.release>%s*([%d%.]+)%s*</maven%.compiler%.release>',
    '<maven%.compiler%.source>%s*([%d%.]+)%s*</maven%.compiler%.source>',
    '<java%.version>%s*([%d%.]+)%s*</java%.version>',
    '<jdk%.version>%s*([%d%.]+)%s*</jdk%.version>',
    '<release>%s*([%d%.]+)%s*</release>',
    '<source>%s*([%d%.]+)%s*</source>',
  }

  for _, pattern in ipairs(tag_patterns) do
    local version = content:match(pattern)
    if version and version ~= '' then
      return version
    end
  end

  return nil
end

local function infer_java_version_from_pom(root_dir)
  if not root_dir or root_dir == '' then
    return nil
  end

  local pom = root_dir .. '/pom.xml'
  if vim.fn.filereadable(pom) ~= 1 then
    return nil
  end

  local content = read_file(pom)
  if not content then
    return nil
  end

  local tag_patterns = {
    '<maven%.compiler%.release>%s*([%d%.]+)%s*</maven%.compiler%.release>',
    '<maven%.compiler%.source>%s*([%d%.]+)%s*</maven%.compiler%.source>',
    '<java%.version>%s*([%d%.]+)%s*</java%.version>',
    '<jdk%.version>%s*([%d%.]+)%s*</jdk%.version>',
    '<release>%s*([%d%.]+)%s*</release>',
    '<source>%s*([%d%.]+)%s*</source>',
  }

  for _, pattern in ipairs(tag_patterns) do
    local version = content:match(pattern)
    if version and version ~= '' then
      return version
    end
  end

  return nil
end

local function normalize_java_version(version)
  if not version or version == '' then
    return 17
  end

  local major = version:match '^(%d+)'
  if not major then
    return 17
  end

  local num = tonumber(major)
  if not num then
    return 17
  end

  if num == 1 then
    local legacy = version:match '^1%.(%d+)'
    return tonumber(legacy) or 8
  end

  return num
end

local function detect_java_home(version_major)
  local explicit = vim.env.JDTLS_JAVA_HOME
  if explicit and explicit ~= '' and vim.fn.isdirectory(explicit) == 1 then
    return explicit
  end

  local version_specific = {
    'JDTLS_JAVA_HOME_' .. tostring(version_major),
    'JAVA_' .. tostring(version_major) .. '_HOME',
    'JDK' .. tostring(version_major) .. '_HOME',
  }
  for _, name in ipairs(version_specific) do
    local value = vim.env[name]
    if value and value ~= '' and vim.fn.isdirectory(value) == 1 then
      return value
    end
  end

  if vim.fn.executable '/usr/libexec/java_home' == 1 then
    local out = vim.fn.systemlist { '/usr/libexec/java_home', '-v', tostring(version_major) }
    if vim.v.shell_error == 0 and out and out[1] and out[1] ~= '' and vim.fn.isdirectory(out[1]) == 1 then
      return out[1]
    end
  end

  local java_home = vim.env.JAVA_HOME
  if java_home and java_home ~= '' and vim.fn.isdirectory(java_home) == 1 then
    return java_home
  end

  return nil
end

local function infer_local_repo_from_settings(settings_xml)
  if not settings_xml then
    return nil
  end

  local content = read_file(settings_xml)
  if not content then
    return nil
  end

  local repo = content:match '<localRepository>%s*(.-)%s*</localRepository>'
  if not repo or repo == '' then
    return nil
  end

  repo = repo:gsub('${user.home}', vim.fn.expand '~')
  repo = vim.fn.expand(repo)

  if vim.fn.isdirectory(repo) == 1 then
    return vim.fs.normalize(repo)
  end

  return nil
end

local function detect_maven_local_repo(settings_xml)
  local repo = vim.env.MAVEN_REPO_LOCAL
  if repo and repo ~= '' and vim.fn.isdirectory(repo) == 1 then
    return vim.fs.normalize(repo)
  end

  repo = infer_local_repo_from_settings(settings_xml)
  if repo then
    return repo
  end

  local fallback = vim.fs.normalize(vim.fn.expand '~/.m2/repository')
  if vim.fn.isdirectory(fallback) == 1 then
    return fallback
  end

  return nil
end

local function detect_maven_global_settings()
  local m2_home = vim.env.M2_HOME or vim.env.MAVEN_HOME
  if not m2_home or m2_home == '' then
    return nil
  end

  local candidate = m2_home .. '/conf/settings.xml'
  if vim.fn.filereadable(candidate) == 1 then
    return candidate
  end

  return nil
end

local function detect_lombok_jar(local_repo)
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

local function parse_active_profiles_from_settings(settings_xml)
  local profiles = {}
  if not settings_xml or settings_xml == '' or vim.fn.filereadable(settings_xml) ~= 1 then
    return profiles
  end

  local content = read_file(settings_xml)
  if not content then
    return profiles
  end

  for profile in content:gmatch '<activeProfile>%s*(.-)%s*</activeProfile>' do
    append_unique(profiles, profile)
  end

  return profiles
end

local function parse_profiles_from_maven_config(root_dir)
  local profiles = {}
  if not root_dir or root_dir == '' then
    return profiles
  end

  local config_file = root_dir .. '/.mvn/maven.config'
  if vim.fn.filereadable(config_file) ~= 1 then
    return profiles
  end

  local content = read_file(config_file)
  if not content then
    return profiles
  end

  local words = split_words(content:gsub('\n', ' '))
  local i = 1
  while i <= #words do
    local w = words[i]
    if w:match '^%-P' and #w > 2 then
      for _, p in ipairs(split_csv(w:sub(3))) do
        append_unique(profiles, p)
      end
    elseif w == '-P' or w == '--activate-profiles' then
      local next_word = words[i + 1] or ''
      for _, p in ipairs(split_csv(next_word)) do
        append_unique(profiles, p)
      end
      i = i + 1
    elseif w:match '^%-%-activate%-profiles=' then
      for _, p in ipairs(split_csv(w:gsub('^%-%-activate%-profiles=', ''))) do
        append_unique(profiles, p)
      end
    end
    i = i + 1
  end

  return profiles
end

local function parse_maven_options_from_maven_config(root_dir)
  local options = {}
  if not root_dir or root_dir == '' then
    return options
  end

  local config_file = root_dir .. '/.mvn/maven.config'
  if vim.fn.filereadable(config_file) ~= 1 then
    return options
  end

  local content = read_file(config_file)
  if not content then
    return options
  end

  local words = split_words(content:gsub('\n', ' '))
  local i = 1
  while i <= #words do
    local w = words[i]
    if w:sub(1, 1) == '-' then
      table.insert(options, w)
      if w == '-P' or w == '--activate-profiles' then
        local next_word = words[i + 1]
        if next_word and next_word ~= '' then
          table.insert(options, next_word)
          i = i + 1
        end
      end
    end
    i = i + 1
  end

  return options
end

local function detect_active_maven_profiles(root_dir, settings_xml)
  local profiles = {}

  local explicit = vim.env.JDTLS_MAVEN_PROFILES
  if explicit and explicit ~= '' then
    for _, profile in ipairs(split_csv(explicit:gsub('%s+', ','))) do
      append_unique(profiles, profile)
    end
  end

  for _, profile in ipairs(parse_active_profiles_from_settings(settings_xml)) do
    append_unique(profiles, profile)
  end

  for _, profile in ipairs(parse_profiles_from_maven_config(root_dir)) do
    append_unique(profiles, profile)
  end

  return profiles
end

local function build_maven_import_arguments(cached)
  local explicit = vim.env.JDTLS_MAVEN_IMPORT_ARGUMENTS
  if explicit and explicit ~= '' then
    return explicit
  end

  local args = {}

  for _, option in ipairs(cached.maven_config_options or {}) do
    table.insert(args, option)
  end

  if cached.local_repo and not list_contains_prefix(args, '-Dmaven.repo.local=') then
    table.insert(args, '-Dmaven.repo.local=' .. cached.local_repo)
  end

  local has_profile_flag = list_contains_prefix(args, '-P')
    or list_contains_prefix(args, '--activate-profiles')
  if not has_profile_flag and type(cached.active_maven_profiles) == 'table' and not vim.tbl_isempty(cached.active_maven_profiles) then
    table.insert(args, '-P' .. table.concat(cached.active_maven_profiles, ','))
  end

  local append_args = vim.env.JDTLS_MAVEN_IMPORT_APPEND_ARGUMENTS
  if append_args and append_args ~= '' then
    for _, word in ipairs(split_words(append_args)) do
      table.insert(args, word)
    end
  end

  return table.concat(args, ' ')
end

local function derive_project_key(root_dir, cached)
  local normalized = vim.fs.normalize(root_dir)
  local base = vim.fs.basename(normalized)
  local key_seed = normalized

  if cached and cached.java_version_major then
    key_seed = key_seed .. '|java:' .. tostring(cached.java_version_major)
  end
  if cached and cached.settings_xml then
    key_seed = key_seed .. '|settings:' .. vim.fs.normalize(cached.settings_xml)
  end
  if cached and cached.local_repo then
    key_seed = key_seed .. '|repo:' .. vim.fs.normalize(cached.local_repo)
  end

  local import_args = build_maven_import_arguments(cached or {})
  if import_args ~= '' then
    key_seed = key_seed .. '|args:' .. import_args
  end

  local hash = vim.fn.sha256(key_seed):sub(1, 10)
  return base .. '-' .. hash
end

local function get_project_cache(root_dir)
  if project_cache[root_dir] then
    return project_cache[root_dir]
  end

  local settings_xml = detect_settings_xml(root_dir)
  local settings_java_version = infer_java_version_from_settings(settings_xml)
  local pom_java_version = infer_java_version_from_pom(root_dir)
  local java_version_major = normalize_java_version(settings_java_version or pom_java_version or '17')

  local cached = {
    settings_xml = settings_xml,
    global_settings_xml = detect_maven_global_settings(),
    settings_java_version = settings_java_version,
    pom_java_version = pom_java_version,
    java_version_major = java_version_major,
    java_home = detect_java_home(java_version_major),
    local_repo = detect_maven_local_repo(settings_xml),
    maven_offline = env_truthy 'JDTLS_MAVEN_OFFLINE' or env_truthy 'MAVEN_OFFLINE',
    active_maven_profiles = detect_active_maven_profiles(root_dir, settings_xml),
    maven_config_options = parse_maven_options_from_maven_config(root_dir),
  }

  cached.lombok_jar = detect_lombok_jar(cached.local_repo)
  project_cache[root_dir] = cached

  return cached
end

local function detect_jdtls_java_bin(cached)
  local explicit = vim.env.JDTLS_JAVA_BIN
  if explicit and explicit ~= '' and vim.fn.executable(explicit) == 1 then
    return explicit
  end

  local from_home = cached and cached.java_home and (cached.java_home .. '/bin/java') or nil
  if from_home and vim.fn.executable(from_home) == 1 then
    return from_home
  end

  local from_path = vim.fn.exepath 'java'
  if from_path ~= '' then
    return from_path
  end

  return 'java'
end

local function resolve_jdtls_cmd(config_dir, workspace_dir, cached)
  local jdtls_xms = vim.env.JDTLS_XMS or '1g'
  local jdtls_xmx = vim.env.JDTLS_XMX or '4g'
  local jdtls_java_bin = detect_jdtls_java_bin(cached)

  local use_lombok_agent = not env_truthy 'JDTLS_DISABLE_LOMBOK_AGENT'
  local use_lombok_bootclasspath = env_truthy 'JDTLS_LOMBOK_BOOTCLASSPATH'

  local explicit_jdtls_bin = vim.env.JDTLS_BIN
  local jdtls_bin = nil
  if explicit_jdtls_bin and explicit_jdtls_bin ~= '' and vim.fn.executable(explicit_jdtls_bin) == 1 then
    jdtls_bin = explicit_jdtls_bin
  else
    local from_path = vim.fn.exepath 'jdtls'
    if from_path ~= '' then
      jdtls_bin = from_path
    end
  end

  if jdtls_bin and jdtls_bin ~= '' then
    local cmd = { jdtls_bin }

    if jdtls_java_bin and jdtls_java_bin ~= '' then
      table.insert(cmd, '--java-executable=' .. jdtls_java_bin)
    end

    table.insert(cmd, '--jvm-arg=-Xms' .. jdtls_xms)
    table.insert(cmd, '--jvm-arg=-Xmx' .. jdtls_xmx)

    if cached.lombok_jar and use_lombok_agent then
      table.insert(cmd, '--jvm-arg=-javaagent:' .. cached.lombok_jar)
      if use_lombok_bootclasspath then
        table.insert(cmd, '--jvm-arg=-Xbootclasspath/a:' .. cached.lombok_jar)
      end
    end

    vim.list_extend(cmd, {
      '-configuration',
      config_dir,
      '-data',
      workspace_dir,
    })

    return cmd, 'jdtls-bin'
  end

  local jdtls_home = vim.env.JDTLS_HOME
  if not jdtls_home or jdtls_home == '' or vim.fn.isdirectory(jdtls_home) ~= 1 then
    return nil, nil
  end

  local launcher = vim.fn.glob(jdtls_home .. '/plugins/org.eclipse.equinox.launcher_*.jar', true, true)[1]
  if not launcher or launcher == '' then
    launcher = vim.fn.glob(jdtls_home .. '/plugins/org.eclipse.equinox.launcher.jar', true, true)[1]
  end
  if not launcher or launcher == '' then
    return nil, nil
  end

  local os_config = 'config_linux'
  if vim.fn.has 'macunix' == 1 then
    os_config = 'config_mac'
  elseif vim.fn.has 'win32' == 1 then
    os_config = 'config_win'
  end

  local jdtls_os_config_dir = jdtls_home .. '/' .. os_config
  if vim.fn.isdirectory(jdtls_os_config_dir) ~= 1 then
    return nil, nil
  end

  local cmd = {
    jdtls_java_bin,
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=WARN',
    '-Xms' .. jdtls_xms,
    '-Xmx' .. jdtls_xmx,
  }

  if cached.lombok_jar and use_lombok_agent then
    table.insert(cmd, '-javaagent:' .. cached.lombok_jar)
    if use_lombok_bootclasspath then
      table.insert(cmd, '-Xbootclasspath/a:' .. cached.lombok_jar)
    end
  end

  vim.list_extend(cmd, {
    '--add-modules=ALL-SYSTEM',
    '--add-opens',
    'java.base/java.util=ALL-UNNAMED',
    '--add-opens',
    'java.base/java.lang=ALL-UNNAMED',
    '-jar',
    launcher,
    '-configuration',
    jdtls_os_config_dir,
    '-data',
    workspace_dir,
  })

  return cmd, 'jdtls-home'
end

local function build_jdtls_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()

  local ok_blink, blink = pcall(require, 'blink.cmp')
  if ok_blink and blink.get_lsp_capabilities then
    capabilities = blink.get_lsp_capabilities(capabilities)
  end

  return capabilities
end

local function build_java_settings(base_settings, cached)
  local settings = vim.deepcopy(base_settings or {})
  settings.java = settings.java or {}

  settings.java.server = settings.java.server or {}
  settings.java.server.launchMode = settings.java.server.launchMode or 'Standard'

  settings.java.configuration = settings.java.configuration or {}
  settings.java.configuration.updateBuildConfiguration = settings.java.configuration.updateBuildConfiguration or 'automatic'
  settings.java.configuration.maven = settings.java.configuration.maven or {}
  if cached.settings_xml then
    settings.java.configuration.maven.userSettings = cached.settings_xml
  end
  if cached.global_settings_xml then
    settings.java.configuration.maven.globalSettings = cached.global_settings_xml
  end

  local explicit_lifecycle = vim.env.JDTLS_M2E_LIFECYCLE_MAPPINGS
  if explicit_lifecycle and explicit_lifecycle ~= '' and vim.fn.filereadable(explicit_lifecycle) == 1 then
    settings.java.configuration.maven.lifecycleMappings = explicit_lifecycle
  end

  settings.java.configuration.runtimes = settings.java.configuration.runtimes or {}
  if cached.java_home and #settings.java.configuration.runtimes == 0 then
    settings.java.configuration.runtimes = {
      {
        name = 'JavaSE-' .. tostring(cached.java_version_major),
        path = cached.java_home,
        default = true,
      },
    }
  end

  settings.java.import = settings.java.import or {}
  settings.java.import.maven = settings.java.import.maven or {}
  settings.java.import.maven.enabled = true
  settings.java.import.maven.disableTestClasspathFlag = false
  if cached.settings_xml then
    settings.java.import.maven.userSettings = cached.settings_xml
  end
  if cached.global_settings_xml then
    settings.java.import.maven.globalSettings = cached.global_settings_xml
  end
  if explicit_lifecycle and explicit_lifecycle ~= '' and vim.fn.filereadable(explicit_lifecycle) == 1 then
    settings.java.import.maven.lifecycleMappings = explicit_lifecycle
  end

  local import_args = build_maven_import_arguments(cached)
  if import_args ~= '' then
    settings.java.import.maven.arguments = import_args
  end

  settings.java.import.maven.offline = {
    enabled = cached.maven_offline,
  }

  settings.java.maven = settings.java.maven or {}
  settings.java.maven.downloadSources = false
  settings.java.maven.updateSnapshots = false

  settings.java.import.gradle = settings.java.import.gradle or {}
  settings.java.import.gradle.enabled = false

  settings.java.eclipse = settings.java.eclipse or {}
  settings.java.eclipse.downloadSources = false

  settings.java.autobuild = settings.java.autobuild or {}
  settings.java.autobuild.enabled = true

  settings.java.errors = settings.java.errors or {}
  settings.java.errors.incompleteClasspath = settings.java.errors.incompleteClasspath or {}
  settings.java.errors.incompleteClasspath.severity = settings.java.errors.incompleteClasspath.severity or 'error'

  return settings
end

local function refresh_jdtls_import(root_dir)
  for _, client in ipairs(vim.lsp.get_clients { name = 'jdtls' }) do
    if client and client.config and client.config.root_dir == root_dir then
      client.request('workspace/executeCommand', {
        command = 'java.project.import',
        arguments = {},
      }, function() end)
      client.request('workspace/executeCommand', {
        command = 'java.project.refreshDiagnostics',
        arguments = {},
      }, function() end)
    end
  end
end

local function refresh_jdtls_projects(root_dir, bufnr)
  bufnr = bufnr or 0

  for _, client in ipairs(vim.lsp.get_clients { name = 'jdtls' }) do
    if client and client.config and client.config.root_dir == root_dir then
      client.request('workspace/executeCommand', {
        command = 'java.project.getAll',
        arguments = {},
      }, function(err, projects)
        if err then
          client.request('java/projectConfigurationUpdate', {
            uri = vim.uri_from_bufnr(bufnr),
          }, function() end, bufnr)
          return
        end

        local identifiers = {}
        if type(projects) == 'table' then
          for _, project_uri in ipairs(projects) do
            if type(project_uri) == 'string' and project_uri ~= '' then
              table.insert(identifiers, { uri = project_uri })
            end
          end
        end

        if vim.tbl_isempty(identifiers) then
          client.request('java/projectConfigurationUpdate', {
            uri = vim.uri_from_bufnr(bufnr),
          }, function() end, bufnr)
          return
        end

        client.notify('java/projectConfigurationsUpdate', {
          identifiers = identifiers,
        })
        client.request('java/buildProjects', {
          identifiers = identifiers,
          isFullBuild = true,
        }, function() end, bufnr)
      end, bufnr)
    end
  end
end

local function build_maven_sync_cmd(root_dir, cached, opts)
  opts = opts or {}

  local cmd = {}
  local mvnw = root_dir .. '/mvnw'
  if vim.fn.executable(mvnw) == 1 then
    table.insert(cmd, mvnw)
  elseif vim.fn.executable 'mvn' == 1 then
    table.insert(cmd, 'mvn')
  else
    return nil
  end

  if cached.settings_xml then
    vim.list_extend(cmd, { '-s', cached.settings_xml })
  end

  if cached.global_settings_xml then
    vim.list_extend(cmd, { '-gs', cached.global_settings_xml })
  end

  if cached.local_repo then
    table.insert(cmd, '-Dmaven.repo.local=' .. cached.local_repo)
  end

  if cached.maven_offline then
    table.insert(cmd, '-o')
  end

  if opts.force then
    table.insert(cmd, '-U')
  end

  if type(cached.active_maven_profiles) == 'table' and not vim.tbl_isempty(cached.active_maven_profiles) then
    table.insert(cmd, '-P' .. table.concat(cached.active_maven_profiles, ','))
  end

  local default_flags = split_words(vim.env.JDTLS_MAVEN_SYNC_FLAGS or '-DskipTests -DskipITs -Dmaven.test.skip=true')
  vim.list_extend(cmd, default_flags)

  local goals = split_words(vim.env.JDTLS_MAVEN_SYNC_GOALS or 'generate-sources')
  if vim.tbl_isempty(goals) then
    goals = { 'generate-sources' }
  end
  vim.list_extend(cmd, goals)

  return cmd
end

local function summarize_text(text)
  if not text or text == '' then
    return ''
  end

  local lines = vim.split(text, '\n', { trimempty = true })
  if vim.tbl_isempty(lines) then
    return ''
  end

  local start = math.max(1, #lines - 11)
  return table.concat(vim.list_slice(lines, start, #lines), '\n')
end

local function run_maven_sync(root_dir, cached, opts)
  opts = opts or {}

  if maven_sync_state[root_dir] then
    vim.notify('[java3] Maven sync already running for this root.', vim.log.levels.INFO)
    return
  end

  local cmd = build_maven_sync_cmd(root_dir, cached, opts)
  if not cmd then
    vim.notify('[java3] Maven executable not found (`mvnw` or `mvn`).', vim.log.levels.ERROR)
    return
  end

  maven_sync_state[root_dir] = true
  vim.notify('[java3] Running Maven sync: ' .. table.concat(cmd, ' '), vim.log.levels.INFO)

  local function on_complete(code, output)
    maven_sync_state[root_dir] = false
    if code == 0 then
      vim.notify('[java3] Maven sync finished. Refreshing JDTLS projects...', vim.log.levels.INFO)
      refresh_jdtls_projects(root_dir, 0)
      refresh_jdtls_import(root_dir)
      return
    end

    local summary = summarize_text(output)
    local suffix = summary ~= '' and ('\n' .. summary) or ''
    vim.notify(string.format('[java3] Maven sync failed (exit %d).%s', code, suffix), vim.log.levels.ERROR)
  end

  if vim.system then
    vim.system(cmd, { cwd = root_dir, text = true }, function(result)
      vim.schedule(function()
        local output = (result.stdout or '') .. '\n' .. (result.stderr or '')
        on_complete(result.code or 1, output)
      end)
    end)
    return
  end

  local chunks = {}
  vim.fn.jobstart(cmd, {
    cwd = root_dir,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if type(data) == 'table' then
        vim.list_extend(chunks, data)
      end
    end,
    on_stderr = function(_, data)
      if type(data) == 'table' then
        vim.list_extend(chunks, data)
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        on_complete(code, table.concat(chunks, '\n'))
      end)
    end,
  })
end

local function apply_active_profiles(client, bufnr, profiles)
  if not client or type(profiles) ~= 'table' or vim.tbl_isempty(profiles) then
    return
  end

  local profiles_csv = table.concat(profiles, ',')
  local uri = vim.uri_from_bufnr(bufnr)
  local params = {
    command = 'java.project.updateSettings',
    arguments = {
      uri,
      {
        ['org.eclipse.m2e.core.selectedProfiles'] = profiles_csv,
      },
    },
  }

  client.request('workspace/executeCommand', params, function() end, bufnr)
end

local function split_path_list(value)
  if not value or value == '' then
    return {}
  end

  local separator = (vim.fn.has 'win32' == 1) and ';' or ':'
  local out = {}
  for _, item in ipairs(vim.split(value, separator, { trimempty = true })) do
    local path = vim.trim(item)
    if path ~= '' and vim.fn.filereadable(path) == 1 then
      table.insert(out, path)
    end
  end
  return out
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
    opts = function()
      return {
        root_dir = function(path)
          return detect_root_dir(path)
        end,
        project_name = function(root_dir)
          return root_dir and vim.fs.basename(root_dir) or nil
        end,
        project_key = derive_project_key,
        jdtls_config_dir = function(project_key)
          return vim.fn.stdpath 'cache' .. '/jdtls/' .. project_key .. '/config'
        end,
        jdtls_workspace_dir = function(project_key)
          return vim.fn.stdpath 'cache' .. '/jdtls/' .. project_key .. '/workspace'
        end,
        bundles = split_path_list(vim.env.JDTLS_BUNDLES),
        full_cmd = function(cfg, project_key, cached)
          local config_dir = cfg.jdtls_config_dir(project_key)
          local workspace_dir = cfg.jdtls_workspace_dir(project_key)
          vim.fn.mkdir(config_dir, 'p')
          vim.fn.mkdir(workspace_dir, 'p')
          local cmd, cmd_source = resolve_jdtls_cmd(config_dir, workspace_dir, cached)
          return cmd, config_dir, workspace_dir, cmd_source
        end,
        settings = {
          java = {
            inlayHints = {
              parameterNames = {
                enabled = 'all',
              },
            },
          },
        },
      }
    end,
    config = function(_, opts)
      local function attach_jdtls()
        if vim.bo.filetype ~= 'java' then
          return
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        if bufname == '' then
          return
        end

        local root_dir = opts.root_dir(bufname)
        if not root_dir or root_dir == '' then
          return
        end

        local cached = get_project_cache(root_dir)
        local project_name = opts.project_name(root_dir)
        local project_key = opts.project_key(root_dir, cached)
        local cmd, config_dir, workspace_dir, cmd_source = opts.full_cmd(opts, project_key, cached)

        if not cmd then
          vim.notify('[java3] jdtls not found. Set JDTLS_BIN or JDTLS_HOME, or ensure `jdtls` is in PATH.', vim.log.levels.WARN)
          return
        end

        local config = {
          cmd = cmd,
          root_dir = root_dir,
          settings = build_java_settings(opts.settings, cached),
          capabilities = build_jdtls_capabilities(),
          init_options = {
            bundles = opts.bundles or {},
          },
        }

        config = extend_or_override(config, opts.jdtls)

        vim.g.ba_jdtls_last = {
          root_dir = root_dir,
          project_name = project_name,
          project_key = project_key,
          config_dir = config_dir,
          workspace_dir = workspace_dir,
          cmd_source = cmd_source,
          cmd = cmd,
          settings_xml = cached.settings_xml,
          global_settings_xml = cached.global_settings_xml,
          local_repo = cached.local_repo,
          maven_import_arguments = build_maven_import_arguments(cached),
          active_maven_profiles = cached.active_maven_profiles,
          java_version_major = cached.java_version_major,
          java_home = cached.java_home,
          lombok_jar = cached.lombok_jar,
          maven_offline = cached.maven_offline,
        }

        require('jdtls').start_or_attach(config)

        vim.defer_fn(function()
          local clients = vim.lsp.get_clients { name = 'jdtls', bufnr = bufnr }
          for _, client in ipairs(clients) do
            if client and client.config and client.config.root_dir == root_dir then
              apply_active_profiles(client, bufnr, cached.active_maven_profiles)
              break
            end
          end
        end, 200)
      end

      local augroup = vim.api.nvim_create_augroup('ba-java3-jdtls', { clear = true })

      if vim.fn.exists ':JdtlsStatus' == 0 then
        vim.api.nvim_create_user_command('JdtlsStatus', function()
          local state = vim.g.ba_jdtls_last
          if not state then
            vim.notify('[java3] jdtls has not been initialized in this session yet.', vim.log.levels.INFO)
            return
          end
          vim.notify(vim.inspect(state), vim.log.levels.INFO)
        end, { desc = 'Show last resolved jdtls configuration' })
      end

      if vim.fn.exists ':JdtMavenSync' == 0 then
        vim.api.nvim_create_user_command('JdtMavenSync', function(command_opts)
          local bufname = vim.api.nvim_buf_get_name(0)
          if bufname == '' then
            vim.notify('[java3] Cannot run Maven sync: no file in current buffer.', vim.log.levels.WARN)
            return
          end

          local root_dir = opts.root_dir(bufname)
          if not root_dir then
            vim.notify('[java3] Cannot run Maven sync: no Java project root found.', vim.log.levels.WARN)
            return
          end

          local cached = get_project_cache(root_dir)
          run_maven_sync(root_dir, cached, { force = command_opts.bang })
        end, {
          bang = true,
          desc = 'Run Maven generate-sources for current Java root (! adds -U)',
        })
      end

      if vim.fn.exists ':JdtProjectsRefresh' == 0 then
        vim.api.nvim_create_user_command('JdtProjectsRefresh', function()
          local bufname = vim.api.nvim_buf_get_name(0)
          if bufname == '' then
            vim.notify('[java3] Cannot refresh projects: no file in current buffer.', vim.log.levels.WARN)
            return
          end

          local root_dir = opts.root_dir(bufname)
          if not root_dir then
            vim.notify('[java3] Cannot refresh projects: no Java project root found.', vim.log.levels.WARN)
            return
          end

          refresh_jdtls_projects(root_dir, 0)
          refresh_jdtls_import(root_dir)
          vim.notify('[java3] Triggered JDTLS project refresh and diagnostics refresh.', vim.log.levels.INFO)
        end, {
          desc = 'Trigger JDTLS project/import refresh for current Java root',
        })
      end

      vim.api.nvim_create_autocmd('FileType', {
        group = augroup,
        pattern = java_filetypes,
        callback = attach_jdtls,
      })

      -- Handle first Java buffer when plugin loads on FileType.
      attach_jdtls()
    end,
  },
}
