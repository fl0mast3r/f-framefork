--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local net = require(ServerScriptService.Server.net)

local SoundsService = {
    
}

function SoundsService.Start(self: Service)
    net.Sounds.CallSoundFromClient.On(function(player: Player, name: string, instance: BasePart?)  
        return self:Play(name, instance, player)
    end)
end

function SoundsService.Play(self: Service, name: string, instance: BasePart?, except: Player?)
    if except then
        return net.Sounds.CallSound.FireExcept(except, name, instance)
    end

    return net.Sounds.CallSound.FireAll(name, instance)
end

export type Service = typeof(SoundsService)
return SoundsService