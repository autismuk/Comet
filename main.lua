--- ************************************************************************************************************************************************************************
---
---				Name : 		main.lua
---				Purpose :	COMET (Component/Entity Framework for Corona/Lua), version 4
---				Created:	5th June 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }

local Comet = require("system.comet")

local cm = Comet:new() 																			-- create a new comet instances
c0 = cm:newC("position",{ x = 100,y = 100 }) 													-- some very basic components
c2 = cm:newC("size", {width = 80,height = 70})
c3 = cm:newC("velocity", { dx = 32, dy = 0 })
c4 = cm:newC("rotation", { rotation = 45 })
c5 = cm:newC("rotatespeed", { da = 360 })
c6 = cm:newC("speed", { speed = 32 })

c1 = cm:newC("sprite", { handle = nil, requires = { c0,c2 }, 									-- a crab sprite component, not very generalised
						 constructor = function(e) e.handle = display.newImage("images/crab.png") end,
						 destructor = function(e) e.handle:removeSelf() end,
})

																								-- create some systems
local s1 = cm:newS({c0,c1}, 																	-- position/sprite (moves it)
		function (e) e.handle.x,e.handle.y = e.x,e.y end, { preProcess = function(el) end })
local s2 = cm:newS({c1,c2},function (e) e.handle.width,e.handle.height = e.width,e.height end) 	-- size/sprite (scales it)
local s4 = cm:newS({c1,c4},function (e) e.handle.rotation = e.rotation end) 					-- rotate/sprite (rotates it)

ClassS5 = cm:getSystemClass():new() 															-- we declare it this way to show Systems Classes

function ClassS5:update(entityList) 															-- get elapsed delta time
	local dt = entityList[1]:getInfo().deltaTime
	for i = 1,#entityList do  																	-- work through the entity list
		local e = entityList[i]
		if e:isAlive() then e.rotation = e.rotation + e.da * dt end								-- apply the rotation adjusted for time.
	end 
end 

ClassS5:new(cm,{c4,c5})																			-- Create an instance of it, the Comet system is notified.

local s3 = cm:newS({c0,c3},function (e) 														-- a system which changes position based on dx,dy and deltaTime
	local dt = e:getInfo().deltaTime
	e.x = e.x + e.dx * dt
	e.y = e.y + e.dy * dt
	-- if e.x < 30 then e:remove() end
end)

local Controller = require("utilities.Controller") 												-- a class which does a touch controller

cm:newC("controller", { controllerObject = nil,													-- convert to a component, which only has one actual controller that is shared

		constructor = function(e) 
			local data = e:getComponentData() 													-- get private data for this component.
			data.instanceCount = (data.instanceCount or 0)+1 									-- initialise the instance count, and increment it
			if data.instanceCount == 1 then  													-- the first time only, create a controller object.
				data.controllerObject = Controller:new() 										-- n.b. the private data is private to the component, using getInstanceData()
			end 																				-- gets the same thing for each entity that has a component.
			e.controllerObject = data.controllerObject 											-- we want to share one controller.
			e.controllerObject.group:toFront() 													-- bring it up front
		end ,

		destructor = function(e)
			local data = e:getComponentData() 													-- get private data for this component.
			data.instanceCount = data.instanceCount - 1 										-- decrement the instance count
			if data.instanceCount == 0 then  													-- if all gone, then remove it.
				e.controllerObject:remove()
				e.controllerObject = nil
			end
			e.controllerObject = nil
		end
	})

cm:newS("controller,velocity,speed", 															-- a system which sets velocity based on controller and speed
		function(e) 
			if e.controllerObject ~= nil then 
				e.dx = e.controllerObject:getX()*e.speed
				e.dy = e.controllerObject:getY()*e.speed
			end
	end)


for i = 1,30 do 																				-- create some crabs that rotate, move and are controllable
	local e = cm:newE({c1,c3,"rotation","rotatespeed"},
				{ x = math.random(320),y = math.random(480),dx = math.random(32,128),dy = math.random(32,160),da = math.random(-360,360), speed = math.random(1,250) }) e.__name = "e"..i
	e:addC("controller,speed")
end


cm:runAutomatic() 																				-- and let them go !
--cm:remove()
--_G.Comet = Comet  require("bully")
-- TODO: Particle explosion on off left.

