local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Controllers = ReplicatedStorage.Shared.Controllers
local ControllersStorage = require(Controllers)

local Promise = require(ReplicatedStorage.Packages.Promise)

--First, the code waits for all controllers to finish initializing.
--Then, as soon as all modules are initialized, the "Start" method is invoked for each of them.
--This ensures that if one controller interacts with another,
--both will be fully loaded, preventing any errors from occurring.

Promise.try(function()
    while task.wait() do
        if #Controllers:GetChildren() > 0 then
            break
        end
    end

    for _, controllerInstance: ModuleScript in Controllers:GetChildren() do
        local controller: any = require(controllerInstance)
        if controller.Init then
            controller:Init()
        end

        ControllersStorage.__controllers[controllerInstance.Name] = controller
    end
end):andThen(function()
    -- :: Right after the initiation we add these controllers into the Controllers main module to store them there
end):andThen(function()
    for _, controller: any in ControllersStorage.__controllers do
        if controller.Start then
            task.spawn(controller.Start, controller)
        end
    end
end):andThen(function()
    if RunService:IsStudio() then
        print("All controllers successfully initiated")
    end
end):catch(warn)