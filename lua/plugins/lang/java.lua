local root_markers = {
  '.git',
  '.mvn',
  'mvnw',
  'gradlew',
  'pom.xml',
  'build.gradle',
  'build.gradle.kts',
  'settings.gradle',
  'settings.gradle.kts',
}
local project_cache = {}

local function env_truthy(name)
  local value = vim.env[name]
  if not value then
    return false
  end
  value = value:lower()
  return value == '1' or value == 'true' or value == 'yes' or value == 'on'
end

local function ascends_until(dir, stop_at, fn)
  local current = dir
  while current and current ~= '' do
    fn(current)
    if stop_at and current == stop_at then
      break
    end
    local parent = vim.fs.dirname(current)
    if not parent or parent == current then
      break
    end
    current = parent
  end
end

local function read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then
    return nil
  end
  return table.concat(lines, '\n')
end

local function detect_project_root(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == '' then
    return vim.loop.cwd()
  end

  local file_dir = vim.fs.dirname(path)
  local git_root = vim.fs.root(path, { '.git' })
  local top_pom = nil
  local maven_root = nil

  ascends_until(file_dir, git_root, function(dir)
    if vim.fn.filereadable(dir .. '/pom.xml') == 1 then
      top_pom = dir
    end
    if not maven_root and vim.fn.isdirectory(dir .. '/.mvn') == 1 then
      maven_root = dir
    end
  end)

  if maven_root then
    return maven_root
  end
  if top_pom then
    return top_pom
  end

  local generic_root = vim.fs.root(path, root_markers)
  if generic_root then
    return generic_root
  end

  return file_dir
end

local function detect_settings_xml(root)
  local candidates = {
    root .. '/settings.xml',
    root .. '/.mvn/settings.xml',
    vim.fn.expand '~/.m2/settings.xml',
  }

  for _, file in ipairs(candidates) do
    if vim.fn.filereadable(file) == 1 then
      return file
    end
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

local function detect_maven_local_repo(_, settings_xml)
  local repo = vim.env.MAVEN_REPO_LOCAL
  if repo and repo ~= '' and vim.fn.isdirectory(repo) == 1 then
    return repo
  end

  repo = infer_local_repo_from_settings(settings_xml)
  if repo then
    return repo
  end

  local global_settings = vim.fn.expand '~/.m2/settings.xml'
  if (not settings_xml or settings_xml ~= global_settings) and vim.fn.filereadable(global_settings) == 1 then
    repo = infer_local_repo_from_settings(global_settings)
  end

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
  if m2_home and m2_home ~= '' then
    local candidate = m2_home .. '/conf/settings.xml'
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end
  return nil
end

local function has_gradle_enterprise_maven_extension(root)
  local extensions_xml = root .. '/.mvn/extensions.xml'
  if vim.fn.filereadable(extensions_xml) ~= 1 then
    return false
  end

  local content = read_file(extensions_xml)
  if not content then
    return false
  end

  local lowered = content:lower()
  return lowered:find('gradle%-enterprise%-maven%-extension', 1, false) ~= nil
    or lowered:find('develocity%-maven%-extension', 1, false) ~= nil
    or lowered:find('com%.gradle', 1, false) ~= nil
end

local function detect_lifecycle_mappings_file()
  local explicit = vim.env.JDTLS_M2E_LIFECYCLE_MAPPINGS
  if explicit and explicit ~= '' and vim.fn.filereadable(explicit) == 1 then
    return explicit
  end

  local fallback = vim.fn.stdpath 'config' .. '/m2e-lifecycle-mapping.xml'
  if vim.fn.filereadable(fallback) == 1 then
    return fallback
  end

  return nil
end

local function detect_lombok_jar(local_repo)
  if not local_repo then
    return nil
  end

  local pattern = local_repo .. '/org/projectlombok/lombok/*/lombok-*.jar'
  local jars = vim.fn.glob(pattern, true, true)
  if type(jars) ~= 'table' or vim.tbl_isempty(jars) then
    return nil
  end

  table.sort(jars)
  return jars[#jars]
end

local function detect_jdtls_cmd(workspace_dir, lombok_jar, java_home, extra_jvm_props)
  extra_jvm_props = extra_jvm_props or {}

  if vim.fn.executable 'jdtls' == 1 then
    local cmd = { 'jdtls', '-data', workspace_dir }
    for _, prop in ipairs(extra_jvm_props) do
      table.insert(cmd, '--jvm-arg=' .. prop)
    end
    if lombok_jar then
      table.insert(cmd, '--jvm-arg=-javaagent:' .. lombok_jar)
      table.insert(cmd, '--jvm-arg=-Xbootclasspath/a:' .. lombok_jar)
    end
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

  local config_dir = jdtls_home .. '/' .. os_config
  if vim.fn.isdirectory(config_dir) ~= 1 then
    return nil
  end

  local java_bin = 'java'
  if java_home then
    local candidate = java_home .. '/bin/java'
    if vim.fn.executable(candidate) == 1 then
      java_bin = candidate
    end
  end

  local cmd = {
    java_bin,
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=WARN',
    '-Xms1g',
  }

  for _, prop in ipairs(extra_jvm_props) do
    table.insert(cmd, prop)
  end

  if lombok_jar then
    table.insert(cmd, '-javaagent:' .. lombok_jar)
    table.insert(cmd, '-Xbootclasspath/a:' .. lombok_jar)
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
    config_dir,
    '-data',
    workspace_dir,
  })

  return cmd
end

local function setup_jdtls(bufnr)
  local ok_jdtls, jdtls = pcall(require, 'jdtls')
  if not ok_jdtls then
    return
  end

  local root_dir = detect_project_root(bufnr)
  if not root_dir or root_dir == '' then
    return
  end

  local cached = project_cache[root_dir]
  if not cached then
    local settings_xml = detect_settings_xml(root_dir)
    local requested_java_version = infer_java_version_from_settings(settings_xml)
    local java_version_major = normalize_java_version(requested_java_version)
    local java_home = detect_java_home(java_version_major)
    local local_repo = detect_maven_local_repo(root_dir, settings_xml)
    local lombok_jar = detect_lombok_jar(local_repo)

    cached = {
      settings_xml = settings_xml,
      global_settings_xml = detect_maven_global_settings(),
      lifecycle_mappings_xml = detect_lifecycle_mappings_file(),
      java_version_major = java_version_major,
      java_home = java_home,
      local_repo = local_repo,
      lombok_jar = lombok_jar,
      maven_offline = env_truthy 'JDTLS_MAVEN_OFFLINE' or env_truthy 'MAVEN_OFFLINE',
      has_ge_maven_extension = has_gradle_enterprise_maven_extension(root_dir),
    }
    project_cache[root_dir] = cached
  end

  local project_name = vim.fs.basename(root_dir)
  local workspace_id = vim.fn.sha256(vim.fs.normalize(root_dir)):sub(1, 12)
  local workspace_dir = vim.fn.stdpath 'data' .. '/jdtls-workspace/' .. project_name .. '-' .. workspace_id
  vim.fn.mkdir(workspace_dir, 'p')

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

  local cmd = detect_jdtls_cmd(workspace_dir, cached.lombok_jar, cached.java_home, extra_jvm_props)
  if not cmd then
    vim.notify('[java] jdtls not found. Install jdtls in PATH or set JDTLS_HOME.', vim.log.levels.WARN)
    return
  end

  local capabilities = {}
  local ok_blink, blink = pcall(require, 'blink.cmp')
  if ok_blink and blink.get_lsp_capabilities then
    capabilities = blink.get_lsp_capabilities()
  end

  local config = {
    cmd = cmd,
    root_dir = root_dir,
    capabilities = capabilities,
    settings = {
      java = {
        server = {
          launchMode = 'Standard',
        },
        configuration = {
          runtimes = {},
          updateBuildConfiguration = 'interactive',
          maven = {
            defaultMojoExecutionAction = 'ignore',
            notCoveredPluginExecutionSeverity = 'ignore',
          },
        },
        errors = {
          incompleteClasspath = {
            severity = 'error',
          },
        },
        eclipse = {
          downloadSources = false,
        },
        maven = {
          downloadSources = false,
          updateSnapshots = false,
        },
        import = {
          maven = {
            enabled = true,
            disableTestClasspathFlag = false,
            offline = {
              enabled = cached.maven_offline,
            },
          },
        },
      },
    },
    init_options = {
      jvm_args = cached.lombok_jar and {
        '-javaagent:' .. cached.lombok_jar,
        '-Xbootclasspath/a:' .. cached.lombok_jar,
      } or {},
    },
  }

  if cached.java_home then
    config.settings.java.configuration.runtimes = {
      {
        name = 'JavaSE-' .. tostring(cached.java_version_major),
        path = cached.java_home,
        default = true,
      },
    }
  end

  if cached.settings_xml then
    config.settings.java.configuration.maven.userSettings = cached.settings_xml
  end

  if cached.global_settings_xml then
    config.settings.java.configuration.maven.globalSettings = cached.global_settings_xml
  end

  if cached.lifecycle_mappings_xml then
    config.settings.java.configuration.maven.lifecycleMappings = cached.lifecycle_mappings_xml
  end

  vim.g.ba_jdtls_last = {
    root_dir = root_dir,
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

  jdtls.start_or_attach(config)
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
    ft = 'java',
    dependencies = {
      'neovim/nvim-lspconfig',
      'saghen/blink.cmp',
    },
    config = function()
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
        pattern = 'java',
        callback = function(args)
          setup_jdtls(args.buf)
        end,
      })
    end,
  },
}
