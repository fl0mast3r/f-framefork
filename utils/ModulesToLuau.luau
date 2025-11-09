local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local placeFile = fs.readFile("game.rbxl")
local game = roblox.deserializePlace(placeFile)

local PATH = game.ReplicatedStorage.Packages.RagdollService
local STARTING_PATH = ``

local function recursiveBuildCode(instance, route: string)
    if #instance:GetChildren() > 0 then
        route = `{route}{instance.Name}/`
        fs.writeDir(route)
        if instance:IsA("ModuleScript") then
            fs.writeFile(`{route}init.luau`, instance.Source)
        end

        for _, instance in instance:GetChildren() do
            recursiveBuildCode(instance, route)
        end

        return
    end

    if not instance:IsA("ModuleScript") then
        return
    end

    fs.writeFile(`{route}{instance.Name}.luau`, instance.Source)
end
 
recursiveBuildCode(PATH, STARTING_PATH)