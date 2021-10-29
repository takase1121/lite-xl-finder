local process = require "process"

local core = require "core"
local common = require "core.common"
local config = require "core.config"

local function replace_placeholders(tbl, cwd)
  local result = {}
  for i, v in ipairs(tbl) do
    result[i] = string.gsub(v, "%%%S+", {
      ["%CWD"] = cwd
    })
  end
  return result
end

-- http://lua-users.org/wiki/SplitJoin (the python one)
local function split(str, sep)
  local result = {}
  if #str > 0 then
    local start, i = 1, 1
    local first, last = str:find(sep, start)
    while first do
      result[#result + 1] = str:sub(start, first - 1)
      start = last + 1
      i = i + 1
      first, last = str:find(sep, start)
    end
    result[#result + 1] = str:sub(start)
  end
  return result
end

local function files_cmd()
  return coroutine.wrap(function()
    for _, dir in ipairs(core.project_directories) do
      local proc = process.start(
        replace_placeholders(config.plugins.finder.files.command, dir.name),
        {
          stdin = process.REDIRECT_DISCARD,
          stderr = process.REDIRECT_DISCARD,
          stdout = process.REDIRECT_PIPE,
        }
      )

      local prev = ""
      local continue = true
      while continue do
        local buf = proc:read_stdout()
        if not buf then break end

        local lines = split(buf, "\r?\n")
        for i, line in ipairs(lines) do
          if i == 1 then
            line = prev .. line
          end

          if i ~= #lines then
            -- don't yield the last line yet because
            -- it might be incomplete
            -- inv, last, continue
            _, _, continue = coroutine.yield(false, line)
          end

          prev = line
          if not continue then break end
        end

        _, _, continue = coroutine.yield(true)
      end
      if prev and prev ~= "" and continue then
        _, _, continue = coroutine.yield(false, prev)
      end

      proc:terminate()
    end
  end)
end

local function files_internal()
  return coroutine.wrap(function()
    local continue = true
    for _, dir in ipairs(core.project_directories) do
      for _, file in ipairs(dir.files) do
        local filename = dir.name .. file.filename
        _, _, continue = coroutine.yield(false, filename)
        if not continue then break end
      end
      if not continue then break end
    end
  end)
end

local function files_source()
  if config.plugins.finder.internal then
    return files_internal()
  else
    return files_cmd()
  end
end

local function files_preview(filename)
  return core.open_doc(filename)
end

local function files_action(value)
  print("open", value)
end

return {
  source = files_source,
  preview = files_preview,
  action = files_action
}
