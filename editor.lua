M = {}

local time = import("time")

-- settings
M.TICK_DELAY = time.ParseDuration("100ms")

local command_buffer = ""

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

M.command_buffer = get_command_buffer
M.add_input_to_command_buffer = add_input_to_command_buffer
M.clear_command_buffer = clear_command_buffer

return M
