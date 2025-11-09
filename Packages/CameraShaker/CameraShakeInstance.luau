-- Camera Shake Instance
-- Stephen Leitnick
-- February 26, 2018

-- Updated by 1ib (@uid3v)
-- December 14, 2024

--[[
	
	cameraShakeInstance = CameraShakeInstance.new(magnitude, roughness, fadeInTime, fadeOutTime)
	
--]]

local CameraShakeInstance = {}
CameraShakeInstance.__index = CameraShakeInstance

local V3 = Vector3.new
local NOISE = math.noise

CameraShakeInstance.CameraShakeState = {
	FadingIn = 0;
	FadingOut = 1;
	Sustained = 2;
	Inactive = 3;
}

export type CameraShakeInstance = {
    UpdateShake: (self: CameraShakeInstance, dt: number) -> Vector3,
    StartFadeOut: (self: CameraShakeInstance, fadeOutTime: number?) -> (),
    StartFadeIn: (self: CameraShakeInstance, fadeInTime: number?) -> (),
    GetScaleRoughness: (self: CameraShakeInstance) -> number,
    SetScaleRoughness: (self: CameraShakeInstance, v: number) -> (),
    GetScaleMagnitude: (self: CameraShakeInstance) -> number,
    SetScaleMagnitude: (self: CameraShakeInstance, v: number) -> (),
    GetNormalizedFadeTime: (self: CameraShakeInstance) -> number,
    IsShaking: (self: CameraShakeInstance) -> boolean,
    IsFadingOut: (self: CameraShakeInstance) -> boolean,
    IsFadingIn: (self: CameraShakeInstance) -> boolean,
    GetState: (self: CameraShakeInstance) -> number,
}

function CameraShakeInstance.new(magnitude, roughness, fadeInTime, fadeOutTime)
	if fadeInTime == nil then 
		fadeInTime = 0
	end

	if fadeOutTime == nil then 
		fadeOutTime = 0 
	end
	
	assert(type(magnitude) == "number", "Magnitude must be a number")
	assert(type(roughness) == "number", "Roughness must be a number")
	assert(type(fadeInTime) == "number", "FadeInTime must be a number")
	assert(type(fadeOutTime) == "number", "FadeOutTime must be a number")
	
	local self = setmetatable({
		Magnitude = magnitude;
		Roughness = roughness;
		PositionInfluence = V3();
		RotationInfluence = V3();
		DeleteOnInactive = true;
		roughMod = 1;
		magnMod = 1;
		fadeOutDuration = fadeOutTime;
		fadeInDuration = fadeInTime;
		sustain = (fadeInTime > 0);
		currentFadeTime = (fadeInTime > 0 and 0 or 1);
		tick = Random.new():NextNumber(-100, 100);
		_camShakeInstance = true;
	}, CameraShakeInstance)
	return self
end
function CameraShakeInstance:UpdateShake(dt)
	self.tick = self.tick + (dt * self.Roughness)
	if self.fadeInDuration > 0 and self.sustain then
		if self.currentFadeTime < 1 then
			self.currentFadeTime = math.min(self.currentFadeTime + (dt / self.fadeInDuration), 1)
		elseif self.fadeOutDuration > 0 then
			self.sustain = false
		end
	end
	if not self.sustain then
		self.currentFadeTime = math.max(self.currentFadeTime - (dt / self.fadeOutDuration), 0)
	end
	local fadeFactor = self.currentFadeTime
	local noiseOffset = V3(
		NOISE(self.tick, 0) * fadeFactor,
		NOISE(0, self.tick) * fadeFactor,
		NOISE(self.tick, self.tick) * fadeFactor
	)
	local finalOffset = noiseOffset * (self.Magnitude * self.magnMod * fadeFactor)
	return finalOffset * (dt * 60)
end
function CameraShakeInstance:StartFadeOut(fadeOutTime)
	if fadeOutTime == 0 then
		self.currentFadeTime = 0
	end
	self.fadeOutDuration = fadeOutTime
	self.fadeInDuration = 0
	self.sustain = false
end
function CameraShakeInstance:StartFadeIn(fadeInTime)
	if fadeInTime == 0 then
		self.currentFadeTime = 1
	end
	self.fadeInDuration = fadeInTime or self.fadeInDuration
	self.fadeOutDuration = 0
	self.sustain = true
end
function CameraShakeInstance:GetScaleRoughness()
	return self.roughMod
end
function CameraShakeInstance:SetScaleRoughness(v)
	self.roughMod = v
end
function CameraShakeInstance:GetScaleMagnitude()
	return self.magnMod
end
function CameraShakeInstance:SetScaleMagnitude(v)
	self.magnMod = v
end
function CameraShakeInstance:GetNormalizedFadeTime()
	return self.currentFadeTime
end
function CameraShakeInstance:IsShaking()
	return (self.currentFadeTime > 0 or self.sustain)
end
function CameraShakeInstance:IsFadingOut()
	return ((not self.sustain) and self.currentFadeTime > 0)
end
function CameraShakeInstance:IsFadingIn()
	return (self.currentFadeTime < 1 and self.sustain and self.fadeInDuration > 0)
end
function CameraShakeInstance:GetState()
	if self:IsFadingIn() then
		return CameraShakeInstance.CameraShakeState.FadingIn
	elseif self:IsFadingOut() then
		return CameraShakeInstance.CameraShakeState.FadingOut
	elseif self:IsShaking() then
		return CameraShakeInstance.CameraShakeState.Sustained
	else
		return CameraShakeInstance.CameraShakeState.Inactive
	end
end
return CameraShakeInstance