M = {}

local micro = import("micro")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/vi/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local editor = require("editor")

-- vi modes
local MODE_COMMAND = 0
local MODE_INSERT = 1

-- states
local mode = MODE_INSERT

local function command()
	mode = MODE_COMMAND
end

local function insert()
	mode = MODE_INSERT
end

local function code()
	return mode
end

local function is_command()
	return mode == MODE_COMMAND
end

local function is_insert()
	return mode == MODE_INSERT
end

local function show()
	local mode_line
	if mode == MODE_COMMAND then
		mode_line = "vi command mode"
	elseif mode == MODE_INSERT then
		mode_line = "vi insert mode"
	else -- program error
		micro.InfoBar():Error("mode.show: invalid mode = " .. mode)
		return
	end
	micro.InfoBar():Message(mode_line .. " [" .. editor.command_buffer() .. "]")
end

M.command = command
M.insert = insert
M.code = code
M.is_command = is_command
M.is_insert = is_insert
M.show = show

return M
