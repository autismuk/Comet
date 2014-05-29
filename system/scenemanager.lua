--- ************************************************************************************************************************************************************************
---
---				Name : 		scenemanager.lua
---				Purpose :	Manage Scene transitions and state
---				Created:	30 April 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }

--- ************************************************************************************************************************************************************************
--//	A scene has a similar purpose as in Composer or Storyboard - it is a finite state machine with visual objects attached. This defines it as a class, which can 
--//	be extended and methods overwritten - template pattern basically. Each scene has an associated view group, and associated storage (for data)
--//	<BR>The scene lifestyle is split into two chunks - create and destroy messages are tearing up and down the basics - audio, scene backgrounds and other resources 
--//	and may be garbage collected. The other four - pre/post open and pre/post close are used when entering or leaving a scene, either side of the visible
--//	transaction, and should deal with things associated with those events.
--- ************************************************************************************************************************************************************************

local Scene = Base:new()

--//	Constructor (does not use constructor parameters) - sets the scene to an initial non-created state.

function Scene:initialise()
	self.isCreated = false 																	-- no scene created yet.
	self.viewGroup = nil 																	-- there is no new group.
	self.owningManager = nil 																-- it is not owned by a scene manager.
	self.allowGarbageCollection = true 														-- true if can be garbage collected.
	self.storage = {} 																		-- 'protected' storage.
end

--//%	Sets the owning instance of the scene, so it knows who manages it. This is used in methods like gotoScene() so that they can be accessed
--//	from the scene code (using self) rather than mandating a reference to the scene manager
--//	@manager 	[scene mananger]		scene manager object that 'owns' the scene.

function Scene:setManagerInstance(manager) self.owningManager = manager return self end 	-- set the manager instance.

--//	Gets the view group for the current scene
--//	@return [displayGroup]				view group for the scene

function Scene:getViewGroup() return self.viewGroup end 									-- get the view group for this scene.

--//%	Set the visibility state of the scene
--//	@isVisible [boolean]				true if should be visible
--//	@return [Scene] allow chaining

function Scene:setVisible(isVisible) self.viewGroup.isVisible = isVisible return self end 	-- set view group (scene in practice) visibility

--//	Helper method that allows gotoScene() to be called from the scene
--//	@scene 	[Scene Name/Reference] name or index of scene

function Scene:gotoScene(scene) self.owningManager:gotoScene(scene) end 					-- helper function

--//	Helper method to insert display object in view group
--//	@return [Scene] allow chaining
function Scene:insert(object) self.viewGroup:insert(object) return self end 				-- helper function

--//	Protect the current scene against garbage collection
--//	@return [Scene] allow chaining

function Scene:protect() self.allowGarbageCollection = false return self end 				-- set the garbage collection protection flag.

--//%	Method responsible for physically creating the viewgroup for the scene, and calling create if required (e.g. it has been destroyed)

function Scene:_initialiseScene()															-- creates scene if necessary.
	if not self.isCreated then 																-- if not created
		if self.viewGroup == nil then self.viewGroup = display.newGroup() end 				-- create a view group, if needed.
		self.isCreated = true 																-- mark as created.
		self:create() 																		-- call the creation routine.
	end
	self:setVisible(false) 																	-- hide the scene, we don't actually want it yet.
end

--//%	Garbage collect the current scene, or try to. If GC is permitted by the Scene, will call destroy and clear up any outstanding references.
--//	@return [boolean]	true if garbage collection happened.

function Scene:_garbageCollectScene() 														-- destroy scene (can be created) if allowed - freeing up space		
	if self.allowGarbageCollection then
		if self.isCreated then self:destroy() end 											-- destroy if created
		self.isCreated = false 																-- mark as 'not created' so it will recreate if needed again.
		if self.viewGroup ~= nil then display.remove(self.viewGroup) end 					-- remove view group if not created
		self.viewGroup = nil 																-- mark that as nil.
	end
	return self.allowGarbageCollection 														-- return true if was garbage collected.
end

--//%	Brutal version of Garbage Collect - clears everything, nulls everything, destroys the object completely.

function Scene:_destroyScene() 																-- murderdeathkill scene destroyer, just destroys it.
	self.allowGarbageCollection = true 														-- we are deleting this whatever.
	self:_garbageCollectScene() 															-- tidy up the view part
	self.owningManager = nil 																-- remove the reference to the owning manager, the whole thing is going.
end

--//	Template method for retrieving the transition type associated with this scene. It is the outgoing transition that is defined here. Can be overridden to change.
--//	@return [string] 	name of transition to be used when leaving scene.

function Scene:getTransitionType() return "fade" end 										-- override this to change the transition (defined by target scene)

--//	Template method for retrieving the transition time associated with this scene. It is the outgoing transition that is defined here. Can be overriden to change.
--//	@return [number]	time of the transition to the next scene in milliseconds.

function Scene:getTransitionTime() return 500 end 											-- obviously these are independent.

--//	Scene message template. There are six of these, each may be overridden if required.
--//	create is called when the scene is first created, but is not actually shown. This should be background stuff that is used all the time. Scenes can be
--//	destroyed for garbage collection reasons (sends a destroy message) and later created if needed. In this case, the associated data will not be lost.

function Scene:create() end 																-- default methods caused to create etc. scenes

--//	Scene message template. There are six of these, each may be overridden if required.
--//	Called when a scene is being switched to, before the visible transition between scenes

function Scene:preOpen() end

--//	Scene message template. There are six of these, each may be overridden if required.
--//	Called when a scene is being switched to, after the visible transition between scenes

function Scene:postOpen() end

--//	Scene message template. There are six of these, each may be overridden if required.
--//	Called when a scene is being left, before the visible transition between scenes

function Scene:preClose() end

--//	Scene message template. There are six of these, each may be overridden if required.
--//	Called when a scene is being left, after the visible transition between scenes

function Scene:postClose() end

--//	Scene message template. There are six of these, each may be overridden if required.
--//	Called when a scene is about to be garbage collected or terminally destroyed (in which case it cannot be recreated, it is dead-dead)

function Scene:destroy() end

--- ************************************************************************************************************************************************************************
--//	The delay scene automatically transits to the next scene without any coding or user intervention. It is used for inbetween scenes that only last for a specific
--//	time.
--- ************************************************************************************************************************************************************************

local DelayScene = Scene:new()

--//%	EnterFrame handler. If sufficient time has elapsed, it will go to the next scene
--//	@e [event object]		Event for enterFrame, from Corona
--//	@elapsed [number]		Elapsed time since scene was opened (does not include the transition)

function DelayScene:enterFrame(e,elapsed) 
	if elapsed > self:sceneDelay() then  													-- if delay time has elapsed
		self:gotoScene(self:nextScene()) 													-- go to the next scene.
	end
end

--//	Override this to define the next scene
--//	@return [string]		Name of next scene

function DelayScene:nextScene() error "DelayScene is an abstract class." end 				-- default target scene

--//	Override this to determine how long the scene stays on.
--//	@return [number]		Visible time in milliseconds

function DelayScene:sceneDelay() return 1000 end 											-- default time.

--- ************************************************************************************************************************************************************************
--//	The OverlayScene operates like other scenes, in that it is 'goto'ed but it leaves the remnants of the scene below, by default dimmed, and you return to the
--//	scene using closeOverlay(). It is designed for popups over the display.
--//	A scene which is overlaid does not receive close/open messages when the overlay opens and closes, it behaves as if the overlay did not occur.
--- ************************************************************************************************************************************************************************

local OverlayScene = Scene:new()

OverlayScene.isOverlay = true 																-- return true if operates as overlay.

--//%	The initialise scene is overridden. The main purpose is to create a rectangle over the current scene, which can 'catch' touch and tap events so they
--//	do not filter through to the screen below.

function OverlayScene:_initialiseScene()
	local wasCreated = self.isCreated 														-- remember if the super call created it.
	Scene._initialiseScene(self) 															-- call the super class (must find a better way !)
	if not wasCreated and self:isModal() then 												-- if it wasn't created, then it will have been now - blocker if modal.
		local blockRect = display.newRect(0,0,display.contentWidth,display.contentHeight)	-- create a rectangle
		blockRect.anchorX,blockRect.anchorY = 0,0
		blockRect:setFillColor( 0,0,0 )
		self:insert(blockRect) 																-- insert at the back of the view group
		blockRect:toBack()
		blockRect:addEventListener( "tap", function(e) return true end) 					-- make it catch all touch/tap events.
		blockRect:addEventListener( "touch", function(e) return true end )
		blockRect.alpha = self:getOverlayAlpha() 											-- you can change the darkening.
	end
end

--//	Helper method which closes the overlay, passing the request on to the Scene Manager instance.

function OverlayScene:closeOverlay() self.owningManager:_closeOverlay() end 				-- passes close overlay to scene manager.

--//	Method which determines if the current dialog is modal (e.g. does it trap touch and tap events, disabling the layer below)
--//	@return [boolean]		true if it is modal

function OverlayScene:isModal() return false end

--//	Simple subclass which extends Overlay scene to be modal.

local ModalOverlayScene = OverlayScene:new()												-- same thing but modal overlay.

--//	Override modal test to return true.
--//	@return [boolean]		true if it is modal, which it is :)

function ModalOverlayScene:isModal() return true end

--//	Determines how dark you want the overlay background scene to be - 0 makes this completely transparent if you override it.
--//	@return [number]		darkness of the overlaid scene.

function ModalOverlayScene:getOverlayAlpha() return 0.6 end 								-- this makes the background 'dark' - making this zero makes it normal

--- ************************************************************************************************************************************************************************
--//	The scene manager class is responsible for managing scenes (there's a surprise) - it keeps a list of scenes by name, switches between them on command, destroys them
--//	all on request and handles the transitions. It locks out transitions when one is taking place, so you cannot start a new transition until the old one has finished.
--//	Additionally, if a scene has an enterFrame() method this will be called every frame with the normal parameter and an additional parameter, the time in milliseconds
--// 	since the scene started. This can be seen in the delay scene subclass. This class is a singleton
--- ************************************************************************************************************************************************************************

local SceneManager = Base:new()

SceneManager.transitionInProgress = false 													-- used to lock out gotoScreen when one is in progress.

--//	Constructor - accesses the transition manager, clears the scene store and current scene
--//	@transitionManager [transition manager] will use this instance of transition manager if provided.

function SceneManager:initialise(transitionManager)
	if transitionManager == nil then transitionManager = require("system.transitions") end 	-- pull in Transition Manager default if not specified.
	self.transitionManager = transitionManager 												-- save transition manager reference.
	self.sceneStore = {} 																	-- hash of scene name -> scene event.object1
	self.currentScene = nil 																-- No current scene.
	self.isEnterFrameEventEnabled = false 													-- true if enter frame event on.
end

SceneManager:initialise() 																	-- make it a real instance rather than a prototype

--//	Destroys the whole shebang - enter frame off, close the current scene and throwing everything away terminally.

function SceneManager:destroy()
	self:_setEnableEnterFrameEvent(false) 													-- disable enter frame runtime listener if on.
	if self.currentScene ~= nil then 														-- If there is a current scene 
		self.currentScene:preClose() 														-- run the shutdown sequence in a peremptory manner
		self.currentScene:setVisible(false)
		self.currentScene:postClose()
		self.currentScene = nil 															-- remove the references
		self.previousScene = nil
	end
	for _,ref in pairs(self.sceneStore) do self.sceneStore[ref]:_destroyScene() end 		-- destroy all the scenes completely.
	self.sceneStore = nil 																	-- and remove remaining references
	self.transitionManager = nil
end

--//%	Enable or disable the enter frame event. The frame status is tracked so it will not be added twice (say)
--//	@newStatus [boolean]	Whether or not the enterFrame event is applied to this object

function SceneManager:_setEnableEnterFrameEvent(newStatus) 									-- turn enter-frame off and on.
	if newStatus ~= self.isEnterFrameEventEnabled then 										-- status changed.
		self.isEnterFrameEventEnabled = newStatus 											-- update status
		if newStatus then  Runtime:addEventListener( "enterFrame", self )					-- add or remove event listener accordingly.
		else 			   Runtime:removeEventListener( "enterFrame", self )
		end
	end
end

--//%	Enterframe event handler. Dispatches to current scene, providing it has an enterFrame method to handle it , and a transition is not
--//	in progress. Also adds a time in milliseconds since the scene opened.
--//	@e [event object]	Corona's enter frame event.
function SceneManager:enterFrame(e) 														-- handle enter frame listener owned by Scene Manager.
	if self.currentScene ~= nil and self.isEnterFrameEventEnabled and 						-- if a scene, enterFrame is on, no transition is happening
	   not SceneManager.transitionInProgress and self.currentScene.enterFrame ~= nil then 	-- and there's an enterFrame function then call it.
			self.currentScene:enterFrame(e,e.time-self.sceneStartTime)
	end
end

--//	Tell the SceneManager about a new scene.
--//	@sceneName [string]		Name of scene, case insensitive
--//	@sceneInstance [Scene]	Scene instance to be added, must be a Scene or subclass instance.

function SceneManager:append(sceneName,sceneInstance)
	sceneName = sceneName:lower() 															-- make it lower case.
	assert(self.sceneStore[sceneName] == nil,"Scene "..sceneName.." has been redefined") 	-- check it is not a duplicate.
	assert(sceneInstance ~= nil,"No scene instance provided.") 								-- check instance is provided.
	self.sceneStore[sceneName] = sceneInstance 												-- store the instance.
	sceneInstance:setManagerInstance(self) 													-- tell the scene who its parent is.
	if sceneInstance.enterFrame ~= nil then self:_setEnableEnterFrameEvent(true) end 		-- enable tick if a scene has enterFrame method
	return self
end

--//	Retrieve the current scene
--//	@return [Scene]	get the current scene instance (not name), may be nil at the start before the first gotoScene()

function SceneManager:getCurrentScene()
	return self.currentScene 																-- retrieve the current scene.
end

--//	Go to a new scene. This will be blocked if a transition is taking place.
--//	This sets everything up, sending preOpen to the new Scene, preClose to the current (creating the new scene if required, which will
--//	cause a create message), then it transitions between the two scenes using the new scenes transition information
--//
--//	@scene [Scene/String]	Name of scene, or reference to scene, to which you transition.

function SceneManager:gotoScene(scene)
	if SceneManager.transitionInProgress then return end									-- cannot do a transition when one is happening.
	SceneManager.transitionInProgress = true

	if self.currentScene ~= nil then 
		assert(not self.currentScene.isOverlay,"Cannot transition when overlay visible") 	-- can't do a gotoScene() when current scene is overlay.
	end

	if type(scene) == "string" then 														-- you can do it by reference or by name
		scene = scene:lower() 																-- lower case names
		assert(self.sceneStore[scene] ~= nil,"Scene "..scene.." is not known")				-- check it is known
		scene = self.sceneStore[scene] 														-- now it's a reference.
	end
	assert(type(scene) == "table","Bad parameter to gotoScene()")							-- check we have a table.

	scene:_initialiseScene() 																-- create scene, if necessary.
	scene:preOpen() 																		-- and we are about to open the new scene as part of the transition.
	self.newScene = scene 																	-- save a reference to the new scene

	local currentViewGroup = nil 															-- get current scene's view group, if there is one.
	if self.currentScene ~= nil and not scene.isOverlay then 								-- if there is a scene and we are not transitioning to an overlay
		self.currentScene:preClose() 														-- call pre-close (i.e. about to fade out the scene)
		currentViewGroup = self.currentScene:getViewGroup()
	end

	self.transitionManager:execute(scene:getTransitionType(),self, 							-- do the transition.
									currentViewGroup,scene:getViewGroup(),
									scene:getTransitionTime())

end

--//%		Method used to close overlay, called from the scene. Like gotoScene() does not function in a transition. 

function SceneManager:_closeOverlay()
	if SceneManager.transitionInProgress then return end									-- cannot do a transition when one is happening.
	SceneManager.transitionInProgress = true
	assert(self.currentScene ~= nil and self.currentScene.isOverlay,"Overlay is not present")
	self.currentScene:preClose()															-- send pre close to overlay.
	self.transitionManager:execute(self.currentScene:getTransitionType(),self,				-- start a transition to close the overlay.
									self.currentScene:getViewGroup(),nil,
									self.currentScene:getTransitionTime())
end

--//%	Method call when the transaction is completed. Two seperate parts - one when coming from an overlay, where it resurrects the 
--//	previous scene, and one coming from another scene, where it sends it post close, hides it, and sends the new scene post open.

function SceneManager:transitionCompleted()													-- this is called when a transition has completed.

	if self.currentScene ~= nil and self.currentScene.isOverlay then 						-- currently in overlay
		self.currentScene:postClose() 														-- post close to overlay
		self.currentScene:setVisible(false) 												-- and hide it.
		self.currentScene = self.previousScene 												-- go to the previous scene.
		self.newScene = nil
	else
		if self.currentScene ~= nil and not self.newScene.isOverlay then 					-- if there was a scene we are leaving.
			self.currentScene:postClose() 													-- call the post close scene
			self.currentScene:setVisible(false) 											-- and hide it.
		end

		self.previousScene = self.currentScene 												-- save previous scene
		self.currentScene = self.newScene 													-- update the current scene member variable
		self.newScene = nil 																-- remove the reference to the new scene.
		self.currentScene:postOpen()  														-- about to open, send that message.
		self.sceneStartTime = system.getTimer() 											-- remember when this scene started.
	end
	SceneManager.transitionInProgress = false 												-- transition no longer in progress.
end

return { SceneManager = SceneManager, Scene = Scene, DelayScene = DelayScene, OverlayScene = OverlayScene, ModalOverlayScene = ModalOverlayScene }

-- TODO: Clean up (GC) via Scene Manager, NOT the current scene obviously.
