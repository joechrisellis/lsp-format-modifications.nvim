
local M = {}
local util = require"lsp-format-modifications.util"
local Job = require"plenary.job"
local Path = require"plenary.path"

local function cmd(spec)
  local exitcode = 0
  local stdout = {}
  local stderr = {}

  Job:new{
    command = spec.command,
    args = spec.args,
    cwd = spec.cwd,

    on_exit = function(_, return_val)
      exitcode = return_val
    end,

    on_stdout = function(_, data)
      table.insert(stdout, data)
    end,

    on_stderr = function(_, data)
      table.insert(stderr, data)
    end,
  }:sync()

  return {
    exitcode = exitcode,
    stdout = stdout,
    stderr = stderr,
  }
end

local GitClient = {}

function GitClient:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function GitClient:init(pathstr)
  local absolute_pathstr = vim.fn.fnamemodify(pathstr, ":p")
  local git_cwd = vim.fn.fnamemodify(pathstr, ":h")

  local result = cmd{
    command = "git",
    cwd = git_cwd,
    args = { "rev-parse", "--show-toplevel" }
  }

  if result.exitcode ~= 0 then
    return "not inside git repository"
  end

  self.repository_root = table.concat(result.stdout, "\n")

  return nil
end

function GitClient:relativize(pathstr)
  local absolute_pathstr = vim.fn.fnamemodify(pathstr, ":p")
  return absolute_pathstr:sub(#self.repository_root + #Path.path.sep + 1)
end

function GitClient:file_info(pathstr)
  local result = cmd{
    command = "git",
    cwd = self.repository_root,
    args = {
      "-c", "core.quotepath=off",
      "ls-files",
      "--stage",
      "--others",
      "--exclude-standard",
      "--eol",
      self:relativize(pathstr)
    }
  }

  if result.exitcode ~= 0 then
    return nil, "failed to get file information for " .. pathstr -- TODO: more robust?
  end

  local file_info = {}
  for _, line in ipairs(result.stdout) do
    local parts = vim.split(line, '\t')

    file_info.is_tracked = #parts > 2

    if file_info.is_tracked then
      local eol = vim.split(parts[2], '%s+')
      file_info.i_crlf = eol[1] == 'i/crlf'
      file_info.w_crlf = eol[2] == 'w/crlf'
      file_info.relpath = parts[3]
      local attrs = vim.split(parts[1], '%s+')
      local stage = tonumber(attrs[3])
      if stage <= 1 then
          file_info.mode_bits   = attrs[1]
          file_info.object_name = attrs[2]
      else
          file_info.has_conflicts = true
      end
    else -- untracked file
      file_info.relpath = parts[2]
    end
  end

  return file_info
end

function GitClient:get_comparee_lines(pathstr)
  local result = cmd{
    command = "git",
    cwd = self.repository_root,
    args = { "--no-pager", "--literal-pathspecs", "show", ":0:./" .. self:relativize(pathstr) }
  }

  if result.exitcode ~= 0 then
    return nil, "exit code from git show is non-zero"
  end

  local comparee_lines = result.stdout
  return comparee_lines
end

M.git = GitClient

local HgClient = {}

function HgClient:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function HgClient:init(pathstr)
  local absolute_pathstr = vim.fn.fnamemodify(pathstr, ':p')
  local hg_cwd = vim.fn.fnamemodify(pathstr, ':h')

  local result = cmd {
    command = 'hg',
    cwd = hg_cwd,
    args = { 'root' }
  }

  if result.exitcode ~= 0 then
    return "not inside a hg repository"
  end

  self.repository_root = table.concat(result.stdout, "\n")

  return nil
end

function HgClient:relativize(pathstr)
  local absolute_pathstr = vim.fn.fnamemodify(pathstr, ':p')
  return absolute_pathstr:sub(#self.repository_root + #Path.path.sep + 1)
end

function HgClient:file_info(pathstr)
  local result = cmd {
    command = 'hg',
    cwd = self.repository_root,
    args = {
      'files',
      '--',
      self:relativize(pathstr)
    }
  }

  if result.exitcode ~= 0 then
    return { is_tracked = false }
  end

  local file_info = {}
  file_info.is_tracked = #result.stdout > 0
  local line = result.stdout[1]
  file_info.i_crlf = true -- TODO
  file_info.w_crlf = true -- TODO
  file_info.relpath = vim.trim(line)
  file_info.mode_bits = '100644' -- TODO
  file_info.object_name = vim.trim(line)

  return file_info
end

function HgClient:get_comparee_lines(pathstr)
  local result = cmd {
    command = 'hg',
    cwd = self.repository_root,
    args = {
      'cat',
      '--',
      self:relativize(pathstr),
    }
  }

  if result.exitcode ~= 0 then
    return nil, "exit code from hg cat is non-zero"
  end

  local comparee_lines = result.stdout
  return comparee_lines
end

M.hg = HgClient

return M
