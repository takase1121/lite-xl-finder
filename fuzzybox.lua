-- fast listbox optimized for fuzzy find

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"

local Widget = require "widget"

local function noop()
end

local function compare_score(a, b)
  return a.score < b.score
end

local function default_getter(value)
  return value
end

local FuzzyBox = Widget:extend()

function FuzzyBox:new(parent, source)
  FuzzyBox.super.new(self, parent)
  self.sorted = {}
  self.source = source
  self.source.getter = self.source.getter or default_getter
  self.border.width = 0
  self.font = style.code_font

  self.lines = {}
  self.last_size  = { x = 0, y = 0 }

  self.line_height = math.floor(self.font:get_height() * config.line_height)
  self.scrollable = true

  self:set_size(200, 200)
  self:resort("")
end

function FuzzyBox:resort(needle)
  self.sorted = {}
  local indexed = 0
  local score
  for _, value in self.source.data() do
    indexed = indexed + 1
    score = system.fuzzy_match(self.source.getter(value), needle, self.source.is_file)
    if score then
      self.sorted[#self.sorted+1] = { data = value, score = score }
    end
  end
  table.sort(self.sorted, compare_score)
  if not self.selected then
    self:set_selected(#self.sorted)
  end
  self:scroll_to(self:get_scrollable_size())

  return #self.sorted, indexed
end

function FuzzyBox:get_scrollable_size()
  return #self.sorted * self.line_height
end

function FuzzyBox:get_visible_line_range()
  local x, y, x2, y2 = self:get_content_bounds()
  local lh = self.line_height
  local minline = math.max(1, math.floor(y / lh))
  local maxline = math.min(#self.sorted, math.floor(y2 / lh) + 1)
  return minline, maxline
end

-- who knows if this is actually necessary
function FuzzyBox:accurate_left_wrap(str, w)
  if self.lines[str] then return self.lines[str] end
  -- get a rough estimation
  local esti = common.round(w / (self.font:get_width(str) / #str))
  -- literally brute force from our estimation
  for i = esti, 1, -1 do
    local s = str:sub(#str - i, -1)
    if self.font:get_width(s) <= w then
      self.lines[str] = s
      return s
    end
  end
  self.lines[str] = str
  return str
end

function FuzzyBox:each_visible_item()
  return coroutine.wrap(function()
    local min_line, max_line = self:get_visible_line_range()
    local ox, oy = self.position.x, self.position.y + self.size.y
    local w, h = self.size.x, self.line_height
    local lww = math.max(0, w - self.font:get_width("..."))
    for i = max_line, min_line, -1 do
      oy = oy - h
      local s = self.source.getter(self.sorted[i].data)
      if self.font:get_width(s) > w then
        coroutine.yield(i, "..." .. self:accurate_left_wrap(s, lww), ox, oy, w, h)
      else
        coroutine.yield(i, s, ox, oy, w, h)
      end
    end
  end)
end

function FuzzyBox:scroll_to(y, instant)
  self.scroll.to.y = y
  self:clamp_scroll_position()
  if instant then
    self.scroll.y = self.scroll.to.y
  end
end

function FuzzyBox:set_selected(idx, diff)
  local selection = self.selected or 0
  if diff then
    selection = selection + diff
  else
    selection = idx
  end

  local min_line, max_line = self:get_visible_line_range()
  selection = common.clamp(selection, min_line, max_line)

  if self.selected ~= selection and self.sorted[selection] then
    self:on_selected_update(self.sorted[selection].data, selection)
  end

  self.selected = selection
  core.redraw = true
end

function FuzzyBox:on_mouse_moved(px, py, dx, dy)
  FuzzyBox.super.on_mouse_moved(self, px, py, dx, dy)
  for i, _, x, y, w, h in self:each_visible_item() do
    if px >= x and py >= y and px < x + w and py < y + h then
      self:set_selected(i)
      return
    end
  end
end

function FuzzyBox:on_click(button, x, y)
  FuzzyBox.super.on_click(self, button, x, y)
  if button == "left" and self.sorted[self.selected] then
    self:on_selected(self.sorted[self.selected].data, self.selected)
  end
end

function FuzzyBox:on_selected(selected, i)
end

function FuzzyBox:on_selected_update(selected, i)
end

function FuzzyBox:update()
  FuzzyBox.super.update(self)
  if self.last_size.x ~= self.size.x or self.last_size.y ~= self.size.y then
    self.last_size.x = self.size.x
    self.last_size.y = self.size.y

    self.lines = {}
  end
end

function FuzzyBox:draw()
  if not FuzzyBox.super.draw(self) then return end

  core.push_clip_rect(self.position.x, self.position.y, self.size.x, self.size.y)
  for i, filename, x, y, w, h in self:each_visible_item() do
    local color = style.text
    if i == self.selected then
      color = style.background
      renderer.draw_rect(x, y, w, h, style.accent)
    end
    common.draw_text(self.font, color, filename, "left", x, y, w, h)
  end
  core.pop_clip_rect()

end

return FuzzyBox
