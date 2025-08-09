VERSION = "0.0.6"

local micro = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")
local utf8 = import("unicode/utf8")

local plug_path = config.ConfigDir .. "/plug/vi/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local editor = require("editor")
local mode = require("mode")
local motion = require("motion")
local insert = require("insert")
local parse = require("parse")

function Vi(bp)
	-- reset states
	editor.clear_command_buffer()

	-- ensure command mode
	if mode.is_command() then -- vi error
		return true
	elseif mode.is_find() then
		mode.command()
		return true
	end
	mode.command()

	--
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local orig_loc = buffer.Loc(cursor.Loc.X, cursor.Loc.Y)

	-- ensure cursor y in text
	local last_line_index = cursor:Buf():LinesNum() - 1
	if cursor.Loc.Y == last_line_index then
		local line = cursor:Buf():Line(cursor.Loc.Y)
		local length = utf8.RuneCount(line)
		if length < 1 then
			cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
			micro.CurPane():Relocate()
		end
	end

	-- ensure cursor x in text
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(math.max(cursor.Loc.X - 1, 0), math.max(length - 1, 0))
	micro.CurPane():Relocate()

	--
	motion.update_virtual_cursor()
	mode.show()

	insert.resume(orig_loc)
	return true
end

function ViEnter(bp)
	if mode.is_command() then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), "\n")
		return true
	elseif mode.is_insert() then
		return false
	elseif mode.is_find() then
		mode.command()
		return true
	else -- program error
		micro.InfoBar():Error("ViEnter: invalid mode = " .. mode.code())
		return false
	end
end

function ViDefault(bp, args)
	local default
	if #args < 1 then
		default = not config.GetGlobalOption("vi.default")
	elseif #args < 2 then
		if args[1] ~= "true" and args[1] ~= "false" then
			micro.InfoBuf():Message("usage: videfault [true|false]")
			return
		end
		default = args[1]
	else
		micro.InfoBuf():Message("usage: videfault [true|false]")
		return
	end
	config.SetGlobalOption("vi.default", tostring(default))
	micro.InfoBar():Message("set vi.default " .. tostring(default))
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
end

function postinit()
	if config.GetGlobalOption("vi.default") then
		Vi()
	end
end
