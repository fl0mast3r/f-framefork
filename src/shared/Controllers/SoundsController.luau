--!strict

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local net = require(ReplicatedStorage.Shared.net)

local SoundsController = {
    _sfxes = {} :: {[string]: Sound},
}

function SoundsController.Start(self: Controller)
    task.defer(function()
        self:_preloadSounds()
    end)

    net.Sounds.CallSound.On(function(name: string, part: BasePart?)  
        return self:Play(name, part)
    end)
end

function SoundsController.PlayGlobal(self: Controller, name: string, instance: BasePart?)
    if not self._sfxes[name] then
        return
    end

    self:Play(name, instance)

    return net.Sounds.CallSoundFromClient.Fire(name, instance)
end

function SoundsController.Play(self: Controller, name: string, instance: BasePart?): ()
    if not self._sfxes[name] then
        return
    end

    local this = self._sfxes[name]:Clone()
    this.Parent = instance or self._sfxes[name].Parent
    
    this:Destroy()
end

function SoundsController._preloadSounds(self: Controller)
    local folder: SoundGroup = SoundService:WaitForChild("SFX") :: SoundGroup
    repeat
        task.wait()
    until #folder:GetChildren() > 0

    local preloadArray: {Sound} = {}
    for _, sound: Instance in next, folder:GetDescendants() do
        if not sound:IsA("Sound") then
            continue
        end

        sound.PlayOnRemove = true

        self._sfxes[sound.Name] = sound
        table.insert(preloadArray, sound)
    end

    ContentProvider:PreloadAsync(preloadArray)
end

export type Controller = typeof(SoundsController)
return SoundsController