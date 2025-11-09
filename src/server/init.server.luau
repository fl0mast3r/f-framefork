local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Services = ServerScriptService.Server.Services
local ServicesStorage = require(Services)

local Promise = require(ReplicatedStorage.Packages.Promise)


--First, the code waits for all services to finish initializing.
--Then, as soon as all modules are initialized, the "Start" method is invoked for each of them.
--This ensures that if one service interacts with another,
--both will be fully loaded, preventing any errors from occurring.

Promise.try(function()
    while task.wait() do
        if #Services:GetChildren() > 0 then
            break
        end
    end

    for _, serviceInstance: ModuleScript in Services:GetChildren() do
        local service: any = require(serviceInstance)
        if service.Init then
            service:Init()
        end

        ServicesStorage.__services[serviceInstance.Name] = service
    end
end):andThen(function()
    -- :: Right after the initiation we add these Services into the Services main module to store them there
end):andThen(function()
    for _, service: any in ServicesStorage.__services do
        if service.Start then
            task.spawn(service.Start, service)
        end
    end
end):andThen(function()
    if RunService:IsStudio() then
        print("All Services successfully initiated")
    end
end):catch(warn)