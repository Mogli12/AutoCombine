--***************************************************************
--
-- AutoCombine
-- 
-- version 4.000 by mogli (biedens)
-- 2015/06/09
--
--***************************************************************

local AutoCombineVersion=4.091

-- allow modders to include this source file together with mogliBase.lua in their mods
if AutoCombine == nil or AutoCombine.version == nil or AutoCombine.version < AutoCombineVersion then

--***************************************************************
source(Utils.getFilename("mogliBase.lua", g_currentModDirectory))
_G[g_currentModName..".mogliBase"].newClass( "AutoCombine", "acParameters" )
--***************************************************************
source(Utils.getFilename("mogliHud.lua", g_currentModDirectory))
_G[g_currentModName..".mogliHud"].newClass( "AutoCombineHud", "acHud" )
--***************************************************************

AutoCombine.version = AutoCombineVersion

------------------------------------------------------------------------
-- prerequisitesPresent
------------------------------------------------------------------------
function AutoCombine.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Hirable, specializations) and SpecializationUtil.hasSpecialization(Steerable, specializations)
end


------------------------------------------------------------------------
-- load
------------------------------------------------------------------------
function AutoCombine:load(xmlFile)

	self.acOnBackCollisionTrigger    = AutoCombine.acOnBackCollisionTrigger
	self.acOnCombineCollisionTrigger = AutoCombine.acOnCombineCollisionTrigger
	self.acSetState                  = AutoCombine.mbSetState

	-- for courseplay  
	self.acNumCollidingVehicles = 0
	self.acIsCPStopped          = false
	self.acTurnStage            = 0
	self.acAxisSide             = 0	
	self.acNodeIsLinked         = false
	self.acButtons              = {}
	self.acParameters           = {}
	
	self.acParameters.rightAreaActive = false

	AutoCombine.registerState( self, "upNDown"        , false, nil                             , true )
	AutoCombine.registerState( self, "otherCombine"   , false, nil                             , true )
	AutoCombine.registerState( self, "waitMode"       , false, nil                             , true )
	AutoCombine.registerState( self, "leftAreaActive" , true , AutoCombine.onSetLeftAreaActive , true )
  AutoCombine.registerState( self, "enabled"        , true , nil                             , true )
  AutoCombine.registerState( self, "noReverse"      , false, nil                             , true )
	AutoCombine.registerState( self, "turnOffset"     , 0    , AutoCombine.onChangeTurnOffset  , true )
	AutoCombine.registerState( self, "widthOffset"    , 0    , AutoCombine.onChangeWidthOffset , true )
	AutoCombine.registerState( self, "speed"          , 10   , nil                             , true )
	AutoCombine.registerState( self, "noSteering"     , false, nil                             , true )
	
	AutoCombine.registerState( self, "CPSupport"      , false )
	
	AutoCombine.registerState( self, "pause"          , false )	
	AutoCombine.registerState( self, "turnStage"      , 0    , AutoCombine.onSetTurnStage )
	AutoCombine.registerState( self, "engineStatus"   , 0    , AutoCombine.onSetEngineStatus )

	self.acDeltaTimeoutWait    = math.max(Utils.getNoNil( self.waitForTurnTimeout, 1500 ), 1000 ) 
	self.acDeltaTimeoutRun     = math.max(Utils.getNoNil( self.driveBackTimeout  , 1000 ),  300 )
	self.acDeltaTimeoutStop    = 4 * math.max(Utils.getNoNil( self.turnStage1Timeout , 20000), 10000)
	self.acDeltaTimeoutStart   = math.max(Utils.getNoNil( self.turnTimeoutLong   , 6000 ), 4000 )
	self.acDeltaTimeoutNoTurn  = math.max(Utils.getNoNil( self.turnStage4Timeout , 2000 ), 1000 )
	self.acSteeringSpeed       = Utils.getNoNil( self.aiSteeringSpeed, 0.001 )
	self.acRecalculateDt       = 0
	self.acTurn2Outside        = false
	self.acDirectionBeforeTurn = {}
	self.acCollidingVehicles   = {}
	self.acCollidingCombines   = {}

	self.acI3D = getChild(Utils.loadSharedI3DFile("AutoCombine.i3d", AutoCombine.baseDirectory),"AutoCombine")
	
	self.acBackTrafficCollisionTrigger   = getChild(self.acI3D,"backCollisionTrigger")
	self.acOtherCombineCollisionTriggerL = getChild(self.acI3D,"otherCombColliTriggerL")
	self.acOtherCombineCollisionTriggerR = getChild(self.acI3D,"otherCombColliTriggerR")
	self.acBorderDetected = nil	
	self.acFruitsDetected = nil
	
  self.acAutoRotateBackSpeedBackup = self.autoRotateBackSpeed	

	self.acRefNode = self.aiTreshingDirectionNode

	if      self.articulatedAxis ~= nil 
			and self.articulatedAxis.componentJoint ~= nil
      and self.articulatedAxis.componentJoint.jointNode ~= nil 
			and self.articulatedAxis.rotMax then	
		self.acRefNode = self.components[self.articulatedAxis.componentJoint.componentIndices[2]].node
	--self.acRefNode = getParent( self.articulatedAxis.componentJoint.jointNode )
		self.acRefNodeCorr = createTransformGroup( "acRefNodeCorr" )
		link( getParent( self.articulatedAxis.componentJoint.jointNode ), self.acRefNodeCorr )
		setTranslation( self.acRefNodeCorr, 0, 0, 0 )
		setRotation( self.acRefNodeCorr, 0, 0, 0 )
	else
		self.acRefNodeCorr = self.acRefNode
	end
	
	self.acTransNode = createTransformGroup( "acTransNode" )
	self.acRotNode   = createTransformGroup( "acRotNode" )
	link( self.acRefNodeCorr, self.acTransNode )
	link( self.acTransNode, self.acRotNode )
	setTranslation( self.acTransNode, 0, 0, 0 )
	setTranslation( self.acRotNode, 0, 0, 0 )
	setRotation( self.acTransNode, 0, 0, 0 )
	setRotation( self.acRotNode, 0, 0, 0 )


	-- ackermann steering
	self.acCenterX = nil
	self.acCenterZ = nil
	local rotCenterWheel1 = getXMLInt(xmlFile, "vehicle.ackermannSteering#rotCenterWheel1");
	if rotCenterWheel1 ~= nil and self.wheels[rotCenterWheel1+1] ~= nil then
		self.acCenterX,_,self.acCenterZ = AutoCombine.getRelativeTranslation( self.acRefNode, self.wheels[rotCenterWheel1+1].repr )
		--self.acCenterX = self.wheels[rotCenterWheel1+1].positionX;
		--self.acCenterZ = self.wheels[rotCenterWheel1+1].positionZ;
		local rotCenterWheel2 = getXMLInt(xmlFile, "vehicle.ackermannSteering#rotCenterWheel2");
		if rotCenterWheel2 ~= nil and self.wheels[rotCenterWheel2+1] ~= nil then
			local x,_,z = AutoCombine.getRelativeTranslation( self.acRefNode, self.wheels[rotCenterWheel2+1].repr )
			self.acCenterX = ( self.acCenterX + x )*0.5 --(self.acCenterX+self.wheels[rotCenterWheel2+1].positionX)*0.5;
			self.acCenterZ = ( self.acCenterZ + z )*0.5 --(self.acCenterZ+self.wheels[rotCenterWheel2+1].positionZ)*0.5;
		end
	else
		local centerNode, rootNode = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.ackermannSteering#rotCenterNode"));
		if centerNode ~= nil then
			self.acCenterX,_,self.acCenterZ = AutoCombine.getRelativeTranslation( self.acRefNode, centerNode )--localToLocal(centerNode, rootNode, 0,0,0);
		else
			local p = Utils.getVectorNFromString(getXMLString(xmlFile, "vehicle.ackermannSteering#rotCenter", 2));
			if p ~= nil then
				local x,_,z = AutoCombine.getRelativeTranslation( self.acRefNode, self.rootNode )
				self.acCenterX = x + p[1];
				self.acCenterZ = z + p[2];
			end
		end
	end
	
end

------------------------------------------------------------------------
-- initMogliHud
------------------------------------------------------------------------
function AutoCombine:initMogliHud()
	if self.acMogliInitDone then
		return
	end
	self.acMogliInitDone = true

	AutoCombineHud.init( self, AutoCombine.baseDirectory, "AutoCombineHud", 0.4,  "AC_COMBINE_TEXTHELPPANELON", "AC_COMBINE_TEXTHELPPANELOFF", InputBinding.AC_COMBINE_HELPPANEL, 0.395, 0.0108, 5, 3 )
	AutoCombineHud.setTitle( self, "AC_COMBINE_VERSION" )
	
	AutoCombineHud.addButton(self, "dds/off.dds",            "dds/on.dds",           AutoCombine.onStart,       AutoCombine.evalStart,     1,1, "HireEmployee", "DismissEmployee", nil, AutoCombine.getStartImage )
	
	AutoCombineHud.addButton(self, "dds/no_wait.dds",        "dds/wait.dds",         AutoCombine.setWait,       AutoCombine.evalWait,      2,1, "AC_COMBINE_WAITMODE_OFF", "AC_COMBINE_WAITMODE_ON" )	
	AutoCombineHud.addButton(self, "dds/inactive_left.dds",  "dds/active_left.dds",  AutoCombine.setAreaLeft,   AutoCombine.evalAreaLeft,  3,1, "AC_COMBINE_TXT_ACTIVESIDERIGHT", "AC_COMBINE_TXT_ACTIVESIDELEFT" )
	AutoCombineHud.addButton(self, "dds/inactive_right.dds", "dds/active_right.dds", AutoCombine.setAreaRight,  AutoCombine.evalAreaRight, 4,1, "AC_COMBINE_TXT_ACTIVESIDELEFT", "AC_COMBINE_TXT_ACTIVESIDERIGHT" )
	AutoCombineHud.addButton(self, "dds/next.dds",           "dds/no_next.dds",      AutoCombine.nextTurnStage, AutoCombine.evalTurnStage, 5,1, "AC_COMBINE_TXT_NEXTTURNSTAGE", nil )
	                            
	AutoCombineHud.addButton(self, "dds/ai_combine.dds",     "dds/auto_combine.dds", AutoCombine.onEnable,      AutoCombine.evalEnable,    1,2, "AC_COMBINE_TXT_STOP", "AC_COMBINE_TXT_START" )
	AutoCombineHud.addButton(self, "dds/no_distance.dds",    "dds/distance.dds",     AutoCombine.setOtherCombine,AutoCombine.evalOtherCombine, 2,2, "AC_COMBINE_COLLISIONTRIGGERMODE_OFF", "AC_COMBINE_COLLISIONTRIGGERMODE_ON" )	
	AutoCombineHud.addButton(self, "dds/no_uturn2.dds",      "dds/uturn.dds",        AutoCombine.setUTurn,     AutoCombine.evalUTurn,      3,2, "AC_COMBINE_UTURN_OFF", "AC_COMBINE_UTURN_ON") 
	AutoCombineHud.addButton(self, "dds/reverse.dds",        "dds/no_reverse.dds",   AutoCombine.setNoReverse, AutoCombine.evalNoReverse,  4,2, "AC_COMBINE_REVERSE_ON", "AC_COMBINE_REVERSE_OFF")
--AutoCombineHud.addButton(self, "dds/no_cp.dds",          "dds/cp.dds",           AutoCombine.setCPSupport, AutoCombine.evalCPSupport,  5,2, "AC_COMBINE_TXT_CP_OFF", "AC_COMBINE_TXT_CP_ON" )

	AutoCombineHud.addButton(self, "dds/bigger.dds",         nil,                AutoCombine.setWidthUp,   nil, 1,3, "AC_COMBINE_WIDTH_OFFSET", nil, AutoCombine.getWidth)
	AutoCombineHud.addButton(self, "dds/smaller.dds",        nil,                AutoCombine.setWidthDown, nil, 2,3, "AC_COMBINE_WIDTH_OFFSET", nil, AutoCombine.getWidth)
	AutoCombineHud.addButton(self, "dds/forward.dds",        nil,                AutoCombine.setForward,   nil, 3,3, "AC_COMBINE_TURN_OFFSET", nil, AutoCombine.getTurnOffset)
	AutoCombineHud.addButton(self, "dds/backward.dds",       nil,                AutoCombine.setBackward,  nil, 4,3, "AC_COMBINE_TURN_OFFSET", nil, AutoCombine.getTurnOffset)
	AutoCombineHud.addButton(self, "dds/auto_steer_off.dds", "dds/auto_steer_on.dds",AutoCombine.onAutoSteer,  AutoCombine.evalAutoSteer, 5,3, "AC_AUTO_STEER_ON", "AC_AUTO_STEER_OFF", nil, AutoCombine.getAutoSteerImage )
	
end

------------------------------------------------------------------------
-- draw
------------------------------------------------------------------------
function AutoCombine:draw()

	if self.acMogliInitDone then
		AutoCombineHud.draw(self,self.acLCtrlPressed or self.acLAltPressed)
	elseif not ( self.acLCtrlPressed ) then
		g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_COMBINE_TEXTHELPPANELON"), InputBinding.AC_COMBINE_HELPPANEL)
	end
	if      self.acParameters ~= nil
			and self.acHud        ~= nil 
			and self.acHud.Title  ~= nil
			and self.acHud.Title  ~= ""
			and not ( self.acHud.GuiActive )
			and self.acParameters.enabled 
			and ( self.isAIThreshing or self.acTurnStage >= 97 ) then

		setTextAlignment(RenderText.ALIGN_LEFT)
		setTextBold(true)		
		if self.acHud.Status == 0 then
			setTextColor(1,1,1,1)
		elseif self.acHud.Status == 1 then
			setTextColor(0,1,0,1)
		elseif self.acHud.Status == 2 then
			setTextColor(1,1,0,1)
		else
			setTextColor(1,0.5,0,1)
		end		
		renderText(self.acHud.TextPosX, self.acHud.TextPosY, self.acHud.TextSize ,self.acHud.Title)		
		setTextBold(false)		
		setTextColor(1,1,1,1)
	end
	
	if self.acLCtrlPressed then
		if      not self.isAIThreshing 
				and self.allowsThreshing or self:canStartAIThreshing() then
			if self.acTurnStage >= 97 then
				g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_AUTO_STEER_OFF"),InputBinding.AC_AUTO_STEER)
			else
				g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_AUTO_STEER_ON"), InputBinding.AC_AUTO_STEER)
			end
		end
		if self.acParameters.enabled then
			g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_COMBINE_TXT_START"), InputBinding.AC_COMBINE_ENABLE)
		else
			g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_COMBINE_TXT_STOP"), InputBinding.AC_COMBINE_ENABLE)
		end
	elseif self.acLAltPressed then
		if self.acParameters.upNDown then
			g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_COMBINE_UTURN_ON"), InputBinding.AC_COMBINE_UTURN_ON_OFF)
		else
			g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_COMBINE_UTURN_OFF"), InputBinding.AC_COMBINE_UTURN_ON_OFF)
		end
		if self.acParameters.noSteering then
			g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_COMBINE_STEERING_OFF"), InputBinding.AC_COMBINE_STEERING)
		else
			g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_COMBINE_STEERING_ON"), InputBinding.AC_COMBINE_STEERING)
		end
	else
		if self.acParameters.enabled or self.acTurnStage >= 97 then
			if self.acParameters.rightAreaActive then
				g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_COMBINE_TXT_ACTIVESIDERIGHT"), InputBinding.AC_COMBINE_SWAP_SIDE)
			else
				g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_COMBINE_TXT_ACTIVESIDELEFT"), InputBinding.AC_COMBINE_SWAP_SIDE)
			end
		end
	end
	
	if self.acParameters.pause then
		g_currentMission:addHelpButtonText(AutoCombineHud.getText("AC_COMBINE_CONTINUE"), InputBinding.TOGGLE_CRUISE_CONTROL)
	end
	
	--if self.aiThreshingTargetX ~= nil then
	--	local x, y, z
	--	x = self.aiThreshingTargetX
	--	z = self.aiThreshingTargetZ
	--	y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
	--	drawDebugLine(  x, y, z, 0,1,0,x, y+2, z, 0,1,0);
	--	drawDebugPoint( x, y+2, z	, 1, 1, 1, 1 )
  --
	--	x,_,z = getWorldTranslation( self.aiTreshingDirectionNode )
	--	y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
	--	drawDebugLine(  x, y, z, 0,0,1,x, y+2, z, 0,0,1);
	--	drawDebugPoint( x, y+2, z	, 1, 1, 1, 1 )
	--end
end

------------------------------------------------------------------------
-- onLeave
------------------------------------------------------------------------
function AutoCombine:onLeave()
	if self.acMogliInitDone then
		AutoCombineHud.onLeave(self)
	end
end

------------------------------------------------------------------------
-- onEnter
------------------------------------------------------------------------
function AutoCombine:onEnter()
	if self.acMogliInitDone then
		AutoCombineHud.onEnter(self)
	end
end

------------------------------------------------------------------------
-- mouseEvent
------------------------------------------------------------------------
function AutoCombine:mouseEvent(posX, posY, isDown, isUp, button)
	if self.isEntered and self.isClient and self.acMogliInitDone then
		AutoCombineHud.mouseEvent(self, posX, posY, isDown, isUp, button)	
	end
end

------------------------------------------------------------------------
-- delete
------------------------------------------------------------------------
function AutoCombine:delete()
	if self.acMogliInitDone then
		AutoCombineHud.delete(self)
	end
	Utils.releaseSharedI3DFile("AutoCombine.i3d", AutoCombine.baseDirectory, true)
end

------------------------------------------------------------------------
-- parameter change callbacks
------------------------------------------------------------------------
function AutoCombine:onSetLeftAreaActive( old, new, noEventSend )
	self.acParameters.leftAreaActive  = new
	self.acParameters.rightAreaActive = not new
end

function AutoCombine:onChangeTurnOffset( old, new, noEventSend ) 
	self.acParameters.turnOffset = new
	self.acDimensions = nil
end

function AutoCombine:onChangeWidthOffset( old, new, noEventSend )
	self.acParameters.widthOffset = new
	self.acDimensions = nil
end

function AutoCombine:onSetTurnStage( old, new, noEventSend ) 
	self.acParameters.turnStage = new
	if not self.isServer then
		self.acTurnStage = new
	end
end
	                  
function AutoCombine:onSetEngineStatus( old, new, noEventSend ) 
	self.acParameters.engineStatus = new
	if self.acMogliInitDone then
		AutoCombineHud.setStatus( self, new )		
	end
end
	
------------------------------------------------------------------------
-- mouse event callbacks
------------------------------------------------------------------------
function AutoCombine:showGui(on)
	if on then
		if self.acMogliInitDone == nil or not self.acMogliInitDone then
			AutoCombine.initMogliHud(self)
		end
		AutoCombineHud.showGui(self,true)
	elseif self.acMogliInitDone then
		AutoCombineHud.showGui(self,false)
	end
end

function AutoCombine:evalUTurn()
	return not self.acParameters.upNDown
end

function AutoCombine:setUTurn(enabled)
	self:acSetState( "upNDown", enabled )
end

function AutoCombine:evalWait()
	return not self.acParameters.waitMode
end

function AutoCombine:setWait(enabled)
	self:acSetState( "waitMode", enabled )
end

function AutoCombine:evalAreaLeft()
	return not self.acParameters.leftAreaActive
end

function AutoCombine:setAreaLeft(enabled)
	if not enabled then return end
	self:acSetState( "leftAreaActive", enabled )
end

function AutoCombine:evalAreaRight()
	return not self.acParameters.rightAreaActive
end

function AutoCombine:setAreaRight(enabled)
	if not enabled then return end
	self:acSetState( "leftAreaActive", not enabled )
end

function AutoCombine:evalStart()
	return not self.isAIThreshing or not self:canStartAIThreshing()
end

function AutoCombine:onStart(enabled)
  if self.isAIThreshing and not enabled then
    self:stopAIThreshing()
  elseif self:canStartAIThreshing() and enabled then
    self:startAIThreshing()
  end
end

function AutoCombine:getStartImage()
	if self.isAIThreshing then
		return "dds/on.dds"
	elseif self:canStartAIThreshing() then
		return "dds/off.dds"
	end
	return "dds/empty.dds"
end

function AutoCombine:evalEnable()
	return not self.acParameters.enabled
end

function AutoCombine:onEnable(enabled)
	if not self.isAIThreshing then
		self:acSetState( "enabled", enabled )
	end
end

function AutoCombine:evalOtherCombine()
	return not self.acParameters.otherCombine
end

function AutoCombine:setOtherCombine(enabled)
	self:acSetState( "otherCombine", enabled )
end

function AutoCombine:evalNoReverse()
	return not self.acParameters.noReverse
end

function AutoCombine:setNoReverse(enabled)
	self:acSetState( "noReverse", enabled )
end

function AutoCombine:setWidthUp()
	self:acSetState( "widthOffset", self.acParameters.widthOffset + 0.125 )
end

function AutoCombine:setWidthDown()
	self:acSetState( "widthOffset", self.acParameters.widthOffset - 0.125 )
end

function AutoCombine:getWidth(old)
	new = string.format(old..": %0.2fm",self.acParameters.widthOffset+self.acParameters.widthOffset)
	return new
end

function AutoCombine:setForward()
	self:acSetState( "turnOffset", self.acParameters.turnOffset + 0.25 )
end                                               

function AutoCombine:setBackward()               
	self:acSetState( "turnOffset", self.acParameters.turnOffset - 0.25 )
end

function AutoCombine:getTurnOffset(old)
	new = string.format(old..": %0.2fm",self.acParameters.turnOffset)
	return new
end

function AutoCombine:evalTurnStage()
	if self.acParameters.enabled then
		if     self.acTurnStage == 2 
				or self.acTurnStage == 12
				or self.acTurnStage == 15
				or self.acTurnStage == 17
				or self.acTurnStage == 18 then
			return true
		end
--	else
--		if self.turnStage > 0 and self.turnStage < 4 then
--			return true
--		end
	end
	
	return false
end

function AutoCombine:nextTurnStage()
	AutoCombine.setNextTurnStage(self)
end

function AutoCombine:evalCPSupport()
	return not self.acParameters.CPSupport
end

function AutoCombine:setCPSupport(enabled)
	self:acSetState( "CPSupport", enabled )
end

function AutoCombine:getAutoSteerImage()
	if self.acTurnStage >= 97 then
		return "dds/auto_steer_on.dds"
	elseif not self.isAIThreshing and self:canStartAIThreshing() then
		return "dds/auto_steer_off.dds"
	end
	return "dds/empty.dds"
end

function AutoCombine:evalAutoSteer()
	return self.isAIThreshing or self.acTurnStage < 97 or not ( self:canStartAIThreshing() )
end

function AutoCombine:onAutoSteer(enabled)
	if self.isAIThreshing then
		if self.acTurnStage >= 97 then
			self.acTurnStage   = 0
		end
	elseif self.canStartAIThreshing ~= nil and enabled and self.isMotorStarted then
		if self:canStartAIThreshing() then
			for _,implement in pairs(self.attachedImplements) do
				if implement.object ~= nil then
					if implement.object.attacherJoint.needsLowering and implement.object.aiNeedsLowering then
						self:setJointMoveDown(implement.jointDescIndex, true, true)
					end;
					implement.object:aiTurnOn();
				end
			end;
			if self.threshingStartAnimation ~= nil and self.playAnimation ~= nil then
				self:playAnimation(self.threshingStartAnimation, self.threshingStartAnimationSpeedScale, nil, true);
			end

			self:setIsTurnedOn(true, true);
			self.waitingForDischarge = false;
			self.waitingForWeather = false;
		end
		self.acTurnStage   = 98
		self.acRotatedTime = 0
	else
		if self.acTurnStage >= 97 then
			self:setIsTurnedOn(false, true);
			for _,implement in pairs(self.attachedImplements) do
				if implement.object ~= nil then
					if implement.object.attacherJoint.needsLowering and implement.object.aiNeedsLowering then
						self:setJointMoveDown(implement.jointDescIndex, false, true)
					end;
					implement.object:aiTurnOff();
				end
			end;
			self.driveBackPosX = nil;
			self.waitingForDischarge = false;
			self.waitingForWeather = false;
		end
		self.acTurnStage   = 0
    self.stopMotorOnLeave = true
    self.deactivateOnLeave = true
	end
end

------------------------------------------------------------------------
-- keyEvent
------------------------------------------------------------------------
function AutoCombine:keyEvent(unicode, sym, modifier, isDown)
	if self.isEntered and self.isClient then
		if sym == Input.KEY_lctrl then
			self.acLCtrlPressed = isDown
		end
		if sym == Input.KEY_lalt then
			self.acLAltPressed = isDown
		end
	end
end

------------------------------------------------------------------------
-- update
------------------------------------------------------------------------
function AutoCombine:update(dt)

	if self.isEntered and self.isClient and self:getIsActive() then
		if     AutoCombine.mbHasInputEvent( "AC_COMBINE_ENABLE" ) then
			AutoCombine.onEnable( self, not self.acParameters.enabled )
		elseif AutoCombine.mbHasInputEvent( "AC_AUTO_STEER" ) then
			AutoCombine.initMogliHud(self)
			if self.acTurnStage < 97 then
				AutoCombine.onAutoSteer(self, true)
			else
				AutoCombine.onAutoSteer(self, false)
			end
		elseif AutoCombine.mbHasInputEvent( "AC_COMBINE_UTURN_ON_OFF" ) then
			self:acSetState( "upNDown", not self.acParameters.upNDown )
		elseif AutoCombine.mbHasInputEvent( "AC_COMBINE_STEERING" ) then
			self:acSetState( "noSteering", not self.acParameters.noSteering )
		elseif AutoCombine.mbHasInputEvent( "AC_COMBINE_SWAP_SIDE" ) then
			self:acSetState( "leftAreaActive", not self.acParameters.leftAreaActive )
		elseif AutoCombine.mbHasInputEvent( "AC_COMBINE_HELPPANEL" ) then
			local guiActive = false
			if self.acHud ~= nil and self.acHud.GuiActive ~= nil then
				guiActive = self.acHud.GuiActive
			end
			AutoCombine.showGui( self, not guiActive )
		end

		if self.isAIThreshing then
			local cc = InputBinding.getDigitalInputAxis(InputBinding.AXIS_CRUISE_CONTROL)
			if InputBinding.isAxisZero(cc) then
				cc = InputBinding.getAnalogInputAxis(InputBinding.AXIS_CRUISE_CONTROL)
				if InputBinding.isAxisZero(cc) then
					cc = 0
				end
			end
			
			local lastSpeed = self.acParameters.speed
			local newSpeed  = Utils.clamp( self.acParameters.speed + 0.005 * dt * cc, 1, 20 ) --AutoSteeringEngine.getToolsSpeedLimit( self )
			if math.abs( newSpeed - lastSpeed ) > 0.1 then
				self:acSetState( "speed", newSpeed )
			end
			if self.acParameters ~= nil and self.acParameters.enabled and self.isAIThreshing then
				self:setCruiseControlMaxSpeed( self.acParameters.speed )
			end
			if AutoCombine.mbHasInputEvent( "TOGGLE_CRUISE_CONTROL" ) then
				self:acSetState( "pause", not self.acParameters.pause )
			end
		end
	end
	
	if math.abs(self.axisSide) > 0.1 and self.acTurnStage >= 97 then
		self.acTurnStage = 97
	elseif self.acTurnStage == 97 then
		self.acTurnStage = 98
	end
	
	if self.acTurnStage >= 97 then
    self.stopMotorOnLeave = false
    self.deactivateOnLeave = false
	end
	
	if self.acMogliInitDone and ( self.acHud.GuiActive or self.acParameters.enabled ) then
		if not self.acNodeIsLinked then
			AutoCombine.calculateDimensions(self)	
			self.acNodeIsLinked = true
			link(self.acRefNode,self.acI3D)
		end
	end

	if      self.acMogliInitDone
			and self.acHud.GuiActive
			and self.isEntered 
			and self.isClient 
			and self:getIsActive() 
			and self.acParameters.enabled
			and self:canStartAIThreshing() then
			
		AutoCombine.calculateDimensions(self)	
		if self.acDimensions ~= nil then				
			local a,n,l,d = 0,0,4,0
			for _,wheel in pairs(self.wheels) do
				if wheel.rotSpeed < -1E-03 then
					a = a - wheel.steeringAngle
					n = n + 1
				end
			end
			
			if n > 1 then a = a / n end		
			if not self.acParameters.leftAreaActive then a = -a end
			if     a < -self.acDimensions.maxSteeringAngle then a = -self.acDimensions.maxSteeringAngle
			elseif a >  self.acDimensions.maxLookingAngle  then a =  self.acDimensions.maxLookingAngle end
			
			d = AutoCombine.calculateWidth(self,l,a)
			if not self.acParameters.leftAreaActive then d = -d end
			
			local x0,y0,z0,x1,y1,z1
			x1,y1,z1 = localDirectionToWorld( self.acRefNode, d,0,l) 
			
			--x0,y0,z0 = getWorldTranslation(lm)
			x0,y0,z0 = localToWorld( self.acRefNode, self.acDimensions.xLeft,0.25,self.acDimensions.zLeft )
				
			drawDebugArrow(x0,y0,z0,x1,0,z1,x1,0,z1,1,0,0)
			drawDebugArrow(x0,y0+1,z0,x1,0,z1,x1,0,z1,1,0,0)
			drawDebugArrow(x0,y0+1,z0,0,-1,0,0,-1,0,1,0,0)

			--x0,y0,z0 = getWorldTranslation(rm)
			x0,y0,z0 = localToWorld( self.acRefNode, self.acDimensions.xRight,0.25,self.acDimensions.zRight )
				
			drawDebugArrow(x0,y0,z0,x1,0,z1,x1,0,z1,1,0,0)
			drawDebugArrow(x0,y0+1,z0,x1,0,z1,x1,0,z1,1,0,0)
			drawDebugArrow(x0,y0+1,z0,0,-1,0,0,-1,0,1,0,0)
			
		--x0,y0,z0 = getWorldTranslation( self.acRotNode )
		--x1,y1,z1 = localDirectionToWorld( self.acRotNode, 0,0,l) 
		--
		--drawDebugArrow(x0,y0,z0,x1,0,z1,x1,0,z1,0,0,1)
		--drawDebugArrow(x0,y0+1,z0,x1,0,z1,x1,0,z1,0,0,1)
		--drawDebugArrow(x0,y0+1,z0,0,-1,0,0,-1,0,0,0,1)
		--
		--local xl, zl = AutoCombine.getTurnVector( self )
		--x0,y0,z0 = localToWorld( self.acRotNode, xl, 0, zl )
		--
		--drawDebugArrow(x0,y0+1,z0,0,-1,0,0,-1,0,0,1,0)
		end
	end
	
	if      self.acDimensions           ~= nil  
			and self.acDimensions.aaAngle   ~= nil
			and self.acDimensions.wheelBase ~= nil
			and self.acDimensions.aaAngle   > 1E-6 then
		local _,angle,_ = getRotation( self.articulatedAxis.componentJoint.jointNode );
		if self.acLastAcRefNodeAngle == nil or math.abs( angle - self.acLastAcRefNodeAngle ) > 1e-6 then
			self.acLastAcRefNodeAngle = angle
			setRotation( self.acRefNodeCorr, 0, 0.2 * angle, 0 )
			setTranslation( self.acRefNodeCorr, -0.5 * self.acDimensions.wheelBase * math.sin( angle ), 0, 0 )
		end
	end

	--if      self.acParameters          ~= nil
	--		and oldCourseplaySide_to_drive == nil
	--		and courseplay                 ~= nil 
	--		and courseplay.side_to_drive   ~= nil
	--		and ( courseplay.versionFlt    == nil 
	--		   or courseplay.versionFlt    <= 3.41 ) then
	--	oldCourseplaySide_to_drive = courseplay.side_to_drive
	--	courseplay.side_to_drive   = AutoCombine.cpSideToDrive
	--	print("AutoCombine was added to CoursePlay v"..tostring(courseplay.version))
	--end

end

------------------------------------------------------------------------
-- AICombine:updateTick
------------------------------------------------------------------------
function AutoCombine:acUpdateTick(superFunc, dt)
	
  if      self.isServer
			and self.isAIThreshing 
			and self.acParameters ~= nil
			and self.pipeIsUnloading  
			and self.capacity > 0 
			then
		if     self.acParameters.waitMode 
				or ( self.acParameters.enabled and self.acTurnStage > 0 ) then
			if self.fillLevel > 0.1 * self.capacity  then	
				if self.acParameters.enabled and self.acTurnStage > 0 then
					self.driveBackPosX = nil
				elseif self.driveBackPosX == nil then
					self.driveBackPosX, self.driveBackPosY, self.driveBackPosZ = getWorldTranslation(self.aiTreshingDirectionNode)
				end
				self.waitingForDischarge  = true
				self.waitForDischargeTime = g_currentMission.time + self.waitForDischargeTimeout
			end
		elseif self.waitingForDischarge and self.fillLevel < 0.9 * self.capacity  then	
			self.waitingForDischarge  = true
		end
	end

	if self.isEntered and self.isClient and self:getIsActive() and not self.acParameters.noSteering then
		self.acAxisSide = InputBinding.getDigitalInputAxis(InputBinding.AXIS_MOVE_SIDE_VEHICLE)
		if InputBinding.isAxisZero(self.acAxisSide) then
			self.acAxisSide = InputBinding.getAnalogInputAxis(InputBinding.AXIS_MOVE_SIDE_VEHICLE)
    end
	else
		self.acAxisSide = 0
  end
	
	superFunc(self,dt)
	
	if self.acParameters == nil or self.acParameters.enabled == nil or not self.acParameters.enabled then
		return
	end
	
	if self.isAIThreshing then
		self.realForceAiDriven = true
	end
	
	if      not self.isAIThreshing 
			and self.lastValidInputFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN
			and self.acTurnStage >= 98 then
		AutoCombineHud.setInfoText( self )
		AutoCombine.autoSteer(self,dt)
	end
	
	if self.acDimensions == nil then
		self.acRecalculateDt = 0
	else
		self.acRecalculateDt = self.acRecalculateDt + dt
		if self.acTurnStage == 0 and self.acRecalculateDt > 60000 then
			self.acRecalculateDt = 0
			self.acDimensions    = nil
		end
	end
		
	if self.isServer then
		if self.acParameters.otherCombine then	
			AutoCombine.addOtherCombineCollisionTrigger(self)
		else
			AutoCombine.removeOtherCombineCollisionTrigger(self)
		end
		
	end		

	self:acSetState( "turnStage", self.acTurnStage )
	
	if      self.acMogliInitDone 
	    and self.acHud.GuiActive
			and self:getIsActive()  
			and AutoCombineHud.getInfoText(self) == "" then
		local workWidth = 0
		if self.acDimensions == nil or self.acDimensions.distance == nil then
			local lm, rm = AutoCombine.getMarker(self)
			if lm ~= nil then
				workWidth,_,_ = AutoCombine.getRelativeTranslation( self.aiTreshingDirectionNode, lm )
			end
			if rm ~= nil then
				x,_,_ = AutoCombine.getRelativeTranslation( self.aiTreshingDirectionNode, rm )
				workWidth = workWidth - x
			end
			workWidth = workWidth - AutoCombine.getAreaOverlap(self,workWidth)	
			workWidth = workWidth + self.acParameters.widthOffset + self.acParameters.widthOffset
		else
			workWidth = self.acDimensions.distance + self.acDimensions.distance
		end
		AutoCombineHud.setInfoText( self, string.format(AutoCombineHud.getText("AC_COMBINE_TXT_WORKWIDTH").." %0.2fm",workWidth) )
		if self.acParameters.enabled and self.isAIThreshing and self.acTurnStage ~= 0 then
			AutoCombineHud.setInfoText( self, AutoCombineHud.getInfoText(self) .. string.format(" (%i)",self.acTurnStage) )
		end
	end

	if not ( ( self.isAIThreshing and self.acParameters.enabled )
				or self.acTurnStage>= 98 ) then
		AutoCombine.setStatus( self, 0 )
	end
end

------------------------------------------------------------------------
-- attachImplement
------------------------------------------------------------------------
function AutoCombine:attachImplement(implement)
	self.acDimensions = nil
end

------------------------------------------------------------------------
-- detachImplement
------------------------------------------------------------------------
function AutoCombine:detachImplement(implementIndex)
	self.acDimensions = nil
end

------------------------------------------------------------------------
-- AICombine:canStartAIThreshing
------------------------------------------------------------------------
function AutoCombine:acCanStartAIThreshing(superFunc)

	if self.acParameters == nil or not ( self.acParameters.enabled ) then
		return superFunc(self)
	end
	if not self:getIsTurnedOnAllowed(true) then
		return false
	end
	if      self.numAttachedTrailers > 0 
			and not self.acParameters.noReverse then
		return false
	end
	if Hirable.numHirablesHired >= g_currentMission.maxNumHirables then
		return false
	end
	if self.aiLeftMarker == nil or self.aiRightMarker == nil then
		for cutter,implement in pairs(self.attachedCutters) do
			if cutter.aiLeftMarker ~= nil and self.aiLeftMarker == nil then
				self.aiLeftMarker = cutter.aiLeftMarker
			end
			if cutter.aiRightMarker ~= nil and self.aiRightMarker == nil then
				self.aiRightMarker = cutter.aiRightMarker
			end
		end
		if self.aiLeftMarker == nil or self.aiRightMarker == nil then
			return false
		end
	end
	return true
end

------------------------------------------------------------------------
-- AICombine:getIsAIThreshingAllowed
------------------------------------------------------------------------
function AutoCombine:acGetIsAIThreshingAllowed(superFunc)

	if self.acParameters == nil or not ( self.acParameters.enabled ) then
		return superFunc(self)
	end
	if not self:getIsTurnedOnAllowed(true) then
		return false
	end
	if      self.numAttachedTrailers > 0 
			and not self.acParameters.noReverse then
		return false
	end
	return true
end


------------------------------------------------------------------------
-- AutoCombine:startAIThreshing
------------------------------------------------------------------------
function AutoCombine:startAIThreshing(noEventSend)
	-- just to be safe...
	if self.acParameters ~= nil and self.acParameters.enabled then
		AutoCombine.initMogliHud(self)
		self.realForceAiDriven = true
		self.acDimensions      = nil
		self.acTurnStage       = -3
		self.turnTimer         = self.acDeltaTimeoutWait
		self.aiRescueTimer     = self.acDeltaTimeoutStop
		self.waitForTurnTime   = 0
		self.lastSpeedLevel    = 0
		self.acTargetRotTimer  = 0

		AutoCombine.addBackTrafficCollisionTrigger(self)
		
		for _, implement in pairs(self.attachedImplements) do
			if     implement.object.attacherJoint.jointType  == Vehicle.JOINTTYPE_TRAILERLOW
					or implement.object.attacherJoint.jointType  == Vehicle.JOINTTYPE_TRAILER then
				self:acSetState( "noReverse", true )
			end
		end
	end
end

------------------------------------------------------------------------
-- AutoCombine:stopAIThreshing
------------------------------------------------------------------------
function AutoCombine:stopAIThreshing(noEventSend)
	if self.acParameters ~= nil and self.acParameters.enabled then
		self.realForceAiDriven = false
		AutoCombine.removeBackTrafficCollisionTrigger(self)
	end
end

------------------------------------------------------------------------
-- getParallelogram
------------------------------------------------------------------------
function AutoCombine:getParallelogram( xOffset, zOffset, width, height, diff )
	local x, z, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ

	if self.acParameters.leftAreaActive then
		x = self.acDimensions.xLeft
		z = self.acDimensions.zLeft
	else
		x = self.acDimensions.xRight
		z = self.acDimensions.zRight
	end
	
	startWorldX,_,startWorldZ   = localToWorld( self.acRefNode, x + xOffset,         0, z + zOffset )
	widthWorldX,_,widthWorldZ   = localToWorld( self.acRefNode, x + xOffset + width, 0, z + zOffset )
	heightWorldX,_,heightWorldZ = localToWorld( self.acRefNode, x +           diff,  0, z + zOffset + height )	
	
	return startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ
end

------------------------------------------------------------------------
-- AutoCombine:getFruitArea
------------------------------------------------------------------------
function AutoCombine:getFruitArea(x1,z1,x2,z2,d,fruitType,hasFruitPreparer)
	local lx1,lz1,lx2,lz2,lx3,lz3 = AutoCombine.getParallelogram( self, x1, z1, x2, z2, d )
	return Utils.getFruitArea(fruitType, lx1,lz1,lx2,lz2,lx3,lz3, hasFruitPreparer)
end

------------------------------------------------------------------------
-- AutoCombine:isField
------------------------------------------------------------------------
function AutoCombine:isField(x1,z1,x2,z2)
	local lx1,lz1,lx2,lz2,lx3,lz3 = AutoCombine.getParallelogram( self, x1, z1, x2, z2, 0 )

	for i=0,3 do
		if Utils.getDensity(g_currentMission.terrainDetailId, i, lx1,lz1,lx2,lz2,lx3,lz3) ~= 0 then
			return true
		end
	end

	return false
	
end

------------------------------------------------------------------------
-- setStatus
------------------------------------------------------------------------
function AutoCombine:setStatus( newStatus )
	
	self:acSetState( "engineStatus", newStatus )
	
end

------------------------------------------------------------------------
-- 
------------------------------------------------------------------------
function AutoCombine:addBackTrafficCollisionTrigger()
	if self.acBackTrafficCollisionTrigger ~= nil then
		AutoCombine.addCollisionTrigger(self,self,self.acBackTrafficCollisionTrigger,"acOnBackCollisionTrigger")
	end
end

------------------------------------------------------------------------
-- 
------------------------------------------------------------------------
function AutoCombine:removeBackTrafficCollisionTrigger()
	if self.acBackTrafficCollisionTrigger ~= nil then		
		AutoCombine.removeCollisionTrigger(self,self,self.acBackTrafficCollisionTrigger,"acOnBackCollisionTrigger")
	end
end

------------------------------------------------------------------------
-- 
------------------------------------------------------------------------
function AutoCombine:addOtherCombineCollisionTrigger()
	local on,off
	if self.acParameters.otherCombine then	
		if self.acParameters.leftAreaActive then
			on  = self.acOtherCombineCollisionTriggerL
			off = self.acOtherCombineCollisionTriggerR
		else
			on  = self.acOtherCombineCollisionTriggerR
			off = self.acOtherCombineCollisionTriggerL
		end
		
		if on ~= nil then
			if self.acCollidingCombines[on] == nil then
				AutoCombine.addCollisionTrigger(self,self,on,"acOnCombineCollisionTrigger")
			end
		end
		if off ~= nil then
			if self.acCollidingCombines[off] ~= nil then
				AutoCombine.removeCollisionTrigger(self,self,off,"acOnCombineCollisionTrigger")
			end
		end
	end
end

------------------------------------------------------------------------
-- 
------------------------------------------------------------------------
function AutoCombine:removeOtherCombineCollisionTrigger()
	local off
	off = self.acOtherCombineCollisionTriggerL
	if off ~= nil then
		if self.acCollidingCombines[off] ~= nil then
			AutoCombine.removeCollisionTrigger(self,self,off,"acOnCombineCollisionTrigger")
		end
	end
	off = self.acOtherCombineCollisionTriggerR
	if off ~= nil then
		if self.acCollidingCombines[off] ~= nil then
			AutoCombine.removeCollisionTrigger(self,self,off,"acOnCombineCollisionTrigger")
		end
	end
end
		
------------------------------------------------------------------------
-- acOnBackCollisionTrigger
------------------------------------------------------------------------
function AutoCombine:acOnBackCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
  if onEnter or onLeave then
    if g_currentMission.players[otherId] ~= nil then
      if onEnter then
        self.acCollidingVehicles[triggerId] = self.acCollidingVehicles[triggerId] + 1
      elseif onLeave then
        self.acCollidingVehicles[triggerId] = math.max(self.acCollidingVehicles[triggerId] - 1, 0)
      end
    elseif self.trafficCollisionIgnoreList[otherId] == nil then
      local vehicle = g_currentMission.nodeToVehicle[otherId]
      if vehicle ~= nil then
        if onEnter then
          self.acCollidingVehicles[triggerId] = self.acCollidingVehicles[triggerId] + 1
        elseif onLeave then
          self.acCollidingVehicles[triggerId] = math.max(self.acCollidingVehicles[triggerId] - 1, 0)
        end
      end
    end
  end
end

		
------------------------------------------------------------------------
-- acOnCombineCollisionTrigger
------------------------------------------------------------------------
function AutoCombine:acOnCombineCollisionTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
  if onEnter or onLeave then
    if g_currentMission.players[otherId] == nil and self.trafficCollisionIgnoreList[otherId] == nil then
      local vehicle = g_currentMission.nodeToVehicle[otherId]
      if vehicle ~= nil and vehicle.specializations ~= nil and SpecializationUtil.hasSpecialization(Combine, vehicle.specializations) then
        if onEnter then
          self.acCollidingCombines[triggerId] = self.acCollidingCombines[triggerId] + 1
        elseif onLeave then
          self.acCollidingCombines[triggerId] = math.max(self.acCollidingCombines[triggerId] - 1, 0)
        end
      end
    end
  end
end

		
------------------------------------------------------------------------
-- addCollisionTrigger
------------------------------------------------------------------------
function AutoCombine:addCollisionTrigger(object,transformId,cb)
  if self.isServer then
    if transformId ~= nil then
			if     cb ~= nil and cb == "acOnBackCollisionTrigger" then
				addTrigger(transformId, cb, self)
				self.acCollidingVehicles[transformId] = 0
			elseif cb ~= nil and cb == "acOnCombineCollisionTrigger" then
				addTrigger(transformId, cb, self)
				self.acCollidingCombines[transformId] = 0
			else
				addTrigger(transformId, "onTrafficCollisionTrigger", self)
				self.numCollidingVehicles[transformId] = 0
			end
    end
    if object ~= self then
      for _, v in pairs(object.components) do
        self.trafficCollisionIgnoreList[v.node] = true
      end
    end
  end
end

------------------------------------------------------------------------
-- removeCollisionTrigger
------------------------------------------------------------------------
function AutoCombine:removeCollisionTrigger(object,transformId,cb)
  if self.isServer then
    if transformId ~= nil then
      removeTrigger(transformId)
			if     cb ~= nil and cb == "acOnBackCollisionTrigger" then
				self.acCollidingVehicles[transformId] = nil
			elseif cb ~= nil and cb == "acOnCombineCollisionTrigger" then
				self.acCollidingCombines[transformId] = nil
			else
				self.numCollidingVehicles[transformId] = nil
			end
    end
    if object ~= self then
      for _, v in pairs(object.components) do
        self.trafficCollisionIgnoreList[v.node] = nil
      end
    end
  end
end

------------------------------------------------------------------------
-- getMarker
------------------------------------------------------------------------
function AutoCombine:getMarker()

  local lm = self.aiLeftMarker
  local rm = self.aiRightMarker
	
  for cutter, implement in pairs(self.attachedCutters) do
    if cutter.aiLeftMarker ~= nil and lm == nil then
      lm = cutter.aiLeftMarker
    end
    if cutter.aiRightMarker ~= nil and rm == nil then
      rm = cutter.aiRightMarker
    end
  end
	
	return lm, rm
end

------------------------------------------------------------------------
-- getAreaOverlap
------------------------------------------------------------------------
function AutoCombine:getAreaOverlap(threshWidth)
  local areaOverlap = 0
	local scale = Utils.getNoNil( self.aiTurnThreshWidthScale, 0.1 )
	local diff  = Utils.getNoNil( self.aiTurnThreshWidthMaxDifference, 0.6 )

	areaOverlap = 0.5 * math.min(threshWidth * (1 - scale), diff)

	return areaOverlap
end

------------------------------------------------------------------------
-- getCorrectedMaxSteeringAngle
------------------------------------------------------------------------
function AutoCombine:getCorrectedMaxSteeringAngle()

	local steeringAngle = self.acDimensions.maxSteeringAngle
	if      self.articulatedAxis ~= nil 
			and self.articulatedAxis.componentJoint ~= nil
      and self.articulatedAxis.componentJoint.jointNode ~= nil 
			and self.articulatedAxis.rotMax then
		-- Ropa
		steeringAngle = steeringAngle + 0.15 * self.articulatedAxis.rotMax
	end

	return steeringAngle
end

------------------------------------------------------------------------
-- calculateDimensions
------------------------------------------------------------------------
function AutoCombine:calculateDimensions()
	if self.acDimensions ~= nil then
		local lm, rm = AutoCombine.getMarker(self)
		if lm == nil then
			return
		end
		
		local _,y,_ = AutoCombine.getRelativeTranslation( self.acRefNode, lm )		
		y = y + 1E-6
		if y >= self.acDimensions.yMin then
			return
		end
	end
	
	self.acRecalculateDt = 0
	self.acDimensions = {}

	local lm, rm = AutoCombine.getMarker(self)
	local n = 0
	self.acDimensions.distance = 0
	self.acDimensions.cutterDistance = 0

	if lm ~= nil then
		self.acDimensions.xLeft,self.acDimensions.yMin,self.acDimensions.zLeft = AutoCombine.getRelativeTranslation( self.acRefNode, lm )		
		self.acDimensions.distance = self.acDimensions.distance + self.acDimensions.xLeft
		self.acDimensions.cutterDistance = self.acDimensions.cutterDistance + self.acDimensions.zLeft
		n = n + 1
	else
		self.acDimensions.xLeft,self.acDimensions.yMin,self.acDimensions.zLeft = 0,99,0		
	end
	if rm ~= nil then
		self.acDimensions.xRight,_,self.acDimensions.zRight = AutoCombine.getRelativeTranslation( self.acRefNode, rm )		
		self.acDimensions.distance = self.acDimensions.distance - self.acDimensions.xRight
		self.acDimensions.cutterDistance = self.acDimensions.cutterDistance + self.acDimensions.zRight
		n = n + 1
	else
		self.acDimensions.xRight,self.acDimensions.zRight = 0,0
	end
	
	if n > 1 then
		self.acDimensions.distance = self.acDimensions.distance / n
		self.acDimensions.cutterDistance = self.acDimensions.cutterDistance / n
	elseif n < 1 then
		self.acDimensions.distance = 1.75
		self.acDimensions.cutterDistance = 3.3
	end
	self.acDimensions.cutterDistance = self.acDimensions.cutterDistance + 0.3
	
	local threshWidth           = self.acDimensions.distance + self.acDimensions.distance
  local areaOverlap           = AutoCombine.getAreaOverlap(self,threshWidth)	
	self.acDimensions.distance  = self.acDimensions.distance - areaOverlap
	self.acDimensions.xLeft     = self.acDimensions.xLeft    - areaOverlap
	self.acDimensions.xRight    = self.acDimensions.xRight   + areaOverlap
	self.acDimensions.distance0 = self.acDimensions.distance
	self.acDimensions.xLeft0    = self.acDimensions.xLeft
	self.acDimensions.xRight0   = self.acDimensions.xRight
		
	-- defaults
	self.acDimensions.zOffset         = 0
	self.acDimensions.wheelBase       = 4
	self.acDimensions.radius          = 10
	self.acDimensions.aaDistance      = 0
	self.acDimensions.aaAngle         = 0
	self.acDimensions.aaAngleFactor   = 0
	self.acDimensions.maxLookingAngle = 25
		
	if self.acCenterZ ~= nil and self.maxTurningRadius ~= nil and self.maxRotation ~= nil then
		--ackermann steering
		self.acDimensions.zOffset          = self.acCenterZ
		self.acDimensions.radius           = self.maxTurningRadius
		self.acDimensions.maxSteeringAngle = self.maxRotation
		
		local maxSteeringAngle = nil
		--local c_ws, z_ws, c_wn, z_wn, c_wp, z_wp = 0,0,0,0,0,0
		for _,wheel in pairs(self.wheels) do
			local temp1 = { getRotation(wheel.driveNode) }
			local temp2 = { getRotation(wheel.repr) }
			setRotation(wheel.driveNode, 0, 0, 0)
			setRotation(wheel.repr, 0, 0, 0)
			local x,y,z = AutoCombine.getRelativeTranslation(self.acRefNode,wheel.driveNode)
			setRotation(wheel.repr, unpack(temp2))
			setRotation(wheel.driveNode, unpack(temp1))
			
			local m = 0
			if math.abs( wheel.rotSpeed ) > 1E-03 then
				m = 0.5 * ( math.abs(wheel.rotMin) + math.abs(wheel.rotMax) )
				if maxSteeringAngle == nil or maxSteeringAngle < m then
					maxSteeringAngle = m
				end
			end
			
		--	local f = 1 --math.abs( wheel.restLoad )
		--	
		--	if math.abs( wheel.rotSpeed ) < 1E-03 or m < 1E-04 then
		--		z_wn = z_wn + f * z
		--		c_wn = c_wn + f
		--	elseif wheel.rotSpeed < 0 then
		--		z_ws = z_ws + f * z
		--		c_ws = c_ws + f
		--	else
		--		z_wp = z_wp + f * z
		--		c_wp = c_wp + f
		--	end
		end

		
		--if c_ws > 1e-3 and math.abs( c_ws - 1) > 1e-3 then z_ws = z_ws / c_ws end
		--if c_wn > 1e-3 and math.abs( c_wn - 1) > 1e-3 then z_wn = z_wn / c_wn end
		--if c_wp > 1e-3 and math.abs( c_wp - 1) > 1e-3 then z_wp = z_wp / c_wp end
		--
		--print(string.format("Ackermann: %0.3f / %0.3f %0.3f / %0.3f %0.3f / %0.3f %0.3f / %0.3f° %0.3f°", self.acCenterZ, z_ws, c_ws, z_wn, c_wn, z_wp, c_wp, math.deg( maxSteeringAngle ), math.deg( self.acDimensions.maxSteeringAngle ) ))
		
		if maxSteeringAngle ~= nil then
			self.acDimensions.maxSteeringAngle = maxSteeringAngle
		end
		self.acDimensions.wheelBase = math.max( 0, math.tan( self.acDimensions.maxSteeringAngle ) ) * self.acDimensions.radius
		
		if      self.articulatedAxis ~= nil 
				and self.articulatedAxis.componentJoint ~= nil
				and self.articulatedAxis.componentJoint.jointNode ~= nil 
				and self.articulatedAxis.rotMax then
			-- Ropa
			local x,y,z = AutoCombine.getRelativeTranslation( self.acRefNode, self.articulatedAxis.componentJoint.jointNode )
			self.acDimensions.aaDistance    = self.acDimensions.cutterDistance - z
			self.acDimensions.aaAngle       = self.articulatedAxis.rotMax
			self.acDimensions.aaAngleFactor = self.acDimensions.aaAngle / self.acDimensions.maxSteeringAngle
		--self.acDimensions.zOffset       = z
		end
	else
		local m_ws, c_ws, z_ws, m_wn, c_wn, z_wn, m_wp, c_wp, z_wp = 0,0,0,0,0,0,0,0,0
		self.acDimensions.maxSteeringAngle = math.rad(1)
		for _,wheel in pairs(self.wheels) do
			local temp1 = { getRotation(wheel.driveNode) }
			local temp2 = { getRotation(wheel.repr) }
			setRotation(wheel.driveNode, 0, 0, 0)
			setRotation(wheel.repr, 0, 0, 0)
			local x,y,z = AutoCombine.getRelativeTranslation(self.acRefNode,wheel.driveNode)
			setRotation(wheel.repr, unpack(temp2))
			setRotation(wheel.driveNode, unpack(temp1))
			
			local m = 0
			if math.abs( wheel.rotSpeed ) > 1E-03 then
				m = 0.5 * ( math.abs(wheel.rotMin) + math.abs(wheel.rotMax) )
				if m > 0 then
					self.acDimensions.maxSteeringAngle = math.max( self.acDimensions.maxSteeringAngle, m )			
				end
			end
			
			if math.abs( wheel.rotSpeed ) < 1E-03 or m < 1E-04 then
				if c_wn < 1 then z_wn = z else z_wn = math.max(z_wn,z) end
				c_wn = 1
			elseif wheel.rotSpeed < 0 then
				if c_ws < 1 then z_ws = z else z_ws = math.min(z_ws,z) end
				c_ws = 1
			else
				if c_wp < 1 then z_wp = z else z_wp = math.max(z_wp,z) end
				c_wp = 1
			end
		end

	--print(string.format("%0.3f %0.3f / %0.3f %0.3f / %0.3f %0.3f", z_ws, c_ws, z_wn, c_wn, z_wp, c_wp))
		
		if c_ws > 1e-3 and math.abs( c_ws - 1) > 1e-3 then z_ws = z_ws / c_ws end
		if c_wn > 1e-3 and math.abs( c_wn - 1) > 1e-3 then z_wn = z_wn / c_wn end
		if c_wp > 1e-3 and math.abs( c_wp - 1) > 1e-3 then z_wp = z_wp / c_wp end
		
		if      self.articulatedAxis ~= nil 
				and self.articulatedAxis.componentJoint ~= nil
				and self.articulatedAxis.componentJoint.jointNode ~= nil 
				and self.articulatedAxis.rotMax then
			-- Ropa
			local x,y,z = AutoCombine.getRelativeTranslation( self.acRefNode, self.articulatedAxis.componentJoint.jointNode )
			self.acDimensions.aaDistance    = self.acDimensions.cutterDistance - z
			self.acDimensions.aaAngle       = self.articulatedAxis.rotMax
			self.acDimensions.aaAngleFactor = self.acDimensions.aaAngle / self.acDimensions.maxSteeringAngle
			self.acDimensions.zOffset       = z
			
		elseif ( c_ws > 0 and c_wn > 0 )
				or ( c_ws > 0 and c_wp > 0 )
				or ( c_wn > 0 and c_wp > 0 ) then		
			if     c_wn < 1 then
				z_wn = 0.5 * ( z_ws + z_wp )
			elseif c_ws < 1 then
				z_ws = z_wp
			end
			
			self.acDimensions.zOffset       = z_wn
		end

		self.acDimensions.wheelBase       = self.acDimensions.zOffset - z_ws
		self.acDimensions.radius          = self.acDimensions.wheelBase / math.tan( AutoCombine.getCorrectedMaxSteeringAngle(self) )
	end
	
	self.acDimensions.cutterDistance  = self.acDimensions.cutterDistance - self.acDimensions.zOffset

	setTranslation( self.acTransNode, 0, 0, self.acDimensions.zOffset )
	
	AutoCombine.calculateDistances(self)
end

------------------------------------------------------------------------
-- calculateDistances
------------------------------------------------------------------------
function AutoCombine:calculateDistances()

	self.acDimensions.distance        = self.acDimensions.distance0 + self.acParameters.widthOffset
	self.acDimensions.xLeft           = self.acDimensions.xLeft0    + self.acParameters.widthOffset
	self.acDimensions.xRight          = self.acDimensions.xRight0   - self.acParameters.widthOffset
	
	local optimDist                   = 0.5+self.acDimensions.distance
	if self.acDimensions.radius > optimDist then
		self.acDimensions.uTurnAngle    = math.acos( optimDist / self.acDimensions.radius )
	else
		self.acDimensions.uTurnAngle    = 0
	end

--self.acDimensions.maxLookingAngle = math.min( AutoCombine.calculateSteeringAngle( self, 2, 1 ) ,self.acDimensions.maxSteeringAngle)
	self.acDimensions.maxLookingAngle = math.min( AutoCombine.calculateSteeringAngle( self, 2, 2 ) ,self.acDimensions.maxSteeringAngle)
--local factor = math.max( 0.7, math.cos( math.min( AutoCombine.getCorrectedMaxSteeringAngle(self), 0.5 * math.pi ) ) - 1 + math.sin( math.max( math.pi - AutoCombine.getCorrectedMaxSteeringAngle(self), 0 ) ) )
--local factor = math.max( 0.8, math.cos( math.min( self.acDimensions.maxLookingAngle, 0.5 * math.pi ) ) - 1 + math.sin( math.max( 0.5 * math.pi - self.acDimensions.maxLookingAngle, 0 ) ) )
	local factor = 1
	self.acDimensions.insideDistance  = self.acDimensions.cutterDistance - self.acDimensions.distance + self.acDimensions.radius * factor 
	
	if self.acDimensions.aaAngle > 1E-6 then
		self.acDimensions.uTurnRefAngle	  = -120
		self.acDimensions.maxLookingAngle = math.min( self.acDimensions.maxLookingAngle, self.acDimensions.aaAngle )
		self.acDimensions.uTurnDistance   = 1.2 * self.acDimensions.cutterDistance + self.acDimensions.distance
	else
		local ref = -100				
		local a0  = math.deg(self.acDimensions.maxLookingAngle)-180
		while ref > a0 do
			local a1 = math.rad( -90-ref )
			local a2 = math.rad( 180+ref )
			
			local d = 0
			d = d + self.acDimensions.radius * ( math.sin( a1 ) + 1 )
			d = d - self.acDimensions.radius * ( math.cos( self.acDimensions.maxLookingAngle ) - math.cos( a2 ) )
			d = d + self.acDimensions.radius * ( 1 - math.cos( self.acDimensions.maxLookingAngle ) ) * self.acDimensions.maxSteeringAngle / self.acDimensions.maxLookingAngle
			
			if d > 2 * self.acDimensions.distance then
				break
			else
				ref  = ref - 5
			end
		end
		
		self.acDimensions.uTurnRefAngle	  = ref
		
		local a = math.rad( 180 + ref ) - self.acDimensions.maxLookingAngle
		
		self.acDimensions.uTurnDistance   = 2 + math.max(0,self.acDimensions.cutterDistance) + math.max(0,self.acDimensions.distance - self.acDimensions.radius) + 0.258 * self.acDimensions.distance
		--math.max(1, self.acDimensions.cutterDistance + 1 + self.acDimensions.distance - self.acDimensions.radius )
	end
  
	local width = 1.5
	
	--                                  distance from marker to border - width/2 - innerRadius * ( 1 - sin(60°) )
	self.acDimensions.uTurnDistance2  = self.acDimensions.cutterDistance - width - math.max( 0, self.acDimensions.radius - width ) * 0.134
	
	if     self.acDimensions.distance <= width then
		self.acDimensions.uTurnDistance2  = self.acDimensions.cutterDistance
	elseif self.acDimensions.distance < self.acDimensions.radius then
		-- avoid driving through fruits with Pythagoras for the inner radius
		local r2 = math.max( 0, self.acDimensions.radius - width ) ^2
		local d2 = ( self.acDimensions.radius - self.acDimensions.distance )^2		
		self.acDimensions.uTurnDistance2 = math.max( self.acDimensions.uTurnDistance2, self.acDimensions.cutterDistance - math.sqrt( r2 - d2 ) )
	end
	
	
	self.acDimensions.insideDistance  = self.acDimensions.insideDistance + self.acParameters.turnOffset
  self.acDimensions.uTurnDistance   = math.max( 1, self.acDimensions.uTurnDistance  + self.acParameters.turnOffset )	
  self.acDimensions.uTurnDistance2  = 1.0 + self.acDimensions.uTurnDistance2 + self.acParameters.turnOffset
	
--print(string.format("a1=%i a2=%i cd=%f di=%f rd=%f wb=%f id=%f ud=%f ud2=%f",math.deg(self.acDimensions.maxSteeringAngle),math.deg(self.acDimensions.maxLookingAngle),self.acDimensions.cutterDistance,self.acDimensions.xLeft,self.acDimensions.radius,self.acDimensions.wheelBase,self.acDimensions.insideDistance,self.acDimensions.uTurnDistance,self.acDimensions.uTurnDistance2 	))
end

------------------------------------------------------------------------
-- getRelativeTranslation
------------------------------------------------------------------------
function AutoCombine.getRelativeTranslation(root,node)
	local x,y,z
	if getParent(node)==root then
		x,y,z = getTranslation(node)
	else
		x,y,z = worldToLocal(root,getWorldTranslation(node))
	end
	return x,y,z
end

------------------------------------------------------------------------
-- calculateSteeringAngle
------------------------------------------------------------------------
function AutoCombine.calculateSteeringAngle(self,x,z)
	local angle = math.atan( self.acDimensions.wheelBase * x / ( self.acDimensions.cutterDistance * z + self.acDimensions.distance * x ) )
	return angle
end

------------------------------------------------------------------------
-- calculateWidth
------------------------------------------------------------------------
function AutoCombine:calculateWidth(z,angle)
	if math.abs(z)<1E-6 then
		return 0
	end
	
	local tanAngle = math.tan( angle )
	local dist = self.acDimensions.cutterDistance * z * tanAngle / ( self.acDimensions.wheelBase - tanAngle * self.acDimensions.distance )

	if self.acDimensions.aaAngleFactor > 0 then
		dist = dist + math.sin( self.acDimensions.aaAngleFactor * angle ) * z
  end
	
	return dist
end

------------------------------------------------------------------------
-- saveDirection
------------------------------------------------------------------------
function AutoCombine:saveDirection( cumulate )

	local vector = {}	
	vector.dx,_,vector.dz = localDirectionToWorld( self.acRefNodeCorr, 0,0,1 )
	vector.px,_,vector.pz = getWorldTranslation( self.acRefNodeCorr )
	
	if cumulate then
		
		if self.acDirectionBeforeTurn.traceIndex == nil then
			self.acDirectionBeforeTurn.trace = {}
			self.acDirectionBeforeTurn.traceIndex = 0
			self.acDirectionBeforeTurn.sx = vector.px
			self.acDirectionBeforeTurn.sz = vector.pz
		else		
			local count = table.getn(self.acDirectionBeforeTurn.trace)
			if count > 500 and self.acDirectionBeforeTurn.traceIndex == count then
				local x = self.acDirectionBeforeTurn.trace[self.acDirectionBeforeTurn.traceIndex].px - self.acDirectionBeforeTurn.trace[1].px
				local z = self.acDirectionBeforeTurn.trace[self.acDirectionBeforeTurn.traceIndex].pz - self.acDirectionBeforeTurn.trace[1].pz		
			
				if Utils.vector2LengthSq( x, z ) > 64 then 
					self.acDirectionBeforeTurn.traceIndex = 0
				end
			end
		end
		
		self.acDirectionBeforeTurn.traceIndex = self.acDirectionBeforeTurn.traceIndex + 1
		
		self.acDirectionBeforeTurn.trace[self.acDirectionBeforeTurn.traceIndex] = vector
		self.acDirectionBeforeTurn.a = nil
		self.acDirectionBeforeTurn.x = vector.px
		self.acDirectionBeforeTurn.z = vector.pz
		
		if self.lastValidInputFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
			local hasFruitPreparer = false
			if self.fruitPreparerFruitType ~= nil and self.fruitPreparerFruitType == self.lastValidInputFruitType then
				hasFruitPreparer = true
			end
				
			local lx,lz
			if self.acParameters.leftAreaActive then
				lx = self.acDimensions.xRight
				lz = self.acDimensions.zRight
			else
				lx = self.acDimensions.xLeft
				lz = self.acDimensions.zLeft
			end
	
			local x,_,z = localToWorld( self.acRefNodeCorr, lx, 0, lz )
			
			if Utils.getFruitArea(self.lastValidInputFruitType, x-1,z-1,x+1,z-1,x-1,z+1, hasFruitPreparer) > 0 then	
				self.acDirectionBeforeTurn.tx = x
				self.acDirectionBeforeTurn.tz = z
			end
		end
		self.acDirectionBeforeTurn.trx, self.acDirectionBeforeTurn.try, self.acDirectionBeforeTurn.trz = getWorldTranslation( self.acRotNode )
	else
		self.acDirectionBeforeTurn.trace      = {}
		self.acDirectionBeforeTurn.trace[1]   = vector
		self.acDirectionBeforeTurn.traceIndex = 0
		self.acDirectionBeforeTurn.sx, _, self.acDirectionBeforeTurn.sz = getWorldTranslation( self.acRefNodeCorr )
	end

	local i = AutoCombine.getFirstTraceIndex( self )
	local current 
	
	if     i == nil
			or 0 == self.acDirectionBeforeTurn.traceIndex 
			or i == self.acDirectionBeforeTurn.traceIndex 
			or table.getn(self.acDirectionBeforeTurn.trace) < 2 then
		current = true
	else
		i = self.acDirectionBeforeTurn.traceIndex
		while true do
			i = i - 1
			if i < 1 then
				i = table.getn(self.acDirectionBeforeTurn.trace)
			end
			if i == self.acDirectionBeforeTurn.traceIndex then
				current = true
				break
			end
			
			if self.acDirectionBeforeTurn.trace[i] == nil or self.acDirectionBeforeTurn.trace[i].px == nil then
				print( "Error in AutoCombine: unexpected trace index @1694 "..tostring(i).." / "..tostring(self.acDirectionBeforeTurn.traceIndex).." / "..tostring(table.getn(self.acDirectionBeforeTurn.trace)))
				current = true
				break
			end
			
			dx = self.acDirectionBeforeTurn.trace[self.acDirectionBeforeTurn.traceIndex].px - self.acDirectionBeforeTurn.trace[i].px
			dz = self.acDirectionBeforeTurn.trace[self.acDirectionBeforeTurn.traceIndex].pz - self.acDirectionBeforeTurn.trace[i].pz		
			
			if Utils.vector2LengthSq( dx, dz ) > 4 then
				current = false
				break
			end
		end
	end
	
	if current then
		self.acDirectionBeforeTurn.dx,_,self.acDirectionBeforeTurn.dz = localDirectionToWorld( self.acRefNodeCorr, 0, 0, 1 )
	else
		local l = Utils.vector2Length( dx, dz )
		self.acDirectionBeforeTurn.dx = dx / l
		self.acDirectionBeforeTurn.dz = dz / l
	end	
	
	local cpIndex = self.acDirectionBeforeTurn.traceIndex + 1
	if cpIndex > table.getn(self.acDirectionBeforeTurn.trace) then
		cpIndex = 1
	end
	
	self.acDirectionBeforeTurn.trace[cpIndex].dx = self.acDirectionBeforeTurn.dx
	self.acDirectionBeforeTurn.trace[cpIndex].dz = self.acDirectionBeforeTurn.dz
	
end

------------------------------------------------------------------------
-- getFirstTraceIndex
------------------------------------------------------------------------
function AutoCombine:getFirstTraceIndex()
	if     self.acDirectionBeforeTurn.trace      == nil 
			or self.acDirectionBeforeTurn.traceIndex == nil 
			or self.acDirectionBeforeTurn.traceIndex < 1 then
		return nil
	end
	local l = table.getn(self.acDirectionBeforeTurn.trace)
	if l < 1 then
		return nil
	end
	local i = self.acDirectionBeforeTurn.traceIndex + 1
	if i > l then i = 1 end
	return i
end

------------------------------------------------------------------------
-- getTurnDistance
------------------------------------------------------------------------
function AutoCombine:getTurnDistance()
	if     self.acRefNodeCorr           == nil
			or self.acDirectionBeforeTurn   == nil
			or self.acDirectionBeforeTurn.x == nil
			or self.acDirectionBeforeTurn.z == nil then
		return 0
	end
	local x,_,z = getWorldTranslation( self.acRefNodeCorr )
	x = x - self.acDirectionBeforeTurn.x
	z = z - self.acDirectionBeforeTurn.z
	return math.sqrt( x*x + z*z )
end

------------------------------------------------------------------------
-- getTurnVector
------------------------------------------------------------------------
function AutoCombine:getTurnVector()
	if     self.acRefNodeCorr             == nil
			or self.acDirectionBeforeTurn     == nil
			or self.acDirectionBeforeTurn.trx == nil
			or self.acDirectionBeforeTurn.try == nil
			or self.acDirectionBeforeTurn.trz == nil then
		return 0, 0
	end

	setRotation( self.acRotNode, 0, -AutoCombine.getTurnAngle( self ), 0 )
	
	local x,_,z = worldToLocal( self.acRotNode, self.acDirectionBeforeTurn.trx, self.acDirectionBeforeTurn.try, self.acDirectionBeforeTurn.trz )
	
	return x, z
end

------------------------------------------------------------------------
-- getTurnDistanceX
------------------------------------------------------------------------
function AutoCombine:getTurnDistanceX()
	local x, z = AutoCombine.getTurnVector( self )
	if self.acParameters.leftAreaActive then
		x = -x
	end
	return x
end

------------------------------------------------------------------------
-- getTurnDistanceZ
------------------------------------------------------------------------
function AutoCombine:getTurnDistanceZ()
	local x, z = AutoCombine.getTurnVector( self )
	return -z
end

------------------------------------------------------------------------
-- getTraceLength
------------------------------------------------------------------------
function AutoCombine.getTraceLength( self )
	if self.acDirectionBeforeTurn.trace == nil then
		return 0
	end
	
	if table.getn(self.acDirectionBeforeTurn.trace) < 2 then
		return 0
	end
	
	local i = AutoCombine.getFirstTraceIndex( self )
	if i == nil then
		return 0
	end
	
	local x = self.acDirectionBeforeTurn.trace[self.acDirectionBeforeTurn.traceIndex].px - self.acDirectionBeforeTurn.sx
	local z = self.acDirectionBeforeTurn.trace[self.acDirectionBeforeTurn.traceIndex].pz - self.acDirectionBeforeTurn.sz
	
	return math.sqrt( x*x + z*z )
end

------------------------------------------------------------------------
-- getTurnAngle
------------------------------------------------------------------------
function AutoCombine.getTurnAngle( self )			
	if self.acDirectionBeforeTurn.a == nil then
		local i = AutoCombine.getFirstTraceIndex( self )
		if i == nil then
			return 0
		end
		if i == self.acDirectionBeforeTurn.traceIndex then
			return 0
		end
		local l = AutoCombine.getTraceLength( self )
		if l < 1E-3 then
			return 0
		end

		local vx = self.acDirectionBeforeTurn.trace[self.acDirectionBeforeTurn.traceIndex].px - self.acDirectionBeforeTurn.trace[i].px
		local vz = self.acDirectionBeforeTurn.trace[self.acDirectionBeforeTurn.traceIndex].pz - self.acDirectionBeforeTurn.trace[i].pz		
		self.acDirectionBeforeTurn.a = Utils.getYRotationFromDirection(vx/l,vz/l)
	end

	local x,y,z = localDirectionToWorld( self.acRefNodeCorr, 0,0,1 )
	
	local angle = Utils.getYRotationFromDirection(x,z) - self.acDirectionBeforeTurn.a
	
--if self.acDimensions.aaAngle > 1E-6 then
--	angle = angle + 0.5 * self.articulatedAxis.curRot
--end
	
	while angle < math.pi do 
		angle = angle+math.pi+math.pi 
	end
	while angle > math.pi do
		angle = angle-math.pi-math.pi 
  end
	
	return angle
end	

------------------------------------------------------------------------
-- setAiThreshingTarget
------------------------------------------------------------------------
function AutoCombine.setAiThreshingTarget( self )			
	
	if     self.acDirectionBeforeTurn            == nil
			or self.acDirectionBeforeTurn.traceIndex == nil
			or self.acDirectionBeforeTurn.traceIndex  < 1
			or self.acDirectionBeforeTurn.trace      == nil
			or self.acDirectionBeforeTurn.dx         == nil
			or self.acDirectionBeforeTurn.dz         == nil then
		self.aiThreshingTargetX,_,self.aiThreshingTargetZ = localToWorld( self.acRefNodeCorr, 0, 0, 10 )
	else
		self.aiThreshingTargetX = self.acDirectionBeforeTurn.trace[self.acDirectionBeforeTurn.traceIndex].px + 10 * self.acDirectionBeforeTurn.dx
		self.aiThreshingTargetZ = self.acDirectionBeforeTurn.trace[self.acDirectionBeforeTurn.traceIndex].pz + 10 * self.acDirectionBeforeTurn.dz
	end	
end	

------------------------------------------------------------------------
-- getRelativeYRotation
------------------------------------------------------------------------
function AutoCombine.getRelativeYRotation(root,node)
	local x, y, z = worldDirectionToLocal(node, localDirectionToWorld(root, 0, 0, 1))
	local dot = z
	dot = dot / Utils.vector2Length(x, z)
	local angle = math.acos(dot)
	if x < 0 then
		angle = -angle
	end
	return angle
end

------------------------------------------------------------------------
-- Manually switch to next turn stage
------------------------------------------------------------------------
function AutoCombine:setNextTurnStage(noEventSend)

	if self.acParameters.enabled then
		if     self.acTurnStage == 2  then
			self.turnTimer     = self.acDeltaTimeoutWait
			self.lastTurnAngle = nil
			self.acTurnStage   = 3
			AICombine.setAIImplementsMoveDown(self,true)
		elseif self.acTurnStage == 12 then
			self.turnTimer     = self.acDeltaTimeoutWait
			self.lastTurnAngle = nil
			if self.acTurn2Outside then
				self.acTurn2Outside = false
				self.acTurnStage   = 13
			else
				self.acTurnStage   = 14
			end
		elseif self.acTurnStage == 15 then
			self.turnTimer     = self.acDeltaTimeoutWait
			self.lastTurnAngle = nil
			self.acTurnStage   = 17
		elseif self.acTurnStage == 17 then
			self.turnTimer     = self.acDeltaTimeoutWait
			self.lastTurnAngle = nil
			if self.acParameters.noReverse then
				self.acTurnStage   = 19
				AICombine.setAIImplementsMoveDown(self,true)
			else
				self.acTurn2Outside = true
				self.turnTimer     = self.acDeltaTimeoutStop
				self.acTurnStage   = 18
			end
		elseif self.acTurnStage == 18 then
			self.turnTimer     = self.acDeltaTimeoutWait
			self.lastTurnAngle = nil
			self.acTurnStage   = 19
			AICombine.setAIImplementsMoveDown(self,true)
		end
	else
		if self.turnStage > 0 and self.turnStage < 4 then
			self.turnStage = self.turnStage + 1
		end
	end

  if noEventSend == nil or noEventSend == false then
    if g_server ~= nil then
      g_server:broadcastEvent(AutoCombineNextTSEvent:new(self), nil, nil, self)
    else
      g_client:getServerConnection():sendEvent(AutoCombineNextTSEvent:new(self))
    end
  end
end


source(Utils.getFilename("ACUpdateAIMovement.lua", g_currentModDirectory))

------------------------------------------------------------------------
-- overwritten functions
------------------------------------------------------------------------
AICombine.updateTick              = Utils.overwrittenFunction( AICombine.updateTick,              AutoCombine.acUpdateTick )
AICombine.canStartAIThreshing     = Utils.overwrittenFunction( AICombine.canStartAIThreshing,     AutoCombine.acCanStartAIThreshing )
AICombine.getIsAIThreshingAllowed = Utils.overwrittenFunction( AICombine.getIsAIThreshingAllowed, AutoCombine.acGetIsAIThreshingAllowed )
AICombine.updateAIMovement        = Utils.overwrittenFunction( AICombine.updateAIMovement,        AutoCombine.acUpdateAIMovement )

end

------------------------------------------------------------------------
-- AutoCombineNextTSEvent
------------------------------------------------------------------------
if AutoCombineNextTSEvent == nil then

AutoCombineNextTSEvent = {}
AutoCombineNextTSEvent_mt = Class(AutoCombineNextTSEvent, Event)
InitEventClass(AutoCombineNextTSEvent, "AutoCombineNextTSEvent")
function AutoCombineNextTSEvent:emptyNew()
  local self = Event:new(AutoCombineNextTSEvent_mt)
  return self
end
function AutoCombineNextTSEvent:new(object)
  local self = AutoCombineNextTSEvent:emptyNew()
  self.object     = object
  return self
end
function AutoCombineNextTSEvent:readStream(streamId, connection)
  local id = streamReadInt32(streamId)
  self.object = networkGetObject(id)
  self:run(connection)
end
function AutoCombineNextTSEvent:writeStream(streamId, connection)
  streamWriteInt32(streamId, networkGetObjectId(self.object))
end
function AutoCombineNextTSEvent:run(connection)
  AutoCombine.setNextTurnStage(self.object,true)
  if not connection:getIsServer() then
    g_server:broadcastEvent(AutoCombineNextTSEvent:new(self.object), nil, connection, self.object)
  end
end

end

