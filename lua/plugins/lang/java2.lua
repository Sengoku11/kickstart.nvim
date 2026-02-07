local java_filetypes = { 'java' }
local project_cache = {}
local maven_sync_state = {}
local workspace_build_state = {}
local should_apply_active_profiles
local should_disable_ge_maven_extension

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
  local project_root, maven_module_root = detect_maven_project_root(path)
  local tooling_root = detect_maven_tooling_root(path)
  local module_root = maven_module_root or vim.fs.root(path, {
    'pom.xml',
    'build.gradle',
    'build.gradle.kts',
  })

  if root_mode == 'repo' or root_mode == 'project' then
    if project_root then
      return project_root
    end
    if tooling_root and vim.fn.filereadable(tooling_root .. '/pom.xml') == 1 then
      return tooling_root
    end
    if module_root then
      return module_root
    end
    if tooling_root then
      return tooling_root
    end
  elseif root_mode == 'module' then
    if module_root then
      return module_root
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
    if module_root then
      return module_root
    end
    if tooling_root then
      return tooling_root
    end
  end

  return vim.fs.root(path, root_markers())
end

local function detect_settings_xml(root_dir)
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

local function detect_active_maven_profiles(root_dir, settings_xml)
  local profiles = {}

  if env_truthy 'JDTLS_INCLUDE_ENV_MAVEN_PROFILES' then
    for _, p in ipairs(split_csv(vim.env.JDTLS_MAVEN_PROFILES)) do
      append_unique(profiles, p)
    end
    for _, p in ipairs(split_csv(vim.env.MAVEN_PROFILES_ACTIVE)) do
      append_unique(profiles, p)
    end
  end
  for _, p in ipairs(parse_active_profiles_from_settings(settings_xml)) do
    append_unique(profiles, p)
  end
  for _, p in ipairs(parse_profiles_from_maven_config(root_dir)) do
    append_unique(profiles, p)
  end

  return profiles
end

local function infer_java_version_from_settings(settings_xml)
  if not settings_xml then
    return '17'
  end

  local content = read_file(settings_xml)
  if not content then
    return '17'
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

  return '17'
end

local function resolve_pom_property(value, content)
  if not value or value == '' or not content then
    return value
  end

  local prop = value:match '^%${([%w%._%-]+)}$'
  if not prop then
    return value
  end

  local escaped = prop:gsub('([%-%.])', '%%%1')
  local resolved = content:match('<' .. escaped .. '>%s*(.-)%s*</' .. escaped .. '>')
  if resolved and resolved ~= '' then
    return resolved
  end

  return value
end

local function infer_java_version_from_pom(root_dir)
  if not root_dir or root_dir == '' then
    return nil
  end

  local pom_xml = root_dir .. '/pom.xml'
  if vim.fn.filereadable(pom_xml) ~= 1 then
    return nil
  end

  local content = read_file(pom_xml)
  if not content then
    return nil
  end

  local patterns = {
    '<maven%.compiler%.release>%s*(.-)%s*</maven%.compiler%.release>',
    '<maven%.compiler%.source>%s*(.-)%s*</maven%.compiler%.source>',
    '<java%.version>%s*(.-)%s*</java%.version>',
    '<jdk%.version>%s*(.-)%s*</jdk%.version>',
    '<release>%s*(.-)%s*</release>',
    '<source>%s*(.-)%s*</source>',
  }

  for _, pattern in ipairs(patterns) do
    local version = resolve_pom_property(content:match(pattern), content)
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
  local function try_mac_java_home(query)
    if vim.fn.executable '/usr/libexec/java_home' ~= 1 then
      return nil
    end
    local out = vim.fn.systemlist { '/usr/libexec/java_home', '-v', query }
    if vim.v.shell_error == 0 and out and out[1] and out[1] ~= '' and vim.fn.isdirectory(out[1]) == 1 then
      return out[1]
    end
    return nil
  end

  if vim.fn.executable '/usr/libexec/java_home' == 1 then
    local exact = try_mac_java_home(tostring(version_major))
    if exact then
      return exact
    end

    local at_least = try_mac_java_home(tostring(version_major) .. '+')
    if at_least then
      return at_least
    end
  end

  local java_home_env = vim.env.JAVA_HOME
  if java_home_env and java_home_env ~= '' and vim.fn.isdirectory(java_home_env) == 1 then
    return java_home_env
  end

  return nil
end

local function extract_toolchain_candidates(toolchains_xml)
  local candidates = {}
  if not toolchains_xml or toolchains_xml == '' or vim.fn.filereadable(toolchains_xml) ~= 1 then
    return candidates
  end

  local content = read_file(toolchains_xml)
  if not content then
    return candidates
  end

  for block in content:gmatch '<toolchain>(.-)</toolchain>' do
    local toolchain_type = block:match '<type>%s*(.-)%s*</type>'
    if toolchain_type == 'jdk' then
      local version = block:match '<provides>.-<version>%s*(.-)%s*</version>.-</provides>'
      local jdk_home = block:match '<configuration>.-<jdkHome>%s*(.-)%s*</jdkHome>.-</configuration>'
      if version and jdk_home then
        jdk_home = jdk_home:gsub('${user.home}', vim.fn.expand '~')
        jdk_home = vim.fn.expand(jdk_home)
        if vim.fn.isdirectory(jdk_home) == 1 then
          table.insert(candidates, { version = version, home = jdk_home })
        end
      end
    end
  end

  return candidates
end

local function detect_java_home_from_toolchains(root_dir, requested_major)
  local files = {}
  if root_dir and root_dir ~= '' then
    table.insert(files, root_dir .. '/.mvn/toolchains.xml')
  end
  table.insert(files, vim.fn.expand '~/.m2/toolchains.xml')

  local best_exact = nil
  local best_ge = nil

  for _, file in ipairs(files) do
    for _, candidate in ipairs(extract_toolchain_candidates(file)) do
      local major = normalize_java_version(candidate.version)
      if major == requested_major and not best_exact then
        best_exact = candidate.home
      elseif major > requested_major and (not best_ge or major < best_ge.major) then
        best_ge = { major = major, home = candidate.home }
      end
    end
  end

  if best_exact then
    return best_exact
  end
  if best_ge then
    return best_ge.home
  end

  return nil
end

local function java_bin_from_home(java_home)
  if not java_home or java_home == '' then
    return nil
  end

  local ext = vim.fn.has 'win32' == 1 and '.exe' or ''
  local candidate = java_home .. '/bin/java' .. ext
  if vim.fn.executable(candidate) == 1 then
    return candidate
  end

  return nil
end

local function detect_jdtls_java_bin(cached)
  local explicit_java_bin = vim.env.JDTLS_JAVA_EXECUTABLE
  if explicit_java_bin and explicit_java_bin ~= '' and vim.fn.executable(explicit_java_bin) == 1 then
    return explicit_java_bin
  end

  local explicit_java_home = vim.env.JDTLS_JAVA_HOME
  local java_bin = java_bin_from_home(explicit_java_home)
  if java_bin then
    return java_bin
  end

  local preferred_launch_major = tonumber(vim.env.JDTLS_LAUNCH_JAVA_MAJOR or '')
    or math.max(21, cached.java_version_major or 21)
  java_bin = java_bin_from_home(detect_java_home(preferred_launch_major))
  if java_bin then
    return java_bin
  end

  java_bin = java_bin_from_home(detect_java_home(21))
  if java_bin then
    return java_bin
  end

  java_bin = java_bin_from_home(cached.java_home)
  if java_bin then
    return java_bin
  end

  local path_java = vim.fn.exepath 'java'
  if path_java ~= '' then
    return path_java
  end

  return 'java'
end

local function detect_mason_jdtls_home()
  local home = vim.fn.stdpath 'data' .. '/mason/packages/jdtls'
  if vim.fn.isdirectory(home) == 1 then
    return home
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
    return repo
  end

  return nil
end

local function detect_maven_local_repo(settings_xml)
  local repo = vim.env.MAVEN_REPO_LOCAL
  if repo and repo ~= '' and vim.fn.isdirectory(repo) == 1 then
    return repo
  end

  repo = infer_local_repo_from_settings(settings_xml)
  if repo then
    return repo
  end

  local fallback = vim.fn.expand '~/.m2/repository'
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

local function append_develocity_disable_flags(args)
  vim.list_extend(args, {
    '-Ddevelocity.enabled=false',
    '-Dgradle.enterprise.enabled=false',
    '-Ddevelocity.scan.disabled=true',
    '-Dscan=false',
    '-Dcom.gradle.scan.disabled=true',
    '-Dgradle.scan.disable=true',
    '-Dcom.gradle.enterprise.maven.extension.enabled=false',
    '-Dgradle.enterprise.maven.extension.enabled=false',
    '-Ddevelocity.maven.extension.enabled=false',
  })
end

local function build_maven_import_arguments(cached)
  local args = {}

  if cached and cached.local_repo then
    table.insert(args, '-Dmaven.repo.local=' .. cached.local_repo)
  end

  if should_apply_active_profiles and should_apply_active_profiles() then
    if cached and type(cached.active_maven_profiles) == 'table' and #cached.active_maven_profiles > 0 then
      table.insert(args, '-P' .. table.concat(cached.active_maven_profiles, ','))
    end
  end

  if should_disable_ge_maven_extension and should_disable_ge_maven_extension(cached) then
    append_develocity_disable_flags(args)
  end

  return table.concat(args, ' ')
end

local function detect_lombok_jar(local_repo)
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

local function has_gradle_enterprise_maven_extension(root_dir)
  local detected = false

  each_parent_dir(root_dir, function(dir)
    local extensions_xml = dir .. '/.mvn/extensions.xml'
    if vim.fn.filereadable(extensions_xml) ~= 1 then
      return false
    end

    local content = read_file(extensions_xml)
    if not content then
      return false
    end

    local lowered = content:lower()
    local match = lowered:find('gradle%-enterprise%-maven%-extension', 1, false) ~= nil
      or lowered:find('develocity%-maven%-extension', 1, false) ~= nil
      or lowered:find('com%.gradle', 1, false) ~= nil

    if match then
      detected = true
      return true
    end

    return false
  end)

  return detected
end

local function detect_lifecycle_mappings_file(root_dir)
  local explicit = vim.env.JDTLS_M2E_LIFECYCLE_MAPPINGS
  if explicit and explicit ~= '' and vim.fn.filereadable(explicit) == 1 then
    return explicit
  end

  local discovered = nil
  each_parent_dir(root_dir, function(dir)
    local candidates = {
      dir .. '/.mvn/lifecycle-mapping-metadata.xml',
      dir .. '/m2e-lifecycle-mapping.xml',
    }

    for _, file in ipairs(candidates) do
      if vim.fn.filereadable(file) == 1 then
        discovered = file
        return true
      end
    end

    return false
  end)

  if discovered then
    return discovered
  end

  local fallback = vim.fn.stdpath 'config' .. '/m2e-lifecycle-mapping.xml'
  if vim.fn.filereadable(fallback) == 1 then
    return fallback
  end

  return nil
end

local function derive_project_key(root_dir, cached)
  local normalized = vim.fs.normalize(root_dir)
  local base = vim.fs.basename(normalized)
  local java_major = cached and cached.java_version_major or nil
  local key_seed = normalized
  if java_major then
    key_seed = key_seed .. '|java:' .. tostring(java_major)
  end
  if cached and cached.settings_xml then
    key_seed = key_seed .. '|settings:' .. vim.fs.normalize(cached.settings_xml)
  end
  if cached and cached.local_repo then
    key_seed = key_seed .. '|repo:' .. vim.fs.normalize(cached.local_repo)
  end
  key_seed = key_seed .. '|rootMode:' .. ((vim.env.JDTLS_ROOT_MODE or 'auto'):lower())
  key_seed = key_seed .. '|importArgs:' .. build_maven_import_arguments(cached)
  local hash = vim.fn.sha256(key_seed):sub(1, 10)
  return base .. '-' .. hash
end

local function get_project_cache(root_dir)
  if project_cache[root_dir] then
    return project_cache[root_dir]
  end

  local settings_xml = detect_settings_xml(root_dir)
  local pom_java_version = infer_java_version_from_pom(root_dir)
  local settings_java_version = infer_java_version_from_settings(settings_xml)
  local java_version_major = normalize_java_version(pom_java_version or settings_java_version)

  local java_home = detect_java_home(java_version_major) or detect_java_home_from_toolchains(root_dir, java_version_major)
  local active_profiles = detect_active_maven_profiles(root_dir, settings_xml)

  local cached = {
    settings_xml = settings_xml,
    global_settings_xml = detect_maven_global_settings(),
    lifecycle_mappings_xml = detect_lifecycle_mappings_file(root_dir),
    pom_java_version = pom_java_version,
    settings_java_version = settings_java_version,
    java_version_major = java_version_major,
    java_home = java_home,
    active_maven_profiles = active_profiles,
    local_repo = detect_maven_local_repo(settings_xml),
    maven_offline = env_truthy 'JDTLS_MAVEN_OFFLINE' or env_truthy 'MAVEN_OFFLINE',
    has_ge_maven_extension = has_gradle_enterprise_maven_extension(root_dir),
  }

  cached.lombok_jar = detect_lombok_jar(cached.local_repo)
  project_cache[root_dir] = cached
  return cached
end

local function resolve_jdtls_cmd(config_dir, workspace_dir, cached)
  local jdtls_xms = vim.env.JDTLS_XMS or '1g'
  local jdtls_xmx = vim.env.JDTLS_XMX or '4g'
  local jdtls_java_bin = detect_jdtls_java_bin(cached)
  local enable_lombok_agent = not env_truthy 'JDTLS_DISABLE_LOMBOK_AGENT'
  local enable_lombok_bootclasspath = env_truthy 'JDTLS_LOMBOK_BOOTCLASSPATH'
  local extra_jvm_props = {}
  if should_disable_ge_maven_extension and should_disable_ge_maven_extension(cached) then
    append_develocity_disable_flags(extra_jvm_props)
  end

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
    if env_truthy 'JDTLS_SKIP_JAVA_VERSION_CHECK' then
      table.insert(cmd, '--no-validate-java-version')
    end

    table.insert(cmd, '--jvm-arg=-Xms' .. jdtls_xms)
    table.insert(cmd, '--jvm-arg=-Xmx' .. jdtls_xmx)

    for _, prop in ipairs(extra_jvm_props) do
      table.insert(cmd, '--jvm-arg=' .. prop)
    end

    if enable_lombok_agent and cached.lombok_jar then
      table.insert(cmd, '--jvm-arg=-javaagent:' .. cached.lombok_jar)
      if enable_lombok_bootclasspath then
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

  local function cmd_from_jdtls_home(jdtls_home, source)
    if not jdtls_home or jdtls_home == '' or vim.fn.isdirectory(jdtls_home) ~= 1 then
      return nil
    end

    local launcher = vim.fn.glob(jdtls_home .. '/plugins/org.eclipse.equinox.launcher_*.jar', true, true)[1]
    if not launcher or launcher == '' then
      launcher = vim.fn.glob(jdtls_home .. '/plugins/org.eclipse.equinox.launcher.jar', true, true)[1]
    end
    if not launcher or launcher == '' then
      return nil
    end

    local os_config = 'config_linux'
    if vim.fn.has 'macunix' == 1 then
      os_config = 'config_mac'
    elseif vim.fn.has 'win32' == 1 then
      os_config = 'config_win'
    end

    local jdtls_os_config_dir = jdtls_home .. '/' .. os_config
    if vim.fn.isdirectory(jdtls_os_config_dir) ~= 1 then
      return nil
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

    vim.list_extend(cmd, extra_jvm_props)

    if enable_lombok_agent and cached.lombok_jar then
      table.insert(cmd, '-javaagent:' .. cached.lombok_jar)
      if enable_lombok_bootclasspath then
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

    return cmd, source
  end

  local explicit_jdtls_home = vim.env.JDTLS_HOME
  if explicit_jdtls_home and explicit_jdtls_home ~= '' then
    local cmd, source = cmd_from_jdtls_home(explicit_jdtls_home, 'env:JDTLS_HOME')
    if cmd then
      return cmd, source
    end
  end

  local mason_jdtls_home = detect_mason_jdtls_home()
  if mason_jdtls_home then
    local cmd, source = cmd_from_jdtls_home(mason_jdtls_home, 'mason:jdtls')
    if cmd then
      return cmd, source
    end
  end

  return nil, nil
end

local function should_auto_maven_sync(cached)
  local explicit = vim.env.JDTLS_MAVEN_SYNC_ON_ATTACH
  if explicit ~= nil and explicit ~= '' then
    return env_truthy 'JDTLS_MAVEN_SYNC_ON_ATTACH'
  end

  -- Auto-sync by default only for known problematic extension setups.
  return cached.has_ge_maven_extension
end

local function build_maven_sync_cmd(cached)
  if vim.fn.executable 'mvn' ~= 1 then
    return nil
  end

  local cmd = { 'mvn', '-B', '-q' }
  if cached.settings_xml then
    vim.list_extend(cmd, { '-s', cached.settings_xml })
  end
  if cached.global_settings_xml then
    vim.list_extend(cmd, { '-gs', cached.global_settings_xml })
  end
  if cached.local_repo then
    table.insert(cmd, '-Dmaven.repo.local=' .. cached.local_repo)
  end
  if should_apply_active_profiles() and type(cached.active_maven_profiles) == 'table' and #cached.active_maven_profiles > 0 then
    table.insert(cmd, '-P' .. table.concat(cached.active_maven_profiles, ','))
  end

  vim.list_extend(cmd, {
    '-DskipTests',
    '-DskipITs',
    '-Dmaven.test.skip=true',
  })
  if should_disable_ge_maven_extension and should_disable_ge_maven_extension(cached) then
    append_develocity_disable_flags(cmd)
  end

  local goals = split_words(vim.env.JDTLS_MAVEN_SYNC_GOALS or 'generate-sources process-resources compile')
  if vim.tbl_isempty(goals) then
    goals = { 'generate-sources', 'process-resources' }
  end
  vim.list_extend(cmd, goals)

  return cmd
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

local function list_generated_source_dirs(root_dir)
  local seen = {}
  local dirs = {}
  local patterns = {
    root_dir .. '/**/target/generated-sources/**/src/main/java',
    root_dir .. '/**/target/generated-sources/**/src/generated/java',
    root_dir .. '/**/target/generated-sources/**/java',
  }

  for _, pattern in ipairs(patterns) do
    local matches = vim.fn.glob(pattern, true, true)
    if type(matches) == 'table' then
      for _, path in ipairs(matches) do
        if vim.fn.isdirectory(path) == 1 then
          local normalized = vim.fs.normalize(path)
          if not seen[normalized] then
            seen[normalized] = true
            table.insert(dirs, normalized)
          end
        end
      end
    end
  end

  table.sort(dirs)
  return dirs
end

local function attach_generated_sources(root_dir, bufnr)
  bufnr = bufnr or 0
  local source_dirs = list_generated_source_dirs(root_dir)
  if vim.tbl_isempty(source_dirs) then
    return
  end

  local uri = vim.uri_from_bufnr(bufnr)
  if not uri or uri == '' then
    uri = vim.uri_from_fname(root_dir .. '/pom.xml')
  end

  for _, client in ipairs(vim.lsp.get_clients { name = 'jdtls' }) do
    if client and client.config and client.config.root_dir == root_dir then
      for _, dir in ipairs(source_dirs) do
        local dir_uri = vim.uri_from_fname(dir)
        local arg_sets = {
          { uri, dir },
          { uri, dir_uri },
          { uri, { dir } },
          { uri, { dir_uri } },
        }
        for _, args in ipairs(arg_sets) do
          client.request('workspace/executeCommand', {
            command = 'java.project.addToSourcePath',
            arguments = args,
          }, function() end, bufnr)
        end
      end
    end
  end
end

local function request_list_source_paths(client, bufnr, uri, cb)
  local arg_sets = {
    { uri },
    { uri, {} },
    {},
  }
  local idx = 1

  local function try_next()
    local args = arg_sets[idx]
    idx = idx + 1
    if not args then
      cb(nil, nil)
      return
    end

    client.request('workspace/executeCommand', {
      command = 'java.project.listSourcePaths',
      arguments = args,
    }, function(err, result)
      if not err and type(result) == 'table' then
        cb(nil, result)
        return
      end
      try_next()
    end, bufnr)
  end

  try_next()
end

local function tail_file_lines(path, max_lines)
  if not path or path == '' or vim.fn.filereadable(path) ~= 1 then
    return {}
  end

  local lines = {}
  if vim.fn.executable 'tail' == 1 then
    lines = vim.fn.systemlist({ 'tail', '-n', tostring(max_lines), path })
    if vim.v.shell_error == 0 and type(lines) == 'table' then
      return lines
    end
  end

  local all = vim.fn.readfile(path)
  if type(all) ~= 'table' then
    return {}
  end
  if #all <= max_lines then
    return all
  end
  return vim.list_slice(all, #all - max_lines + 1, #all)
end

local function collect_log_hits(path, patterns, max_lines, max_hits)
  local lines = tail_file_lines(path, max_lines)
  if vim.tbl_isempty(lines) then
    return {}
  end

  local hits = {}
  for idx, line in ipairs(lines) do
    local lowered = line:lower()
    local matched = false
    for _, pattern in ipairs(patterns) do
      if pattern ~= '' and lowered:find(pattern, 1, true) then
        matched = true
        break
      end
    end
    if matched then
      table.insert(hits, string.format('%s:%d: %s', path, idx, line))
      if #hits >= max_hits then
        break
      end
    end
  end

  return hits
end

local function gather_log_candidates(workspace_dir)
  local seen = {}
  local paths = {}
  local function add(path)
    if not path or path == '' then
      return
    end
    path = vim.fs.normalize(vim.fn.expand(path))
    if seen[path] then
      return
    end
    if vim.fn.filereadable(path) == 1 then
      seen[path] = true
      table.insert(paths, path)
    end
  end

  if workspace_dir and workspace_dir ~= '' then
    workspace_dir = vim.fs.normalize(vim.fn.expand(workspace_dir))
    add(workspace_dir .. '/.metadata/.log')
    for _, path in ipairs(vim.fn.glob(workspace_dir .. '/.metadata/.plugins/**/*.log', true, true)) do
      local lowered = path:lower()
      if lowered:find('m2e', 1, true) or lowered:find('jdt', 1, true) or lowered:find('maven', 1, true) then
        add(path)
      end
    end
  end

  local lsp_log_path = vim.lsp.get_log_path and vim.lsp.get_log_path() or nil
  add(lsp_log_path)

  table.sort(paths)
  return paths
end

local function find_generated_package_files(root_dir, package_name)
  if not root_dir or root_dir == '' or not package_name or package_name == '' then
    return {}
  end
  local rel = package_name:gsub('%.', '/')
  local pattern = root_dir .. '/**/target/generated-sources/**/' .. rel .. '/**/*.java'
  local files = vim.fn.glob(pattern, true, true)
  if type(files) ~= 'table' then
    return {}
  end
  table.sort(files)
  return files
end

local function open_report_buffer(title, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, title)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'markdown'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.cmd 'botright split'
  vim.api.nvim_win_set_buf(0, buf)
end

local function run_root_cause_probe(query)
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients { name = 'jdtls', bufnr = bufnr }
  if vim.tbl_isempty(clients) then
    vim.notify('[java2] No jdtls client attached to current buffer.', vim.log.levels.WARN)
    return
  end

  local client = clients[1]
  local root_dir = client.config and client.config.root_dir or ''
  local uri = vim.uri_from_bufnr(bufnr)
  local state = vim.g.ba_jdtls_last or {}
  local workspace_dir = state.workspace_dir and vim.fs.normalize(vim.fn.expand(state.workspace_dir)) or nil
  local query_path = query:gsub('%.', '/')
  local patterns = {
    'outofscopeexception',
    'failed to execute mojo',
    'unable to provision',
    'no mavenproject is executing on this thread',
    'pluginexecutionexception',
    'openapi-generator-maven-plugin',
    'maven-antrun-plugin',
    'import cannot be resolved',
    'the import cannot be resolved',
    query:lower(),
    query_path:lower(),
  }

  vim.notify('[java2] Running root-cause probe for import resolution...', vim.log.levels.INFO)

  client.request('java/buildWorkspace', true, function(build_err, build_result)
    client.request('workspace/executeCommand', {
      command = 'java.project.getClasspaths',
      arguments = { uri, vim.fn.json_encode { scope = 'runtime' } },
    }, function(cp_err, classpaths)
      request_list_source_paths(client, bufnr, uri, function(sp_err, source_paths)
        vim.schedule(function()
          local log_candidates = gather_log_candidates(workspace_dir)
          local hit_lines = {}
          for _, path in ipairs(log_candidates) do
            local hits = collect_log_hits(path, patterns, 2500, 60)
            vim.list_extend(hit_lines, hits)
          end

          local generated_files = find_generated_package_files(root_dir, query)
          local generated_dirs = list_generated_source_dirs(root_dir)

          local report = {
            '# JDTLS Root Cause Probe',
            '',
            '- query: `' .. query .. '`',
            '- root_dir: `' .. tostring(root_dir) .. '`',
            '- workspace_dir: `' .. tostring(workspace_dir or '') .. '`',
            '- build_result: `' .. tostring(build_result) .. '`',
            '- build_error: `' .. tostring(build_err and (build_err.message or vim.inspect(build_err)) or 'nil') .. '`',
            '- classpath_error: `' .. tostring(cp_err and (cp_err.message or vim.inspect(cp_err)) or 'nil') .. '`',
            '- source_paths_error: `' .. tostring(sp_err and (sp_err.message or vim.inspect(sp_err)) or 'nil') .. '`',
            '- generated_files_count: `' .. tostring(#generated_files) .. '`',
            '- generated_dirs_count: `' .. tostring(#generated_dirs) .. '`',
            '',
            '## Generated Dirs',
          }

          if vim.tbl_isempty(generated_dirs) then
            table.insert(report, '- none detected under `target/generated-sources`')
          else
            for _, dir in ipairs(vim.list_slice(generated_dirs, 1, 40)) do
              table.insert(report, '- `' .. dir .. '`')
            end
          end

          table.insert(report, '')
          table.insert(report, '## Generated Files Matching Query')
          if vim.tbl_isempty(generated_files) then
            table.insert(report, '- none found')
          else
            for _, file in ipairs(vim.list_slice(generated_files, 1, 40)) do
              table.insert(report, '- `' .. file .. '`')
            end
          end

          table.insert(report, '')
          table.insert(report, '## JDTLS Source Paths')
          if type(source_paths) == 'table' and not vim.tbl_isempty(source_paths) then
            for _, item in ipairs(vim.list_slice(source_paths, 1, 120)) do
              table.insert(report, '- `' .. tostring(item) .. '`')
            end
          else
            table.insert(report, '- no source paths returned')
          end

          table.insert(report, '')
          table.insert(report, '## JDTLS Runtime Classpaths')
          local cps = type(classpaths) == 'table' and classpaths.classpaths or nil
          if type(cps) == 'table' and not vim.tbl_isempty(cps) then
            for _, item in ipairs(vim.list_slice(cps, 1, 120)) do
              table.insert(report, '- `' .. tostring(item) .. '`')
            end
          else
            table.insert(report, '- no classpaths returned')
          end

          table.insert(report, '')
          table.insert(report, '## Relevant Log Hits')
          if vim.tbl_isempty(hit_lines) then
            table.insert(report, '- no matching lines found in scanned logs')
          else
            for _, line in ipairs(vim.list_slice(hit_lines, 1, 300)) do
              table.insert(report, '- ' .. line)
            end
          end

          open_report_buffer('JdtRootCause.md', report)
        end)
      end)
    end, bufnr)
  end, bufnr)
end

local function run_maven_sync(root_dir, cached, opts)
  opts = opts or {}
  local state = maven_sync_state[root_dir] or {}
  if state.running then
    return
  end
  if state.done and not opts.force then
    return
  end

  local cmd = build_maven_sync_cmd(cached)
  if not cmd then
    vim.notify('[java] Maven sync skipped: `mvn` is not available in PATH.', vim.log.levels.WARN)
    return
  end

  state.running = true
  maven_sync_state[root_dir] = state

  vim.notify('[java] Maven sync started for JDTLS project model...', vim.log.levels.INFO)

  vim.system(cmd, { cwd = root_dir, text = true }, function(result)
    local stderr_first = ''
    if result and result.stderr and result.stderr ~= '' then
      stderr_first = vim.split(result.stderr, '\n', { trimempty = true })[1] or ''
    end

    vim.schedule(function()
      local cur = maven_sync_state[root_dir] or {}
      cur.running = false
      cur.done = true
      cur.last_exit = result and result.code or 1
      cur.last_error = stderr_first
      maven_sync_state[root_dir] = cur

      if result and result.code == 0 then
        vim.notify('[java] Maven sync finished. Refreshing JDTLS import/diagnostics...', vim.log.levels.INFO)
        refresh_jdtls_import(root_dir)
        refresh_jdtls_projects(root_dir, 0)
        attach_generated_sources(root_dir, 0)
      else
        local msg = '[java] Maven sync failed'
        if stderr_first ~= '' then
          msg = msg .. ': ' .. stderr_first
        end
        vim.notify(msg, vim.log.levels.WARN)
      end
    end)
  end)
end

local function trigger_initial_diagnostics_refresh(root_dir)
  vim.defer_fn(function()
    refresh_jdtls_import(root_dir)
    refresh_jdtls_projects(root_dir, 0)
    attach_generated_sources(root_dir, 0)
  end, 800)
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

should_apply_active_profiles = function()
  local value = vim.env.JDTLS_APPLY_MAVEN_PROFILES
  if not value or value == '' then
    return true
  end
  value = value:lower()
  return value ~= '0' and value ~= 'false' and value ~= 'no' and value ~= 'off'
end

should_disable_ge_maven_extension = function(cached)
  if env_truthy 'JDTLS_ENABLE_DEVELOCITY_MAVEN_EXTENSION' then
    return false
  end
  if env_truthy 'JDTLS_DISABLE_DEVELOCITY_MAVEN_EXTENSION' then
    return true
  end
  if env_truthy 'JDTLS_DISABLE_GE_MAVEN_EXTENSION' then
    return true
  end
  if env_truthy 'JDTLS_AUTO_DISABLE_DEVELOCITY_MAVEN_EXTENSION' then
    return cached and cached.has_ge_maven_extension or false
  end
  return cached and cached.has_ge_maven_extension or false
end

local function sanitize_jdtls_capabilities(capabilities)
  if type(capabilities) ~= 'table' then
    return capabilities
  end

  local sanitized = vim.deepcopy(capabilities)
  if sanitized.textDocument then
    -- Force classic publishDiagnostics path for jdtls.
    sanitized.textDocument.diagnostic = nil
  end
  if sanitized.workspace then
    sanitized.workspace.diagnostic = nil
  end

  return sanitized
end

local function build_jdtls_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()

  local ok_blink, blink = pcall(require, 'blink.cmp')
  if ok_blink and blink.get_lsp_capabilities then
    capabilities = blink.get_lsp_capabilities(capabilities)
  end

  return sanitize_jdtls_capabilities(capabilities)
end

local function get_jdtls_namespace(client_id)
  local ok, ns = pcall(vim.lsp.diagnostic.get_namespace, client_id)
  if ok then
    return ns
  end
  return nil
end

local function diagnostic_is_enabled(bufnr, namespace)
  local ok, enabled = pcall(vim.diagnostic.is_enabled, { bufnr = bufnr, namespace = namespace })
  if ok then
    return enabled
  end

  ok, enabled = pcall(vim.diagnostic.is_enabled, bufnr, namespace)
  if ok then
    return enabled
  end

  ok, enabled = pcall(vim.diagnostic.is_enabled, bufnr)
  if ok then
    return enabled
  end

  return nil
end

local function force_enable_jdtls_diagnostics(client_id, bufnr)
  local ns = get_jdtls_namespace(client_id)
  if not ns then
    return
  end

  pcall(vim.diagnostic.enable, { bufnr = bufnr, namespace = ns })
  pcall(vim.diagnostic.enable, bufnr, ns)
  pcall(vim.diagnostic.show, ns, bufnr)
  pcall(vim.diagnostic.show, nil, bufnr)
end

local function trigger_initial_workspace_build(root_dir, bufnr)
  if workspace_build_state[root_dir] then
    return
  end
  workspace_build_state[root_dir] = true

  vim.defer_fn(function()
    local clients = vim.lsp.get_clients { name = 'jdtls', bufnr = bufnr }
    for _, client in ipairs(clients) do
      if client and client.config and client.config.root_dir == root_dir then
        client.request('java/buildWorkspace', true, function()
          force_enable_jdtls_diagnostics(client.id, bufnr)
        end, bufnr)
      end
    end
  end, 1400)
end

local function summarize_root_diagnostics(root_dir)
  local summary = {
    total = 0,
    java = 0,
    pom = 0,
    other = 0,
    errors = 0,
    warns = 0,
  }

  local by_file = {}
  for _, d in ipairs(vim.diagnostic.get(nil)) do
    local fname = vim.api.nvim_buf_get_name(d.bufnr)
    if fname ~= '' and fname:find(root_dir, 1, true) == 1 then
      summary.total = summary.total + 1
      if fname:sub(-5) == '.java' then
        summary.java = summary.java + 1
      elseif fname:sub(-8) == 'pom.xml' then
        summary.pom = summary.pom + 1
      else
        summary.other = summary.other + 1
      end

      if d.severity == vim.diagnostic.severity.ERROR then
        summary.errors = summary.errors + 1
      elseif d.severity == vim.diagnostic.severity.WARN then
        summary.warns = summary.warns + 1
      end

      if not by_file[fname] then
        by_file[fname] = 1
      else
        by_file[fname] = by_file[fname] + 1
      end
    end
  end

  return summary, by_file
end

local function build_java_settings(base_settings, cached)
  local settings = vim.deepcopy(base_settings or {})
  settings.java = settings.java or {}

  settings.java.server = settings.java.server or {}
  settings.java.server.launchMode = settings.java.server.launchMode or 'Standard'

  settings.java.configuration = settings.java.configuration or {}
  settings.java.configuration.updateBuildConfiguration = settings.java.configuration.updateBuildConfiguration or 'automatic'
  settings.java.configuration.maven = settings.java.configuration.maven or {}
  local explicit_mojo_action = vim.env.JDTLS_M2E_DEFAULT_MOJO_ACTION
  if explicit_mojo_action and explicit_mojo_action ~= '' then
    local allowed = { ignore = true, warn = true, error = true, execute = true }
    explicit_mojo_action = allowed[explicit_mojo_action] and explicit_mojo_action or nil
  end
  settings.java.configuration.maven.defaultMojoExecutionAction = settings.java.configuration.maven.defaultMojoExecutionAction
    or explicit_mojo_action
    or 'execute'
  settings.java.configuration.maven.notCoveredPluginExecutionSeverity = settings.java.configuration.maven.notCoveredPluginExecutionSeverity
    or 'ignore'

  if cached.settings_xml then
    settings.java.configuration.maven.userSettings = cached.settings_xml
  end
  if cached.global_settings_xml then
    settings.java.configuration.maven.globalSettings = cached.global_settings_xml
  end
  if cached.lifecycle_mappings_xml then
    settings.java.configuration.maven.lifecycleMappings = cached.lifecycle_mappings_xml
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
  if cached.lifecycle_mappings_xml then
    settings.java.import.maven.lifecycleMappings = cached.lifecycle_mappings_xml
  end
  local import_args = build_maven_import_arguments(cached)
  if import_args ~= '' then
    if not settings.java.import.maven.arguments or settings.java.import.maven.arguments == '' then
      settings.java.import.maven.arguments = import_args
    elseif not settings.java.import.maven.arguments:find(import_args, 1, true) then
      settings.java.import.maven.arguments = settings.java.import.maven.arguments .. ' ' .. import_args
    end
  end
  settings.java.import.maven.offline = {
    enabled = cached.maven_offline,
  }

  settings.java.maven = settings.java.maven or {}
  settings.java.maven.downloadSources = false
  settings.java.maven.updateSnapshots = false

  settings.java.import.gradle = settings.java.import.gradle or {}
  settings.java.import.gradle.enabled = false
  settings.java.import.gradle.wrapper = settings.java.import.gradle.wrapper or {}
  settings.java.import.gradle.wrapper.enabled = false
  settings.java.import.gradle.offline = settings.java.import.gradle.offline or {}
  settings.java.import.gradle.offline.enabled = true

  settings.java.eclipse = settings.java.eclipse or {}
  settings.java.eclipse.downloadSources = false

  settings.java.autobuild = settings.java.autobuild or {}
  settings.java.autobuild.enabled = true

  settings.java.errors = settings.java.errors or {}
  settings.java.errors.incompleteClasspath = settings.java.errors.incompleteClasspath or {}
  settings.java.errors.incompleteClasspath.severity = settings.java.errors.incompleteClasspath.severity or 'error'

  return settings
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
    'nvim-java/nvim-java',
    optional = true,
    ft = java_filetypes,
    config = function()
      -- `nvim-java` bootstrap is opt-in, because auto-installers fail in restricted networks.
      if not env_truthy 'NVIM_JAVA_ENABLE_BOOTSTRAP' then
        return
      end

      local ok_java, java = pcall(require, 'java')
      if not ok_java then
        vim.notify('[java2] nvim-java requested, but not available.', vim.log.levels.WARN)
        return
      end

      local ok_setup, err = pcall(java.setup, {
        verification = {
          invalid_order = true,
          duplicate_setup_calls = false,
          invalid_mason_registry = false,
        },
        checks = {
          nvim_version = true,
          nvim_jdtls_conflict = false,
        },
        jdk = {
          auto_install = false,
          version = '17',
        },
        lombok = {
          enable = false,
        },
        java_test = {
          enable = false,
        },
        java_debug_adapter = {
          enable = false,
        },
        spring_boot_tools = {
          enable = false,
        },
      })

      if not ok_setup then
        vim.notify('[java2] nvim-java setup failed: ' .. tostring(err), vim.log.levels.WARN)
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

        local bufname = vim.api.nvim_buf_get_name(0)
        if bufname == '' then
          return
        end

        local root_dir = opts.root_dir(bufname)
        if not root_dir or root_dir == '' then
          return
        end

        local project_name = opts.project_name(root_dir)
        local cached = get_project_cache(root_dir)
        local project_key = opts.project_key(root_dir, cached)
        local cmd, config_dir, workspace_dir, cmd_source = opts.full_cmd(opts, project_key, cached)

        if not cmd then
          vim.notify(
            '[java2] jdtls not found. Set JDTLS_HOME/JDTLS_BIN or ensure mason package `jdtls` exists locally.',
            vim.log.levels.WARN
          )
          return
        end

        local capabilities = build_jdtls_capabilities()

        local config = {
          cmd = cmd,
          root_dir = root_dir,
          settings = build_java_settings(opts.settings, cached),
          capabilities = capabilities,
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
          cmd = cmd,
          cmd_source = cmd_source,
          settings_xml = cached.settings_xml,
          global_settings_xml = cached.global_settings_xml,
          lifecycle_mappings_xml = cached.lifecycle_mappings_xml,
          active_maven_profiles = cached.active_maven_profiles,
          pom_java_version = cached.pom_java_version,
          settings_java_version = cached.settings_java_version,
          java_home = cached.java_home,
          java_version_major = cached.java_version_major,
          lombok_jar = cached.lombok_jar,
          lombok_agent_enabled = not env_truthy 'JDTLS_DISABLE_LOMBOK_AGENT',
          lombok_bootclasspath_enabled = env_truthy 'JDTLS_LOMBOK_BOOTCLASSPATH',
          maven_offline = cached.maven_offline,
          local_repo = cached.local_repo,
          has_ge_maven_extension = cached.has_ge_maven_extension,
          disable_ge_maven_extension = should_disable_ge_maven_extension(cached),
          apply_maven_profiles_enabled = should_apply_active_profiles(),
          include_env_maven_profiles = env_truthy 'JDTLS_INCLUDE_ENV_MAVEN_PROFILES',
          maven_import_arguments = build_maven_import_arguments(cached),
          generated_source_dirs = list_generated_source_dirs(root_dir),
          root_mode = (vim.env.JDTLS_ROOT_MODE or 'auto'):lower(),
        }

        require('jdtls').start_or_attach(config)

        if should_apply_active_profiles() then
          vim.defer_fn(function()
            local clients = vim.lsp.get_clients { name = 'jdtls', bufnr = 0 }
            for _, client in ipairs(clients) do
              if client and client.config and client.config.root_dir == root_dir then
                apply_active_profiles(client, 0, cached.active_maven_profiles)
              end
            end
          end, 150)
        end

        trigger_initial_diagnostics_refresh(root_dir)

        vim.defer_fn(function()
          local clients = vim.lsp.get_clients { name = 'jdtls', bufnr = 0 }
          for _, client in ipairs(clients) do
            force_enable_jdtls_diagnostics(client.id, 0)
          end
        end, 300)
        trigger_initial_workspace_build(root_dir, 0)

        if should_auto_maven_sync(cached) then
          run_maven_sync(root_dir, cached, { force = false })
        end
      end

      local augroup = vim.api.nvim_create_augroup('ba-java-jdtls', { clear = true })

      if vim.fn.exists ':JdtlsStatus' == 0 then
        vim.api.nvim_create_user_command('JdtlsStatus', function()
          local state = vim.g.ba_jdtls_last
          if not state then
            vim.notify('[java] jdtls has not been initialized for this session yet.', vim.log.levels.INFO)
            return
          end
          vim.notify(vim.inspect(state), vim.log.levels.INFO)
        end, { desc = 'Show last resolved jdtls configuration' })
      end

      if vim.fn.exists ':JdtMavenSync' == 0 then
        vim.api.nvim_create_user_command('JdtMavenSync', function(command_opts)
          local bufname = vim.api.nvim_buf_get_name(0)
          if bufname == '' then
            vim.notify('[java] Cannot run Maven sync: no file in current buffer.', vim.log.levels.WARN)
            return
          end
          local root_dir = opts.root_dir(bufname)
          if not root_dir then
            vim.notify('[java] Cannot run Maven sync: no Java project root found.', vim.log.levels.WARN)
            return
          end
          local cached = get_project_cache(root_dir)
          run_maven_sync(root_dir, cached, { force = command_opts.bang })
        end, {
          bang = true,
          desc = 'Run Maven generate-sources/process-resources for current Java root (! to force rerun)',
        })
      end

      if vim.fn.exists ':JdtProjectsRefresh' == 0 then
        vim.api.nvim_create_user_command('JdtProjectsRefresh', function()
          local bufname = vim.api.nvim_buf_get_name(0)
          if bufname == '' then
            vim.notify('[java] Cannot refresh project configuration: no file in current buffer.', vim.log.levels.WARN)
            return
          end
          local root_dir = opts.root_dir(bufname)
          if not root_dir then
            vim.notify('[java] Cannot refresh project configuration: no Java project root found.', vim.log.levels.WARN)
            return
          end
          refresh_jdtls_projects(root_dir, 0)
          attach_generated_sources(root_dir, 0)
          refresh_jdtls_import(root_dir)
          vim.notify('[java] Triggered full project configuration refresh for all detected Java projects.', vim.log.levels.INFO)
        end, {
          desc = 'Force projectConfigurationsUpdate/buildProjects for all JDTLS projects in current root',
        })
      end

      if vim.fn.exists ':JdtAttachGeneratedSources' == 0 then
        vim.api.nvim_create_user_command('JdtAttachGeneratedSources', function()
          local bufname = vim.api.nvim_buf_get_name(0)
          if bufname == '' then
            vim.notify('[java] Cannot attach generated sources: no file in current buffer.', vim.log.levels.WARN)
            return
          end
          local root_dir = opts.root_dir(bufname)
          if not root_dir then
            vim.notify('[java] Cannot attach generated sources: no Java project root found.', vim.log.levels.WARN)
            return
          end
          local dirs = list_generated_source_dirs(root_dir)
          if vim.tbl_isempty(dirs) then
            vim.notify('[java] No generated source directories found under target/generated-sources.', vim.log.levels.INFO)
            return
          end
          attach_generated_sources(root_dir, 0)
          refresh_jdtls_projects(root_dir, 0)
          refresh_jdtls_import(root_dir)
          vim.notify('[java] Requested JDTLS to add generated source directories to source path.', vim.log.levels.INFO)
        end, {
          desc = 'Add target/generated-sources directories to JDTLS source path and refresh import',
        })
      end

      if vim.fn.exists ':JdtSourcePaths' == 0 then
        vim.api.nvim_create_user_command('JdtSourcePaths', function()
          local bufnr = vim.api.nvim_get_current_buf()
          local clients = vim.lsp.get_clients { name = 'jdtls', bufnr = bufnr }
          if vim.tbl_isempty(clients) then
            vim.notify('[java2] No jdtls client attached to current buffer.', vim.log.levels.WARN)
            return
          end

          local client = clients[1]
          local root_dir = client.config and client.config.root_dir or ''
          local uri = vim.uri_from_bufnr(bufnr)
          local generated_dirs = list_generated_source_dirs(root_dir)

          request_list_source_paths(client, bufnr, uri, function(err, source_paths)
            vim.schedule(function()
              local state = {
                root_dir = root_dir,
                generated_dirs = generated_dirs,
                source_paths = source_paths,
                error = err and (err.message or vim.inspect(err)) or nil,
              }
              vim.notify(vim.inspect(state), vim.log.levels.INFO)
            end)
          end)
        end, {
          desc = 'Show JDTLS source paths and detected generated source directories',
        })
      end

      if vim.fn.exists ':JdtRootCause' == 0 then
        vim.api.nvim_create_user_command('JdtRootCause', function(command_opts)
          local query = command_opts.args ~= '' and vim.trim(command_opts.args) or 'fr.bdf'
          run_root_cause_probe(query)
        end, {
          nargs = '?',
          desc = 'Collect concrete JDTLS/m2e/classpath evidence for unresolved imports (default query: fr.bdf)',
        })
      end

      if vim.fn.exists ':JdtDiagStatus' == 0 then
        vim.api.nvim_create_user_command('JdtDiagStatus', function()
          local bufnr = vim.api.nvim_get_current_buf()
          local clients = vim.lsp.get_clients { name = 'jdtls', bufnr = bufnr }
          if vim.tbl_isempty(clients) then
            vim.notify('[java2] No jdtls client attached to current buffer.', vim.log.levels.WARN)
            return
          end

          local client = clients[1]
          local ns = get_jdtls_namespace(client.id)
          local diags = vim.diagnostic.get(bufnr, ns and { namespace = ns } or {})
          local errors = 0
          for _, d in ipairs(diags) do
            if d.severity == vim.diagnostic.severity.ERROR then
              errors = errors + 1
            end
          end

          local state = {
            bufnr = bufnr,
            client_id = client.id,
            namespace = ns,
            diagnostics_count = #diags,
            error_count = errors,
            diagnostic_enabled = diagnostic_is_enabled(bufnr, ns),
          }
          vim.notify(vim.inspect(state), vim.log.levels.INFO)
        end, { desc = 'Show jdtls diagnostics state for current buffer' })
      end

      if vim.fn.exists ':JdtDiagSummary' == 0 then
        vim.api.nvim_create_user_command('JdtDiagSummary', function()
          local bufnr = vim.api.nvim_get_current_buf()
          local clients = vim.lsp.get_clients { name = 'jdtls', bufnr = bufnr }
          if vim.tbl_isempty(clients) then
            vim.notify('[java2] No jdtls client attached to current buffer.', vim.log.levels.WARN)
            return
          end

          local client = clients[1]
          local root_dir = client.config and client.config.root_dir or ''
          local summary, _ = summarize_root_diagnostics(root_dir)
          local msg = string.format(
            '[java2] root diagnostics total=%d java=%d pom=%d other=%d errors=%d warns=%d',
            summary.total,
            summary.java,
            summary.pom,
            summary.other,
            summary.errors,
            summary.warns
          )
          vim.notify(msg, vim.log.levels.INFO)
        end, { desc = 'Show jdtls diagnostics summary for current root' })
      end

      if vim.fn.exists ':JdtDiagProbe' == 0 then
        vim.api.nvim_create_user_command('JdtDiagProbe', function()
          local bufnr = vim.api.nvim_get_current_buf()
          local clients = vim.lsp.get_clients { name = 'jdtls', bufnr = bufnr }
          if vim.tbl_isempty(clients) then
            vim.notify('[java2] No jdtls client attached to current buffer.', vim.log.levels.WARN)
            return
          end

          local client = clients[1]
          local root_dir = client.config and client.config.root_dir or ''
          refresh_jdtls_projects(root_dir, bufnr)
          attach_generated_sources(root_dir, bufnr)
          client.request('workspace/executeCommand', {
            command = 'java.project.import',
            arguments = {},
          }, function() end, bufnr)
          client.request('workspace/executeCommand', {
            command = 'java.project.refreshDiagnostics',
            arguments = {},
          }, function() end, bufnr)
          client.request('java/buildWorkspace', true, function(err, result)
            vim.schedule(function()
              local summary, _ = summarize_root_diagnostics(root_dir)
              local state = {
                build_error = err and (err.message or vim.inspect(err)) or nil,
                build_result = result,
                diagnostics_total = summary.total,
                diagnostics_java = summary.java,
                diagnostics_pom = summary.pom,
                diagnostics_other = summary.other,
                diagnostics_errors = summary.errors,
              }
              vim.notify(vim.inspect(state), vim.log.levels.INFO)
            end)
          end, bufnr)
        end, { desc = 'Run import+build and print compact diagnostics summary' })
      end

      vim.api.nvim_create_autocmd('FileType', {
        group = augroup,
        pattern = java_filetypes,
        callback = attach_jdtls,
      })

      -- Same pattern as LazyVim: handle the first Java buffer immediately.
      attach_jdtls()
    end,
  },
}
