local java_filetypes = { 'java' }
local project_cache = {}

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

  return vim.fs.root(path, {
    '.git',
    'mvnw',
    'gradlew',
    'pom.xml',
    'build.gradle',
    'build.gradle.kts',
  })
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

  local patterns = {
    '<maven%.compiler%.release>%s*([%d%.]+)%s*</maven%.compiler%.release>',
    '<maven%.compiler%.source>%s*([%d%.]+)%s*</maven%.compiler%.source>',
    '<java%.version>%s*([%d%.]+)%s*</java%.version>',
    '<jdk%.version>%s*([%d%.]+)%s*</jdk%.version>',
    '<release>%s*([%d%.]+)%s*</release>',
    '<source>%s*([%d%.]+)%s*</source>',
  }

  for _, pattern in ipairs(patterns) do
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

local function get_project_cache(root_dir)
  if project_cache[root_dir] then
    return project_cache[root_dir]
  end

  local settings_xml = detect_settings_xml(root_dir)
  local java_version_major = normalize_java_version(infer_java_version_from_settings(settings_xml))
  local cached = {
    settings_xml = settings_xml,
    global_settings_xml = detect_maven_global_settings(),
    java_version_major = java_version_major,
    java_home = detect_java_home(java_version_major),
    local_repo = detect_maven_local_repo(settings_xml),
  }

  cached.lombok_jar = detect_lombok_jar(cached.local_repo)
  project_cache[root_dir] = cached
  return cached
end

local function append_once(list, value)
  if not list or not value then
    return
  end

  for _, v in ipairs(list) do
    if v == value then
      return
    end
  end

  table.insert(list, value)
end

local function maybe_inject_lombok_cmd_args(cmd, lombok_jar)
  if type(cmd) ~= 'table' or not lombok_jar or lombok_jar == '' then
    return
  end

  local first = cmd[1] or ''
  if first:match 'jdtls$' then
    append_once(cmd, '--jvm-arg=-javaagent:' .. lombok_jar)
    append_once(cmd, '--jvm-arg=-Xbootclasspath/a:' .. lombok_jar)
  else
    append_once(cmd, '-javaagent:' .. lombok_jar)
    append_once(cmd, '-Xbootclasspath/a:' .. lombok_jar)
  end
end

local function with_existing_values(base, existing)
  if type(existing) ~= 'table' then
    return base
  end
  return vim.tbl_deep_extend('force', base, existing)
end

local function build_jdtls_settings(existing, cached)
  local settings = with_existing_values({
    java = {
      configuration = {
        updateBuildConfiguration = 'interactive',
        maven = {
          defaultMojoExecutionAction = 'ignore',
          notCoveredPluginExecutionSeverity = 'ignore',
        },
      },
      import = {
        maven = {
          enabled = true,
          disableTestClasspathFlag = false,
        },
        gradle = {
          enabled = false,
        },
      },
      maven = {
        downloadSources = false,
        updateSnapshots = false,
      },
      eclipse = {
        downloadSources = false,
      },
      errors = {
        incompleteClasspath = {
          severity = 'warning',
        },
      },
    },
  }, existing)

  settings.java = settings.java or {}
  settings.java.configuration = settings.java.configuration or {}
  settings.java.configuration.maven = settings.java.configuration.maven or {}

  if cached.settings_xml then
    settings.java.configuration.maven.userSettings = cached.settings_xml
  end
  if cached.global_settings_xml then
    settings.java.configuration.maven.globalSettings = cached.global_settings_xml
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
    ft = java_filetypes,
    dependencies = {
      'nvim-java/lua-async-await',
      'nvim-java/nvim-java-core',
      'neovim/nvim-lspconfig',
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'mfussenegger/nvim-dap',
      'saghen/blink.cmp',
    },
    config = function()
      local ok_java, java = pcall(require, 'java')
      if not ok_java then
        vim.notify('[java2] nvim-java is not available', vim.log.levels.WARN)
        return
      end

      java.setup {
        verification = {
          invalid_order = true,
          duplicate_setup_calls = false,
          invalid_mason_registry = false,
        },
        checks = {
          nvim_version = true,
          nvim_jdtls_conflict = true,
        },
        jdk = {
          auto_install = false,
          version = '17',
        },
        lombok = {
          -- Use project maven lombok jar when available.
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
      }

      local capabilities = nil
      local ok_blink, blink = pcall(require, 'blink.cmp')
      if ok_blink and blink.get_lsp_capabilities then
        capabilities = blink.get_lsp_capabilities()
      end

      vim.lsp.config('jdtls', {
        capabilities = capabilities,
        root_dir = function(path)
          return detect_root_dir(path)
        end,
        on_new_config = function(new_config, root_dir)
          local cached = get_project_cache(root_dir)
          new_config.settings = build_jdtls_settings(new_config.settings, cached)
          maybe_inject_lombok_cmd_args(new_config.cmd, cached.lombok_jar)

          vim.g.ba_java2_last = {
            root_dir = root_dir,
            cmd = new_config.cmd,
            settings_xml = cached.settings_xml,
            global_settings_xml = cached.global_settings_xml,
            java_home = cached.java_home,
            java_version_major = cached.java_version_major,
            lombok_jar = cached.lombok_jar,
          }
        end,
      })

      if vim.fn.exists ':Java2Status' == 0 then
        vim.api.nvim_create_user_command('Java2Status', function()
          local state = vim.g.ba_java2_last
          if not state then
            vim.notify('[java2] jdtls has not been initialized yet.', vim.log.levels.INFO)
            return
          end
          vim.notify(vim.inspect(state), vim.log.levels.INFO)
        end, { desc = 'Show resolved nvim-java/jdtls project settings' })
      end

      vim.lsp.enable 'jdtls'
    end,
  },
}
