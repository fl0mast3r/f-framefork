--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Packages.LemonSignal)
local ImGizmo = require(ReplicatedStorage.Packages.CeiveImGizmo)
local StrictGetter = require(ReplicatedStorage.Packages.StrictGetter)

local PavelCast = {}
PavelCast.__index = PavelCast

type RayPrompt = {
    Origin: Vector3,
    Direction: Vector3,
}

type Properties = {
    OnHit: Signal.Signal<{Humanoid}>,
    GridPreset: BasePart,
    Player: Player,
    OtherData: any?,

    _grid: {[number]: Attachment},
    _savedHumanoids: {Humanoid},
    _rayLength: number,
    _updateConnection: thread?,
}
export type ClassType = typeof(setmetatable({} :: Properties, PavelCast))

function PavelCast.new(gridPreset: BasePart, rayLength: number, data: any)
    local self: Properties = {
        OnHit = Signal.new(),
        GridPreset = gridPreset,
        Player = Players.LocalPlayer,
        OtherData = data,

        _rayLength = rayLength,
        _grid = {},
        _savedHumanoids = {},
        _updateConnection = nil,
    }

    setmetatable(self, PavelCast)

    return self
end

function PavelCast.Start(self: ClassType)
    self._savedHumanoids = {}

    self._updateConnection = task.defer(function()
        while RunService.RenderStepped:Wait() do
            self:_update()
        end
    end)
end

-- :: Alias to :Destroy() method
function PavelCast.Stop(self: ClassType)
    self:Destroy()
end

-- :: Cleanup and Stop
function PavelCast.Destroy(self: ClassType)
    if self._updateConnection then
        task.cancel(self._updateConnection)
        self._updateConnection = nil
    end

    if self._grid then
        for _, attachment: Attachment in next, self._grid do
            attachment:Destroy()
        end

        table.clear(self._grid)
    end

    if self._savedHumanoids then
        table.clear(self._savedHumanoids)
    end
end

-- :: Creating Attachments Grid
function PavelCast._createGrid(self: ClassType, originPart: BasePart)
    self._grid = {}

    for _, attachment: Instance in next, self.GridPreset:GetChildren() do
        if not attachment:IsA("Attachment") then
            continue
        end
        
        local newAttachment: Attachment = attachment:Clone()
        newAttachment.Parent = originPart

        table.insert(self._grid, newAttachment)
    end
end

function PavelCast._raycastAttachments(self: ClassType, params: RaycastParams): ({Humanoid})
    local targetStore: {[number]: Humanoid} = {}

    for _, attachment in next, self._grid do
        local raycast: RaycastResult? = workspace:Raycast(
            attachment.WorldCFrame.Position,
            attachment.WorldCFrame.LookVector * self._rayLength,
            params
        )

        self:_debugRaycast(raycast, {
            Origin = attachment.WorldCFrame.Position,
            Direction = attachment.WorldCFrame.LookVector * self._rayLength,
        })


        if not raycast then
            continue
        end

        if not raycast.Instance then
            continue
        end

        if not raycast.Instance.Parent then
            continue
        end

        if not raycast.Instance.Parent:IsA("Model") then
            continue
        end

        local humanoid: Humanoid? = StrictGetter.Humanoid(raycast.Instance.Parent:FindFirstChild("Humanoid"))
        if not humanoid then
            continue
        end

        if table.find(targetStore, humanoid) then
            continue
        end

        table.insert(targetStore, humanoid)
    end

    return targetStore
end

-- :: Private update method / binding on :Start() and unbinding on :Stop()/:Destroy()
function PavelCast._update(self: ClassType)
    local character: Model? = self.Player.Character
    if not character then
        return
    end

    local humanoidRootPart: BasePart? = StrictGetter.BasePart(character:FindFirstChild("HumanoidRootPart"))
    if not humanoidRootPart then
        return
    end

    if #self._grid == 0 then
        self:_createGrid(humanoidRootPart)
    end

    local raycastParms: RaycastParams = RaycastParams.new()
    raycastParms.FilterType = Enum.RaycastFilterType.Exclude
    raycastParms.FilterDescendantsInstances = {character}

    local resultArray: {Humanoid} = self:_raycastAttachments(raycastParms)
    local newArray: {Humanoid} = {}
    for _, humanoid:  Humanoid in next, resultArray do
        if table.find(self._savedHumanoids, humanoid) then
            continue
        end

        table.insert(newArray, humanoid)
        table.insert(self._savedHumanoids, humanoid)
    end

    table.clear(resultArray)

    if #newArray > 0 then
        self.OnHit:Fire(newArray)
    end
end

function PavelCast._debugRaycast(self: ClassType, raycastResult: RaycastResult?, prompt: RayPrompt)
    ImGizmo.PushProperty("Color3", if raycastResult and raycastResult.Instance and raycastResult.Instance.Parent and raycastResult.Instance.Parent:FindFirstChild("Humanoid") then Color3.new(0,1,0) else Color3.new(1,0,0))
    ImGizmo.PushProperty("AlwaysOnTop", false)
    ImGizmo.Ray:Draw(prompt.Origin, prompt.Origin+prompt.Direction)
end

return PavelCast
