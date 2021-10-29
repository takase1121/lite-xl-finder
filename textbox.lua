-- by default a DocView's on_text_input is pretty useless for our use
-- we need to detect actual keypresses to appear snappy

local TextBox = require "widget.textbox"

local textbox_new = TextBox.new
function TextBox:new(...)
  textbox_new(self, ...)

  local this = self

  local doc_raw_insert = self.textview.doc.raw_insert
  function self.textview.doc:raw_insert(...)
    doc_raw_insert(self, ...)
    this:on_doc_change("insert", ...)
  end

  local doc_raw_remove = self.textview.doc.raw_remove
  function self.textview.doc:raw_remove(...)
    doc_raw_remove(self, ...)
    this:on_doc_change("remove", ...)
  end
end

function TextBox:on_doc_change()
  -- noop
end

return TextBox
