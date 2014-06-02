
-- Factory method when creating new Components ?

-- require("bully")

local Comet = require("system.comet")																				-- bring in the library

local comet = Comet:new() 																							-- create an instance

local c1 = comet:newC({ name = "position", x = 0, y = 0}) 															-- size and position components
local c2 = comet:newC({ name = "size", width = 50, height = 50 })

local c3 = comet:newC({ name = "coronaObject", coronaObject = nil })												-- a sort of link component.

local c4 = comet:newC({ name = "rectangle",  																		-- a rectangle, showing constructors and destructors
						requires = "position,size,coronaObject",
						constructor = function(c,e,p) e.coronaObject = display.newRect(10,10,10,10) end,
						destructor = function(c,e,p) e.coronaObject:removeSelf() e.coronaObject = {} end})

local c5 = comet:newC({ name = "colour", red = 1, green = 1, blue = 1}) 											-- a colour component
local c6 = comet:newC({ name = "velocity",dx = 0,dy = 0}) 															-- a 2D velocity component

local c7 = comet:newC({ name = "sprite", sprite = "crab.png", requires = "position,size,coronaObject", 				-- a sprite component, very simple.
						constructor = function(c,e,p) e.coronaObject = display.newImage(e.sprite) end,
						destructor = function(c,e,p) e.coronaObject:removeSelf() e.coronaObject = {} end})

local c8 = comet:newC("power", { power = 10 }) 																		-- a power component, scales velocity

comet:newC({ name = "controller" }) 																				-- marker component. If you create one for each entity
																													-- that's what you'' get.

for i = 1,53 do 																									-- create lots of entities in a rather haphazard manner.
	local e1 = comet:newE({ x = math.random(0,display.contentWidth),y = math.random(0,display.contentHeight), 
									width = math.random(20,60),height = math.random(20,60),power = math.random(1,10),height = 40 },c4)
	e1:addC("colour,velocity,controller,power")
	e1.red = math.random(100)/100
	e1.green = math.random(100)/100
	e1.blue = math.random(100)/100
	local s = math.random(30,80)
	local e2 = comet:newE({ x = math.random(0,display.contentWidth),y = math.random(0,display.contentHeight), power = math.random(1,10),width = s,height = s},"sprite,velocity,controller,power")
end

comet:newS("position,coronaObject", function(c,e,s) e.coronaObject.x,e.coronaObject.y = e.x,e.y end) 				-- position/CO system
comet:newS("size,coronaObject",function(c,e,s) e.coronaObject.width,e.coronaObject.height = e.width,e.height end) 	-- size/CO system
comet:newS("colour,coronaObject",function(c,e,s) e.coronaObject:setFillColor(e.red,e.green,e.blue) end) 			-- colour/CO system

comet:newS("position,velocity",function(c,e,s) 																		-- position and velocity components
	e.x = e.x + e.dx * s.deltaTime * 30
	e.y = e.y + e.dy * s.deltaTime * 30
	end)

local controller = require("controller"):new(270,430,50) 															-- we have ONE controller, and the controller/velocity/power
comet:newS("controller,velocity,power",function(c,e,s)  															-- system accesses this.
	e.dx = controller:getX() * e.power
	e.dy = controller:getY() * e.power
end)

Runtime:addEventListener( "enterFrame",function() comet:updateSystems() end)										-- Run all the systems.

--comet:remove()