-- I copied this because this is so frustratingly similiar to CodeBox but not

local core = require "core"
local style = require "core.style"
local DocView = require "core.docview"

local Widget = require "widget"

local CodeBox = Widget:extend()

function CodeBox:new(parent, writable)
  CodeBox.super.new(self, parent)
  self.size.x = 200 + (style.padding.x * 2)
  self.size.y = 200 * self.font:get_height() + (style.padding.y * 2)

  -- this widget is for text input
  self.input_text = writable
end

--- Get the text displayed on the textbox.
---@return string
function CodeBox:get_text()
  return self.textview and self.textview:get_text() or ""
end

--- Set the text displayed on the textbox.
---@param text string
---@param select boolean
function CodeBox:set_text(text, select)
  if self.textview then
    self.textview:set_text(text, select)
  end
end

function CodeBox:set_doc(filename)
  if filename then
    local d = core.open_doc(filename)
    self.textview = DocView(d)
  else
    self.textviewview = nil
  end
end

--
-- Events
--

function CodeBox:on_mouse_pressed(button, x, y, clicks)
  CodeBox.super.on_mouse_pressed(self, button, x, y, clicks)
  if self.textview then
    self.textview:on_mouse_pressed(button, x, y, clicks)
  end
end

function CodeBox:on_mouse_released(button, x, y)
  CodeBox.super.on_mouse_released(self, button, x, y)
  if self.textview then
    self.textview:on_mouse_released(button, x, y)
  end
end

function CodeBox:on_mouse_moved(x, y, dx, dy)
  CodeBox.super.on_mouse_moved(self, x, y, dx, dy)
  if self.textview then
    self.textview:on_mouse_moved(x, y, dx, dy)
  end
  core.request_cursor("arrow")
end

function CodeBox:on_mouse_wheel(y)
  CodeBox.super.on_mouse_wheel(self, y)
  if self.textview then
    self.textview:on_mouse_wheel(y)
  end
end

function CodeBox:activate()
  self.hover_border = style.caret
  core.request_cursor("arrow")
end

function CodeBox:deactivate()
  self.hover_border = nil
  core.request_cursor("arrow")
end

function CodeBox:on_text_input(text)
  CodeBox.super.on_text_input(self, text)
  if self.textview then
    self.textview:on_text_input(text)
  end
end

---Event fired on any text change event.
---@param action string Can be "insert" or "remove",
---insert arguments (see Doc:raw_insert):
---  line, col, text, undo_stack, time
---remove arguments (see Doc:raw_remove):
---  line1, col1, line2, col2, undo_stack, time
function CodeBox:on_text_change(action, ...) end

function CodeBox:update()
  CodeBox.super.update(self)
  if self.textview then
    self.textview:update()
  end
end

function CodeBox:draw()
  self.border.color = self.hover_border or style.text
  CodeBox.super.draw(self)

  if not self.textview then return end

  self.textview.position.x = self.position.x + (style.padding.x / 2)
  self.textview.position.y = self.position.y - (style.padding.y/2.5)
  self.textview.size.x = self.size.x
  self.textview.size.y = self.size.y - (style.padding.y * 2)

  core.push_clip_rect(
  self.position.x,
  self.position.y,
  self.size.x,
  self.size.y
  )
  self.textview:draw()
  core.pop_clip_rect()
end


return CodeBox
