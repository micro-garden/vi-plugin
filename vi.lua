VERSION = "0.0.4"

local micro = import("micro")
local config = import("micro/config")
local utf8 = import("unicode/utf8")
local time = import("time")

-- internal constants
local TEXT_EVENT_INSERT = 1
local TEXT_EVENT_REPLACE = 0
local TEXT_EVENT_REMOVE = -1

-- settings
local TICK_DELAY = time.ParseDuration("100ms")

-- vi modes
local VI_MODE_COMMAND = 0
local VI_MODE_INSERT = 1

-- states
local vi_mode = VI_MODE_INSERT
local command_buffer = ""
local command_cached = false
local command_cache = {
	["no_number"] = false,
	["number"] = 1,
	["edit"] = "",
	["move"] = "",
}

local virtual_cursor_x = 0

local deleted_lines = {}

local function command_mode()
	vi_mode = VI_MODE_COMMAND
end

local function insert_mode()
	vi_mode = VI_MODE_INSERT
end

local function show_mode()
	local mode_line
	if vi_mode == VI_MODE_COMMAND then
		mode_line = "vi command mode"
	elseif vi_mode == VI_MODE_INSERT then
		mode_line = "vi insert mode"
	else -- program error
		micro.InfoBar():Error("show_mode: invalid mode = " .. vi_mode)
		return
	end
	micro.InfoBar():Message(mode_line .. " [" .. command_buffer .. "]")
end

local function add_input_to_command_buffer(input)
	command_buffer = command_buffer .. input
	return command_buffer
end

local function clear_command_buffer()
	command_buffer = ""
end

local function cache_command(no_number, number, edit, move)
	command_cache["no_number"] = no_number
	command_cache["number"] = number
	command_cache["edit"] = edit
	command_cache["move"] = move

	command_cached = true
end

local function get_command_cache()
	return command_cache["no_number"], command_cache["number"], command_cache["edit"], command_cache["move"]
end

function Vi(bp)
	-- reset states
	clear_command_buffer()

	-- ensure command mode
	if vi_mode == VI_MODE_COMMAND then -- vi error
		return true
	end
	command_mode()

	--
	local cursor = micro.CurPane().Buf:GetActiveCursor()

	-- ensure cursor y in text
	local last_line_index = cursor:Buf():LinesNum() - 1
	if cursor.Loc.Y == last_line_index then
		local line = cursor:Buf():Line(cursor.Loc.Y)
		local length = utf8.RuneCount(line)
		if length < 1 then
			cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
			micro.CurPane():Relocate()
		end
	end

	-- ensure cursor x in text
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(math.max(cursor.Loc.X - 1, 0), math.max(length - 1, 0))
	micro.CurPane():Relocate()

	--
	virtual_cursor_x = cursor.Loc.X
	show_mode()
	return true
end

function ViEnter(bp)
	if vi_mode == VI_MODE_COMMAND then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), "\n")
		return true
	elseif vi_mode == VI_MODE_INSERT then
		return false
	else -- program error
		micro.InfoBar():Error("ViEnter: invalid mode = " .. vi_mode)
		return false
	end
end

function ViDefault(bp, args)
	local default
	if #args < 1 then
		default = not config.GetGlobalOption("vi.default")
	elseif #args < 2 then
		if args[1] ~= "true" and args[1] ~= "false" then
			micro.InfoBuf():Message("usage: videfault [true|false]")
			return
		end
		default = args[1]
	else
		micro.InfoBuf():Message("usage: videfault [true|false]")
		return
	end
	config.SetGlobalOption("vi.default", tostring(default))
	micro.InfoBar():Message("set vi.default " .. tostring(default))
end

local function bytes_to_string(array)
	local buf = {}
	for i = 1, #array do
		table.insert(buf, string.char(array[i]))
	end
	return table.concat(buf)
end

local function move_left(number)
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.X = math.max(cursor.Loc.X - number, 0)

	virtual_cursor_x = cursor.Loc.X
end

local function move_right(number)
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X + number, math.max(length - 1, 0))

	virtual_cursor_x = cursor.Loc.X
end

local function move_up(number)
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.Y = math.max(cursor.Loc.Y - number, 0)

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(virtual_cursor_x, math.max(length - 1, 0))
end

local function move_down(number)
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local last_line_index = cursor:Buf():LinesNum() - 1
	local y = math.min(cursor.Loc.Y + number, last_line_index)
	if y == last_line_index then
		local line = cursor:Buf():Line(y)
		local length = utf8.RuneCount(line)
		if length < 1 then
			y = math.max(y - 1, 0)
		end
	end
	cursor.Loc.Y = y

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(virtual_cursor_x, math.max(length - 1, 0))
end

local function move_line_start()
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.X = 0

	virtual_cursor_x = cursor.Loc.X
end

local function move_line_end()
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.max(length - 1, 0)

	virtual_cursor_x = cursor.Loc.X
end

local function move_next_line_start(number)
	show_mode()

	move_line_start()
	move_down(number)

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	virtual_cursor_x = cursor.Loc.X

	micro.CurPane():Relocate()
end

-- XXX incompatible with proper vi
-- using micro's Cursor.WordRight
local function move_next_word(number)
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	for _ = 1, number do
		local line = cursor:Buf():Line(cursor.Loc.Y)
		local length = utf8.RuneCount(line)

		if cursor.Loc.X == length - 1 then
			local last_line_index = cursor:Buf():LinesNum() - 1
			if cursor.Loc.Y == last_line_index - 1 then
				local line = cursor:Buf():Line(last_line_index)
				local length = utf8.RuneCount(line)
				if length < 1 then
					break -- vi error
				end
			end

			cursor.Loc.X = length
			cursor:WordRight() -- XXX micro method
		else
			cursor:WordRight() -- XXX micro method
			cursor.Loc.X = math.min(cursor.Loc.X + 1, math.max(length - 1, 0))
		end
	end

	virtual_cursor_x = cursor.Loc.X
end

-- XXX incompatible with proper vi
-- using micro's Cursor.WordLeft
local function move_prev_word(number)
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	for _ = 1, number do
		cursor:WordLeft() -- XXX micro method
	end

	virtual_cursor_x = cursor.Loc.X
end

local function goto_bottom()
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local last_line_index = cursor:Buf():LinesNum() - 1
	local line = cursor:Buf():Line(last_line_index)
	local length = utf8.RuneCount(line)
	if length < 1 then
		last_line_index = last_line_index - 1
	end
	cursor.Loc.Y = last_line_index
	cursor.Loc.X = 0
	virtual_cursor_x = cursor.Loc.X
end

local function goto_line(number)
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local last_line_index = cursor:Buf():LinesNum() - 1
	local line = cursor:Buf():Line(last_line_index)
	local length = utf8.RuneCount(line)
	if length < 1 then
		last_line_index = last_line_index - 1
	end
	if number - 1 > last_line_index then
		micro.InfoBar():Error("line number out of range: " .. number .. " > " .. last_line_index + 1)
		return
	end
	cursor.Loc.Y = number - 1
	cursor.Loc.X = 0
	virtual_cursor_x = cursor.Loc.X
end

local function insert_here()
	insert_mode()
	show_mode()
end

local function insert_line_start()
	insert_mode()
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local spaces = line:match("^(%s*).*$")
	cursor.Loc.X = #spaces

	insert_here()
end

local function insert_after_here()
	insert_mode()
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X + 1, math.max(length, 0))

	insert_here()
end

local function insert_after_line_end()
	insert_mode()
	show_mode()

	move_line_end()
	insert_after_here()
end

local function open_below()
	insert_mode()
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	cursor.Loc.X = utf8.RuneCount(line)
	cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), "\n")

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(TICK_DELAY, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(TICK_DELAY, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
		end)
	end

	virtual_cursor_x = 0
end

local function open_above()
	insert_mode()
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.X = 0
	cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), "\n")

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(TICK_DELAY, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 2, 0)
		end)
	elseif -- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(TICK_DELAY, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 2, 0)
		end)
	end

	virtual_cursor_x = 0
end

local function delete_lines(number)
	show_mode()

	deleted_lines = {}
	for i = 1, number do
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		local line = cursor:Buf():Line(cursor.Loc.Y)
		table.insert(deleted_lines, line)
		micro.CurPane():DeleteLine()

		local last_line_index = cursor:Buf():LinesNum() - 1
		if cursor.Loc.Y == last_line_index then
			local line = cursor:Buf():Line(cursor.Loc.Y)
			local length = utf8.RuneCount(line)
			if length < 1 then
				cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
			end
		end
		local line = cursor:Buf():Line(cursor.Loc.Y)
		local spaces = line:match("^(%s*).*$")
		cursor.Loc.X = #spaces
		virtual_cursor_x = cursor.Loc.X
	end
end

local function copy_lines(number)
	show_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local last_line_index = cursor:Buf():LinesNum() - 1
	local line = cursor:Buf():Line(last_line_index)
	local length = utf8.RuneCount(line)
	if length < 1 then
		last_line_index = math.max(last_line_index - 1, 0)
	end
	if cursor.Loc.Y + number - 1 > last_line_index then
		micro.InfoBar():Error("line number out of range: " .. cursor.Loc.Y + number .. " > " .. last_line_index + 1)
		return
	end

	deleted_lines = {}
	for i = 1, number do
		local line = cursor:Buf():Line(cursor.Loc.Y + i - 1)
		table.insert(deleted_lines, line)
	end
end

local function paste_below(number)
	show_mode()

	if #deleted_lines < 1 then
		micro.InfoBar():Error("no copied lines yet")
		return
	end

	insert_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local saved_y
	local text = "\n" .. table.concat(deleted_lines, "\n")
	for _ = 1, number do
		saved_y = cursor.Loc.Y
		local line = cursor:Buf():Line(cursor.Loc.Y)
		cursor.Loc.X = utf8.RuneCount(line)
		cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), text)
		cursor.Loc.Y = saved_y + 1
	end

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(TICK_DELAY, function()
			cursor.Loc.Y = saved_y + 1

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			command_mode()
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(TICK_DELAY, function()
			cursor.Loc.Y = saved_y + 1

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			command_mode()
		end)
	end
end

local function paste_above(number)
	show_mode()

	if #deleted_lines < 1 then
		micro.InfoBar():Error("no copied lines yet")
		return
	end

	insert_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local saved_y
	local text = table.concat(deleted_lines, "\n") .. "\n"
	for _ = 1, number do
		saved_y = cursor.Loc.Y
		cursor.Loc.X = 0
		cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), text)
		cursor.Loc.Y = saved_y
	end

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(TICK_DELAY, function()
			cursor.Loc.Y = saved_y

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			command_mode()
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(TICK_DELAY, function()
			cursor.Loc.Y = saved_y

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			command_mode()
		end)
	end
end

local run_command

local function repeat_command(number)
	show_mode()

	if not command_cached then
		micro.InfoBar():Error("no command cached yet")
		return
	end

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(TICK_DELAY, function()
			for _ = 1, number do
				run_command(get_command_cache())
			end
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(TICK_DELAY, function()
			for _ = 1, number do
				run_command(get_command_cache())
			end
		end)
	end
end

local function quit()
	show_mode()

	micro.CurPane():QuitCmd({})
end

run_command = function(no_number, number, edit, move)
	if edit == "i" then
		insert_here()
		cache_command(false, number, edit, "")
		return true
	elseif edit == "I" then
		insert_line_start()
		cache_command(false, number, edit, "")
		return true
	elseif edit == "a" then
		insert_after_here()
		cache_command(false, number, edit, "")
		return true
	elseif edit == "A" then
		insert_after_line_end()
		cache_command(false, number, edit, "")
		return true
	elseif edit == "o" then
		open_below()
		cache_command(false, number, edit, "")
		return true
	elseif edit == "O" then
		open_above()
		cache_command(false, number, edit, "")
		return true
	elseif edit == "dd" then
		delete_lines(number)
		cache_command(false, number, edit, "")
		return true
	elseif edit == "yy" then
		copy_lines(number)
		cache_command(false, number, edit, "")
		return true
	elseif edit == "p" then
		paste_below(number)
		cache_command(false, number, edit, "")
		return true
	elseif edit == "P" then
		paste_above(number)
		cache_command(false, number, edit, "")
		return true
	elseif edit == "." then
		repeat_command(number)
		return true
	elseif move == "h" then
		move_left(number)
		return true
	elseif move == "j" then
		move_down(number)
		return true
	elseif move == "k" then
		move_up(number)
		return true
	elseif move == "l" then
		move_right(number)
		return true
	elseif move == "\n" then
		move_next_line_start(number)
		return true
	elseif move == "0" then
		move_line_start()
		return true
	elseif move == "$" then
		move_line_end()
		return true
	elseif move == "w" then
		move_next_word(number)
		return true
	elseif move == "b" then
		move_prev_word(number)
		return true
	elseif move == "G" then
		if no_number then
			goto_bottom()
		else
			goto_line(number)
		end
		return true
	elseif edit == "ZZ" then
		quit()
		return true
	else
		return false
	end
end

function onBeforeTextEvent(buf, ev)
	if vi_mode == VI_MODE_INSERT then
		return true
	end

	if ev.EventType == TEXT_EVENT_REMOVE or ev.EventType == TEXT_EVENT_REPLACE then
		return true
	end

	-- assert
	if ev.EventType ~= TEXT_EVENT_INSERT then -- program error
		micro.InfoBar():Error("Invalid text event type = ev.EventType")
		return true
	end

	if #ev.Deltas ~= 1 then
		return true
	end
	local delta = ev.Deltas[1]

	-- pass through pasted long text
	if #delta.Text ~= 1 then
		return true
	end

	-- Text is byte array
	local input = bytes_to_string(delta.Text)

	delta.Text = ""
	delta.Start.X = 0
	delta.Start.Y = 0
	delta.End.X = 0
	delta.End.Y = 0

	local command_buffer = add_input_to_command_buffer(input)

	local number_str, edit, move
	if command_buffer:match("^0$") then
		number_str, edit, move = "", "", "0"
	else
		number_str, edit, move = command_buffer:match("^(%d*)([iIaAoOdypP%.Z]*)([hjkl\n0%$wbG]*)$")
	end

	if not number_str then
		micro.InfoBar():Error("not (yet) a vi command [" .. command_buffer .. "]")
		clear_command_buffer()
		return true
	end

	local no_number = false
	local number = 1
	if #number_str < 1 then
		no_number = true
	else
		number = tonumber(number_str)
	end

	if run_command(no_number, number, edit, move) then
		clear_command_buffer()
		return true
	end

	show_mode()
	return true
end

function onBufPaneOpen(bp)
	if config.GetGlobalOption("vi.default") then
		Vi()
	end
end

function preinit()
	config.RegisterCommonOption("vi", "default", false)
end

function init()
	config.MakeCommand("vi", Vi, config.NoComplete)
	config.MakeCommand("vienter", ViEnter, config.NoComplete)
	config.MakeCommand("videfault", ViDefault, config.NoComplete)
	config.TryBindKey("Escape", "Escape,Deselect,ClearInfo,RemoveAllMultiCursors,UnhighlightSearch,lua:vi.Vi", false)
	config.TryBindKey("Enter", "lua:vi.ViEnter|InsertNewline", false)
	config.AddRuntimeFile("vi", config.RTHelp, "help/vi.md")
end
