local core = require "core"

local docs = {}
local function docs_source()
  docs = {}
  return coroutine.wrap(function()
    local i = 1
    for _, doc in ipairs(core.docs) do
      local filename = doc.filename
      if not filename then
        filename = string.format("unnamed (%d)", i)
        i = i + 1
      end
      docs[filename] = doc
      coroutine.yield(false, filename)
    end
  end)
end

local function docs_preview(value)
  return docs[value]
end

local function docs_action(value)
end

return {
  source = docs_source,
  preview = docs_preview,
  action = docs_action
}
