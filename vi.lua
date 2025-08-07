VERSION = "0.0.3"

local micro = import("micro")
local config = import("micro/config")
local utf8 = import("unicode/utf8")
local time = import("time")

-- internal constants
local TextEventInsert = 1
local TextEventReplace = 0
local TextEventRemove = -1

-- settings
local tick_delay = time.ParseDuration("100ms")

-- vi modes
local CommandMode = 0
local InsertMode = 1

-- states
local vi_mode = InsertMode
local command_buffer = ""
local command_number = 1
local command_edit = nil

local virtual_cursor_x = 0

local killed_lines = {}

local function show_mode()
	local mode_line
	if vi_mode == CommandMode then
		mode_line = "vi command mode"
	elseif vi_mode == InsertMode then
		mode_line = "vi insert mode"
	else -- program error
		micro.InfoBar():Error("show_mode: invalid mode = " .. vi_mode)
		return
	end
	micro.InfoBar():Message(mode_line .. " [" .. command_buffer .. "]")
end

function Vi(bp)
	-- reset states
	command_buffer = ""
	command_number = 1
	command_edit = nil

	-- ensure command mode
	if vi_mode == CommandMode then -- vi error
		return true
	end
	vi_mode = CommandMode

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
	if vi_mode == CommandMode then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), "\n")
		return true
	elseif vi_mode == InsertMode then
		return false
	else -- program error
		micro.InfoBar():Error("ViEnter: invalid mode = " .. vi_mode)
		return false
	end
end

local function bytes_to_string(array)
	local buf = {}
	for i = 1, #array do
		table.insert(buf, string.char(array[i]))
	end
	return table.concat(buf)
end

local function move_left(number)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.X = math.max(cursor.Loc.X - number, 0)

	virtual_cursor_x = cursor.Loc.X
end

local function move_right(number)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X + number, math.max(length - 1, 0))

	virtual_cursor_x = cursor.Loc.X
end

local function move_up(number)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.Y = math.max(cursor.Loc.Y - number, 0)

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(virtual_cursor_x, math.max(length - 1, 0))
end

local function move_down(number)
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
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.X = 0

	virtual_cursor_x = cursor.Loc.X
end

local function move_line_end()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.max(length - 1, 0)

	virtual_cursor_x = cursor.Loc.X
end

local function move_next_line_start(number)
	move_line_start()
	move_down(number)

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	virtual_cursor_x = cursor.Loc.X

	micro.CurPane():Relocate()
end

-- XXX incompatible with proper vi
-- using micro's Cursor.WordRight
local function move_next_word(number)
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
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	for _ = 1, number do
		cursor:WordLeft() -- XXX micro method
	end

	virtual_cursor_x = cursor.Loc.X
end

local function move_bottom_line()
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

local function move_line(number)
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
	-- nothing to do
end

local function insert_at_line_start()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local spaces = line:match("^(%s*).*$")
	cursor.Loc.X = #spaces

	insert_here()
end

local function insert_after_here()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X + 1, math.max(length, 0))

	insert_here()
end

local function insert_after_line_end()
	move_line_end()
	insert_after_here()
end

local function open_next_line()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	cursor.Loc.X = utf8.RuneCount(line)
	cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), "\n")

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(tick_delay, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(tick_delay, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
		end)
	end

	virtual_cursor_x = 0
end

local function open_prev_line()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.X = 0
	cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), "\n")

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(tick_delay, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 2, 0)
		end)
	elseif -- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(tick_delay, function()
			cursor.Loc.Y = math.max(cursor.Loc.Y - 2, 0)
		end)
	end

	virtual_cursor_x = 0
end

local function delete_line(number)
	killed_lines = {}
	for i = 1, number do
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		local line = cursor:Buf():Line(cursor.Loc.Y)
		table.insert(killed_lines, line)
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

local function yank_line(number)
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

	killed_lines = {}
	for i = 1, number do
		local line = cursor:Buf():Line(cursor.Loc.Y + i - 1)
		table.insert(killed_lines, line)
	end
end

local function paste_next_line(number)
	if #killed_lines < 1 then
		return
	end

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local saved_y
	local text = "\n" .. table.concat(killed_lines, "\n")
	for _ = 1, number do
		saved_y = cursor.Loc.Y
		local line = cursor:Buf():Line(cursor.Loc.Y)
		cursor.Loc.X = utf8.RuneCount(line)
		cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), text)
		cursor.Loc.Y = saved_y + 1
	end

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(tick_delay, function()
			cursor.Loc.Y = saved_y + 1

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			vi_mode = CommandMode
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(tick_delay, function()
			cursor.Loc.Y = saved_y + 1

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			vi_mode = CommandMode
		end)
	end
end

local function paste_prev_line(number)
	if #killed_lines < 1 then
		return
	end

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local saved_y
	local text = table.concat(killed_lines, "\n") .. "\n"
	for _ = 1, number do
		saved_y = cursor.Loc.Y
		cursor.Loc.X = 0
		cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), text)
		cursor.Loc.Y = saved_y
	end

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(tick_delay, function()
			cursor.Loc.Y = saved_y

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			vi_mode = CommandMode
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(tick_delay, function()
			cursor.Loc.Y = saved_y

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			vi_mode = CommandMode
		end)
	end
end

local function quit()
	micro.CurPane():QuitCmd({})
end

function onBeforeTextEvent(buf, ev)
	if vi_mode == InsertMode then
		return true
	end

	if ev.EventType == TextEventRemove or ev.EventType == TextEventReplace then
		return true
	end

	-- assert
	if ev.EventType ~= TextEventInsert then -- program error
		micro.InfoBar():Error("Invalid text event type = ev.EventType")
		return true
	end

	if #ev.Deltas ~= 1 then
		return true
	end

	-- pass through pasted long text
	if #ev.Deltas[1].Text ~= 1 then
		return true
	end

	-- Text is byte array
	local text = bytes_to_string(ev.Deltas[1].Text)

	local delta = ev.Deltas[1]
	delta.Text = ""
	delta.Start.X = 0
	delta.Start.Y = 0
	delta.End.X = 0
	delta.End.Y = 0

	command_buffer = command_buffer .. text

	local number_str, edit, move
	if command_buffer:match("^0$") then
		number_str, edit, move = "", "", "0"
	else
		number_str, edit, move = command_buffer:match("^(%d*)([iIaAoOdypPZ]*)([hjkl\n0%$wbG]*)$")
	end

	if not number_str then
		micro.InfoBar():Error("not (yet) a vi command [" .. command_buffer .. "]")
		command_buffer = ""
		return true
	end

	local no_number = false
	local number = 1
	if #number_str < 1 then
		no_number = true
	else
		number = tonumber(number_str)
	end

	if edit == "i" then
		vi_mode = InsertMode
		show_mode()
		command_buffer = ""
		insert_here()

		command_number = number
		command_edit = edit
		return true
	elseif edit == "I" then
		vi_mode = InsertMode
		show_mode()
		command_buffer = ""
		insert_at_line_start()

		command_number = number
		command_edit = edit
		return true
	elseif edit == "a" then
		vi_mode = InsertMode
		show_mode()
		command_buffer = ""
		insert_after_here()

		command_number = number
		command_edit = edit
		return true
	elseif edit == "A" then
		vi_mode = InsertMode
		show_mode()
		command_buffer = ""
		insert_after_line_end()

		command_number = number
		command_edit = edit
		return true
	elseif edit == "o" then
		vi_mode = InsertMode
		show_mode()
		command_buffer = ""
		open_next_line()

		command_number = number
		command_edit = edit
		return true
	elseif edit == "O" then
		vi_mode = InsertMode
		show_mode()
		command_buffer = ""
		open_prev_line()

		command_number = number
		command_edit = edit
		return true
	elseif edit == "dd" then
		show_mode()
		command_buffer = ""
		delete_line(number)

		command_number = number
		command_edit = edit
		return true
	elseif edit == "yy" then
		show_mode()
		command_buffer = ""
		yank_line(number)

		command_number = number
		command_edit = edit
		return true
	elseif edit == "p" then
		show_mode()
		command_buffer = ""
		vi_mode = InsertMode
		paste_next_line(number)

		command_number = number
		command_edit = edit
		return true
	elseif edit == "P" then
		show_mode()
		command_buffer = ""
		vi_mode = InsertMode
		paste_prev_line(number)

		command_number = number
		command_edit = edit
		return true
	elseif move == "h" then
		show_mode()
		command_buffer = ""
		move_left(number)
		return true
	elseif move == "j" then
		show_mode()
		command_buffer = ""
		move_down(number)
		return true
	elseif move == "k" then
		show_mode()
		command_buffer = ""
		move_up(number)
		return true
	elseif move == "l" then
		show_mode()
		command_buffer = ""
		move_right(number)
		return true
	elseif move == "\n" then
		show_mode()
		command_buffer = ""
		move_next_line_start(number)
		return true
	elseif move == "0" then
		show_mode()
		command_buffer = ""
		move_line_start()
		return true
	elseif move == "$" then
		show_mode()
		command_buffer = ""
		move_line_end()
		return true
	elseif move == "w" then
		show_mode()
		command_buffer = ""
		move_next_word(number)
		return true
	elseif move == "b" then
		show_mode()
		command_buffer = ""
		move_prev_word(number)
		return true
	elseif move == "G" then
		show_mode()
		command_buffer = ""
		if no_number then
			move_bottom_line()
		else
			move_line(number)
		end
		return true
	elseif edit == "ZZ" then
		show_mode()
		command_buffer = ""
		quit()
		return true
	end

	show_mode()
	return true
end

function init()
	config.MakeCommand("vi", Vi, config.NoComplete)
	config.MakeCommand("vienter", ViEnter, config.NoComplete)
	config.TryBindKey("Escape", "Escape,Deselect,ClearInfo,RemoveAllMultiCursors,UnhighlightSearch,lua:vi.Vi", false)
	config.TryBindKey("Enter", "lua:vi.ViEnter|InsertNewline", false)
	config.AddRuntimeFile("vi", config.RTHelp, "help/vi.md")
end
