local java_filetypes = { 'java' }
local project_cache = {}

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

local function detect_root_dir(path)
  local file_dir = vim.fs.dirname(path)
  local maven_root = nil

  each_parent_dir(file_dir, function(dir)
    if vim.fn.isdirectory(dir .. '/.mvn') == 1 or vim.fn.filereadable(dir .. '/mvnw') == 1 then
      maven_root = dir
      return true
    end
    return false
  end)

  if maven_root then
    return maven_root
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
  if vim.fn.executable '/usr/libexec/java_home' == 1 then
    local out = vim.fn.systemlist { '/usr/libexec/java_home', '-v', tostring(version_major) }
    if vim.v.shell_error == 0 and out and out[1] and out[1] ~= '' and vim.fn.isdirectory(out[1]) == 1 then
      return out[1]
    end
  end

  local java_home_env = vim.env.JAVA_HOME
  if java_home_env and java_home_env ~= '' and vim.fn.isdirectory(java_home_env) == 1 then
    return java_home_env
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

local function derive_project_key(root_dir)
  local normalized = vim.fs.normalize(root_dir)
  local base = vim.fs.basename(normalized)
  local hash = vim.fn.sha256(normalized):sub(1, 10)
  return base .. '-' .. hash
end

local function get_project_cache(root_dir)
  if project_cache[root_dir] then
    return project_cache[root_dir]
  end

  local settings_xml = detect_settings_xml(root_dir)
  local java_version_major = normalize_java_version(infer_java_version_from_settings(settings_xml))

  local cached = {
    settings_xml = settings_xml,
    global_settings_xml = detect_maven_global_settings(),
    lifecycle_mappings_xml = detect_lifecycle_mappings_file(root_dir),
    java_version_major = java_version_major,
    java_home = detect_java_home(java_version_major),
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
  local jdtls_xmx = vim.env.JDTLS_XMX or '2g'
  local extra_jvm_props = {}
  if cached.has_ge_maven_extension or env_truthy 'JDTLS_DISABLE_DEVELOCITY_MAVEN_EXTENSION' then
    vim.list_extend(extra_jvm_props, {
      '-Ddevelocity.enabled=false',
      '-Dgradle.enterprise.enabled=false',
      '-Ddevelocity.scan.disabled=true',
      '-Dscan=false',
      '-Dgradle.enterprise.maven.extension.enabled=false',
      '-Ddevelocity.maven.extension.enabled=false',
    })
  end

  local jdtls_bin = vim.fn.exepath 'jdtls'
  if jdtls_bin ~= '' then
    local cmd = { jdtls_bin }

    table.insert(cmd, '--jvm-arg=-Xms' .. jdtls_xms)
    table.insert(cmd, '--jvm-arg=-Xmx' .. jdtls_xmx)

    for _, prop in ipairs(extra_jvm_props) do
      table.insert(cmd, '--jvm-arg=' .. prop)
    end

    if cached.lombok_jar then
      table.insert(cmd, '--jvm-arg=-javaagent:' .. cached.lombok_jar)
      table.insert(cmd, '--jvm-arg=-Xbootclasspath/a:' .. cached.lombok_jar)
    end

    vim.list_extend(cmd, {
      '-configuration',
      config_dir,
      '-data',
      workspace_dir,
    })

    return cmd
  end

  local jdtls_home = vim.env.JDTLS_HOME
  if not jdtls_home or jdtls_home == '' or vim.fn.isdirectory(jdtls_home) ~= 1 then
    return nil
  end

  local launcher = vim.fn.glob(jdtls_home .. '/plugins/org.eclipse.equinox.launcher_*.jar', true, true)[1]
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

  local java_bin = vim.fn.exepath 'java'
  if java_bin == '' then
    local candidate = cached.java_home and (cached.java_home .. '/bin/java') or nil
    if candidate and vim.fn.executable(candidate) == 1 then
      java_bin = candidate
    else
      java_bin = 'java'
    end
  end

  local cmd = {
    java_bin,
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=WARN',
    '-Xms' .. jdtls_xms,
    '-Xmx' .. jdtls_xmx,
  }

  vim.list_extend(cmd, extra_jvm_props)

  if cached.lombok_jar then
    table.insert(cmd, '-javaagent:' .. cached.lombok_jar)
    table.insert(cmd, '-Xbootclasspath/a:' .. cached.lombok_jar)
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

  return cmd
end

local function build_java_settings(base_settings, cached)
  local settings = vim.deepcopy(base_settings or {})
  settings.java = settings.java or {}

  settings.java.server = settings.java.server or {}
  settings.java.server.launchMode = settings.java.server.launchMode or 'Standard'

  settings.java.configuration = settings.java.configuration or {}
  settings.java.configuration.updateBuildConfiguration = settings.java.configuration.updateBuildConfiguration or 'automatic'
  settings.java.configuration.maven = settings.java.configuration.maven or {}
  settings.java.configuration.maven.defaultMojoExecutionAction = settings.java.configuration.maven.defaultMojoExecutionAction or 'execute'
  settings.java.configuration.maven.notCoveredPluginExecutionSeverity = settings.java.configuration.maven.notCoveredPluginExecutionSeverity
    or 'warning'

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
          local cmd = resolve_jdtls_cmd(config_dir, workspace_dir, cached)
          return cmd, config_dir, workspace_dir
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
        local project_key = opts.project_key(root_dir)
        local cached = get_project_cache(root_dir)
        local cmd, config_dir, workspace_dir = opts.full_cmd(opts, project_key, cached)

        if not cmd then
          vim.notify('[java] jdtls not found. Install jdtls in PATH or set JDTLS_HOME.', vim.log.levels.WARN)
          return
        end

        local capabilities = nil
        local ok_blink, blink = pcall(require, 'blink.cmp')
        if ok_blink and blink.get_lsp_capabilities then
          capabilities = blink.get_lsp_capabilities()
        end

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
          settings_xml = cached.settings_xml,
          global_settings_xml = cached.global_settings_xml,
          lifecycle_mappings_xml = cached.lifecycle_mappings_xml,
          java_home = cached.java_home,
          java_version_major = cached.java_version_major,
          lombok_jar = cached.lombok_jar,
          maven_offline = cached.maven_offline,
          has_ge_maven_extension = cached.has_ge_maven_extension,
        }

        require('jdtls').start_or_attach(config)
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
