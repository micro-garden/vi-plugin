-- Character Finding Commands

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local bell = require("vi/bell")

-- f<letter> : Find character <letter> forward in current line.
local function forward(num, letter)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end
	if #letter ~= 1 then
		bell.program_error("1 ~= #letter == " .. #letter)
		return
	end

	bell.planned("f<letter> (find.forward)")
end

-- F<letter> : Find character <letter> backward in current line.
local function backward(num, letter)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end
	if #letter ~= 1 then
		bell.program_error("1 ~= #letter == " .. #letter)
		return
	end

	bell.planned("F<letter> (find.backward)")
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

	bell.planned("t<letter> (find.before_forward)")
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

	bell.planned("T<letter> (find.before_backward)")
end

-- ; : Find next match.
local function next_match(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	bell.planned(";<letter> (find.next_match)")
end

-- , : Find previous match.
local function prev_match(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	bell.planned(",<letter> (find.prev_match)")
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
