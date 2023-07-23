local Tween = {}
Tween.__index = Tween

--// Dependencies
local TweenService = game:GetService("TweenService")


--// Helper functions
--[[
	Get a ValueBase for the type of the given variable
]]
local function GetValueBase(var: any)
	local varType = typeof(var)
	local valueBase

	if varType == "boolean" then
		valueBase = Instance.new("BoolValue")
	else
		valueBase = Instance.new(varType:gsub("^%l", string.upper) .. "Value")
	end

	valueBase.Value = var
	return valueBase
end

local function GetProperty(instance, property)
	if property == "CFrame" then
		if instance:IsA("Model") or instance:IsA("BasePart") then
			return instance:GetPivot()
		else
			return instance.CFrame
		end
	elseif property == "Size" or property == "Scale" then
		return instance:IsA("Model") and instance:GetScale() or instance.Size
	elseif instance:GetAttribute(property) ~= nil then
		return instance:GetAttribute(property)
	else
		return instance[property]
	end
end

local function GetSetFunction(instance, property)
	if property == "CFrame" then
		if instance:IsA("Model") or instance:IsA("BasePart") then
			return instance.PivotTo
		else
			return function(instance, value)
				instance.CFrame = value
			end
		end
	elseif property == "Size" or property == "Scale" then
		if instance:IsA("Model") then
			return instance.ScaleTo
		else
			return function(instance, value)
				instance.Size = value
			end
		end
	elseif instance:GetAttribute(property) ~= nil then
		return function(instance, value)
			instance:SetAttribute(property, value)
		end
	else
		return function(instance, value)
			instance[property] = value
		end
	end
end

local function CreateDummyTween(instance: Instance, tweenInfo: TweenInfo, property: string, targetValue: any, byDiff: boolean)
	local currentValue = GetProperty(instance, property)
	local setFunction = GetSetFunction(instance, property)
	if currentValue == nil then return end

	local dummyValue = GetValueBase(currentValue)
	local lastValue = dummyValue.Value
	dummyValue.Changed:Connect(function()
		if byDiff then
			setFunction(instance, GetProperty(instance, property) + (dummyValue.Value - lastValue))
			lastValue = dummyValue.Value
		else
			setFunction(instance, dummyValue.Value)
		end
	end)

	local dummyTween = TweenService:Create(dummyValue, tweenInfo, {Value = targetValue})

	return dummyTween, dummyValue
end


--// Constructors
local function ConstructTween(instance: Instance, tweenInfo: TweenInfo, propertyTable: table, byDiff: boolean)
	local self = setmetatable({
		Instance = instance;
		TweenInfo = tweenInfo;
		Tweens = {};
		DummyValues = {};
	}, Tween)

	-- tweening a model's cframe
	if instance:IsA("Model") and (propertyTable.CFrame or propertyTable.Value) then
		local baseCF = propertyTable.CFrame or propertyTable.Value
		local dummyTween, dummyValue = CreateDummyTween(instance, tweenInfo, "CFrame", baseCF, byDiff)
		propertyTable.CFrame = nil
		propertyTable.Value = nil

		table.insert(self.Tweens, dummyTween)
		table.insert(self.DummyValues, dummyValue)
	end

	if instance:IsA("Model") and (propertyTable.Size or propertyTable.Scale) then
		local baseScale = propertyTable.Size or propertyTable.Scale
		local dummyTween, dummyValue = CreateDummyTween(instance, tweenInfo, "Size", baseScale, byDiff)
		propertyTable.Size = nil
		propertyTable.Scale = nil

		table.insert(self.Tweens, dummyTween)
		table.insert(self.DummyValues, dummyValue)
	end

	-- tweening an attribute
	for attribute, value in pairs(propertyTable) do
		if instance:GetAttribute(attribute) ~= nil then
			local dummyTween, dummyValue = CreateDummyTween(instance, tweenInfo, attribute, value, byDiff)
			propertyTable[attribute] = nil

			table.insert(self.Tweens, dummyTween)
			table.insert(self.DummyValues, dummyValue)
		end
	end

	if byDiff and next(propertyTable) ~= nil then
		for property, value in pairs(propertyTable) do
			local dummyTween, dummyValue = CreateDummyTween(instance, tweenInfo, property, value, byDiff)
			table.insert(self.Tweens, dummyTween)
			table.insert(self.DummyValues, dummyValue)
		end
	else
		local tween = TweenService:Create(instance, tweenInfo, propertyTable)
		table.insert(self.Tweens, 1, tween)
	end

	-- attach Completed event
	self.Completed = self.Tweens[1].Completed

	return self	
end

--[[
	Create a standard tween object
]]
function Tween:Create(instance: Instance, tweenInfo: TweenInfo, propertyTable: table)
	return ConstructTween(instance, tweenInfo, propertyTable, false)
end

--[[
	Create a Tween who's target is the current value plus the given value
	Uses all Dummy Tweens and increments by difference
		Allows for multiple tweens affecting same property of an instance
]]
function Tween:CreateDiff(instance: Instance, tweenInfo: TweenInfo, propertyTable: table)
	for attribute, value in pairs(propertyTable) do
		local currentValue = GetProperty(instance, attribute)
		if typeof(currentValue) == "CFrame" and typeof(value) == "CFrame" then
			propertyTable[attribute] = currentValue * value
		else
			propertyTable[attribute] = currentValue + value
		end
	end

	return ConstructTween(instance, tweenInfo, propertyTable, true)
end

--[[
	Create a dummy tween between two values, and connect a closure on Changed event
	onChange closure recieves the current value, and the previous value of the dummy ValueBase
]]
function Tween:Connect(first: any, last: any, tweenInfo: TweenInfo, onChange: Function)
	assert(typeof(first) == typeof(last), "Attempting to tween from " .. typeof(first) .. " to " .. typeof(last) .. ".")

	local valueBase = GetValueBase(first)
	valueBase.Value = first

	local lastValue = first
	valueBase.Changed:Connect(function()
		onChange(valueBase.Value, lastValue)
		lastValue = valueBase.Value
	end)

	return ConstructTween(valueBase, tweenInfo, {Value = last}, false)
end


--// TweenService GetValue Method
function Tween:GetValue(alpha: number, easingStyle: Enum.EasingStyle, easingDirection: Enum.EasingDirection)
	return TweenService:GetValue(alpha, easingStyle, easingDirection)
end


--// Default Tween Methods
function Tween:Play()
	if self:PlaybackState() == Enum.PlaybackState.Begin then
		self:andThen(function()
			self:Destroy()
		end)
	end

	for i, tween in pairs(self.Tweens) do
		tween:Play()
	end

	return self
end

function Tween:Pause()
	for i, tween in pairs(self.Tweens) do
		tween:Pause()
	end

	return self
end

function Tween:Cancel()
	for i, tween in pairs(self.Tweens) do
		tween:Cancel()
	end

	return self
end


--// Custom Tween Methods
function Tween:PlaybackState()
	return self.Tweens[1].PlaybackState
end

--[[
	Wait until Tween has completed playing or is stopped with :Cancel()
	If a durationMult is given, then yield for a duration relative to the Tweens's length
	Returns the Tween's current PlaybackState
]]
function Tween:Yield(durationMult: number?)
	if durationMult then
		task.wait(self.TweenInfo.Time * durationMult)
	else
		if self:PlaybackState() ~= Enum.PlaybackState.Completed then
			self.Completed:Wait()
		end
	end

	return self:PlaybackState()
end

--[[
	Asynchronously call a function when the Tween is completed or stopped with :Cancel()
]]
function Tween:andThen(callback: Function)
	task.spawn(function()
		local playbackState = self:Yield()
		callback(playbackState)
	end)

	return self
end

--[[
	Clean up resources used by custom Tween objects
	Called automatically when tween is played and has been completed or canceled
]]
function Tween:Destroy()
	for i, value in pairs(self.DummyValues) do
		value:Destroy()
	end
end

--//
return Tween
