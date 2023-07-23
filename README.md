# Table of Contents
* [Introduction](#introduction)
* [Constructors](#constructors)
* [Methods](#methods)


# Introduction
Tween a wrapper module for Roblox's [TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService) class intended to improve TweenService's functionality and ease of use. 

Tween is especially useful for tweening things that cannot easily be tweened with Roblox's TweenService, such as Instance Attributes, the CFrame of models, and the Size of models. As TweenService only allows the tweening of Instance properties, attempting to tween an Attribute is possible with a dummy tween workaround.

For example, this is an example of how to tween an attribute using **vanilla Roblox TweenService:**
```lua
local TweenService = game:GetService("TweenService")

local gun = script.Parent
gun:SetAttribute("Cooldown", 5)

local dummyValue = Instance.new("NumberValue")
dummyValue.Value = gun:GetAttribute("Cooldown")

dummyValue.Changed:Connect(function(value)
    gun:SetAttribute("Cooldown", value)
end)

local tween = TweenService:Create(
    dummyValue,
    TweenInfo.new(5, Enum.EasingStyle.Linear),
    {Value = 0}
)

tween:Play()
tween.Completed:Wait()

dummyValue:Destroy()

print(gun:GetAttribute("Cooldown")) --> 0
```

The Tween module, however, implements this dummy tween process under the hood, allowing the code to be simplified to:
```lua
local Tween = require(game.ReplicatedStorage.Services.Tween)

local gun = script.Parent
gun:SetAttribute("Cooldown", 5)

local tween = Tween:Create(
    gun,
    TweenInfo.new(5, Enum.EasingStyle.Linear),
    {Cooldown = 0}
)

tween:Play():Yield()

print(gun:GetAttribute("Cooldown")) --> 0
```


# Constructors
## `Create()`
Creates a standard Tween object. If non-properties are being tweened, then a dummy tween is created for each non-property.
### Parameters
|     |     |     |
| :-- | :-- | :-- |
| **instance** | *Instance* | The instances whose properties are to be tweened |
| **tweenInfo** | *TweenInfo* | The [TweenInfo](https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo) to be used |
| **propertyTable** | *table* | A dictionary of properties, and their target values, to be tweened |


## `CreateDiff()`
Creates a Tween object that tween's the target value by a given amount. All properties being tweened also use a dummy tween, allowing for tweening by a difference in value. This allows tweening the same property of the same instance at the same time.
### Parameters
|     |     |     |
| :-- | :-- | :-- |
| **instance** | *Instance* | The instances whose properties are to be tweened |
| **tweenInfo** | *TweenInfo* | The [TweenInfo](https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo) to be used |
| **propertyTable** | *table* | A dictionary of properties, and their target values, to be tweened |


## `Connect()`
Creates a dummy tween that is not associated with any instance. Used to perform any custom tween behavior, such as tweening multiple instances with a single Tween.
|     |     |     |
| :-- | :-- | :-- |
| **first** | *any* | The initial value of the dummy tween |
| **last** | *any* | The final value of the dummy tween |
| **tweenInfo** | *TweenInfo* | The [TweenInfo](https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo) to be used |
| **onChange** | *function* | Function called when dummy tween's value changes. Recieves two arguments, the current value and the previous value |



# Methods
## `Play()`
Starts playback of the tween. Has no effect if the tween is currently playing. 
```lua
local tween = Tween:Create(instance, TweenInfo.new(5), {Transparency = 1})
tween:Play()

```
This method also returns the tween object, allowing you to create and play a tween on the same line while still having reference to the tween.
```lua
local tween = Tween:Create(instance, TweenInfo.new(5), {Transparency = 1}):Play()
tween.Completed:Wait()
```


## `Pause()`
Halts the playback of the tween. Pausing does not reset the progress of the tween, meaning if you call `Play()` after pausing, the tween will resume where it left off.


## `Cancel()`
Halts the playback of the tween and resets its progress. 


## `PlaybackState()`
Returns the current [playback state](https://create.roblox.com/docs/reference/engine/enums/PlaybackState) of the tween.
```lua
local tween = Tween:Create(instance, TweenInfo.new(5), {Transparency = 1})
print(tween:PlaybackState()) --> Enum.PlaybackState.Begin

tween:Play()
print(tween:PlaybackState()) --> Enum.PlaybackState.Playing

tween:Pause()
print(tween:PlaybackState()) --> Enum.PlaybackState.Paused

tween:Cancel()
print(tween:PlaybackState()) --> Enum.PlaybackState.Cancelled

tween:Play():Yield()
print(tween:PlaybackState()) --> Enum.PlaybackState.Completed
```


## `Yield()`
Yields the current thread until the tween has completed playing, or until it is stopped with `Cancel()`. Optionally, can pass a number argument to yield for a proportion of the tween's length. Returns the tween's current playback state.
### Parameters
| **durationMult** | *number?* | Proportion of the tween's lenth to yield. For example, if `durationMult = 0.5` and the tween's length is `10`, then the thread yields for 5 seconds |
| :-- | :-- | :-- |
```lua
local start = os.clock()

local tween = Tween:Create(instance, TweenInfo.new(5), {Transparency = 1}):Play()
local playbackState = tween:Yield()

print(playbackState)      --> Enum.PlaybackState.Completed
print(os.clock() - start) --> 5
```
```lua
local start = os.clock()

local tween = Tween:Create(instance, TweenInfo.new(5), {Transparency = 1}):Play()
tween:Yield(0.5)

print(playbackState)      --> Enum.PlaybackState.Playing
print(os.clock() - start) --> 2.5
```

Tween also persists the `Completed` event, allowing you to yield the same way you would a Roblox Tween object.
```lua
local tween = Tween:Create(instance, TweenInfo.new(5), {Transparency = 1}):Play()
tween.Completed:Wait()
```


## `andThen()`
Asynchronously calls a function when the tween has completed playing or is stopped with `Cancel()`.
### Parameters
| **callback** | *function* | Function to be called upon tween completeion or cancelation. Recieves one argument, the current playback state |
| :-- | :-- | :-- |
```lua
local tween = Tween:Create(instance, TweenInfo.new(5), {Transparency = 1})

tween:Play():andThen(function(playbackState)
    print(1, playbackState)
end)

print(2)

--[[
    2
    1 Enum.PlaybackState.Completed
]]
```


## `Destroy()`
Destroys all extra connections made to facilitate tween. **Destroy is called automatically when tween is completed**, and is only neccessary in scenarios where the tween is paused and never resumed.
