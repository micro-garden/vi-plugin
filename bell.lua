local M = {}

local micro = import("micro")
local time = import("time")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local utils = require("utils")

local FATAL_HEAD = "** vi fatal error **\n"
local BELL_HEAD = " * RING! * "
local BELL_DURATION = time.ParseDuration("1s")

local function general_error(message)
	micro.InfoBar():Error(message)
end

local function fatal(message)
	micro.TermMessage(FATAL_HEAD .. message)
end

local function show_message(message)
	micro.InfoBar():Message(message)
end

local function ring(reason)
	if reason then
		micro.InfoBar():Error(BELL_HEAD .. "(" .. reason .. ")")
	else
		micro.InfoBar():Error(BELL_HEAD)
	end

	utils.after(BELL_DURATION, function()
		micro.InfoBar():Message("")
	end)
end

M.fatal = fatal
M.error = general_error
M.info = show_message
M.vi_info = show_message
M.ring = ring
return M
