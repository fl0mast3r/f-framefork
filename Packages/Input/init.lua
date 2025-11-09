-- Input
-- Stephen Leitnick
-- October 10, 2021

--[=[
	@class Input

	The Input package provides access to various user input classes.

	- [PreferredInput](/api/PreferredInput)
	- [Mouse](/api/Mouse)
	- [Keyboard](/api/Keyboard)
	- [Touch](/api/Touch)
	- [Gamepad](/api/Gamepad)

	Reference the desired input modules via the Input package to get started:

	```lua
	local PreferredInput = require(Packages.Input).PreferredInput
	local Mouse = require(Packages.Input).Mouse
	local Keyboard = require(Packages.Input).Keyboard
	local Touch = require(Packages.Input).Touch
	local Gamepad = require(Packages.Input).Gamepad
	```
]=]

local PreferredInput = require(script.PreferredInput)
local Mouse = require(script.Mouse)
local Keyboard = require(script.Keyboard)
local Touch = require(script.Touch)
local Gamepad = require(script.Gamepad)

local Input = {
	PreferredInput = PreferredInput,
	Mouse = Mouse,
	Keyboard = Keyboard,
	Touch = Touch,
	Gamepad = Gamepad,
}

export type PreferredInput = typeof(PreferredInput)
export type Mouse = typeof(Mouse.new(...))
export type Keyboard = typeof(Keyboard.new(...))
export type Touch = typeof(Touch.new(...))
export type Gamepad = typeof(Gamepad.new(...))

return Input
