local Tween = {}
Tween.__index = Tween

--// Dependencies
local TweenService = game:GetService("TweenService")

--// Variables
export type TweenClass = typeof(setmetatable({} :: {
	Instance: instance,
	TweenInfo: TweenInfo,
	Tweens: {Tween},
	DummyValues: {BaseValue},
	Completed: RBXScriptSignal,
}, Tween))


--// Helper functions
local function GetValueBase(var: any): ValueBase
	local typeofVar = typeof(var)
	local valueBase

	if typeofVar == "boolean" then
		valueBase = Instance.new("BoolValue")
	elseif typeofVar == "Instance" then
		valueBase = Instance.new("ObjectValue")
	else
		valueBase = Instance.new(`{typeofVar:gsub("^%l", string.upper)}Value`)
	end

	valueBase.Value = var

	return valueBase
end

local function GetProperty(instance: Instance, property: string): any
	if instance:IsA("Model") then
		if property == "CFrame" then
			return instance:GetPivot()
		elseif property == "Size" or property == "Scale" then
			return instance:GetScale()
		end
	end

	if instance:GetAttribute(property) ~= nil then
		return instance:GetAttribute(property)
	else
		return instance[property]
	end
end

local function GetSetFunction(instance: Instance, property: string): (instance: Instance, value: any) -> nil
	if instance:IsA("Model") then
		if property == "CFrame" then
			return instance.PivotTo
		elseif property == "Size" or property == "Scale" then
			return instance.ScaleTo
		end
	end

	if instance:GetAttribute(property) ~= nil then
		return function(instance, value)
			instance:SetAttribute(property, value)
		end
	end

	assert(instance[property])
	return function(instance, value)
		instance[property] = value
	end
end

local function CreateDummyTween(instance: Instance, tweenInfo: TweenInfo, property: string, targetValue: any, byDelta: boolean): (Tween, ValueBase)
	local currentValue = GetProperty(instance, property)
	local setFunction = GetSetFunction(instance, property)

	local dummyValue = GetValueBase(currentValue)
	local lastValue = currentValue

	dummyValue.Changed:Connect(function()
		if byDelta then
			local delta = (dummyValue.Value - lastValue)
			setFunction(instance, GetProperty(instance, property) + delta)
			lastValue = dummyValue.Value
		else
			setFunction(instance, dummyValue.Value)
		end
	end)

	local dummyTween = TweenService:Create(dummyValue, tweenInfo, {Value = targetValue})

	return dummyTween, dummyValue
end

local function CreateTween(instance: Instance, tweenInfo: TweenInfo, propertyTable: {}, byDelta: boolean): TweenClass
	local self = setmetatable({}, Tween)
	self.Instance = instance
	self.TweenInfo = tweenInfo
	self.Tweens = {}
	self.DummyValues = {}

	propertyTable = table.clone(propertyTable)

	if instance:IsA("Model") then
		if propertyTable.CFrame ~= nil then
			local dummyTween, dummyValue = CreateDummyTween(instance, tweenInfo, "CFrame", propertyTable.CFrame, byDelta)
			table.insert(self.Tweens, dummyTween)
			table.insert(self.DummyValues, dummyValue)
			propertyTable["CFrame"] = nil
		end

		if propertyTable.Size ~= nil or propertyTable.Scale ~= nil then
			local currentSize = propertyTable.Size or propertyTable.Scale
			local dummyTween, dummyValue = CreateDummyTween(instance, tweenInfo, "Size", currentSize, byDelta)
			table.insert(self.Tweens, dummyTween)
			table.insert(self.DummyValues, dummyValue)
			propertyTable["Size"] = nil
			propertyTable["Scale"] = nil
		end
	end

	for attribute, value in pairs(propertyTable) do
		if instance:GetAttribute(attribute) ~= nil then
			local dummyTween, dummyValue = CreateDummyTween(instance, tweenInfo, attribute, value, byDelta)
			table.insert(self.Tweens, dummyTween)
			table.insert(self.DummyValues, dummyValue)
			propertyTable[attribute] = nil
		end
	end

	if next(propertyTable) ~= nil then
		if byDelta then
			for property, value in pairs(propertyTable) do
				local dummyTween, dummyValue = CreateDummyTween(instance, tweenInfo, property, value, byDelta)
				table.insert(self.Tweens, dummyTween)
				table.insert(self.DummyValues, dummyValue)
			end
		else
			local tween = TweenService:Create(instance, tweenInfo, propertyTable)
			table.insert(self.Tweens, 1, tween)
		end
	end

	self.Completed = self.Tweens[1].Completed

	return self
end


--// Constructors
function Tween:Create(instance: Instance, tweenInfo: TweenInfo, propertyTable: {}): TweenClass
	return CreateTween(instance, tweenInfo, propertyTable, false)
end

function Tween:CreateByDelta(instance: Instance, tweenInfo: TweenInfo, propertyTable: {}): TweenClass
	local deltaPropertyTable = {}

	for property, value in pairs(propertyTable) do
		local currentValue = GetProperty(instance, property)
		if typeof(value) == "CFrame" then
			deltaPropertyTable[property] = currentValue * value
		else
			deltaPropertyTable[property] = currentValue + value
		end
	end

	return CreateTween(instance, tweenInfo, deltaPropertyTable, true)
end

function Tween:Connect<T>(first: T, last: T, tweenInfo: TweenInfo, update: (value: T, lastValue: T) -> nil): TweenClass
	assert(typeof(first) == typeof(last),
		`Attempted to tween between value types ({typeof(first)} to {typeof(last)})`
	)

	local valueBase = GetValueBase(first)
	local lastValue = first

	valueBase.Changed:Connect(function()
		update(valueBase.Value, lastValue)
		lastValue = valueBase.Value
	end)

	return CreateTween(valueBase, tweenInfo, {Value = last}, false)
end

--// Methods
function Tween.Play(self: TweenClass, doNotCleanup: boolean?): TweenClass
	if not doNotCleanup and self:PlaybackState() == Enum.PlaybackState.Begin then
		self.Completed:Once(function()
			self:Destroy()
		end)
	end
	
	for i, tween in pairs(self.Tweens) do
		tween:Play()
	end
	
	return self
end

function Tween.Pause(self: TweenClass): TweenClass
	for i, tween in pairs(self.Tweens) do
		tween:Pause()
	end

	return self
end

function Tween.Cancel(self: TweenClass): TweenClass
	for i, tween in pairs(self.Tweens) do
		tween:Cancel()
	end

	return self
end

function Tween.PlaybackState(self: TweenClass): Enum.PlaybackState
	return self.Tweens[1].PlaybackState
end

function Tween.Yield(self: TweenClass, durationMult: number?): Enum.PlaybackState
	if durationMult then
		task.wait(self.TweenInfo.Time * durationMult)
	else
		if self:PlaybackState() ~= Enum.PlaybackState.Completed then
			self.Completed:Wait()
		end
	end

	return self:PlaybackState()
end

function Tween.andThen(self: TweenClass, callback: () -> Enum.PlaybackState)
	self.Completed:Connect(callback)
end

function Tween.Destroy(self: TweenClass)
	for i, value in pairs(self.DummyValues) do
		value:Destroy()
	end
	for i, tween in pairs(self.Tweens) do
		tween:Destroy()
	end
end

--//
return Tween
