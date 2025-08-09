M = {}

local micro = import("micro")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/vi/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local editor = require("editor")
local mode = require("mode")
local command = require("command")

-- internal constants
local TEXT_EVENT_INSERT = 1
local TEXT_EVENT_REPLACE = 0
local TEXT_EVENT_REMOVE = -1

local function bytes_to_string(array)
	local buf = {}
	for i = 1, #array do
		table.insert(buf, string.char(array[i]))
	end
	return table.concat(buf)
end

function onBeforeTextEvent(buf, ev)
	if mode.is_insert() or mode.is_find() then
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

	local command_buffer = editor.add_input_to_command_buffer(input)

	local number_str, edit, subnum_str, move =
		command_buffer:match("^(%d*)([iIaAoOdyYxXDspP%.uUZ]*)(%d*)([hjkl\n0%$wbG/?nN]*)$")

	if not number_str then
		micro.InfoBar():Error("not (yet) a vi command [" .. command_buffer .. "]")
		editor.clear_command_buffer()
		return true
	end

	local no_number = false
	local number = 1
	if #number_str < 1 then
		no_number = true
	elseif number_str == "0" then
		number_str, move = "", "0"
	else
		number = tonumber(number_str)
	end

	local no_subnum = false
	local subnum = 1
	if #subnum_str < 1 then
		no_subnum = true
	elseif subnum_str == "0" then
		subnum_str, move = "", "0"
	else
		subnum = tonumber(subnum_str)
	end

	if command.run(no_number, number, edit, no_subnum, subnum, move) then
		editor.clear_command_buffer()
		return true
	end

	mode.show()
	return true
end

return M
