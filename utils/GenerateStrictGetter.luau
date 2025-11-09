local fs = require("@lune/fs")
local net = require("@lune/net")
local serde = require("@lune/serde")

local response = net.request("https://tss-dev.ru/api-dump")
local data = serde.decode("json", response.body)
local newSource = [[
--[=[
    Copyright Accoast x fl0mDeveloper DEVELOPER SPECIALLY FOR TOPCAT GAMES
	updated by qaltx: added ParticleEmitter, VectorForce, LinearVelocity, TextLabel, CanvasGroup,
		PlayerGui, ScreenGui, Model, Part, MeshPart
]=]

--!strict

local StrictGetter = {
    
]]

for i, v in next, data.Classes do
    local name = v.Name

    newSource ..= name .. [[ = function(input: Instance?): ]] .. name..[[?
		if input and input:IsA("]]..name..[[") then
			return input
		end
		
		return nil
	end,

    ]]
end

newSource ..= "\n}"

fs.writeFile(`bebra.luau`, newSource)
