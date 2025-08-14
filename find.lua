local M = {}

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local bell = require("bell")

-- key: f<letter>
local function forward(num, letter)
	bell.planned("f<letter> (find.forward)")
end

-- key: F<letter>
local function backward(num, letter)
	bell.planned("F<letter> (find.backward)")
end

-- key: t<letter>
local function before_forward(num, letter)
	bell.planned("t<letter> (find.before_forward)")
end

-- key: T<letter>
local function before_backward(num, letter)
	bell.planned("T<letter> (find.before_backward)")
end

-- key: ;
local function next_match(num)
	bell.planned(";<letter> (find.next_match)")
end

-- key: ,
local function prev_match(num)
	bell.planned(",<letter> (find.prev_match)")
end

--
M.forward = forward
M.backward = backward
M.before_forward = before_forward
M.before_backward = before_backward
M.next_match = next_match
M.prev_match = prev_match

return M
