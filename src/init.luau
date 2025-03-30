local Tween = {}
Tween.__index = Tween

--// Dependencies
local TweenService = game:GetService("TweenService")

--// Variables
export type PropertyTable = {[string]: any}
export type ClassType = typeof(setmetatable({} :: {
	Instance: Instance,
	TweenInfo: TweenInfo,
	PlaybackState: Enum.PlaybackState,
	Completed: RBXScriptSignal<Enum.PlaybackState>,
	
	PropertyTable: PropertyTable,
	Type: "Standard" | "Delta" | "Connect",
	
	_autoCleanup: boolean?,
	
	_tweens: {Tween},
	_valueBases: {ValueBase},
	_connections: {RBXScriptConnection},
	_completedBindable: BindableEvent,
}, Tween))


--// Helper functions
local function GetValueBase(var: any): ValueBase
	if typeof(var) == "boolean" then
		return Instance.new("BoolValue")
	else
		return Instance.new(`{typeof(var):gsub("^%l", string.upper)}Value`)
	end
end

local function GetValue(instance: Instance, property: string): (any, boolean)
	if instance:IsA("Model") then
		if property == "CFrame" then
			return instance:GetPivot(), false
		elseif property == "Scale" then
			return instance:GetScale(), false
		end
	end
	
	if instance:GetAttribute(property) ~= nil then
		return instance:GetAttribute(property), false
	else
		return instance[property], true
	end
end

local function GetSetFunction(instance: Instance, property: string): (instance: Instance, value: any) -> nil
	if instance:IsA("Model") then
		if property == "CFrame" then
			return instance.PivotTo
		elseif property == "Scale" then
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


--// Constructors
-- creates a custom Tween object that can manipulate properties and attributes that are not
-- natively manipulable by TweenService
function Tween:Create(instance: Instance, tweenInfo: TweenInfo, propertyTable: PropertyTable): ClassType
	local self = setmetatable({}, Tween) :: ClassType
	
	self.Instance = instance
	self.TweenInfo = tweenInfo
	self.PlaybackState = Enum.PlaybackState.Begin
	
	self.PropertyTable = propertyTable
	self.Type = "Standard"
	
	self._completedBindable = Instance.new("BindableEvent")
	self.Completed = self._completedBindable.Event
	
	self._autoCleanup = true
	
	self._tweens = {}
	self._valueBases = {}
	self._connections = {}
	
	return self
end

-- tweens by incrementing instead of overwriting property, allowing for multiple scripts to edit the
-- tweened properties at once
function Tween:CreateByDelta(instance: Instance, tweenInfo: TweenInfo, propertyTable: PropertyTable): ClassType
	local self = Tween:Create(instance, tweenInfo, propertyTable)
	self.Type = "Delta"
	
	return self
end

-- tween between the two given values, and update using the given closure
function Tween:Connect<T>(first: T, last: T, tweenInfo: TweenInfo, update: (value: T, lastValue: T) -> nil): ClassType
	assert(typeof(first) == typeof(last),
		`Attempted to tween between different value types ('{typeof(first)}' to '{typeof(last)}')`
	)
	
	local valueBase = GetValueBase(first)
	valueBase.Value = first
	
	local self = Tween:Create(valueBase, tweenInfo, {Value = last})
	self.Type = "Connect"
	
	local lastValue = first
	valueBase.Changed:Connect(function()
		update(valueBase.Value, lastValue)
		lastValue = valueBase.Value
	end)

	return self
end

-- creates a tween from the current values of the instance
function Tween:CreateFromCurrent(instance: Instance, tweenInfo: TweenInfo, propertyNames: {string}): ClassType
	local propertyTable = {}
	for i, property in pairs(propertyNames) do
		propertyTable[property] = GetValue(instance, property)
	end
	
	return Tween:Create(instance, tweenInfo, propertyTable)
end


--// Methods
-- play the tween. object will automatically destroy on completion unless :Persist() is called before :Play()
function Tween.Play(self: ClassType): ClassType
	if self.PlaybackState == Enum.PlaybackState.Playing or self.PlaybackState == Enum.PlaybackState.Delayed then
		return
	end
	
	if #self._tweens == 0 then
		self:_generateTweens()
	end
	
	for i, tween in ipairs(self._tweens) do
		tween:Play()
	end
	
	if self.TweenInfo.DelayTime > 0 then
		self.PlaybackState = Enum.PlaybackState.Delayed
		
		task.spawn(function()
			local start = os.clock()
			while self.PlaybackState == Enum.PlaybackState.Delayed and os.clock() - start < self.TweenInfo.DelayTime do
				task.wait()
			end
			
			if self.PlaybackState == Enum.PlaybackState.Delayed then
				self.PlaybackState = Enum.PlaybackState.Playing
			end
		end)
	else
		self.PlaybackState = Enum.PlaybackState.Playing	
	end
	
	if self._autoCleanup then -- destroy on completion to
		table.insert(self._connections, self.Completed:Once(function()
			self:Destroy()
		end))
	end
	
	return self
end

function Tween.Pause(self: ClassType): ClassType
	if self.PlaybackState ~= Enum.PlaybackState.Playing then
		return
	end
	
	for i, tween in ipairs(self._tweens) do
		tween:Pause()
	end
	
	self.PlaybackState = Enum.PlaybackState.Paused
	
	return self
end

function Tween.Cancel(self: ClassType): ClassType
	self:_cleanup()

	self.PlaybackState = Enum.PlaybackState.Cancelled
	self._completedBindable:Fire(Enum.PlaybackState.Cancelled)
	
	return self
end

-- yields until the tween is completed or canceled
function Tween.Wait(self: ClassType): Enum.PlaybackState
	return self.Completed:Wait()
end

-- asynchronously calls a closure when the tween is completed or canceled
function Tween.andThen(self: ClassType, closure: (playbackState: Enum.PlaybackState) -> nil): ClassType
	self.Completed:Once(closure)
	
	return self
end

-- sets the tween to not automatically destroy itself when completed
-- should be called before :Play()
-- if persisted, then :Destroy() must be called manually when tween is no longer needed
function Tween.Persist(self: ClassType): ClassType
	self._autoCleanup = false
	
	return self
end

-- creates a tween on a dummy ValueBase which updates the given property
-- used for tweening properties/attributes that cannot normally be tweened by TweenService
function Tween._createDummyTween(self: ClassType, property: string, target: any): (Tween, ValueBase)
	local currentValue = GetValue(self.Instance, property)
	local setFunction = GetSetFunction(self.Instance, property)

	local isCFrame = (typeof(currentValue) == "CFrame")
	local dummyValue = GetValueBase(currentValue)
	if self.Type ~= "Delta" then
		dummyValue.Value = currentValue
	end
	
	local lastValue = dummyValue.Value
	table.insert(self._connections, dummyValue.Changed:Connect(function()
		if self.Type == "Delta" then
			local delta = isCFrame and (dummyValue.Value * lastValue:Inverse()) or (dummyValue.Value - lastValue)
			currentValue = GetValue(self.Instance, property)
			
			setFunction(self.Instance, isCFrame and (currentValue * delta) or (currentValue + delta))
			lastValue = dummyValue.Value
		else
			setFunction(self.Instance, dummyValue.Value)
		end
	end))

	local tween = TweenService:Create(dummyValue, self.TweenInfo, {Value = target})
	
	table.insert(self._tweens, tween)
	table.insert(self._valueBases, dummyValue)
end

-- creates all Tween instances that are required for manipulating given properties
function Tween._generateTweens(self: ClassType)
	local safePropertyTable: PropertyTable = {}
	
	for property, target in pairs(self.PropertyTable) do
		local value, isProperty = GetValue(self.Instance, property)
		if isProperty and self.Type ~= "Delta" then
			safePropertyTable[property] = target
		else
			self:_createDummyTween(property, target)
		end
	end

	if next(safePropertyTable) then -- properties that can be safely tweened by TweenService
		local tween = TweenService:Create(self.Instance, self.TweenInfo, safePropertyTable)
		table.insert(self._tweens, 1, tween)
	end
	
	local firstTween = self._tweens[1]
	if firstTween then
		table.insert(self._connections, firstTween.Completed:Connect(function(playbackState)
			self:_cleanup()
			self.PlaybackState = playbackState
			self._completedBindable:Fire(playbackState)
		end))
	end
end

function Tween._cleanup(self: ClassType)
	for i, tween in ipairs(self._tweens) do
		tween:Cancel()
		tween:Destroy()
	end

	for i, valueBase in pairs(self._valueBases) do
		valueBase:Destroy()
	end

	for i, connection in pairs(self._connections) do
		connection:Disconnect()
	end

	table.clear(self._tweens)
	table.clear(self._valueBases)
	table.clear(self._connections)
end


--// Destructor
function Tween.Destroy(self: ClassType)
	self:_cleanup()
	
	if self.Type == "Connect" then
		self.Instance:Destroy()
	end
	
	if self._completedBindable then
		self._completedBindable:Destroy()
		self._completedBindable = nil
	end
	
	self.Instance = nil
	self.TweenInfo = nil
	self.PropertyTable = nil
end

--//
return Tween
