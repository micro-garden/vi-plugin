M = {}

local micro = import("micro")
local utf8 = import("unicode/utf8")
local time = import("time")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/vi/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local editor = require("editor")
local mode = require("mode")
local motion = require("motion")

local function insert_here()
	mode.insert()
	mode.show()
end

local function insert_line_start()
	mode.insert()
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local spaces = line:match("^(%s*).*$")
	cursor.Loc.X = #spaces

	insert_here()
end

local function insert_after_here()
	mode.insert()
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X + 1, math.max(length, 0))

	insert_here()
end

local function insert_after_line_end()
	mode.insert()
	mode.show()

	motion.move_line_end()
	insert_after_here()
end

local function open_below()
	mode.insert()
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	cursor.Loc.X = utf8.RuneCount(line)
	cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), "\n")

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(editor.TICK_DELAY, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
			cursor.Loc.X = 0
			motion.update__cursor()
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(editor.TICK_DELAY, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
			cursor.Loc.X = 0
			motion.update_virtual_cursor()
		end)
	end
end

local function open_above()
	mode.insert()
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.X = 0
	cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), "\n")

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(editor.TICK_DELAY, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 2, 0)
			cursor.Loc.X = 0
			motion.update_virtual_cursor();
		end)
	elseif -- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(editor.TICK_DELAY, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 2, 0)
			cursor.Loc.X = 0
			motion.update_virtual_cursor();
		end)
	end
end

M.insert_here = insert_here
M.insert_line_start = insert_line_start
M.insert_after_here = insert_after_here
M.insert_after_line_end = insert_after_line_end
M.open_below = open_below
M.open_above = open_above

return M
