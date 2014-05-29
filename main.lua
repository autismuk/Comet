--- ************************************************************************************************************************************************************************
---
---				Name : 		main.lua
---				Purpose :	COMET (Component/Entity Framework for Corona/Lua)
---				Created:	27 May 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }

local Comet = require("system.comet")
local Particle = require("system.particle")

local c = Comet:new()


--	sprite components and systems

local c1 = c:newC("position","x:int,y:int")
local c2 = c:newC("size","width:number,height:number")
local c4 = c:newC("coronaobject","displayObj:object")
local c3 = c:newC("sprite","",{ requires = "position,size,coronaobject",
								constructor = function(entity,fileName,size) entity.displayObj = display.newImage(fileName) end,
								destructor = function(entity) entity.displayObj:removeSelf() entity.displayObj = nil end })


-- two objects, sprites, created differently
local e1 = c:newE()
e1:addC("sprite","crab.png",42)
e1.x,e1.y = 100,200
e1.width = 64 e1.height = 64

local e2 = c:newE({"position","size","coronaobject"})
e2:addC("sprite","cat.jpg",44)
e2.x,e2.y = 200,300
e2.width = 100
e2.height = 100


--	systems for updating position and size.

c:newS("position,coronaobject",function(e) e.displayObj.x = e.x e.displayObj.y = e.y end)

c:newS("size,coronaobject",function(e) e.displayObj.width = e.width e.displayObj.height = e.height end)

-- 	component and system for rotating

c:newC("spinner","spinspeed:int",{ requires = "coronaobject",
									constructor = function(e,s) e.spinspeed = s or 3 end})

c:newS("spinner",function(e) e.displayObj.rotation = system.getTimer()/e.spinspeed end)

-- add to our cat and crab entities

e1:addC("spinner",5)
e2:addC("spinner",10)

-- basic emitter component - note autoremoves corona object.

c:newC("emitter","particleRef:table",{ requires = "position,coronaobject",
									  constructor = function(e,fx) 
									  					e.particleRef = Particle.Emitter:new("stars"):start(10,0) 
									  					e.displayObj = e.particleRef.emitter
													end,
									  destructor = function(e) 
									  					e.particleRef:removeSelf()
									  					e:remC("coronaobject")
									  				end
									})


-- vector components 

c:newC("Vector","dx:number,dy:number")

-- stars emitter

local e3 = c:newE("emitter","stars")
e3:addC("spinner",-12)
e3.x = display.contentWidth/2
e3.y = display.contentHeight/2

-- system to update position from vectors


c:newS("vector,position", function(e,i) 
		e.x = e.x + e.dx * i.deltaTime 
		e.y = e.y + e.dy * i.deltaTime
	end)

r = display.newText("xx fps",40,20,system.nativeFont,16)

-- controller compoennt

local Controller = require("controller")

c:newC("controller","controllerRef:table",
					{ 	requires = "vector",
						constructor = function(e) e.controllerRef = Controller:new() end,
						destructor = function(e) e.controllerRef:remove() end })

-- add to entities

e2:addC("controller")
e1:addC("controller")

-- system to update vector from controller

c:newS("controller,vector", function(e,i) 
									e.dx = e.controllerRef:getX()*40
									e.dy = e.controllerRef:getY()*40
									end)
-- e2:remC("controller")

-- run and track fps
local start = system.getTimer()
local count = 0

Runtime:addEventListener( "enterFrame", function()
	c:process()
	count = count + 1
	local fps = math.round(count * 1000 / (system.getTimer() - start))
	r.text = fps .. " fps"
end)

