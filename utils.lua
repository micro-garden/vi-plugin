local M = {}

local micro = import("micro")
local utf8 = import("unicode/utf8")
local time = import("time")

local TICK_DURATION = time.ParseDuration("0ms")

local function toboolean(str)
	if str == "true" then
		return true
	elseif str == "false" then
		return false
	else
		return nil
	end
end

local function xor(a, b)
	return (a or b) and not (a and b)
end

local function after(duration, fn)
	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(duration, fn)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(duration, fn)
	else
		micro.TermMessage("** vi environment error **\nCannot find After API")
	end
end

local function next_tick(fn)
	after(TICK_DURATION, fn)
end

local function last_line_index(buf)
	if not buf then
		buf = micro.CurPane().Buf
	end

	local index = buf:LinesNum() - 1
	local last_line = buf:Line(index)
	local last_line_length = utf8.RuneCount(last_line)
	if last_line_length < 1 then
		index = math.max(index - 1, 0)
	end

	return index
end

local function utf8_sub(line, from, to)
	if not to then
		to = utf8.RuneCount(line)
	end

	local str = line
	local start_offset = 0
	for _ = 1, from - 1 do
		local _, size = utf8.DecodeRuneInString(str)
		str = str:sub(1 + size)
		start_offset = start_offset + size
	end

	local end_offset = start_offset
	for _ = 1, to - from + 1 do
		local _, size = utf8.DecodeRuneInString(str)
		str = str:sub(1 + size)
		end_offset = end_offset + size
	end

	return line:sub(1 + start_offset, end_offset)
end

M.toboolean = toboolean
M.xor = xor
M.after = after
M.next_tick = next_tick
M.last_line_index = last_line_index
M.utf8_sub = utf8_sub

return M
