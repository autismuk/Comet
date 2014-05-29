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

local c1 = c:newC("position","x:int,y:int")
local c2 = c:newC("size","width:number,height:number")
local c4 = c:newC("coronaobject","displayObj:object")
local c3 = c:newC("sprite","",{ requires = "position,size,coronaobject",
								constructor = function(entity,fileName,size) entity.displayObj = display.newImage(fileName) end,
								destructor = function(entity) entity.displayObj:removeSelf() entity.displayObj = nil end })

local e1 = c:newE()
e1:addC("sprite","crab.png",42)
e1.x,e1.y = 100,200
e1.width = 64 e1.height = 64

local e2 = c:newE({"position","size","coronaobject"})
e2:addC("sprite","cat.jpg",44)
e2.displayObj.x,e2.displayObj.y = 60,100
e2.x,e2.y = 200,300
e2.width = 100
e2.height = 100


c:newS("position,coronaobject",function(e) e.displayObj.x = e.x e.displayObj.y = e.y end)
c:newS("size,coronaobject",function(e) e.displayObj.width = e.width e.displayObj.height = e.height end)

c:newC("spinner","spinspeed:int",{ requires = "coronaobject",
									constructor = function(e,s) e.spinspeed = s or 3 end})
c:newS("spinner",function(e) e.displayObj.rotation = system.getTimer()/e.spinspeed end)

e1:addC("spinner",5)
e2:addC("spinner",10)

c:newC("Emitter","particleRef:table",{ requires = "position,coronaobject",
									  constructor = function(e,fx) 
									  					e.particleRef = Particle.Emitter:new("stars"):start(10,0) 
									  					e.displayObj = e.particleRef.emitter
													end,
									  destructor = function(e) 
									  					e.particleRef:removeSelf()
									  					e:remC("coronaobject")
									  				end
									})

local e3 = c:newE("emitter","stars")
e3:addC("spinner",-12)
e3.x = display.contentWidth/2
e3.y = display.contentHeight/2

local rem = false
Runtime:addEventListener( "enterFrame", function()
	c:process()	
	if not rem and system.getTimer() > 10000 then 
		e3:remC("emitter")
		rem = true
	end
end)

