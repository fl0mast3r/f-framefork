--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Observers = require(ReplicatedStorage.Packages.Observers)
local StrictGetter = require(ReplicatedStorage.Packages.StrictGetter)
local Promise = require(ReplicatedStorage.Packages.TypedPromise)
local Animations = require(ReplicatedStorage.Shared.Configs.Animations)

--[=[
    @class AnimationsController

    Controls all the animations
]=]
local AnimationsController = {
    _player = Players.LocalPlayer :: Player,
    _character = nil :: Model?,

    _lastPercent = 30,
    _animationInstances = {},
    _savedSpeeds = {} :: {[Instance]: {[string]: {[string]: number}}},
    _tracks = {} :: {[Instance]: {[string]: {[string]: AnimationTrack}}},
    _playingTracks = {} :: {[Instance]: {[string]: {[string]: Promise.TypedPromise<AnimationTrack?>}}},
}

function AnimationsController.Init(self: Controller)
    self:_createAnimationInstances()
end

function AnimationsController.Start(self: Controller)
    Observers.observeCharacter(function(player: Player, character: Model): (() -> ())?  
        if player.UserId ~= self._player.UserId then
            return
        end

        self._character = character

        local humanoid: Instance = character:WaitForChild("Humanoid")
        local animator: Animator? = StrictGetter.Animator(humanoid:WaitForChild("Animator"))
        if not animator then
            return
        end

        for _, track: AnimationTrack in next, animator:GetPlayingAnimationTracks() do
            track:Stop(0)
        end

        self:PreloadAnimationsForInstance(character, animator, "Character")

        return function()
            self._tracks = {}
        end
    end)

    Observers.observeTag("Ragdoll", function(humanoid: Instance): (() -> ())? 
        if not humanoid:IsA("Humanoid") then
            return
        end

        local character: Instance? = humanoid.Parent
        if not character then
            return
        end

        local player = Players:GetPlayerFromCharacter(character)
        if not player then
            return
        end

        if self._player.UserId ~= player.UserId then
            return
        end

        for categoryName: string, animationData: {[string]: AnimationTrack} in next, self._tracks[character] do
            for animationName: string, _ in next, animationData do
                self:Stop(character, categoryName, animationName, 0)
            end
        end

        return function()
            
        end
    end)
end

function AnimationsController.GetSpeed(self: Controller, instance: Instance, category: string, name: string): (number)
    local thisTrack: AnimationTrack? = self:Get(instance, category, name)
    if not thisTrack then
        return 0
    end

    return thisTrack.Speed
end

function AnimationsController.AdjustSpeed(self: Controller, instance: Instance, category: string, name: string, newSpeed: number?)
    local thisTrack: AnimationTrack? = self:Get(instance, category, name)
    if not thisTrack then
        return
    end

    thisTrack:AdjustSpeed(newSpeed or 1)
end

--[=[
    Method to get target animation track
]=]
function AnimationsController.Get(self: Controller, instance: Instance, category: string, name: string): (AnimationTrack?)
    if not self._tracks[instance] then
        return
    end

    if not self._tracks[instance][category] then
        return
    end

    return self._tracks[instance][category][name]
end

--[=[
    Method to adjust target animation track's weight
]=]
function AnimationsController.SetWeight(self: Controller, instance: Instance, category: string, name: string, value: number?, fadeTime: number?): ()
    local animationTrack: AnimationTrack? = self:Get(instance, category, name)
    if not animationTrack then
        return
    end

    if value == 0 then
        value = nil
    end

    animationTrack:AdjustWeight(value or 0.0001, fadeTime)
end

--[=[
    Method to play target animation

    @param returnIfPlaying boolean? -- If choosen animations is already playing, we're escaping from this method, avoiding new cycle of playing
]=]
function AnimationsController.Play(self: Controller, instance: Instance, category: string, name: string, fadeIn: number?, returnIfPlaying: boolean?, isAutoCleanupDisabled: boolean?): (Promise.TypedPromise<AnimationTrack?>?, AnimationTrack?)
    local animationTrack: AnimationTrack? = self:Get(instance, category, name)
    if not animationTrack then
        return warn(`Can't find animatiion track`)
    end

    if animationTrack.IsPlaying and returnIfPlaying then
        return
    end

    if animationTrack.Length <= 0 then
        return
    end

    if self._playingTracks[instance][category][name] then
        self._playingTracks[instance][category][name]:cancel()
    end

    self._playingTracks[instance][category][name] = Promise.new(function(resolve, _reject: (...any) -> (), onCancel: (abortHandler: (() -> ())?) -> boolean)     
        local awaitMultiplier: number = 1

        animationTrack:Play(fadeIn)

        onCancel(function()
            return resolve()
        end)

        if animationTrack.Looped then
            return
        end

        if isAutoCleanupDisabled == true then
            return
        end
        
        Promise.delay(animationTrack.Length * awaitMultiplier * 0.95):await()

        return resolve()
    end):finally(function(_status: "Cancelled" | "Rejected" | "Resolved" | "Started")
        animationTrack:Stop()
        self._playingTracks[instance][category][name] = nil
    end)

    return self._playingTracks[instance][category][name], animationTrack
end

--[=[
    Method to stop target animation
]=]
function AnimationsController.Stop(self: Controller, instance: Instance, category: string, name: string, fadeOut: number?)
    if not self._playingTracks[instance][category][name] then
        return
    end

    self._tracks[instance][category][name]:Stop(fadeOut)
    self._playingTracks[instance][category][name]:cancel()
end

--[=[
    Method to adjust the speed of an animation based on the player energy:)

    @deprecated new versions -- Don't use it, it doesn't work anyway :V
]=]
function AnimationsController.AdjustMovementSpeed(self: Controller, percent: number)
    self._lastPercent = percent
end

--[=[
    Preloads animations for choosen rig by loading each animation in choosen claster

    @param instance Instance -- We use it to link the instance to some animations from config
    @param animator Animator -- To load animations in it
    @param clasterName string -- Rig type name, go check animations config to see all the supported rigs!
]=]
function AnimationsController.PreloadAnimationsForInstance(self: Controller, instance: Instance, animator: Animator, clasterName: string)
    self:_preloadAnimations(instance, animator, clasterName)
end

function AnimationsController._createAnimationInstances(self: Controller)
    for instanceName, instanceAnimationsData in next, Animations do
        self._animationInstances[instanceName] = {}

        for category, animationsData in next, instanceAnimationsData do
            self._animationInstances[instanceName][category] = {}

            for animationName, animationId in next, animationsData do
                local animation: Animation = Instance.new("Animation")
                animation.AnimationId = `rbxassetid://{animationId}`

                self._animationInstances[instanceName][category][animationName] = animation
            end
        end
    end
end

function AnimationsController._preloadAnimations(self: Controller, instance: Instance, animator: Animator, clasterName: string)
    local rigAnimationsData = self._animationInstances[clasterName]
    if not rigAnimationsData then
        return
    end

    self._savedSpeeds[instance] = {}
    self._tracks[instance] = {}
    self._playingTracks[instance] = {}

    for category, animationsData in next, self._animationInstances[clasterName] do
        self._tracks[instance][category] = {}
        self._playingTracks[instance][category] = {}
        self._savedSpeeds[instance][category] = {}

        for animationName, animation: Animation in animationsData do
            local track = animator:LoadAnimation(animation)
            self._tracks[instance][category][animationName] = track
            self._savedSpeeds[instance][category][animationName] = track.Speed
        end
    end

    local destructorConnection: RBXScriptConnection
    destructorConnection = instance:GetPropertyChangedSignal("Parent"):Connect(function()  
        if instance.Parent then
            return
        end

        self._tracks[instance] = nil
        self._playingTracks[instance] = nil

        destructorConnection:Disconnect()
    end)
end

type Controller = typeof(AnimationsController)
return AnimationsController