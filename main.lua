--- ************************************************************************************************************************************************************************
---
---				Name : 		main.lua
---				Purpose :	COMET (Component/Entity Framework for Corona/Lua), version 3.0
---				Created:	30 May 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }

local Comet, Component, Entity 																	-- this to avoid fwd referencing issues.

--- ************************************************************************************************************************************************************************
--//	Comet class. This is the manager of the current set of entities, components and systems.
--- ************************************************************************************************************************************************************************

Comet = Base:new()

--//	Initialise the Comet object

function Comet:initialise()
	self.cm_components = {} 																	-- known components (ref => ref)
	self.cm_entities = {} 																		-- known entities (ref => ref)
	self.cm_invalidComponentList = {} 															-- components whose cached queries are now invalid (ref=>ref)
end 

--//	Delete the Comet object

function Comet:remove() 
	-- TODO: Delete all systems ?
	for k,v in pairs(self.cm_entities) do v:remove() end 										-- remove all entities
	self.cm_components = nil self.cm_invalidComponentList = nil 								-- and tidy up.
	self.cm_entities = nil
end 

--//%	Given either a csv string, or a table of strings, convert it to a table of component references.
--//	@table 		[string/table]		csv strings or table of strings
--//	@return 	[table]				table of component references

function Comet:createList(table)
	local result = {}
	if type(table) == "table" then 																-- is it a table already ?
		for k,v in pairs(table) do result[k] = self:getComponentByName(v) end 					-- copy the components in.
	elseif type(table) == "string" then 														-- is it a string ?
		table = table .. "," 																	-- add a comma for regex
		while table ~= "" do 																	-- dismantle the string into pieces.
			local newComp
			newComp,table = table:match("^([%w%_]+)%,(.*)$") 									-- split about next comma
			result[#result+1] = self:getComponentByName(newComp) 								-- add reference to list
		end
	else
		error("Bad createList() source object")
	end
	return result
end

--//% 	A preprocessor for component list arguments - takes a variety of formats and converts them to a list of component references.
--//	@components [string, Component, table]	A name or CSV Names, a single component, or a list of components.

function Comet:processList(components)
	local result 
	if type(components) == "string" then 														-- if it is a string already ?
		result = self:createList(components)
	elseif type(components) == "table" then 													-- if it is a table ?
		if type(components[1]) == "string" then 												-- table of strings ?
			result = self:createList(components)
		end
		if type(components[1] == "table") then 													-- is it a table of tables ?
			result = components  																-- this for a table of references.
			if result.co_name ~= nil then result = { result } end 								-- this for a single component object.
		end
	end
	if result == nil then
		error("Unknown component list format")
	end
	return result
end 

--//	Find a component by name
--//	@name 	[string]				Name of required component
--//	@return [component]				Component object. Throws error on not found.

function Comet:getComponentByName(name)
	assert(name ~= nil and type(name) == "string","Bad component name") 
	name = name:lower() 																		-- case independent
	assert(self.cm_components[name] ~= nil,"Component does not exist ["..name.."]")				-- check it actually exists
	return self.cm_components[name]
end 

--//% 	When a component is added or removed from the cache, any query featuring it that has been cached becomes invalid.
--//	@component 	[component] 		Component added or removed.

function Comet:invalidateCache(component)
	self.cm_invalidComponentList[component] = component 										-- mark that component as not valid (entity add/removed it.)
end

--//	Create a new component. Uses component.new effectively, but shorthand
--//	@name 		[string] 				Component Name (optional parameter, can be name in source table)
--//	@source 	[table/object]			Table, Class or Instance being used to create the component.

function Comet:newC(name,source)
	return Component:new(self,name,source) 														-- calls the component constructor.
end 

--- ************************************************************************************************************************************************************************
--//	Component Class. This is a Hybrid system so Components and contain Methods, Message Recipients, Constructors, Destructors and anything else you like.
--//	Components are built out of tables containing member variables they use, functions they use, and requires (the components that are required), and 
--// 	a constructor and destructor method (the last three are optional). All methods are called with the first two parameters being self (the entity reference)
--//	and private (the components private members). Components can be constructed simply out of tables, or from classes. Constructors and Destructors do not
--//	take any parameters.
--- ************************************************************************************************************************************************************************

Component = Base:new()

--//	Component constructor. Takes a table containing members, functions, and optionsl require, constructor and destructor methods. Any member or function
--//	preceded with an underscore is not added to the component. 
--//	@comet 		[Comet]					Comet object being added to.
--//	@name 		[string] 				Component Name (optional parameter, can be name in source table)
--//	@source 	[table/object]			Table, Class or Instance being used to create the component.

function Component:initialise(comet,name,info)
	assert(comet ~= nil and type(comet) == "table" and comet.cm_components ~= nil,"Bad Comet")	-- Check the first parameter is a comet.
	if info ~= nil then 																		-- two parameters.
		assert(type(name) == "string","Component name must be a string") 						-- check the first is a string.
		self.co_name = name:lower() 															-- store the name in the component entry.
	else 
		info = name 																			-- otherwise the second parameter is the info structure
	end  																					
	assert(info ~= nil and type(info) == "table","Bad component definition parameter") 			-- check legality.

	self.co_comet = comet 																		-- save reference to commt
	self.co_requires = {} 																		-- list of required components by reference
	self.co_members = {} 																		-- table of members name => default value
	self.co_methods = {} 																		-- table of methods name => function

	self:addInfo(info) 																			-- add basic information from the source object.
	assert(self.co_name ~= nil and type(self.co_name) == "string","Bad component name")			-- check name is a string.
	self.co_name = self.co_name:lower() 														-- make it lower case as we are not case sensitive
	assert(comet.cm_components[self.co_name] == nil,											-- check component name duplicated.
									"Component name duplicated [" .. self.co_name .. "]") 		
	comet.cm_components[self.co_name] = self 													-- add the component into the manager's list of components.
end

--//%	Add the information from the given table to the new component.
--//	@source 	[table/object]			Table, class or instance being used to create it.

function Component:addInfo(info)
	for k,v in pairs(info) do 																	-- scan through the information structure
		if k:sub(1,1) ~= "_" then  																-- if the name does not begin with an underscore
			self:addItem(k,v)  																	-- add it to the component.
		end
	end 
	local mt = getmetatable(info) 																-- get the metatable.
	if mt ~= nil then 																			-- is there a metatable, then unless the coder is doing
		self:addInfo(mt) 																		-- something wierd, it's a superclass, so import those
	end 																						-- methods and members as well.

end

--//%	Add a single item to the new component, can be a table, function, string, number etc.
--//	@name 	[sstring] 					Member/Function etc. name
--//	@value 	[anything] 					What is going in.

function Component:addItem(name,value)
	if type(value) == "function" then 															-- functions are handled specially.
		if name == "constructor" or name == "destructor" then 									-- constructor or destructor ?
			assert(self["co_"..name] == nil,"Duplicate ".."name in component definition") 		-- each must only have one constructor/destructor
			self["co_"..name] = value 															-- store value in constructor/destructor part.
		elseif name ~= "new" and name ~= "initialise" then 										-- do not import new() or initialise() 
			self.co_methods[name] = value 														-- if neither, store in the methods table.
		end
	else
		if name == "requires" then 																-- is it a requires list ?
			self.co_requires = self.co_comet:createList(value) 									-- store a list of components in the requires entry.
		elseif name == "name" then 																-- is it the component name
			self.co_name = value 																-- then store that.
		else
			self.co_members[name] = value 														-- otherwise add it to the members list.
		end
	end 
end 

--//	Convert the component to a string
--//	@return 	[string] 				String representation of component.

function Component:toString()
	local s = "[Component] Name:" .. self.co_name .. " Reference:" .. tostring(self)
	if #self.co_requires > 0 then
		s = s .. " Requires:"
		for _,r in ipairs(self.co_requires) do s = s .. " " .. r.co_name end 
	end
	s = s .. "\nMembers:"
	for k,v in pairs(self.co_members) do s = s .. " " .. k .. "=" .. tostring(v) end
	if self.co_constructor ~= nil then s = s .. "\nConstructor: ".. tostring(self.co_constructor) end
	if self.co_destructor ~= nil  then s = s .. " Destructor: ".. tostring(self.co_destructor) end
	local m = ""
	for k,v in pairs(self.co_methods) do m = m .. " " .. k .. "=" .. tostring(v) end 
	if m ~= "" then s = s .. "\nMethods: " .. m end
	return s
end 

--- ************************************************************************************************************************************************************************
--//	An entity is a collection of components that can have things added to and removed from them arbitrarily to form working entities. An entity is class in its own
--//	right and as such could be subclassed to provide a factory for entities rather than using individual factory methods, or as part of a factory pattern.
--- ************************************************************************************************************************************************************************

Entity = Base:new()

--//	Entity constructor. Takes a parent comet object and a list of components, which is optional - empty entites are allowable, but don't make much sense.
--//	@comet 		[Comet]						comet object
--//	@initial 	[table] 					Initialisation values for members.
--//	@components [string, Component, table]	A name or CSV Names, a single component, or a list of components.

function Entity:initialise(comet,initial,components)
	self.en_components = {} 																	-- a list of components this entity has [comp ref => comp ref]
	self.en_comet = comet 																		-- save reference to comet object
	self.en_memberValues = initial or {} 														-- save the initialisation values.
	comet.cm_entities[self] = self 																-- add into the known entities list.
	if components ~= nil then self:addC(components) end 										-- add the relevant components.
end 

--//	Remove an entire entity. Repeated removes are harmless.

function Entity:remove()
	if self.en_comet == nil then return end 													-- it already has been removed if there is no 'comet' reference.
	for k,v in pairs(self.en_components) do self:removeComponentByReference(v) end 				-- remove all components, call destructors etc.
	self.en_comet.cm_entities[self] = nil 														-- clear reference in comet's entity table.
	self.en_comet = nil self.en_components = nil self.en_memberValues = nil						-- and tidy up.
end 

--//	Add a collection of components (which may take various forms)
--//	@components [string, Component, table]	A name or CSV Names, a single component, or a list of components.
--//	@return 	[self] 						Chainable

function Entity:addC(components)
	components = self.en_comet:processList(components) 											-- convert to useable list.
	for k,v in ipairs(components) do self:addComponentByReference(v) end 						-- and add them all in.
end 

--//	Remove a collection of components, or a component from the entity.
--//	@components [string, Component, table]	A name or CSV Names, a single component, or a list of components.
--//	@return 	[self] 						Chainable

function Entity:remC(components)
	components = self.en_comet:processList(components) 											-- convert to useable list.
	for k,v in ipairs(components) do self:removeComponentByReference(v) end 					-- and remove them all.
end 

--//%	Add a single component by reference
--//	@component 	[component]		Reference to the component to add

function Entity:addComponentByReference(component)
	if self.en_components[component] ~= nil then return end 									-- if it is already there, we do not mind.
	print("Adding",component.co_name)
	self.en_components[component] = component 													-- add it in to the entity list
	-- TODO: Add it in, copying member data and initial data as required.
	self.en_comet:invalidateCache(component) 													-- invalidate the query cache for this component
	if component.co_constructor ~= nil then 														-- call the constructor if there is one.
		self:methodCall(component,component.co_constructor) 
	end 		
end 

--//%	Remove a single component by reference
--//	@component 	[component]		Reference to the component to remove

function Entity:removeComponentByReference(component)
	assert(self.en_components[component] ~= nil,												-- however, we can only remove it once.
			"Component is not present and/or has already been removed [" .. component.co_name.."]")
	print("Removing",component.co_name)
	self.en_components[component] = nil 														-- remove it from the component list.
	if component.co_destructor ~= nil then 														-- call the destructor if there is one.
		self:methodCall(component,component.co_destructor) 
	end 		
	self.en_comet:invalidateCache(component) 													-- invalidate the query cache for this component
end 

--//%	Call an entity method. There are two parameters, the entity and its private informaton
--//	@component 	[component]		Component to call it on.
--//	@method 	[function]		The function to call.

function Entity:methodCall(component,method)
	method(component,self,{})
	-- TODO: Private storage for component.
end 

--//	Convert an entity to a string representation
--//	@return [string]	String representation of entity

function Entity:toString()
	if self.en_components == nil then return "[Entity] <Deleted>" end 
	local s = "[Entity] Components:"
	for k,v in pairs(self.en_components) do s = s .. " " .. v.co_name end 
	s = s .. "\nMembers:"
	return s 
end 

local comet = Comet:new()

local c1 = Component:new(comet,"c1",{ x = 4, y = 3, z = 2, constructor = function(c,e) print("Construct c1",c,e) end, destructor = function(c,e) print("Destroy c1",c,e) end})
local c2 = comet:newC({ name = "c2",a = 4,x2 = 3 })

local c3Class = Base:new()
function c3Class.constructor(c,e) print("Construct c3",c,e) end
function c3Class.destructor(c,e) print("Destruct c3",c,e) end
local c3 = comet:newC("c3",c3Class)

print(c1:toString())
print(c2:toString())

local e1 = Entity:new(comet,{},{c1,c2,c3})
print("C1",c1,"E1",e1,"C3",c3)
print(e1:toString())
e1:remove()
comet:remove()

-- TODO: Member adding and initialisation.
-- TODO: Add private storage code, only on demand.
-- TODO: Then bully test it.
