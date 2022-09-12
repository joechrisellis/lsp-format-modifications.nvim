
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

function GitClient:is_file_tracked(pathstr)
  local result = cmd{
    command = "git",
    cwd = self.repository_root,
    args = { "--literal-pathspecs", "ls-files", "--error-unmatch", self:relativize(pathstr) }
  }

  return result.exitcode == 0
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

return M
