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

-- vi modes
local MODE_COMMAND = 0
local MODE_INSERT = 1
local MODE_FIND = 2
local MODE_PROMPT = 3

-- states
local mode = MODE_INSERT

local function command()
	if mode == MODE_FIND then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		if cursor:HasSelection() then
			local start = cursor.CurSelection[1]
			cursor.X = start.X
			cursor.Y = start.Y
			cursor:ResetSelection()
		end
	end

	mode = MODE_COMMAND
end

local function insert()
	mode = MODE_INSERT
end

local function find()
	mode = MODE_FIND
end

local function prompt()
	mode = MODE_PROMPT
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

local function is_find()
	return mode == MODE_FIND
end

local function is_prompt()
	return mode == MODE_PROMPT
end

local function show()
	local mode_line
	if mode == MODE_COMMAND then
		mode_line = "vi command mode"
	elseif mode == MODE_INSERT then
		mode_line = "vi insert mode"
	else
		bell.fatal("mode.show: invalid mode = " .. mode)
		return
	end
	bell.info(mode_line .. " [" .. combuf.get() .. "]")
end

M.command = command
M.insert = insert
M.find = find
M.prompt = prompt
M.code = code
M.is_command = is_command
M.is_insert = is_insert
M.is_find = is_find
M.is_prompt = is_prompt
M.show = show

return M
