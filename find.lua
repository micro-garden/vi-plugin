-- Character Finding Commands

local micro = import("micro")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local utils = require("vi/utils")
local bell = require("vi/bell")
local move = require("vi/move")

local mv_cache = nil
local letter_cache = nil

local function forward_one(line, index, letter)
	local _, size = utf8.DecodeRuneInString(line:sub(index))
	return line:find(letter, index + size, true)
end

local function forward_internal(num, letter)
	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)

	local index = utils.utf8_index(line, cursor.X)
	for _ = 1, num do
		index = forward_one(line, index, letter)
		if not index then
			bell.ring("cannot find letter " .. letter)
			return
		end
	end

	cursor.X = utf8.RuneCount(line:sub(1, index - 1))
end

-- f<letter> : Find character <letter> forward in current line.
local function forward(num, letter)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end
	if utf8.RuneCount(letter) ~= 1 then
		bell.program_error("1 ~= utif8.len(letter) == " .. #letter)
		return
	end

	mv_cache = "f"
	letter_cache = letter

	forward_internal(num, letter)

	move.update_virtual_cursor()
end

local function backward_one(line, index, letter)
	local offset = line:sub(1, index - 1):reverse():find(letter:reverse(), 1, true)
	if not offset then
		return nil
	end
	return index - offset - (#letter - 1)
end

local function backward_internal(num, letter)
	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)

	local index = utils.utf8_index(line, cursor.X)
	for _ = 1, num do
		index = backward_one(line, index, letter)
		if not index then
			bell.ring("cannot find letter " .. letter)
			return
		end
		index = index
	end

	cursor.X = utf8.RuneCount(line:sub(1, index - 1))
end

-- F<letter> : Find character <letter> backward in current line.
local function backward(num, letter)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end
	if utf8.RuneCount(letter) ~= 1 then
		bell.program_error("1 ~= utif8.len(letter) == " .. #letter)
		return
	end

	mv_cache = "F"
	letter_cache = letter

	backward_internal(num, letter)

	move.update_virtual_cursor()
end

local function before_forward_internal(num, letter)
	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)

	local index = utils.utf8_index(line, cursor.X)
	for _ = 1, num do
		index = forward_one(line, index, letter)
		if not index then
			bell.ring("cannot find letter " .. letter)
			return
		end
	end

	cursor.X = utf8.RuneCount(line:sub(1, index - 1)) - 1
end

-- t<letter> : Find before character <letter> forward in current line.
local function before_forward(num, letter)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end
	if #letter ~= 1 then
		bell.program_error("1 ~= #letter == " .. #letter)
		return
	end

	mv_cache = "t"
	letter_cache = letter

	before_forward_internal(num, letter)

	move.update_virtual_cursor()
end

local function before_backward_internal(num, letter)
	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)

	local index = utils.utf8_index(line, cursor.X)
	for _ = 1, num do
		index = backward_one(line, index, letter)
		if not index then
			bell.ring("cannot find letter " .. letter)
			return
		end
		index = index
	end

	cursor.X = utf8.RuneCount(line:sub(1, index - 1)) + 1
end

-- T<letter> : Find before character <letter> backward in current line.
local function before_backward(num, letter)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end
	if #letter ~= 1 then
		bell.program_error("1 ~= #letter == " .. #letter)
		return
	end

	mv_cache = "T"
	letter_cache = letter

	before_backward_internal(num, letter)

	move.update_virtual_cursor()
end

-- ; : Find next match.
local function next_match(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	if not mv_cache then
		bell.ring("find not yet run")
		return
	end

	if mv_cache == "f" then
		forward_internal(num, letter_cache)
	elseif mv_cache == "F" then
		backward_internal(num, letter_cache)
	elseif mv_cache == "t" then
		before_forward_internal(num, letter_cache)
	elseif mv_cache == "T" then
		before_backward_internal(num, letter_cache)
	else
		bell.program_error("invalid mv_cache == " .. mv_cache)
		return
	end

	move.update_virtual_cursor()
end

-- , : Find previous match.
local function prev_match(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	if not mv_cache then
		bell.ring("find not yet run")
		return
	end

	if mv_cache == "f" then
		backward_internal(num, letter_cache)
	elseif mv_cache == "F" then
		forward_internal(num, letter_cache)
	elseif mv_cache == "t" then
		before_backward_internal(num, letter_cache)
	elseif mv_cache == "T" then
		before_forward_internal(num, letter_cache)
	else
		bell.program_error("invalid mv_cache == " .. mv_cache)
		return
	end
end

-------------
-- Exports --
-------------

local M = {}

M.forward = forward
M.backward = backward
M.before_forward = before_forward
M.before_backward = before_backward
M.next_match = next_match
M.prev_match = prev_match

return M
