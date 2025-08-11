M = {}

local micro = import("micro")
local time = import("time")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local utils = require("utils")

-- settings
TICK_DURATION = time.ParseDuration("100ms")
BELL_DURATION = time.ParseDuration("1s")

local command_buffer = ""

local function general_error(message)
	micro.InfoBar():Error(message)
end

local function program_error(message)
	micro.TermMessage("** vi program error **\n" .. message)
end

local function vi_error(message)
	micro.InfoBar():Message(message)
end

local function bell(reason)
	local head = " * RING! * "
	if reason then
		micro.InfoBar():Error(head .. "(" .. reason .. ")")
	else
		micro.InfoBar():Error(head)
	end

	utils.after(BELL_DURATION, function()
		micro.InfoBar():Message("")
	end)
end

local function get_command_buffer()
	return command_buffer
end

local function add_input_to_command_buffer(input)
	command_buffer = command_buffer .. input
	return command_buffer
end

local function clear_command_buffer()
	command_buffer = ""
end

M.TICK_DURATION = TICK_DURATION

M.error = general_error
M.vi_error = vi_error
M.bell = bell

M.command_buffer = get_command_buffer
M.add_input_to_command_buffer = add_input_to_command_buffer
M.clear_command_buffer = clear_command_buffer

return M
