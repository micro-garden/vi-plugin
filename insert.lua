M = {}

local micro = import("micro")
local buffer = import("micro/buffer")
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
local utils = require("utils")

local saved_func = nil
local saved_number = 1
local saved_replay = false

local saved_loc = nil
local saved_size = nil
local inserted_lines = {}

local WORDS_MODE = 1
local LINES_MODE = 2
local REPLACE_MODE = 3
local insert_mode = WORDS_MODE

local function size_with_linefeeds()
	local buf = micro.CurPane().Buf
	local linesnum = buf:LinesNum()
	local size = 0
	for i = 0, linesnum - 1 do
		local line = buf:Line(i)
		size = size + #line + 1
	end
	return size
end

local function save_state(func, number, replay)
	saved_func = func
	saved_number = number
	saved_replay = replay

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	if insert_mode == REPLACE_MODE then
		saved_loc = buffer.Loc(cursor.Loc.X + 1, cursor.Loc.Y)
	else
		saved_loc = buffer.Loc(cursor.Loc.X, cursor.Loc.Y)
	end
	saved_size = size_with_linefeeds()
end

local function extend(loc, func, number, replay)
	local n
	if replay then
		n = number
	else
		n = number - 1
	end
	local lines = {}

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local x = cursor.Loc.X
	local y = cursor.Loc.Y

	for _ = 1, n do
		for i = 1, #inserted_lines do
			table.insert(lines, inserted_lines[i])
			local length = utf8.RuneCount(inserted_lines[i])
			if i == 1 and insert_mode == WORDS_MODE or insert_mode == REPLACE_MODE then
				x = math.max(x + length - 1, 0)
			else
				x = math.max(length - 1, 0)
			end
			y = y + 1
		end
	end

	if replay and (insert_mode == WORDS_MODE or insert_mode == REPLACE_MODE) and #inserted_lines > 0 then
		y = y - 1
	end

	local buf = micro.CurPane().Buf
	if insert_mode == WORDS_MODE or insert_mode == REPLACE_MODE then
		buf:Insert(loc, table.concat(lines, "\n"))
	elseif insert_mode == LINES_MODE then
		buf:Insert(loc, table.concat(lines, "\n") .. "\n")
	else -- program error
		micro.InfoBar():Error("insert.extend: invalid insert mode = " .. insert_mode)
		return
	end

	cursor.Loc.X = x
	cursor.Loc.Y = y
	motion.update_virtual_cursor()
end

local function resume(orig_loc)
	if saved_loc then
		size = size_with_linefeeds()
		if size > saved_size then
			inserted_lines = {}
			local buf = micro.CurPane().Buf
			local x = saved_loc.X
			local y = saved_loc.Y
			local run = saved_size
			if insert_mode == WORDS_MODE or insert_mode == REPLACE_MODE then
				run = run - 1
				size = size - 1
			end
			while run < size do
				local line = buf:Line(y)
				local length = #line
				if run + length - x > size then
					x = size - run
					if y == saved_loc.Y then
						if insert_mode == REPLACE_MODE then
						table.insert(inserted_lines, line:sub(saved_loc.X, saved_loc.X + x - 1))
						else
						table.insert(inserted_lines, line:sub(saved_loc.X, saved_loc.X + x))
						end
					else
						table.insert(inserted_lines, line:sub(1, x))
					end
					run = run + (size - run)
					break
				end
				local subline = line:sub(x + 1)
				table.insert(inserted_lines, subline)
				run = run + #subline + 1
				x = 0
				y = y + 1
			end
			local end_loc = buffer.Loc(x, y)
		end
		saved_loc = nil
		saved_size = nil
	end

	if saved_func then
		extend(orig_loc, saved_func, saved_number, saved_replay)

		save_func = nil
		saved_number = 1
		saved_replay = false
	end
end

local function words_mode()
	insert_mode = WORDS_MODE
end

local function lines_mode()
	insert_mode = LINES_MODE
end

local function replace_mode()
	insert_mode = REPLACE_MODE
end

local function insert_here(number, replay)
	words_mode()
	if replay then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		local loc = buffer.Loc(cursor.Loc.X, cursor.Loc.Y)
		extend(loc, insert_here, number, replay)
	else
		mode.insert()
		mode.show()

		save_state(insert_here, number, replay)
	end
end

local function insert_line_start(number, replay)
	words_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local spaces = line:match("^(%s*).*$")
	cursor.Loc.X = #spaces

	if replay then
		local loc = buffer.Loc(cursor.Loc.X, cursor.Loc.Y)
		extend(loc, insert_line_start, number, replay)
	else
		mode.insert()
		mode.show()

		save_state(insert_line_start, number, replay)
	end
end

local function insert_after_here(number, replay)
	words_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X + 1, math.max(length, 0))

	if replay then
		local loc = buffer.Loc(cursor.Loc.X, cursor.Loc.Y)
		extend(loc, insert_after_here, number, replay)
	else
		mode.insert()
		mode.show()

		save_state(insert_after_here, number, replay)
	end
end

local function insert_after_line_end(number, replay)
	words_mode()

	motion.move_line_end()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X + 1, math.max(length, 0))

	if replay then
		local loc = buffer.Loc(cursor.Loc.X, cursor.Loc.Y)
		extend(loc, insert_after_line_end, number, replay)
	else
		mode.insert()
		mode.show()

		save_state(insert_after_line_end, number, replay)
	end
end

local function open_below(number, replay)
	lines_mode()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	if replay then
		local linesnum = cursor:Buf():LinesNum()
		local loc = buffer.Loc(0, math.min(cursor.Loc.Y + 1, linesnum - 1))
		extend(loc, open_below, number, replay)
	else
		mode.insert()
		mode.show()

		local line = cursor:Buf():Line(cursor.Loc.Y)
		cursor.Loc.X = utf8.RuneCount(line)
		cursor:Buf():Insert(buffer.Loc(cursor.Loc.X, cursor.Loc.Y), "\n")

		utils.after(editor.TICK_DELAY, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
			cursor.Loc.X = 0
			motion.update_virtual_cursor()

			save_state(open_below, number, replay)
		end)
	end
end

local function open_above(number, replay)
	lines_mode()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	if replay then
		local loc = buffer.Loc(0, cursor.Loc.Y)
		extend(loc, open_above, number, replay)
	else
		mode.insert()
		mode.show()

		cursor.Loc.X = 0
		cursor:Buf():Insert(buffer.Loc(cursor.Loc.X, cursor.Loc.Y), "\n")

		utils.after(editor.TICK_DELAY, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 2, 0)
			cursor.Loc.X = 0
			motion.update_virtual_cursor()

			save_state(open_above, number, replay)
		end)
	end
end

local function open_here(number, replay)
	lines_mode()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	if replay then
		local loc = buffer.Loc(0, cursor.Loc.Y)
		extend(loc, open_here, number, replay)
	else
		mode.insert()
		mode.show()

		cursor.Loc.X = 0
		cursor:Buf():Insert(buffer.Loc(cursor.Loc.X, cursor.Loc.Y), "\n")

		utils.after(editor.TICK_DELAY, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
			cursor.Loc.X = 0
			motion.update_virtual_cursor()

			save_state(open_here, number, replay)
		end)
	end
end

local function insert_here_replace(number, replay)
	replace_mode()
	if replay then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		local loc = buffer.Loc(cursor.Loc.X, cursor.Loc.Y)
		extend(loc, insert_here_replace, number, replay)
	else
		mode.insert()
		mode.show()

		save_state(insert_here_replace, number, replay)
	end
end

M.resume = resume
M.save_state = save_state
M.extend = extend
M.words_mode = words_mode
M.lines_mode = lines_mode
M.replace_mode = replace_mode

M.insert_here = insert_here
M.insert_line_start = insert_line_start
M.insert_after_here = insert_after_here
M.insert_after_line_end = insert_after_line_end
M.open_below = open_below
M.open_above = open_above
M.open_here = open_here

M.insert_here_replace = insert_here_replace

return M
