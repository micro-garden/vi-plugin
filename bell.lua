local micro = import("micro")
local time = import("time")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local utils = require("vi/utils")

local PROGRAM_ERROR_HEAD = "** vi program error **\n"
local NOT_PLANNED_HEAD = "Not planned to implement"
local PLANNED_HEAD = "Not implemented yet, but planned"
local BELL_HEAD = " * RING! * "
local BELL_DURATION = time.ParseDuration("1s")

local function where(level)
	level = (level or 3)
	local info = debug and debug.getinfo(level, "nSl")
	if not info then
		return ""
	end
	return string.format("[%s:%d in %s]", info.source or "?", info.currentline or -1, info.name or "?")
end

local function program_error(message)
	micro.TermMessage(PROGRAM_ERROR_HEAD .. where(3) .. "\n" .. message)
end

local function not_planned(message)
	if message then
		micro.InfoBar():Error(NOT_PLANNED_HEAD .. ": " .. message)
	else
		micro.InfoBar():Error(NOT_PLANNED_HEAD)
	end
end

local function planned(message)
	if message then
		micro.InfoBar():Error(PLANNED_HEAD .. ": " .. message)
	else
		micro.InfoBar():Error(PLANNED_HEAD)
	end
end

local function general_error(message)
	micro.InfoBar():Error(message)
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

-------------
-- Exports --
-------------

local M = {}

M.program_error = program_error
M.not_planned = not_planned
M.planned = planned
M.error = general_error
M.info = show_message
M.vi_error = general_error
M.vi_info = show_message
M.ring = ring

return M
