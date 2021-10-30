local core = require "core"

local function docs_iter(inv, i)
  i = i + 1
  local doc = inv.docs[i]
  if not doc then return end

  local name = doc.filename
  if not name then
    name = string.format("unnamed (%d)", inv.i)
    inv.i = inv.i + 1
  end
  return i, { doc = doc, name = name }
end

local docs_source = {
  data = function()
    return docs_iter, { i = 1, docs = core.docs }, 0
  end,
  getter = function(value)
    return value.name
  end
}

local function docs_preview(value)
  return value.doc
end

local function docs_action(value)
  core.root_view:open_doc(value.doc)
end

return {
  source = docs_source,
  preview = docs_preview,
  action = docs_action
}
