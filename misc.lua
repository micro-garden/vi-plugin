M = {}

local micro = import("micro")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local mode = require("mode")

local function quit()
	mode.show()

	micro.CurPane():QuitCmd({})
end

M.quit = quit

return M
