M = {}

local micro = import("micro")
local time = import("time")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
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
		micro.InfoBar():Error("Cannot find After API")
	end
end

M.xor = xor
M.after = after

return M
