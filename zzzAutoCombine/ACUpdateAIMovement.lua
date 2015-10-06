--***************************************************************
--
-- AutoCombine methods acUpdateAIMovement & autoSteer
--
-- version 4.000 by mogli (biedens)
-- 2015/06/09
--
--***************************************************************

------------------------------------------------------------------------
-- AICombine:updateAIMovement
------------------------------------------------------------------------
function AutoCombine:acUpdateAIMovement(superFunc, dt)

	AutoCombineHud.setInfoText( self )

--if self.acTurnStage > 0 then print(tostring(AutoCombine.getTurnDistanceX(self)).." "..tostring(AutoCombine.getTurnDistanceZ(self)).." "..tostring(math.deg(AutoCombine.getTurnAngle(self)))) end

	if self.acParameters == nil or self.acParameters.enabled == nil or not self.acParameters.enabled then
		return superFunc(self,dt)
	end

	self.acIsCPCombine = self.acParameters.CPSupport
	if not ( self.acParameters.CPSupport ) and self.courseplayers ~= nil and table.getn( self.courseplayers ) > 0 then
		self.acIsCPCombine = true
	end
	
	if not self:getIsAIThreshingAllowed() then
		self:stopAIThreshing()
		return
	end

	if not self.isControlled then
		if g_currentMission.environment.needsLights then
			self:setLightsVisibility(true)
		else
			self:setLightsVisibility(false)
		end
	end

	local allowedToDrive = true
	if self:getCapacity() == 0 then
		if not self.pipeStateIsUnloading[self.currentPipeState] then
			allowedToDrive = false
		end
		if not self.isPipeUnloading and (self.lastArea > 0 or self.lastLostFillLevel > 0) then
			-- there is some fruit to unload, but there is no trailer. Stop and wait for a trailer
			self.waitingForTrailerToUnload = true
		end
	else
		if self.fillLevel >= self:getCapacity() then
			allowedToDrive = false
		end
	end

	if self.waitingForTrailerToUnload then
		if self.lastValidFillType ~= Fillable.FILLTYPE_UNKNOWN then
			local trailer = self:findTrailerToUnload(self.lastValidFillType)
			if trailer ~= nil then
				-- there is a trailer to unload. Continue working
				self.waitingForTrailerToUnload = false
			end
		else
			-- we did not cut anything yet. We shouldn't have ended in this state. Just continue working
			self.waitingForTrailerToUnload = false
		end
	end
	
	if (self.fillLevel >= self:getCapacity() and self:getCapacity() > 0) or self.waitingForTrailerToUnload or self.waitingForDischarge then
		allowedToDrive = false
	end

	if not allowedToDrive then
		if self.waitingForTrailerToUnload then
			AutoCombineHud.setInfoTextID(self, "AC_COMBINE_WAITING_TRAILER")
			AutoCombine.setStatus( self, 2 )
		elseif self.waitingForDischarge then
			AutoCombineHud.setInfoTextID(self, "AC_COMBINE_WAITING_DISCHARGE")
			AutoCombine.setStatus( self, 1 )
		end
	end
	
	if     self.acTurnStage == 2 
			or self.acTurnStage == 5 
			or self.acTurnStage == 18 
			or self.acTurnStage == 19 then
	-- back trigger only
		if not ( self.acIsCPCombine ) then
			for _, v in pairs(self.acCollidingVehicles) do
				if v > 0 then
					AutoCombineHud.setInfoTextID(self, "AC_COMBINE_COLLISION_BACK")
					AutoCombine.setStatus( self, 3 )
					allowedToDrive = false
					break
				end
			end
		end
	elseif  self.acTurnStage ~= 4
			and self.acTurnStage ~= 3
			and self.acTurnStage ~= 6
			and self.acTurnStage ~= 11
			and self.acTurnStage ~= 13
			and self.acTurnStage ~= 14
			and self.acTurnStage ~= 16
			and self.acTurnStage ~= 19
			and self.acTurnStage ~= 23
			and self.acTurnStage ~= 25
			and self.acTurnStage ~= 27
			and self.acTurnStage ~= 29
			and self.acTurnStage ~= 32 then
	-- front trigger
		for _,v in pairs(self.numCollidingVehicles) do
			if v > 0 then
				AutoCombineHud.setInfoTextID(self, "AC_COMBINE_COLLISION_OTHER")
				AutoCombine.setStatus( self, 3 )
				allowedToDrive = false
				break
			end
		end
		if self.acParameters.otherCombine then
			for _, v in pairs(self.acCollidingCombines) do
				if v > 0 then
					AutoCombineHud.setInfoTextID(self, "AC_COMBINE_COLLISION_OTHER")
					AutoCombine.setStatus( self, 2 )
					allowedToDrive = false
					break
				end
			end
		end
	end

	if self.acIsCPStopped then
		self.acIsCPStopped = false
    allowedToDrive     = false
  end
	
	if not self:getIsThreshingAllowed(true) then
		if self.acTurnStage == 0 then
			allowedToDrive = false
			self:setIsTurnedOn(false)
			self.waitingForWeather = true
			AutoCombineHud.setInfoTextID(self, "AC_COMBINE_WAITING_WEATHER")
		end	
	else
		if self.waitingForWeather then
			self:startThreshing()
			self.waitingForWeather = false
		end
	end

	if self.driveBackPosX == nil and self.acTurnStage <= 0 then
		-- check if cutter is lowered completly
		local cutterIsLowered = true
		for _,implement in pairs(self.attachedImplements) do
			if implement.object ~= nil then
				if implement.object.attacherJoint.needsLowering and implement.object.aiNeedsLowering then
					local jointDesc = self.attacherJoints[implement.jointDescIndex]
					cutterIsLowered = cutterIsLowered and (jointDesc.moveAlpha == jointDesc.lowerAlpha)
				end
			end
		end

		allowedToDrive = allowedToDrive and cutterIsLowered
		
		if      not allowedToDrive
				and self.acTurnStage == 0
				and not ( self:getIsTurnedOn() and cutterIsLowered ) then
			self.driveBackPosX, self.driveBackPosY, self.driveBackPosZ = getWorldTranslation(self.aiTreshingDirectionNode)
		end
	end

	if not allowedToDrive then
		self.isHirableBlocked = true
		AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, nil, nil)
		return
	elseif self:getIsTurnedOn() == false then
		self:setIsTurnedOn(true)
	end
	self.isHirableBlocked = false
	
	
	local moveForwards = true
	local noBreaking   = false
	
  local speedLevel = self.acParameters.speed
	if speedLevel <= 0 or self.acParameters.pause then
		allowedToDrive = false
		self.isHirableBlocked = true
		AutoCombine.setStatus( self, 0 )
		AutoCombineHud.setInfoTextID(self, "AC_COMBINE_WAITING_PAUSE")
	end
	
	if self.driveBackPosX ~= nil then
		local x,y,z = getWorldTranslation(self.aiTreshingDirectionNode)
		local dx, dy, dz = worldToLocal(self.aiTreshingDirectionNode, self.driveBackPosX, self.driveBackPosY, self.driveBackPosZ)
		local lx, lz = AIVehicleUtil.getDriveDirection(self.aiTreshingDirectionNode, self.aiThreshingTargetX, y, self.aiThreshingTargetZ)
		self.lastSpeedLevel = 0
		AIVehicleUtil.driveInDirection(self, dt, 30, 1, 0.5, 28, true, false, lx, lz, speedLevel, 1) -- dz > 0, lx, lz, maxSpeed, 1)
		if dz >= 0 then
			self.driveBackPosX = nil
		else
			return
		end
	end

	if self.acTurnStage <= 0 then
		AutoCombine.setAiThreshingTarget( self )				
	end
	
  local hasFruitPreparer = false
  local fruitType = self.lastValidInputFruitType
	
	if fruitType == FruitUtil.FRUITTYPE_GRASS then
		if self.acLastValidInputFruitType ~= nil then
			fruitType = self.acLastValidInputFruitType
		else
			fruitType = FruitUtil.FRUITTYPE_UNKNOWN
		end
	end
	
	self.acLastValidInputFruitType = fruitType
	
--==============================================================				
-- find fruit type if cutter supports only one
	if self.acTurnStage == -3 and fruitType == FruitUtil.FRUITTYPE_UNKNOWN then
		local found = nil
		for cutter, implement in pairs(self.attachedCutters) do
			for i,f in pairs(cutter.fruitTypes) do
				if f and i>0 and i ~= FruitUtil.FRUITTYPE_GRASS then
					if fruitType == FruitUtil.FRUITTYPE_UNKNOWN then
						found = true
						fruitType = i
					elseif fruitType ~= i then
						found = false
						break
					end
				end
			end
		end
		
		if found == nil or not found then
			fruitType = FruitUtil.FRUITTYPE_UNKNOWN
		end
	end

-- find fruit type looking ahead
	if self.acTurnStage == -3 and fruitType == FruitUtil.FRUITTYPE_UNKNOWN then
		AutoCombine.calculateDimensions(self)
		d = - self.acDimensions.distance - self.acDimensions.distance
		if not self.acParameters.leftAreaActive then d = -d end

		for cutter, implement in pairs(self.attachedCutters) do
			for i,f in pairs(cutter.fruitTypes) do
				if f and i>0 and i ~= FruitUtil.FRUITTYPE_GRASS then
					if AutoCombine.getFruitArea( self, 0, -1, d, 10, 0, i, false ) > 0 then
						fruitType = i
						break
					end
				end
			end
			if fruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then break end
		end
	end
	
  if self.fruitPreparerFruitType ~= nil and self.fruitPreparerFruitType == fruitType then
    hasFruitPreparer = true
  end

	local angle = 0
	self.acBorderDetected = false
	self.turnTimer        = self.turnTimer - dt
	
	if self.aiRescueTimer ~= nil and self.acTurnStage ~= 0 then
		if self.aiRescueTimer < 0 then
			self:stopAIThreshing()
			return
		end
		self.aiRescueTimer = self.aiRescueTimer - dt
	else
		self.aiRescueTimer = self.acDeltaTimeoutStop
	end
	
--==============================================================				
-- calculate...		
	if fruitType == FruitUtil.FRUITTYPE_UNKNOWN then
		AICombine.setAIImplementsMoveDown(self,true)
		AutoCombine.setStatus( self, 2 )
	else
		AutoCombine.calculateDimensions(self)
	
		local offsetOutside = 0
		if     self.acParameters.rightAreaActive then
			offsetOutside = -1
		elseif self.acParameters.leftAreaActive then
			offsetOutside = 1
		end
			
		AutoCombineHud.setInfoText(self, nil ) 		
		
		local d, lookAhead = 0,10							
		local border	
		local aaDiffX, aaDiffZ = 0,0
		
--==============================================================		
		local turnAngle = math.deg(AutoCombine.getTurnAngle(self))
		if self.acParameters.leftAreaActive then
			turnAngle = -turnAngle
		end
		
--==============================================================				
		self.acFruitsDetected = false
		
		if     self.acTurnStage == 17 then -- and self.acParameters.noReverse then
			d = - self.acDimensions.distance - self.acDimensions.distance
			if not self.acParameters.leftAreaActive then d = -d end
			self.acFruitsDetected = AutoCombine.getFruitArea( self, 0, -2, d, 2, 0, fruitType, hasFruitPreparer ) > 0
		elseif self.acTurnStage == 2 then --or self.acTurnStage == 18 then
			local w = math.max( 2, math.min( 1.4 * self.acDimensions.distance, 0.7 * (self.acDimensions.cutterDistance + self.acDimensions.wheelBase) ) )
			if self.acTurn2Outside then		
				d = - self.acDimensions.distance
			else
				d = - 2 * self.acDimensions.distance
			end
			if not self.acParameters.leftAreaActive then d = -d end
			self.acFruitsDetected = AutoCombine.getFruitArea( self, 0, -w, d, w, 0, fruitType, hasFruitPreparer ) > 0
		elseif self.acTurnStage == 11 or self.acTurnStage == 15 then
			d = self.acDimensions.distance + self.acDimensions.distance
			self.acFruitsDetected = AutoCombine.getFruitArea( self, -self.acDimensions.distance, 0, d, 1, 0, fruitType, hasFruitPreparer ) > 0		
		elseif self.acTurnStage <= 0 or self.acTurnStage == 31 then
			d = self.acDimensions.distance + self.acDimensions.distance
			d = - math.max( 0.9 * d, d - 1 )
			if not self.acParameters.leftAreaActive then d = -d end
			self.acFruitsDetected = AutoCombine.getFruitArea( self, 0, 0, d, 4, 0, fruitType, hasFruitPreparer ) > 0		
		end		

--==============================================================				
		if self.acTurnStage <= 0 then
-- look 3 to 10 meters ahead				
			self.acTurn2Outside = false
			local found = self.acFruitsDetected
			if self.acTurnStage == 0 then found = true end
			
			local lmin = math.min( 7, 2    + math.max( 1, 0.6 * self.acDimensions.distance ) )
			local lmax = math.min(10, lmin + math.max( 2, math.floor( 0.6 * self.acDimensions.distance + 0.5 ) ) )

--			if found then
--				d = - self.acDimensions.distance - self.acDimensions.distance
--				if not self.acParameters.leftAreaActive then d = -d end
--				while not AutoCombine.isField( self, 0, lmax, d, 1 ) do
--					lmax = lmax - 1
--					if lmax < lmin then 
--						lmin = lmin - 1
--						if lmin < 0.5 then
--							break
--						end
--					end
--				end
--			end
						
			lookAhead = lmin
			while lookAhead < lmax do --10 do
				d = AutoCombine.calculateWidth(self,lookAhead-1,self.acDimensions.maxLookingAngle)
				local w = math.max(1, AutoCombine.calculateWidth(self,lookAhead-1,-self.acDimensions.maxSteeringAngle) + d )
				if not self.acParameters.leftAreaActive then 
					d = -d
				else
					w = -w
				end
				if     not AutoCombine.isField( self, d, lookAhead, w, 1, 0 ) then
					break
				elseif not found and AutoCombine.getFruitArea( self, d, lookAhead-1, w, 1, 0, fruitType, hasFruitPreparer ) > 0 then
					found = true
				elseif found and ( lookAhead >= lmax or AutoCombine.getFruitArea( self, d, lookAhead-1, w, 1, 0, fruitType, hasFruitPreparer ) <= 0 ) then
					break
				end
				lookAhead = lookAhead + 1
				if lookAhead > 10 then
					lookAhead = 10
					break
				end
			end
	
			local turnAngleRad   = 0 
			local limitAngle     = false
			local maxUpDownAngle = 1.3089969389957471826927680763665 -- 75°
			
			if self.acTurnStage == 0 and AutoCombine.getTraceLength(self) > 1 then
			  limitAngle   = -3.14 <= turnAngleRad and turnAngleRad <= 3.14
				turnAngleRad = AutoCombine.getTurnAngle(self)
				if self.acParameters.leftAreaActive then
					turnAngleRad = -turnAngleRad
				end
				if self.acParameters.upNDown then
					maxUpDownAngle = 0.52359877559829887307710723054658 -- 30°
				end
			end
			

			if lookAhead < 0.5 then
				self.acFruitsDetected = false		
				self.acBorderDetected = false
				border                = 0
			else
				angle        = 0	
				border       = AutoCombine.getFruitArea( self, 0, 0, offsetOutside, lookAhead, 0, fruitType, hasFruitPreparer )
				local factor = 0.05		
				factor       = factor * factor
				if border <= 0 then
					factor = -factor					
				elseif self.acDimensions.maxLookingAngle < self.acDimensions.maxSteeringAngle then
					factor = factor * self.acDimensions.maxLookingAngle / self.acDimensions.maxSteeringAngle
				end 
				
				for i=1,20 do
					local a = factor*i*i*self.acDimensions.maxSteeringAngle 	
					if limitAngle then
						a = math.max( a, turnAngleRad - maxUpDownAngle )
					end
					d = AutoCombine.calculateWidth(self,lookAhead,a)
					if not self.acParameters.leftAreaActive then d = -d end
					if self.acDimensions.aaAngleFactor > 0 then
						aaDiffX = math.sin( self.acDimensions.aaAngleFactor * a ) * self.acDimensions.aaDistance
						aaDiffZ = ( math.cos( self.acDimensions.aaAngleFactor * a ) - 1 ) * self.acDimensions.aaDistance
						if not self.acParameters.leftAreaActive then aaDiffX = -aaDiffX end
					end

					b = AutoCombine.getFruitArea( self, aaDiffX, aaDiffZ, offsetOutside, lookAhead, d, fruitType, hasFruitPreparer )
					
					if     border > 0 then
						if b <= 0 then
							self.acBorderDetected = true
							angle = a
							break
						end
					else
						if b > 0 then
							self.acBorderDetected = true
							break
						end
					end
					angle = a
				end
			end
			
			if not self.acBorderDetected then
				if      self.acTurnStage              <   0
						and self.acTurnStage              >  -3
						and self.acDirectionBeforeTurn.tx ~= nil
						and self.acDirectionBeforeTurn.tz ~= nil then
					-- navigate to last good point
					angle = nil			
				elseif border > 0 then
					-- border => to outside
					angle = self.acDimensions.maxSteeringAngle
					self.acTurn2Outside = true				
				elseif  not ( self.acFruitsDetected ) then
					-- no fruits at all => straight
					if self.acParameters.upNDown then
						angle = turnAngleRad 
					else
						angle = 0
					end
				elseif  self.acTurnStage == 0 
						and self.turnTimer   >= 0 then
					-- in field, no border but fruits => straight until turnTimer < 0
					if self.acParameters.upNDown then
						angle = turnAngleRad 
					else
						angle = 0
					end
				else
					-- no border but fruits => to inside
					angle = -self.acDimensions.maxSteeringAngle
					if limitAngle then
						angle = math.max( angle, turnAngleRad - maxUpDownAngle )
					end
				end
			end
						
--==============================================================				
-- backwards
		elseif self.acTurnStage == 2 or self.acTurnStage == 18 then
			self.acBorderDetected = false

			local a, b2, at1, at2
			local offsetInside               = -offsetOutside			
			local fMin, fMax, fStep          = 0,1,0.1
			
			for l=18,3,-3 do
			if self.acTurn2Outside then
				angle = self.acDimensions.maxSteeringAngle
			else
				angle = -self.acDimensions.maxSteeringAngle
			end
			
			--for l=3,18,3 do
				local doBreak = false
				for f=fMin,fMax,fStep do
					a = f*self.acDimensions.maxLookingAngle 	
					if not self.acTurn2Outside then a = -a end

					d = AutoCombine.calculateWidth(self,l,-a)
					if not self.acParameters.leftAreaActive then d = -d end

					border, at1 = AutoCombine.getFruitArea( self, aaDiffX, aaDiffZ, offsetOutside, l, d, fruitType, hasFruitPreparer )
					b2    , at2 = AutoCombine.getFruitArea( self, aaDiffX, aaDiffZ, offsetInside , l, d, fruitType, hasFruitPreparer )				
									
					if border < 1 and b2 > 0 then
						--print(tostring(l).." "..tostring(d).." "..tostring(offsetOutside).." "..tostring(math.deg(a)).." "..tostring(f))
						angle   = a
						--doBreak = true
						self.acBorderDetected = true
						break
					elseif self.acTurnStage == 2 then
						if     self.acTurn2Outside and border < 1 then
							angle = math.min( angle, a )
						elseif not self.acTurn2Outside and b2 > 0 then
							angle = math.max( angle, a )
						end
					end
				end
				if doBreak then
					break
				end			
			end
			
--==============================================================		
-- U turn		
		elseif self.acTurnStage == 17 or self.acTurnStage == 31 then
			angle = self.acDimensions.maxLookingAngle
			d = AutoCombine.calculateWidth(self,lookAhead,angle)
			if not self.acParameters.leftAreaActive then d = -d end
		
			border = AutoCombine.getFruitArea( self, aaDiffX, aaDiffZ, -offsetOutside, lookAhead, d, fruitType, hasFruitPreparer )
				
			if border > 0 then
				border = AutoCombine.getFruitArea( self, aaDiffX, aaDiffZ, offsetOutside, lookAhead, d, fruitType, hasFruitPreparer )
				if border < 1 then
					self.acBorderDetected = true						
				end
			end
			
--==============================================================		
-- 90° with dolly backwards
		elseif self.acTurnStage == 5 then
			if AutoCombine.getTurnDistance(self) > 20 then
				self.acBorderDetected = true
			elseif self.acTurn2Outside then		
				angle = self.acDimensions.maxLookingAngle
				d = AutoCombine.calculateWidth(self,lookAhead,angle)
				if not self.acParameters.leftAreaActive then d = -d end
				border = AutoCombine.getFruitArea( self, aaDiffX, aaDiffZ, offsetOutside, lookAhead, d, fruitType, hasFruitPreparer )
				if border < 1 then
					self.acBorderDetected = true
				end
			else				
				local dist = self.acDimensions.radius + self.acDimensions.distance - self.acDimensions.cutterDistance

				self.acParameters.leftAreaActive = not self.acParameters.leftAreaActive
				border = AutoCombine.getFruitArea( self, aaDiffX, dist + aaDiffZ, - offsetOutside * ( self.acDimensions.distance + self.acDimensions.distance ), 1, 0, fruitType, hasFruitPreparer )
				self.acParameters.leftAreaActive = not self.acParameters.leftAreaActive
				
				if border > 0 then
					self.acBorderDetected = true					
				end
			end
			
--==============================================================		
-- 90° with dolly forwards
		elseif self.acTurnStage == 7 then
			if self.acTurn2Outside then				
				angle = self.acDimensions.maxLookingAngle
			else
				angle = -self.acDimensions.maxLookingAngle
			end
			
			d = AutoCombine.calculateWidth(self,lookAhead,angle)
			if not self.acParameters.leftAreaActive then d = -d end
		
			if self.acTurn2Outside then
				border = AutoCombine.getFruitArea( self, aaDiffX, aaDiffZ, offsetOutside, lookAhead, d, fruitType, hasFruitPreparer )
				if border < 1 then
					self.acBorderDetected = true
				end
			else
				border = AutoCombine.getFruitArea( self, aaDiffX, aaDiffZ, -offsetOutside, lookAhead, d, fruitType, hasFruitPreparer )
			
				if border > 0 then
					border = AutoCombine.getFruitArea( self, aaDiffX, aaDiffZ, offsetOutside, lookAhead, d, fruitType, hasFruitPreparer )
					if border < 1 then
						self.acBorderDetected = true						
					end
				end
			end
		end
		
--==============================================================		
--==============================================================		

		if angle == nil then
			local m = self.acDimensions.maxSteeringAngle
			
			if self.acTrunStage == -2 then
				angle = 0
			elseif self.acTurn2Outside then
				angle = m
			else
				angle = -m
			end
		
			if self.acDirectionBeforeTurn.tx ~= nil and self.acDirectionBeforeTurn.tz ~= nil then
				local x,z,dx,dz,wx,wz
				if self.acParameters.leftAreaActive then
					x,_,z = localToWorld(self.acRefNode, self.acDimensions.xLeft, 0, self.acDimensions.zLeft )
				else
					x,_,z = localToWorld(self.acRefNode, self.acDimensions.xRight, 0, self.acDimensions.zRight)
				end			
				dx = self.acDirectionBeforeTurn.tx - x
				dz = self.acDirectionBeforeTurn.tz - z		
				wx,_,wz = worldDirectionToLocal(self.acRefNode,dx,0,dz)
				
			--print(tostring(wx)(wx).." "..tostring(wz))
				--if wz < 0 then wz = -wz end

				if wz > 0.1 then
					
					if not self.acParameters.leftAreaActive then wx = -wx end
					
					dmax = AutoCombine.calculateWidth(self,wz, self.acDimensions.maxLookingAngle)
					dmin = AutoCombine.calculateWidth(self,wz,-self.acDimensions.maxSteeringAngle)
						
					if wx > dmax then
						angle = m
					elseif wx < dmin then
						angle = -m
					else
						angle = AutoCombine.calculateSteeringAngle(self,wx,wz)
					end
					if self.acTurnStage >= 0 and math.abs(wx) < 0.2 and wz > 4 then
						self.acBorderDetected = true									
					end
				--print(tostring(wx)(math.deg(angle)))
				end
			end
		end

--==============================================================		
--==============================================================		
-- turn 90° or turn outside
		if     self.acTurnStage == 1 then
			AICombine.setAIImplementsMoveDown(self,false)
			self.acTurnStage   = 8
			self.turnTimer     = self.acDeltaTimeoutWait
--==============================================================		
-- move far enough			
		elseif self.acTurnStage == 8 then

			if AutoCombine.getTurnDistance(self) > 5 then
				angle = 0
			elseif self.acIsCPCombine and turnAngle > 5 then
				angle = self.acDimensions.maxSteeringAngle
			elseif math.abs( turnAngle ) > 3 and self.strawPSenabled then
				angle = math.rad( turnAngle )
			elseif turnAngle < -5 then
				angle = math.rad( turnAngle )
			else
				angle = 0
			end

			if      self.acTurn2Outside then
				self.acTurnStage   = 4
				self.turnTimer     = self.acDeltaTimeoutWait
				allowedToDrive     = false				
				self.waitForTurnTime = g_currentMission.time + self.turnTimer
			elseif  math.abs( angle ) < 0.02 
					and AutoCombine.getTurnDistanceZ(self) > self.acDimensions.insideDistance - 0.5 then
				self.acTurnStage   = 4
				self.turnTimer     = self.acDeltaTimeoutWait
				allowedToDrive     = false				
				self.waitForTurnTime = g_currentMission.time + self.turnTimer
			end

--==============================================================				
-- wait before going back				
		elseif self.acTurnStage == 4 then
			allowedToDrive = false				
			moveForwards   = false		
			local targetTS = 2

			if self.acParameters.noReverse then
				angle    = 0
				targetTS = 5
			elseif self.acTurn2Outside then				
				angle    = self.acDimensions.maxSteeringAngle
			elseif AutoCombine.getTurnDistanceZ(self) > self.acDimensions.insideDistance + 0.5 then
				angle    = math.rad( turnAngle )
				targetTS = 9
			else
				angle    = -self.acDimensions.maxSteeringAngle
			end
			
			--if self.turnTimer < 0 then
			if self.strawPSenabled then
			-- wait
			elseif self.waitForTurnTime < g_currentMission.time then
				self.acTurnStage = targetTS
				self.turnTimer   = self.acDeltaTimeoutStart
			end

--==============================================================				
-- going back (straight)
		elseif self.acTurnStage == 9 then
			
			moveForwards = false					
			angle        = math.rad( turnAngle )
			
			if AutoCombine.getTurnDistanceZ(self) < self.acDimensions.insideDistance then
				self.acTurnStage = 2
				self.turnTimer   = self.acDeltaTimeoutStart
			end
			
--==============================================================				
-- going back (turn 90°)
		elseif self.acTurnStage == 2 then

			moveForwards = false					
			
			if     AutoCombine.getTurnDistance(self) > 18
					or ( not self.acFruitsDetected
					 and ( self.acBorderDetected or ( self.turnTimer < 0 and math.abs( turnAngle ) > 90 ) ) ) 
					or ( self.acTurn2Outside and self.acBorderDetected ) then
				self.acTurnStage   = 3
				self.turnTimer     = self.acDeltaTimeoutWait
				self.lastTurnAngle = -angle
				AICombine.setAIImplementsMoveDown(self,true)
			end

--==============================================================				
-- wait after going back					
		elseif self.acTurnStage == 3 then
			allowedToDrive = false						
			
			angle = self.lastTurnAngle
			
			if self.turnTimer < 0 then
				self.acTurnStage   = -1					
				self.turnTimer     = self.acDeltaTimeoutStart
			end
			
--==============================================================				
-- going back
		elseif self.acTurnStage == 5 then

			moveForwards = false				
			angle        = 0
			
			for _, implement in pairs(self.attachedImplements) do
				if implement.object.steeringAxleNode ~= nil and implement.object.steeringAxleNode > 0 then
					local toolAngle = AutoCombine.getRelativeYRotation( self.acRefNode, implement.object.steeringAxleNode )
					if self.acParameters.leftAreaActive then
						toolAngle = -toolAngle
					end
					angle = math.min( math.max( toolAngle, -self.acDimensions.maxSteeringAngle ), self.acDimensions.maxSteeringAngle )
				end
			end
			
			if self.acBorderDetected then
				self.acTurnStage   = 6					
				self.turnTimer     = self.acDeltaTimeoutStart
				AICombine.setAIImplementsMoveDown(self,true)
			end
			
--==============================================================				
-- wait before going forward				
		elseif self.acTurnStage == 6 then
			allowedToDrive = false				

			if self.acTurn2Outside then				
				angle = self.acDimensions.maxSteeringAngle
			else
				angle = -self.acDimensions.maxSteeringAngle
			end
						
			--if self.turnTimer < 0 then
			if self.waitForTurnTime < g_currentMission.time then
				self.acTurnStage = 7
				self.turnTimer   = self.acDeltaTimeoutWait
			end

--==============================================================				
-- going forward
		elseif self.acTurnStage == 7 then
		
			if self.acFruitsDetected or self.acBorderDetected then
				self.acTurnStage   = -1					
				self.turnTimer     = self.acDeltaTimeoutStart
			elseif self.acTurn2Outside then				
				angle = self.acDimensions.maxSteeringAngle
			else
				angle = -self.acDimensions.maxSteeringAngle
			end

--==============================================================				
-- U turn w/o reverse
--==============================================================				
-- wait before U-turn					
		elseif self.acTurnStage == 11 then
			allowedToDrive = false		
			noBreaking     = false
			angle = 0

			--if self.turnTimer < 0 then
			if self.strawPSenabled then
			-- wait
				if math.abs( turnAngle ) > 3 then
					angle          = math.rad( turnAngle )
					allowedToDrive = true
				end
			elseif self.waitForTurnTime < g_currentMission.time then
				AICombine.setAIImplementsMoveDown(self,false)

				if self.acTurn2Outside then
					self.acTurnStage = 12
					self.turnTimer   = self.acDeltaTimeoutStop
				elseif not self.acFruitsDetected and AutoCombine.getTurnDistance(self) > self.acDimensions.uTurnDistance then
					self.acTurnStage = 17
					self.lastTurnAngle = math.deg(AutoCombine.getTurnAngle(self))					
				else
					self.acTurnStage = 15
					self.turnTimer   = self.acDeltaTimeoutWait
				end
			end
			
--==============================================================				
-- move to the right position before U-turn					
		elseif  self.acTurnStage == 12 then

			if self.acTurn2Outside then
				angle = -self.acDimensions.maxSteeringAngle
										
				if turnAngle >= math.deg(self.acDimensions.uTurnAngle) then
					self.acTurn2Outside = false
					self.acTurnStage = 13
					self.turnTimer   = self.acDeltaTimeoutRun
				end
			else
				angle = self.acDimensions.maxSteeringAngle
								
				if turnAngle <= 0 then
					if not self.acFruitsDetected and AutoCombine.getTurnDistance(self) > self.acDimensions.uTurnDistance then
						--AICombine.setAIImplementsMoveDown(self,true)
						self.acTurnStage = 17
						self.lastTurnAngle = math.deg(AutoCombine.getTurnAngle(self))					
					else
						self.acTurnStage = 14
						self.turnTimer   = self.acDeltaTimeoutRun
					end
				end
			end

--==============================================================				
-- wait during U-turn
		elseif self.acTurnStage == 13 then
			allowedToDrive = false						
			noBreaking     = true
			
			angle = self.acDimensions.maxSteeringAngle
			
			if self.turnTimer < 0 then
				self.acTurnStage = 12					
			end

--==============================================================				
-- wait during U-turn before going forward
		elseif self.acTurnStage == 14 then
			allowedToDrive = false						
			noBreaking     = true
			
			angle = 0
			
			if self.turnTimer < 0 then
				self.acTurnStage = 15					
			end
			
--==============================================================				
-- go to the right distance before the U-turn
		elseif self.acTurnStage == 15 then

			angle = 0
				
			if not self.acFruitsDetected and AutoCombine.getTurnDistance(self) > self.acDimensions.uTurnDistance then
				self.acTurnStage = 16					
				self.turnTimer   = self.acDeltaTimeoutRun
			end

--==============================================================				
-- wait during U-turn after going forward
		elseif self.acTurnStage == 16 then

			allowedToDrive = false						
			noBreaking     = true
												
			angle = self.acDimensions.maxSteeringAngle
			if self.turnTimer < 0 then
				--AICombine.setAIImplementsMoveDown(self,true)
				self.acTurnStage   = 17					
				self.lastTurnAngle = math.deg(AutoCombine.getTurnAngle(self))					
			end
			
--==============================================================				
-- The U-turn					
		elseif self.acTurnStage == 17 then
	
			if self.acBorderDetected then
				AICombine.setAIImplementsMoveDown(self,true)
				self.acTurnStage    = 19				
				self.lastTurnAngle  = self.acDimensions.maxLookingAngle
				self.turnTimer      = self.acDeltaTimeoutRun
			elseif turnAngle <= -175 then 
				AICombine.setAIImplementsMoveDown(self,true)
				self.acTurnStage      = 19				
				self.lastTurnAngle    = 0
				self.turnTimer        = self.acDeltaTimeoutRun
			elseif  self.acFruitsDetected 
					and self.acBorderDetected then
				AICombine.setAIImplementsMoveDown(self,true)
				self.acTurnStage    = 19				
				self.lastTurnAngle  = self.acDimensions.maxLookingAngle
				self.turnTimer      = self.acDeltaTimeoutRun
			end
			
			angle = self.acDimensions.maxSteeringAngle

--==============================================================				
-- going back
		elseif self.acTurnStage == 18 then

			moveForwards = false					
			
			if      self.acBorderDetected 
					and not self.acFruitsDetected then
				AICombine.setAIImplementsMoveDown(self,true)
				self.acTurnStage    = 19
				self.turnTimer      = self.acDeltaTimeoutRun
				self.lastTurnAngle  = angle
			elseif math.abs(turnAngle) > 175 then
				AICombine.setAIImplementsMoveDown(self,true)
				self.acTurnStage    = 19
				self.turnTimer      = self.acDeltaTimeoutRun
				self.lastTurnAngle  = 0
			end

--==============================================================				
-- wait after U-turn
		elseif self.acTurnStage == 19 then
			allowedToDrive = false						
			
			angle = self.lastTurnAngle
			
			if self.turnTimer < 0 then
				self.acTurnStage = -2					
				self.turnTimer   = self.acDeltaTimeoutStart
			end
			
--==============================================================				
-- U turn with reverse
--==============================================================				
-- raise cutter 			
		elseif self.acTurnStage == 21 then
			AICombine.setAIImplementsMoveDown(self,false)
			self.acTurnStage = self.acTurnStage + 1
			self.turnTimer   = self.acDeltaTimeoutRun
			
		--print(string.format("acTurnStage 21: %2.2fm",AutoCombine.getTurnDistanceZ(self)))
			
--==============================================================				
-- go to the right distance before the U-turn
		elseif self.acTurnStage == 22 then

			angle = math.rad( turnAngle )
			
			local z = AutoCombine.getTurnDistanceZ(self)
		--print(string.format("acTurnStage 22: %2.2fm",z))

			if     z > self.acDimensions.uTurnDistance2 + 0.5 then
				moveForwards = false
			--angle = -angle
			elseif z < self.acDimensions.uTurnDistance2 - 0.5 then
				moveForwards = true
			else
				self.acTurnStage = self.acTurnStage + 1
				self.turnTimer   = self.acDeltaTimeoutRun
			end

--==============================================================				
-- wait before U-turn					
		elseif self.acTurnStage == 23 then
			allowedToDrive = false		
			angle          = self.acDimensions.maxSteeringAngle

			local z = AutoCombine.getTurnDistanceZ(self)

			if self.strawPSenabled then
			-- wait
				angle            = math.rad( turnAngle )
				self.turnTimer   = self.acDeltaTimeoutRun
			--noBreaking       = true
			elseif self.turnTimer < 0 then
				self.acTurnStage = self.acTurnStage + 1
				self.turnTimer   = self.acDeltaTimeoutRun
				angle = self.acDimensions.maxSteeringAngle
			--print(string.format("acTurnStage 23: %2.2fm",AutoCombine.getTurnDistanceZ(self)))
			end

--==============================================================				
-- turn 90°
		elseif self.acTurnStage == 24 then

			angle = self.acDimensions.maxSteeringAngle
			
			if turnAngle < -87 then

				if     AutoCombine.getTurnDistanceX(self) > self.acDimensions.distance + self.acDimensions.distance + 0.5
				    or AutoCombine.getTurnDistanceX(self) < self.acDimensions.distance + self.acDimensions.distance - 0.5 then
				-- move to right position II
					self.acTurnStage = self.acTurnStage + 1
					self.turnTimer   = self.acDeltaTimeoutRun
				else
				-- turn 30°
					self.acTurnStage = self.acTurnStage + 4
					self.turnTimer   = self.acDeltaTimeoutRun
				end
			end
			
--==============================================================				
-- wait during U-turn
		elseif self.acTurnStage == 25 then
			allowedToDrive = false	
			noBreaking     = true
			
			angle = math.rad( turnAngle + 90 )
			
			if self.turnTimer < 0 then
				self.acTurnStage = self.acTurnStage + 1
				self.turnTimer   = self.acDeltaTimeoutRun
			end

--==============================================================				
-- move to right position II
		elseif self.acTurnStage == 26 then

			angle = math.rad( turnAngle + 90 )
			
			if     AutoCombine.getTurnDistanceX(self) > self.acDimensions.distance + self.acDimensions.distance + 0.5 then
				moveForwards = false
			--angle = -angle
			elseif AutoCombine.getTurnDistanceX(self) < self.acDimensions.distance + self.acDimensions.distance - 0.5 then
				moveForwards = true					
			else
				self.acTurnStage = self.acTurnStage + 1
				self.turnTimer   = self.acDeltaTimeoutRun
			end
			
--==============================================================				
-- wait during U-turn
		elseif self.acTurnStage == 27 then
			allowedToDrive = false						
			
			angle = self.acDimensions.maxSteeringAngle
			
			if self.turnTimer < 0 then
				self.acTurnStage = self.acTurnStage + 1
				self.turnTimer   = self.acDeltaTimeoutRun
			end

--==============================================================				
-- turn 30°
		elseif self.acTurnStage == 28 then

			angle = self.acDimensions.maxSteeringAngle
			
			if turnAngle < -119 then
				self.acTurnStage = self.acTurnStage + 1
				self.turnTimer   = self.acDeltaTimeoutRun
			end
			
--==============================================================				
-- wait during U-turn
		elseif self.acTurnStage == 29 then
			allowedToDrive = false						
			
			angle = -self.acDimensions.maxSteeringAngle
			
			if self.turnTimer < 0 then
				self.acTurnStage = self.acTurnStage + 1
				self.turnTimer   = self.acDeltaTimeoutRun
			end
			
--==============================================================				
-- turn -60°
		elseif self.acTurnStage == 30 then

			angle = self.acDimensions.maxSteeringAngle
			moveForwards = false
			
			if turnAngle < -175 or turnAngle > 0 then
				self.acTurnStage   = self.acTurnStage + 1
				self.turnTimer     = self.acDeltaTimeoutRun
			end
		
--==============================================================				
-- turn -60°
		elseif self.acTurnStage == 31 then

			angle = math.rad( 180 - turnAngle )
			moveForwards = false
			
			if     self.acFruitsDetected then
			elseif self.acBorderDetected then
				AICombine.setAIImplementsMoveDown(self,true)
				self.lastTurnAngle = angle
				self.acTurnStage   = self.acTurnStage + 1
				self.turnTimer     = self.acDeltaTimeoutRun
			elseif turnAngle < -175 or turnAngle > 0 then
				AICombine.setAIImplementsMoveDown(self,true)
				self.lastTurnAngle = angle
				self.acTurnStage   = self.acTurnStage + 1
				self.turnTimer     = self.acDeltaTimeoutRun
			end
		
--==============================================================				
-- wait after U-turn
		elseif self.acTurnStage == 32 then
			allowedToDrive = false						
			
			angle = self.lastTurnAngle
			
			if self.turnTimer < 0 then
				self.acTurnStage = -2					
				self.turnTimer   = self.acDeltaTimeoutStart
			end
			
--==============================================================	
-- after start of hired worker or after turn			
--==============================================================				
-- searching...
		elseif self.acTurnStage < 0 then
			AutoCombine.saveDirection( self, false )
			moveForwards     = true

			if      self.acFruitsDetected 
					and ( self.acTurnStage > -3 or self.acBorderDetected ) then
				self.acTurnStage    = 0
				self.acTurn2Outside = false
				self.turnTimer      = self.acDeltaTimeoutNoTurn
				self.aiRescueTimer  = self.acDeltaTimeoutStop
			end
			
--==============================================================
-- in the field				
--==============================================================				
-- threshing...					
		elseif self.acTurnStage == 0 then
			moveForwards     = true
			
			--if not self.acBorderDetected then 
			--	print(tostring(math.deg(angle)).." "..tostring(self.acBorderDetected).." "..tostring(self.acFruitsDetected).." "..tostring(self.acTurn2Outside))
			--end
			
			if self.acBorderDetected then --and self.acFruitsDetected then
				AutoCombine.saveDirection( self, true )
				self.turnTimer   	  = math.max(self.turnTimer,self.acDeltaTimeoutRun)
				self.aiRescueTimer  = self.acDeltaTimeoutStop
			elseif  self.acFruitsDetected 
					and not self.acTurn2Outside then
				AutoCombine.saveDirection( self, true )
			elseif self.turnTimer < 0 then
			
--==============================================================				
--      Stop ???
				if not self.acTurn2Outside and not self.acFruitsDetected then 
					local dist    = math.floor( 2.5 * math.max( 10, self.acDimensions.distance ) )
					local wx,_,wz = getWorldTranslation( self.acRefNode )
					local stop    = true
					local lx,lz
					for i=0,dist do
						for j=0,dist do
							for k=1,4 do
								if     k==1 then 
									lx = wx + i
									lz = wz + j
								elseif k==2 then
									lx = wx - i
									lz = wz + j
								elseif k==3 then
									lx = wx + i
									lz = wz - j
								else
									lx = wx - i
									lz = wz - j
								end
								if Utils.getFruitArea(fruitType, lx-0.5,lz-0.5,lx+1,lz,lx,lz+1, hasFruitPreparer) > 0 then
									stop = false
									break
								end						
							end
							if not stop then break end
						end
						if not stop then break end
					end
							
					if stop then
						self:stopAIThreshing()
						return
					end
				end			
--==============================================================				
			
				if     self.acTurn2Outside 
						or not self.acParameters.upNDown
						or AutoCombine.getTraceLength(self) < self.acDimensions.distance + self.acDimensions.distance then		
					self.acTurnStage = 1
					self.turnTimer = self.acDeltaTimeoutWait
				elseif self.acParameters.noReverse then
					--invert turn angle because we will swap left/right in about 10 lines
					turnAngle = -turnAngle
					self.acTurn2Outside = true --turnAngle < self.acDimensions.uTurnAngle
					self.acTurnStage = 11
					self.turnTimer = self.acDeltaTimeoutWait
					self.waitForTurnTime = g_currentMission.time + self.turnTimer
					self:acSetState( "leftAreaActive", not self.acParameters.leftAreaActive )
				else
					--invert turn angle because we will swap left/right in about 10 lines
					turnAngle = -turnAngle
					self.acTurnStage = 21
					self.turnTimer = self.acDeltaTimeoutWait
					self.waitForTurnTime = g_currentMission.time + self.turnTimer
					self:acSetState( "leftAreaActive", not self.acParameters.leftAreaActive )
				end
				AutoCombine.saveDirection( self, false )
			end
			
--==============================================================				
-- error!!!
		else
			allowedToDrive = false						
			AutoCombineHud.setInfoText(self, string.format(AutoCombineHud.getText("AC_COMBINE_ERROR")..": %i",self.acTurnStage))
			self:stopAIThreshing()
			return
		end

		if self.acTurnStage == -3 and self.acBorderDetected then
			AutoCombine.setStatus( self, 2 )
		elseif self.acTurnStage == -3 then
			AutoCombine.setStatus( self, 0 )
		elseif self.acTurnStage <= 0 then
			if self.acBorderDetected then
				AutoCombine.setStatus( self, 1 )
			else
				AutoCombine.setStatus( self, 2 )
			end
		else
			AutoCombine.setStatus( self, 0 )
		end		
	end		
--==============================================================				


--==============================================================				
--==============================================================				
	if math.abs( self.acAxisSide ) > 0.1 then
		self.acOverrideSteeringTime = g_currentMission.time + 2000
	end
	
	if self.acOverrideSteeringTime ~= nil then
		if self.acOverrideSteeringTime <= g_currentMission.time then
			self.acOverrideSteeringTime = nil
		else
			AutoCombine.setStatus( self, 0 )
			self.acBorderDetected = false
			border   = 0
			deltaAngle = 0.001 * ( self.acOverrideSteeringTime - g_currentMission.time ) * self.acAxisSide * self.acDimensions.maxSteeringAngle
			if self.acParameters.leftAreaActive then
				deltaAngle = -deltaAngle		
			end
			if not moveForwards then
				deltaAngle = -deltaAngle		
			end
			angle          = angle + deltaAngle
			self.turnTimer = self.turnTimer + dt
			if self.aiRescueTimer ~= nil and self.acTurnStage <= 0 then
				self.aiRescueTimer = self.aiRescueTimer + dt
			end			
		end
	end			
--==============================================================				
--==============================================================				


	local acceleration = 0					
	local slowAngleLimit = 20
	if self.isMotorStarted and speedLevel ~= 0 and self.fuelFillLevel > 0 then
		acceleration = 1.0
	end
	
	--if not allowedToDrive and moveForwards and noBreaking and self.lastSpeedLevel > 0 then
	--	allowedToDrive = true
	--	speedLevel     = math.max( 0, self.lastSpeedLevel - 0.002 * dt )
	--elseif not allowedToDrive then
	--	speedLevel     = 0
	--end		
	if not allowedToDrive then
		speedLevel     = 0
	end		

	if self.haeckseldolly and self.acTurnStage ~= 0 then
		for _, implement in pairs(self.attachedImplements) do
			if implement.object.bunkerrechts ~= nil then
				implement.object.bunkerrechts = not self.acParameters.leftAreaActive
			end
		end
	end
	
	local maxAngle = 25
	if self.acDimensions ~= nil and self.acDimensions.maxSteeringAngle ~= nil then
		maxAngle = math.deg( self.acDimensions.maxSteeringAngle )
	end
	
	local lx, lz = 0, 1

--local turnAngleRad = AutoCombine.getTurnAngle(self)
--if self.acParameters.leftAreaActive then
--	turnAngleRad = -turnAngleRad
--end
--print( self, string.format( "stage: %d angle: %3.1f° turn: %3.1f°", self.acTurnStage, math.deg( Utils.getNoNil( angle, 0 )), math.deg( turnAngleRad ) ) )
		
	if angle == nil then
		angle = 0
	elseif not self.acParameters.leftAreaActive then
		angle = -angle
	end

	self.turnStage = 0
	self.turnAP    = nil
	if self.acTurnStage ==  4 then
		self.turnStage = 1
		--self.turnAP    = true
	elseif self.acTurnStage ==  3 then
		self.turnStage = 5
		--self.turnAP    = true
	elseif self.acTurnStage >=  2 and self.acTurnStage <  11 then
		if self.acParameters.noReverse then
			self.turnStage = 3
		else
			self.turnStage = 2
		end
		--self.turnAP    = true
	elseif self.acTurnStage >= 12 and self.acTurnStage <  15 then
		self.turnStage = 1
	elseif self.acTurnStage >= 15 and self.acTurnStage <  17 then
		if self.acParameters.noReverse then
			self.turnStage = 3
		else
			self.turnStage = 2
		end
	elseif self.acTurnStage >= 17 and self.acTurnStage <  18 then
		self.turnStage = 4
	elseif self.acTurnStage >= 18 and self.acTurnStage <= 19 then
		self.turnStage = 5		
		
	elseif self.acTurnStage >= 21 and self.acTurnStage <= 23 then
		self.turnStage = 1
	elseif self.acTurnStage >= 24 and self.acTurnStage <= 25 then
		self.turnStage = 2
	elseif self.acTurnStage >= 26 and self.acTurnStage <= 29 then
		self.turnStage = 4
	elseif self.acTurnStage >= 30 and self.acTurnStage <= 32 then
		self.turnStage = 5		
		
	else
		self.turnStage = 0
	end
	
	if acceleration > 0 and speedLevel > 7 then
		if self.acTurnStage ~= 0 or not self.acBorderDetected then
			speedLevel = 7
		end
	end
	
	lx, lz = math.sin(angle), math.cos(angle)
	
	if      self.acTurnStage == 0 
			and self.acBorderDetected 
			and self.acFruitsDetected then
		self.aiSteeringSpeed = 0.75 * self.acSteeringSpeed	
	elseif self.acTurnStage <= 0 then
		self.aiSteeringSpeed = self.acSteeringSpeed	
	else
		self.aiSteeringSpeed = 1.5 * self.acSteeringSpeed	
	end
		
	if self.lastSpeedLevel == nil or self.lastSpeedLevel < 0 then
		self.lastSpeedLevel = speedLevel 
	elseif speedLevel > self.lastSpeedLevel then
		speedLevel = math.min( speedLevel, math.max( 3, self.lastSpeedLevel + 0.0015 * dt ) )
	elseif speedLevel > 0  then                                                         
		speedLevel = math.max( speedLevel, self.lastSpeedLevel - 0.0015 * dt )
	end
	self.lastSpeedLevel = speedLevel
	
	AIVehicleUtil.driveInDirection(self, dt, maxAngle, acceleration, math.max(0.25,0.75*acceleration), slowAngleLimit, allowedToDrive, moveForwards, lx, lz, speedLevel, 0.6)
	
	--local maxlx = 0.7071067 --math.sin(maxAngle)
	--local colDirX = lx
	--local colDirZ = lz
	--
	--if colDirX > maxlx then
	--	colDirX = maxlx
	--	colDirZ = 0.7071067 --math.cos(maxAngle)
	--elseif colDirX < -maxlx then
	--	colDirX = -maxlx
	--	colDirZ = 0.7071067 --math.cos(maxAngle)
	--end
	--
	--if not moveForwards or not allowedToDrive then
	--	colDirX = 0
	--	colDirZ = 1
	--end
  --
	--if self.acBackTrafficCollisionTrigger ~= nil then		
	--	AIVehicleUtil.setCollisionDirection(self.aiTreshingDirectionNode, self.acBackTrafficCollisionTrigger, colDirX, colDirZ)
	--end
  --
	--for triggerId,_ in pairs(self.numCollidingVehicles) do
	--	AIVehicleUtil.setCollisionDirection(self.aiTreshingDirectionNode, triggerId, colDirX, colDirZ)
	--end	
		
	self.aiSteeringSpeed = self.acSteeringSpeed	
end 

------------------------------------------------------------------------
-- autoSteer
------------------------------------------------------------------------
function AutoCombine:autoSteer(dt)

	AutoCombine.calculateDimensions(self)

	local offsetOutside = 0
	if     self.acParameters.rightAreaActive then
		offsetOutside = -1
	elseif self.acParameters.leftAreaActive then
		offsetOutside = 1
	end
		
  local fruitType = self.lastValidInputFruitType
  if fruitType == FruitUtil.FRUITTYPE_UNKNOWN then
		return
	elseif self.fruitPreparerFruitType ~= nil and self.fruitPreparerFruitType == fruitType then
    hasFruitPreparer = true
  end
	local d, lookAhead = 0,4							
	local aaDiffX, aaDiffZ = 0,0
  local hasFruitPreparer = false
	local border = AutoCombine.getFruitArea( self, 0, 0, offsetOutside, lookAhead, 0, fruitType, hasFruitPreparer )
	local angle = 0	
	local detected = false
	local factor = 0.05			
	if border <= 0 then
		factor = -factor					
	elseif self.acDimensions.maxLookingAngle < self.acDimensions.maxSteeringAngle then
		factor = factor * self.acDimensions.maxLookingAngle / self.acDimensions.maxSteeringAngle
	end 
	
	for i=1,20 do
		local a = factor*i*self.acDimensions.maxSteeringAngle 							
		d = AutoCombine.calculateWidth(self,lookAhead,a)
		if not self.acParameters.leftAreaActive then d = -d end
		if self.acDimensions.aaAngleFactor > 0 then
			aaDiffX = math.sin( self.acDimensions.aaAngleFactor * a ) * self.acDimensions.aaDistance
			aaDiffZ = ( math.cos( self.acDimensions.aaAngleFactor * a ) - 1 ) * self.acDimensions.aaDistance
			if not self.acParameters.leftAreaActive then aaDiffX = -aaDiffX end
		end

		b = AutoCombine.getFruitArea( self, aaDiffX, aaDiffZ, offsetOutside, lookAhead, d, fruitType, hasFruitPreparer )
		
		if     border > 0 then
			if b <= 0 then
				detected = true
				angle = a
				break
			end
		else
			if b > 0 then
				detected = true
				break
			end
		end
		angle = a
	end
	
	local allowedToDrive = true
	local fruitsDetected = false
	
	if not self:getIsThreshingAllowed(true) then
		allowedToDrive = false
		self:setIsTurnedOn(false)
		self.waitingForWeather = true
	elseif self.waitingForWeather then
		self:startThreshing()
		self.waitingForWeather = false
	end
		
	if self:getCapacity() > 0 and self.fillLevel >= self:getCapacity() then
		allowedToDrive = false
	end
	
	if not allowedToDrive then
		AutoCombine.setStatus( self, 3 )
		if self.acTurnStage == 99 then
			self.acTurnStage = 98
			self:setCruiseControlState( Drivable.CRUISECONTROL_STATE_OFF )
		end
		self.turnTimer = -1
	elseif detected then	
		fruitsDetected = true
		AutoCombine.setStatus( self, 1 )
		
		if self.acTurnStage ~= 99 then
			self.acTurnStage = 99
			AutoCombine.saveDirection( self, false )
		end
		AutoCombine.saveDirection( self, true )
		self.turnTimer = self.acDeltaTimeoutRun
	else
		AutoCombine.setStatus( self, 2 )
			
		if border > 0 then
			fruitsDetected = true
			angle = self.acDimensions.maxSteeringAngle
		else
			local d = self.acDimensions.distance + self.acDimensions.distance
			d = - math.max( 0.9 * d, d - 1 )
			if not self.acParameters.leftAreaActive then d = -d end
			if AutoCombine.getFruitArea( self, 0, -2, d, 3, 0, fruitType, hasFruitPreparer ) > 0 then
			-- fruits detected 
				fruitsDetected = true		
				angle = -self.acDimensions.maxSteeringAngle

				local l = AutoCombine.getTraceLength(self)
				local a = math.deg(AutoCombine.getTurnAngle(self))
				if not self.acParameters.leftAreaActive then a = -a end
				if      l >= 1
						and a < -15 then
					angle = 0
				end
			end
		end
		
		if self.acTurnStage == 99 then
			if border > 0 or not fruitsDetected then
				self.turnTimer = self.turnTimer - dt
			end
			if self.turnTimer < 0 then
				self.acTurnStage = 98
				if border > 0 then
					self:setCruiseControlState( Drivable.CRUISECONTROL_STATE_OFF )
				elseif not fruitsDetected then
					AICombine.setAIImplementsMoveDown(self,false)
					self:setCruiseControlState( Drivable.CRUISECONTROL_STATE_OFF )
					if self.acParameters.upNDown then
						self:acSetState( "leftAreaActive", not self.acParameters.leftAreaActive )
					end
				end
			end
		end
	end
	
	if fruitsDetected then
		if self:getIsTurnedOn() == false then
			self:setIsTurnedOn(true)
		end
		AICombine.setAIImplementsMoveDown(self,true)
	end
	
	if not self.acParameters.leftAreaActive then angle = -angle end
	if self.movingDirection < -1E-2 then angle = -angle end
	local targetRotTime = 0
	
	if self.acRotatedTime == nil then
		self.rotatedTime = 0
	else
		self.rotatedTime = self.acRotatedTime
	end
	
	if self.isEntered then
		if not fruitsDetected then
			targetRotTime = self.rotatedTime
		elseif angle == 0 then
			targetRotTime = 0
		elseif angle  > 0 then
			targetRotTime = self.maxRotTime * math.min( angle / self.acDimensions.maxSteeringAngle, 1)
		else
			targetRotTime = self.minRotTime * math.min(-angle / self.acDimensions.maxSteeringAngle, 1)
		end
		if     targetRotTime > self.rotatedTime then
			self.rotatedTime = math.min(self.rotatedTime + dt * self.aiSteeringSpeed, targetRotTime)
		elseif targetRotTime < self.rotatedTime then
			self.rotatedTime = math.max(self.rotatedTime - dt * self.aiSteeringSpeed, targetRotTime)
		end
	end
	
	self.acRotatedTime = self.rotatedTime
end
