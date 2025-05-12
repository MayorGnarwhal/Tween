# Tween
Tween is a wrapper module for Roblox's [TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService) class that expands the functionality and ease of use. Tween supports the manipulation of properties that are not natively supported by TweenService, including Attributes and the CFrame and Scales of models, as well as provide multiple new constructors for more specialized use cases.

## Table of Contents
- [How it works](#how-it-works)
- [Constructors](#constructors)
- [Methods](#methods)
- [Properties](#properties)
- [Events](#events)
- [Limitations](#limitations)
- [Installation](#installation)

## How it works
Tween allows the manipulation of additionally properties by taking advantage of ValueBases to create "dummy tweens" on an instance that can be tweened natively by TweenService, and replicating those changes to the real instance. This means that a Tween object can consist of multiple TweenService [TweenBases](https://create.roblox.com/docs/reference/engine/classes/TweenBase) and have additional created instances.

For example, the traditional way of tweening a model is to create a CFrameValue that will be tweened, and update the model's CFrame on the Changed connetion. Below is an example of how this may be done using native TweenService:
```luau
local TweenService = game:GetService("TweenService")

local model = workspace.Model

local dummyValue = Instance.new("CFrameValue")
dummyValue.Value = model:GetPivot()

local connection = dummyValue.Changed:Connect(function(cframe)
	model:PivotTo(cframe)
end)

local tween = TweenService:Create(dummyValue, TweenInfo.new(5), {
	Value = model:GetPivot() + Vector3.new(0, 20, 0)}
)

tween:Play()
tween.Completed:Wait()

dummyValue:Destroy()
connection:Disconnect()
```

However, Tween handles all this logic under the hood, and allows this exact functionality in significantly simplier and more readable code while also managing the extra instances and connections that are required.
```luau
local Tween = require(ReplicatedStorage.Tween)

local model = workspace.Model

local tween = Tween:Create(model, TweenInfo.new(5), {
	CFrame = model:GetPivot() + Vector3.new(0, 20, 0)
}):Play()

tween:Wait()
```

<br>

## Constructors
### `Create`
### Parameters
|     |     |     |
| :-- | :-- | :-- |
| **instance** | *Instance* | The instance whos properties are to be tweened |
| **tweenInfo** | *[TweenInfo](https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo)* | The TweenInfo to be used |
| **propertyTable** | *{[string]: any}* | A dictonary of properties and their target values to be tweened |

<br>

### `CreateByDelta`
Creates a Tween object using offsets instead of target values and increments the properties instead of overwrites. This allows multiple scripts to change the instances properties at once, unlike how TweenService traditionally overwrites the property throughout the tween.
### Parameters
|     |     |     |
| :-- | :-- | :-- |
| **instance** | *Instance* | The instance whos properties are to be tweened |
| **tweenInfo** | *[TweenInfo](https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo)* | The TweenInfo to be used |
| **propertyTable** | *{[string]: any}* | A dictonary of properties and the offset value to be tweened by |

### Code Samples
Since `CreateByDelta` uses offsets, `tween1` and `tween2` are functionally similar, tweening the numberValue to have a value of 200.
```luau
local numberValue = Instance.new("NumberValue")
numberValue.Value = 100

local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine)

local tween1 = Tween:Create(numberValue, tweenInfo, {Value = 200})
local tween2 = Tween:CreateByDelta(numberValue, tweenInfo, {Value = 100})
```

The tweened properties can be manipualted in the middle of the tween's playback, allowing for stacking effects.
```luau
local numberValue = Instance.new("NumberValue")
numberValue.Value = 0

local tween = Tween:CreateByDelta(numberValue, TweenInfo.new(1), {Value = 100})

tween:Play()

task.wait(tween.TweenInfo.Time / 2)
numberValue.Value += 1_000

tween.Completed:Wait()
print(numberValue.Value) --> 1100
```

Tween a model up by 20 studs on the global axis.
```luau
local model = workspace.Model
Tween:CreateByDelta(model, TweenInfo.new(1), {CFrame = Vector3.new(0, 20, 0)}):Play()
```

<br>

### `Connect`
Creates a tween between a start and end value that calls an update callback function, allowing for custom tween behavior. 
### Parameters
|     |     |     |
| :-- | :-- | :-- |
| **first** | *any* | The start value of the tween |
| **last** | *any* | The end value of the tween. Must have the same type as `first` |
| **tweenInfo** | *[TweenInfo](https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo)* | The TweenInfo to be used |
| **update** | *(value: any, lastValue: any) -> nil* | Update function that is called as the tween is played |

### Code Samples
Rotating a part by more than 180 degrees
```luau
Tween:Connect(0, math.rad(720), TweenInfo.new(10), function(value, lastValue)
	workspace.Baseplate.CFrame *= CFrame.Angles(0, value - lastValue, 0)
end):Play()
```

<br>

### `CreateFromCurrent`
Creates a tween from a list of property names, generating the PropertyTable based on the instance's current values. Useful for creating a tween to return to the current state after the instance is manipulated by other means.
### Parameters
|     |     |     |
| :-- | :-- | :-- |
| **instance** | *Instance* | The instance whos properties are to be tweened |
| **tweenInfo** | *[TweenInfo](https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo)* | The TweenInfo to be used |
| **propertyNames** | *{string}* | A list of property names that are used to generate the PropertyTable based on the instance's current values |

### Code Samples
Creating an open and close animation for a door, assuming the door is already in the closed state
```luau
local doorModel = workspace.Door
local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine)

local closeTween = Tween:CreateFromCurrent(doorModel, tweenInfo, {"CFrame"}):Persist()
local openTween = Tween:Create(doorModel, tweenInfo, {
	CFrame = door:GetPivot() * CFrame.Angles(0, math.rad(90), 0)
}):Persist()
```

<br>

## Methods
### `Play`
Starts playback of the tween. Has no effect if the tween is currently playing.

### `Pause`
Halts playback of the tween. Does not reset the tween's progress, so calling [Play()](#play) again will resume playback from the moment it was paused.

### `Cancel`
Halts playback of the tween and resets its progress, but does not reset the properties of the instance. Successive calls of [Play()](#play) will take the entire TweenInfo's duration.

### `Wait`
Yields the current thread until the tween is either completed or canceled. Returns the current PlaybackState. Is equivalent to waiting for the [Completed event](#events) with `tween.Completed:Wait()`.

### `andThen`
Asynchronously calls a function when the tween is either completed or canceled.

### Parameters
|     |     |     |
| :-- | :-- | :-- |
| **closure** | *(playbackState: [Enum.PlaybackState](https://create.roblox.com/docs/reference/engine/enums/PlaybackState)) -> nil* | The instance whos properties are to be tweened |

### Code Samples
```luau
tween:andThen(function(playbackState)
	if playbackState == Enum.PlaybackState.Completed then
		print("completed!")
	elseif playbackState == Enum.PlaybackState.Cancelled then
		print("canceled")
	end
end)
```

### `Persist`
Prevents the tween from automatically calling [Destroy()](#destroy) when it has completed, allowing for reusing the tween instance. Must be called before playback is completed or cancelled. Note that [Destroy()](#destroy) must then be manually called when the tween is no longer required.

### `Destroy`
Destroys the Tween object, cleaning up all of the instances that were created to handle the tween's behavior. Is called automatically upon completion, unless [Persist()](#persist)] is called before playback is completed or cancelled.

<br>

## Properties
### `Instance`: [Instance](https://create.roblox.com/docs/reference/engine/datatypes/Instance)

### `TweenInfo`: [TweenInfo](https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo)

### `PropertyTable`: `{[string]: any}`

### `PlaybackState`: [Enum.PlaybackState](https://create.roblox.com/docs/reference/engine/enums/PlaybackState)

<br>

## Events
### `Completed(playbackState: Enum.PlaybackState)`
Fires when the tween is either completed or canceled. Passes the current PlaybackState of the tween.

```luau
tween.Completed:Connect(function(playbackState)
	if playbackState == Enum.PlaybackState.Completed then
		print("completed!")
	elseif playbackState == Enum.PlaybackState.Cancelled then
		print("canceled")
	end
end)
```

<br>

## Limitations
- Since Tween is a wrapper built on top of TweenService, it is inherently less performant than TweenService. It is recommended to use TweenService when your use case allows it, however Tween can greatly simplify code for the extra functionality that it is built for

<br>

## Installation
Get Tween [on Roblox](https://create.roblox.com/store/asset/105202054717410/Tween) or from the [latest GitHub release](https://github.com/MayorGnarwhal/Tween/releases)
