local root_markers = {
  '.git',
  'mvnw',
  'gradlew',
  'pom.xml',
  'build.gradle',
  'build.gradle.kts',
  'settings.gradle',
  'settings.gradle.kts',
}
local project_cache = {}

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

  local root = vim.fs.root(path, root_markers)
  if root then
    return root
  end

  return vim.fs.dirname(path)
end

local function detect_settings_xml(root)
  local candidates = {
    root .. '/settings.xml',
    root .. '/.mvn/settings.xml',
  }

  for _, file in ipairs(candidates) do
    if vim.fn.filereadable(file) == 1 then
      return file
    end
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
  local java_home_env = vim.env.JAVA_HOME
  if java_home_env and java_home_env ~= '' and vim.fn.isdirectory(java_home_env) == 1 then
    return java_home_env
  end

  if vim.fn.executable '/usr/libexec/java_home' == 1 then
    local out = vim.fn.systemlist { '/usr/libexec/java_home', '-v', tostring(version_major) }
    if vim.v.shell_error == 0 and out and out[1] and out[1] ~= '' and vim.fn.isdirectory(out[1]) == 1 then
      return out[1]
    end
  end

  return nil
end

local function run_mvn_for_local_repo(root, settings_xml)
  if vim.fn.executable 'mvn' ~= 1 then
    return nil
  end

  local cmd = { 'mvn', '-q', '-DforceStdout', 'help:evaluate', '-Dexpression=settings.localRepository' }
  if settings_xml then
    table.insert(cmd, '-s')
    table.insert(cmd, settings_xml)
  end

  if vim.system then
    local result = vim.system(cmd, { cwd = root, text = true }):wait()
    if result.code == 0 and result.stdout then
      for line in result.stdout:gmatch '[^\r\n]+' do
        local value = vim.trim(line)
        if value ~= '' and not value:match '^%[' and vim.fn.isdirectory(value) == 1 then
          return value
        end
      end
    end
    return nil
  end

  local escaped_root = vim.fn.shellescape(root)
  local escaped_cmd = {}
  for _, part in ipairs(cmd) do
    table.insert(escaped_cmd, vim.fn.shellescape(part))
  end
  local shell_cmd = table.concat(escaped_cmd, ' ')
  local out = vim.fn.systemlist('cd ' .. escaped_root .. ' && ' .. shell_cmd)
  if vim.v.shell_error == 0 and out then
    for _, line in ipairs(out) do
      local value = vim.trim(line)
      if value ~= '' and not value:match '^%[' and vim.fn.isdirectory(value) == 1 then
        return value
      end
    end
  end

  return nil
end

local function detect_maven_local_repo(root, settings_xml)
  local repo = run_mvn_for_local_repo(root, settings_xml)
  if repo then
    return repo
  end

  local fallback = vim.fn.expand '~/.m2/repository'
  if vim.fn.isdirectory(fallback) == 1 then
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

local function detect_jdtls_cmd(workspace_dir, lombok_jar, java_home)
  if vim.fn.executable 'jdtls' == 1 then
    local cmd = { 'jdtls', '-data', workspace_dir }
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
      java_version_major = java_version_major,
      java_home = java_home,
      local_repo = local_repo,
      lombok_jar = lombok_jar,
    }
    project_cache[root_dir] = cached
  end

  local project_name = vim.fs.basename(root_dir)
  local workspace_dir = vim.fn.stdpath 'data' .. '/jdtls-workspace/' .. project_name
  vim.fn.mkdir(workspace_dir, 'p')

  local cmd = detect_jdtls_cmd(workspace_dir, cached.lombok_jar, cached.java_home)
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
        configuration = {
          runtimes = {},
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
