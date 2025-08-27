-- Miscellaneous Commands

local micro = import("micro")
local buffer = import("micro/buffer")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local utils = require("vi/utils")
local bell = require("vi/bell")
local mode = require("vi/mode")
local snapshot = require("vi/snapshot")
local move = require("vi/move")

-- Ctrl-g : Show info such as current cursor position.
local function show_info()
	bell.not_planned("Ctrl-g (misc.show_info)")
end

-- . : Repeat last edit.
-- repeat is implemented in command.lua

-- u : Undo.
-- undo is implemented in command.lua

-- U : Restore current line to previous state.
local function restore()
	mode.show()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local cache = snapshot.cache()
	if cursor.Y ~= cache.y then
		return
	end

	if cursor.Y < 1 then
		pane:DeleteLine()
		cursor.Y = math.max(cursor.Y - 1, 0)
	elseif cursor.Y >= utils.last_line_index() then
		pane:DeleteLine()
		buf:Insert(buffer.Loc(cursor.X, cursor.Y), "\n")
	else
		pane:DeleteLine()
		cursor.Y = math.max(cursor.Y - 1, 0)
		buf:Insert(buffer.Loc(cursor.X, cursor.Y), "\n")
	end
	buf:Insert(buffer.Loc(0, cursor.Y), cache.line .. "\n")
	cursor.Y = math.max(cursor.Y - 1, 0)

	cursor.X = 0
	move.update_virtual_cursor()
end

-- ZZ : Save and quit.
local function save_and_quit()
	mode.show()

	micro.CurPane():QuitCmd({})
end

-------------
-- Exports --
-------------

local M = {}

M.show_info = show_info
--M.repeat = repeat
--M.undo = undo
M.restore = restore
M.save_and_quit = save_and_quit

return M
