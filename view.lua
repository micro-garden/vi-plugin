-- View Commands
local micro = import("micro")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local bell = require("vi/bell")
local mode = require("vi/mode")
local move = require("vi/move")

--
-- Scroll by View Height / Scroll by Line
--

-- Ctrl-f : Scroll down by view height.
local function down()
	bell.not_planned("Ctrl-f (view.down)")
end

-- Ctrl-b : Scroll up by view height.
local function up()
	bell.not_planned("Ctrl-b (view.up)")
end

-- Ctrl-d : Scroll down by half view height.
local function down_half()
	bell.not_planned("Ctrl-d (view.down_half)")
end

-- Ctrl-u : Scroll up by half view height.
local function up_half()
	bell.not_planned("Ctrl-u (view.up_half)")
end

-- Ctrl-y : Scroll down by line.
local function down_line()
	bell.not_planned("Ctrl-y (view.down_line)")
end

-- Ctrl-e : Scroll up by line.
local function up_line()
	bell.not_planned("Ctrl-e (view.up_line)")
end

--
-- Reposition
--

-- z Enter : Reposition cursor line to top of view.
local function to_top()
	mode.show()

	local pane = micro.CurPane()
	local v = pane:GetView()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	v.StartLine.Line = cursor.Y

	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	cursor.X = utf8.RuneCount(spaces)

	move.update_virtual_cursor()
end

-- z. : Reposition cursor line middle of view.
local function to_middle()
	mode.show()

	local pane = micro.CurPane()
	local v = pane:GetView()
	local bv = pane:BufView()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local offset = math.floor(bv.Height / 2)
	v.StartLine.Line = math.max(cursor.Y - offset, 0)

	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	cursor.X = utf8.RuneCount(spaces)

	move.update_virtual_cursor()
end

-- z- : Reposition cursor line bottom of view.
local function to_bottom()
	mode.show()

	local pane = micro.CurPane()
	local v = pane:GetView()
	local bv = pane:BufView()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	v.StartLine.Line = math.max(cursor.Y - bv.Height + 1, 0)

	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	cursor.X = utf8.RuneCount(spaces)

	move.update_virtual_cursor()
end

--
-- Redraw
--

-- Ctrl-l : Redraw view.
local function redraw()
	bell.not_planned("Ctrl-l (view.redraw)")
end

-------------
-- Exports --
-------------

local M = {}

-- Scroll by View Height / Scroll by Line
M.down = down
M.up = up
M.down_half = down_half
M.up_half = up_half
M.down_line = down_line
M.up_line = up_line

-- Reposition
M.to_top = to_top
M.to_middle = to_middle
M.to_bottom = to_bottom

-- Redraw
M.redraw = redraw

return M
