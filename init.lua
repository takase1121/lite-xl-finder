-- mod-version: 2 -- lite-xl 2.0
local core = require "core"
local config = require "core.config"
local command = require "core.command"
local keymap = require "core.keymap"
local style = require "core.style"

local Notebook = require "widget.notebook"
local Label = require "widget.label"

-- we need our own textbox for doc change events
local TextBox = require "plugins.finder.textbox"
local CodeBox = require "plugins.finder.codebox"
local FuzzyBox = require "plugins.finder.fuzzybox"
local files_source = require "plugins.finder.files"

config.plugins.finder = {
  size = { w = 0.8, h = 0.8 },
  delay = 0.04,
  files = {
    internal = true,
    command = { "find", "%CWD", "-type", "f" },
  }
}

local finder_overlay = Notebook()
local finder_overlay_update = finder_overlay.update
function finder_overlay:update()
  self:set_size(
    core.root_view.size.x * config.plugins.finder.size.w,
    core.root_view.size.y * config.plugins.finder.size.h
  )
  local ox = (core.root_view.size.x - finder_overlay.size.x) / 2
  local oy = (core.root_view.size.y - finder_overlay.size.y) / 2
  finder_overlay:set_position(ox, oy)
  finder_overlay_update(self)
end

local files = finder_overlay:add_pane("files", "Find Files")
local docs = finder_overlay:add_pane("docs", "Find Docs")

local function create_ui(pane, source, file)
  local code = CodeBox(pane, false)
  local list = FuzzyBox(pane, source, file)
  local input = TextBox(pane, "", "Find...")
  local status = Label(pane, "-")

  local pane_update = pane.update
  function pane:update()
    pane_update(self)
    local x, y = style.padding.x, style.padding.y
    local section_w = (self:get_width() - (3 * style.padding.x)) / 2
    local section_h = (self:get_height() - (2 * style.padding.y))

    local input_h = input:get_height()
    local list_h = section_h - input_h - status:get_height() - 2 * style.padding.y
    list:set_size(section_w, list_h)
    list:set_position(x, y)

    status:set_position(x, list:get_bottom() + style.padding.y)

    input:set_size(section_w, input_h)
    input:set_position(x, status:get_bottom() + style.padding.y)

    code:set_size(section_w, section_h)
    code:set_position(list:get_right() + style.padding.x, y)
  end

  local last_doc_change, done = system.get_time(), false
  local on_doc_change = input.on_doc_change
  function input:on_doc_change(...)
    on_doc_change(self, ...)
    last_doc_change = system.get_time()
    done = false
  end

  local input_update = input.update
  function input:update()
    input_update(self)
    local time = system.get_time()
    if not done and time - last_doc_change > config.plugins.finder.delay then
      done = true
      list:resort(self:get_text())

      status:set_label(string.format("%d/%d file(s) %s", #list.sorted, list.status.indexed, list.status.indexing and "and going..." or ""))
      local current = list.sorted[#list.sorted]
      code:set_doc(current and current.filename or nil)
    end
  end
end

create_ui(files, files_source, true)


command.add(nil, {
  ["finder:toggle-overlay"] = function()
    if finder_overlay.visible then
      finder_overlay:hide()
    else
      finder_overlay:show()
    end
  end,
  ["finder:close-overlay"] = function()
    if finder_overlay.visible then
      finder_overlay:hide()
    end
  end
})

keymap.add {
  ["alt+f"] = "finder:toggle-overlay",
  ["escape"] = "finder:close-overlay"
}
