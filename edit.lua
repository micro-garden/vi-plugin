-- Editing Commands

local micro = import("micro")
local buffer = import("micro/buffer")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local utils = require("vi/utils")
local bell = require("vi/bell")
local mode = require("vi/mode")
local move = require("vi/move")

-- r : Replace single character under cursor.
local function replace(letter)
	bell.planned("r (edit.replace)")
end

-- J : Join current line with next line.
local function join(num)
	mode.show()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	if cursor.Y >= last_line_index then
		bell.vi_info("no lines to join below")
		return
	end

	local n = num
	if n > 1 then
		n = n - 1
	end

	for _ = 1, n do
		if cursor.Y >= last_line_index then
			break
		end

		local line = buf:Line(cursor.Y)
		local length = utf8.RuneCount(line)
		cursor.X = length
		local next_line = buf:Line(cursor.Y + 1)
		local loc = buffer.Loc(cursor.X, cursor.Y)
		local _, body = next_line:match("^(%s*)(.*)$")
		if #body > 0 then
			buf:Insert(loc, " " .. body)
		end
		cursor.Y = cursor.Y + 1
		pane:DeleteLine()
		cursor.Y = cursor.Y - 1

		utils.next_tick(function()
			cursor.Y = loc.Y
			line = buf:Line(cursor.Y)
			if length < 1 or #next_line < 1 then
				local current_length = utf8.RuneCount(line)
				cursor.X = math.max(current_length - 1, 0)
			else
				cursor.X = loc.X
			end
			move.update_virtual_cursor()
		end)
	end
end

-- internal use
--
local function indent_lines_internal(num, right)
	mode.show()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	if cursor.Y + num - 1 > last_line_index then
		bell.ring("there are not " .. num .. " lines below, only " .. last_line_index - cursor.Y + 1)
		return
	end

	mode.insert()
	local saved_x = cursor.X
	local saved_y = cursor.Y
	for i = 1, num do
		if right then
			micro.CurPane():IndentLine()
		else
			micro.CurPane():OutdentLine()
		end
		if num > 1 then
			if i == 1 then
				saved_x = cursor.X
				saved_y = cursor.Y
			end
			cursor.X = 0
			cursor.Y = cursor.Y + 1
		end
	end
	if num > 1 then
		cursor.X = saved_x
		cursor.Y = saved_y
	end
	mode.command()
end

-- >> : Indent current line.
local function indent(num)
	indent_lines_internal(num, true)
end

-- << : Outdent current line.
local function outdent(num)
	indent_lines_internal(num, false)
end

-- internal use
--
local function indent_region_internal(start_loc, end_loc, num, right)
	if not utils.is_locs_ordered(start_loc, end_loc) then
		start_loc, end_loc = end_loc, start_loc -- swap
	end

	local n = end_loc.Y - start_loc.Y + 1
	indent_lines_internal(num * n, right)
end

-- > <mv> : Indent region from current cursor to destination of motion <mv>.
local function indent_region(start_loc, end_loc, num)
	indent_region_internal(start_loc, end_loc, num, true)
end

--  < <mv> : Outdent region from current cursor to destination of motion <mv>.
local function outdent_region(start_loc, end_loc, num)
	indent_region_internal(start_loc, end_loc, num, false)
end

-------------
-- Exports --
-------------

local M = {}

M.replace = replace
M.join = join
M.indent = indent
M.outdent = outdent
M.indent_region = indent_region
M.outdent_region = outdent_region

return M
