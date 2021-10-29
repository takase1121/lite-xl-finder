-- fast listbox optimized for fuzzy find

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"

local Widget = require "widget"

local function compare_score(a, b)
  return a.score < b.score
end

local FuzzyBox = Widget:extend()

function FuzzyBox:new(parent, src, src_file)
  FuzzyBox.super.new(self, parent)
  self.sorted = {}
  self.status = { indexing = false, indexed = 0, force_stop = false }
  self.resort_req = {}
  self.border.width = 0
  self.font = style.code_font

  self.lines = {}
  self.last_size  = { x = 0, y = 0 }

  self.line_height = math.floor(self.font:get_height() * config.line_height)
  self.scrollable = true

  self:set_size(200, 200)
  core.add_thread(function()
    while true do
      if #self.resort_req > 0 then
        local needle = table.remove(self.resort_req, 1)
        self.sorted = {}
        self.status.indexing = true
        self.status.indexed = 0

        local iter, inv, last = src()
        while true do
          if self.status.force_stop then
            pcall(iter, inv, last, false)
            break
          end

          local ok, yield, value = pcall(iter, inv, last, true)
          last = yield
          if not ok then
            core.error("[ffzf] source failed: %s", yield)
            break
          end

          if yield then
            coroutine.yield()
          elseif yield == false then
            self.status.indexed = self.status.indexed + 1
            local score = system.fuzzy_match(value, needle, src_file)
            if score then
              self.sorted[#self.sorted + 1] = { data = value, score = score }
            end
          else
            break
          end
        end
        table.sort(self.sorted, compare_score)
        self.status.indexing = false
      end
      coroutine.yield(1 / config.fps)
    end
  end, self)
end

function FuzzyBox:resort(needle)
  self.resort_req[#self.resort_req + 1] = needle
end

function FuzzyBox:cancel_resort()
  self.resort_req = {}
  self.status.force_stop = true
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
      local s = common.home_encode(self.sorted[i].data)
      if self.font:get_width(s) > w then
        coroutine.yield(i, "..." .. self:accurate_left_wrap(s, lww), ox, oy, w, h)
      else
        coroutine.yield(i, s, ox, oy, w, h)
      end
    end
  end)
end

function FuzzyBox:on_mouse_pressed(button, px, py, clicks)
  local caught = FuzzyBox.super.on_mouse_pressed(self, button, px, py, clicks)
  if button == "left" and clicks == 1 then
    for i, _, x, y, w, h in self:each_visible_item() do
      if px >= x and py >= y and px < x + w and py < y + h then
        self.selected = i
        return
      end
    end
  end
  if button == "left" and clicks >= 2 and self.selected then
    -- TODO: do something
  end
end

function FuzzyBox:update()
  FuzzyBox.super.update(self)
  if self.last_size.x ~= self.size.x or self.last_size.y ~= self.size.y then
    self.last_size.x = self.size.x
    self.last_size.y = self.size.y

    self.lines = {}
  end

  if not self.status.indexing then
    if not self.selected then
      self.selected = #self.sorted
    end

    local min_line, max_line = self:get_visible_line_range()
    self.selected = common.clamp(self.selected, min_line, max_line)
    self.scroll.y = self:get_scrollable_size() - self.size.y
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
