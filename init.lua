VERSION = "0.0.12"

local micro = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")
local utf8 = import("unicode/utf8")

local plug_path = config.ConfigDir .. "/plug/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local utils = require("vi/utils")
local bell = require("vi/bell")
local mode = require("vi/mode")
local combuf = require("vi/combuf")
local prompt = require("vi/prompt")
local move = require("vi/move")
local insert = require("vi/insert")

function Vi(_)
	-- reset states
	combuf.clear()

	-- ensure command mode
	if mode.is_command() then
		bell.ring("already in vi command mode")
		return true
	elseif mode.is_search() then
		mode.command()
		return true
	elseif mode.is_prompt() then
		prompt.escape()
		return true
	end
	mode.command()

	--
	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local orig_loc = buffer.Loc(cursor.X, cursor.Y)

	-- ensure cursor y in text
	local last_line_index = utils.last_line_index(buf)
	cursor.Y = math.min(cursor.Y, last_line_index)

	-- ensure cursor x in text
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.min(math.max(cursor.X - 1, 0), math.max(length - 1, 0))
	pane:Relocate()

	--
	move.update_virtual_cursor()
	mode.show()

	--
	insert.resume(orig_loc)
	return true
end

function ViEnter(_)
	if mode.is_command() then
		local buf = micro.CurPane().Buf
		local cursor = buf:GetActiveCursor()
		local loc = buffer.Loc(cursor.X, cursor.Y)
		buf:Insert(loc, "\n")
		return true
	elseif mode.is_insert() then
		return false
	elseif mode.is_search() then
		mode.command()
		return true
	elseif mode.is_prompt() then
		prompt.enter()
		return true
	else
		bell.program_error("invalid mode == " .. mode.code())
		return false
	end
end

function ViDefault(_, args)
	local USAGE = "usage: videfault [true|false]"
	local default
	if #args < 1 then
		default = not config.GetGlobalOption("vi.default")
	elseif #args < 2 then
		if utils.toboolean(args[1]) == nil then
			bell.info(USAGE)
			return
		end
		default = args[1]
	else
		bell.info(USAGE)
		return
	end
	config.SetGlobalOption("vi.default", tostring(default))
	bell.info("vi.default is now " .. tostring(default))
end

function preinit()
	config.RegisterCommonOption("vi", "default", false)
end

function init()
	config.MakeCommand("vi", Vi, config.NoComplete)
	config.MakeCommand("vienter", ViEnter, config.NoComplete)
	config.MakeCommand("videfault", ViDefault, config.NoComplete)
	config.TryBindKey("Escape", "Escape,Deselect,ClearInfo,RemoveAllMultiCursors,UnhighlightSearch,lua:vi.Vi", false)
	config.TryBindKey("Enter", "lua:vi.ViEnter|InsertNewline", false)
	config.AddRuntimeFile("vi", config.RTHelp, "help/vi.md")
	config.AddRuntimeFile("vi", config.RTHelp, "help/vicommands.md")
end

function postinit()
	if config.GetGlobalOption("vi.default") then
		Vi()
	end
end
