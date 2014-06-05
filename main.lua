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

local cm = Comet:new() 
c0 = cm:newC("position",{ x = 100,y = 100 })
c2 = cm:newC("size", {width = 80,height = 70})
c3 = cm:newC("velocity", { dx = 32, dy = 0 })
c4 = cm:newC("rotation", { rotation = 45 })
c5 = cm:newC("rotatespeed", { da = 360 })

c1 = cm:newC("sprite", { handle = nil, requires = { c0,c2 },
						 constructor = function(e) e.handle = display.newImage("images/crab.png") end,
						 destructor = function(e) e.handle:removeSelf() end,
})

local s1 = cm:newS({c0,c1},function (e) e.handle.x,e.handle.y = e.x,e.y end, { preProcess = function(el) end })
local s2 = cm:newS({c1,c2},function (e) e.handle.width,e.handle.height = e.width,e.height end)

local s4 = cm:newS({c1,c4},function (e) e.handle.rotation = e.rotation end)

ClassS5 = cm:getSystemClass():new()

function ClassS5:update(entityList)
	local dt = entityList[1]:getInfo().deltaTime
	for i = 1,#entityList do 
		local e = entityList[i]
		e.rotation = e.rotation + e.da * dt
	end 
end 

ClassS5:new(cm,{c4,c5})

local s3 = cm:newS({c0,c3},function (e)
	local dt = e:getInfo().deltaTime
	e.x = e.x + e.dx * dt
	e.y = e.y + e.dy * dt
	if e.x < 0 or e.x > 320 then e.dx = -e.dx end
	if e.y < 0 or e.y > 480 then e.dy = -e.dy end
end)

for i = 1,10 do
	local e = cm:newE({c1,c3,"rotation","rotatespeed"},
				{ x = math.random(320),y = math.random(480),dx = math.random(32,128),dy = math.random(32,160),da = math.random(-360,360) }) e.__name = "e"..i
end

cm:runAutomatic()

--_G.Comet = Comet  require("bully")


