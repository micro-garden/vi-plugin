local M = {}

local micro = import("micro")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local bell = require("bell")
local combuf = require("combuf")
local mode = require("mode")
local command = require("command")
local prompt = require("prompt")

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
	if ev.EventType ~= TEXT_EVENT_INSERT then
		bell.fatal("onBeforeTextEvent: invalid text event type = " .. ev.EventType)
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

	if mode.is_prompt() then
		if input == "\n" then
			prompt.enter()
		else
			prompt.insert_chars(input)
		end
		return true
	end

	combuf.insert_chars(input)
	local comb = combuf.get()

	local number_str, edit, subnum_str, move, _ =
		comb:match("^(%d*)([:iIaAoOdyYxXDsScCpPJ><m%.uZ]*)(%d*)([hjkl\n0%$wbG'`/?nN]*)(.-)$")

	local mark_command, letter = comb:match("([m'`])([^'`])$")
	if mark_command == "m" then
		edit = mark_command
	elseif mark_command == "'" or mark_command == "`" then
		move = mark_command
	end

	if not number_str then
		bell.error("not (yet) a vi command [" .. comb .. "]")
		combuf.clear()
		return true
	end

	local no_number = false
	local number = 1
	if #number_str < 1 then
		no_number = true
	elseif number_str == "0" then
		move = "0"
	else
		number = tonumber(number_str)
	end

	local no_subnum = false
	local subnum = 1
	if #subnum_str < 1 then
		no_subnum = true
	elseif subnum_str == "0" then
		move = "0"
	else
		subnum = tonumber(subnum_str)
	end

	if command.run(no_number, number, edit, no_subnum, subnum, move, letter, false) then
		combuf.clear()
		return true
	end

	mode.show()
	return true
end

return M
