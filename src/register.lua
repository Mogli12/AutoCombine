AutoCombineRegister = {};
AutoCombineRegister.isLoaded = true;
AutoCombineRegister.g_currentModDirectory = g_currentModDirectory;

if SpecializationUtil.specializations["AutoCombine"] == nil then
	SpecializationUtil.registerSpecialization("AutoCombine", "AutoCombine", g_currentModDirectory.."AutoCombine.lua")
	AutoCombineRegister.isLoaded = false;
end;

function AutoCombineRegister:loadMap(name)	
  if not AutoCombineRegister.isLoaded then	
		AutoCombineRegister:add();
    AutoCombineRegister.isLoaded = true;
  end;
end;

function AutoCombineRegister:deleteMap()
  --AutoCombineRegister.isLoaded = false;
end;

function AutoCombineRegister:mouseEvent(posX, posY, isDown, isUp, button)
end;

function AutoCombineRegister:keyEvent(unicode, sym, modifier, isDown)
end;

function AutoCombineRegister:update(dt)
end;

function AutoCombineRegister:draw()
end;

function AutoCombineRegister:add()

	print("--- loading "..g_i18n:getText("AC_COMBINE_VERSION").." by mogli ---")

	local searchTable = { "APCombine", "AutoCombine" };	
	
	for k, v in pairs(VehicleTypeUtil.vehicleTypes) do
		local modName             = string.match(k, "([^.]+)");
		local AutoCombineRegister = true;
		local correctLocation     = false;
		
		for _, search in pairs(searchTable) do
			if SpecializationUtil.specializations[modName .. "." .. search] ~= nil then
				AutoCombineRegister = false;
				break;
			end;
		end;
		
		for i = 1, table.maxn(v.specializations) do
			local vs = v.specializations[i];
			if      vs   ~= nil 
					and ( vs == SpecializationUtil.getSpecialization("aiCombine")
		-- Krone BigX Beast
              ) then --or vs == SpecializationUtil.getSpecialization(modName .. "." .. "aiCombine2") ) then
				correctLocation = true;
				break;
			end;
		end;
		
		if AutoCombineRegister and correctLocation then
			table.insert(v.specializations, SpecializationUtil.getSpecialization("AutoCombine"));
		  print("  AutoCombine was inserted on " .. k);
		elseif correctLocation and not AutoCombineRegister then
			print("  Failed to inserting AutoCombine on " .. k);
		end;
	end;
	
	-- make l10n global 
	g_i18n.globalI18N.texts["AC_COMBINE_VERSION"]                  = g_i18n:getText("AC_COMBINE_VERSION");
	g_i18n.globalI18N.texts["AC_COMBINE_TXT_START"]                = g_i18n:getText("AC_COMBINE_TXT_START");
	g_i18n.globalI18N.texts["AC_COMBINE_TXT_STOP"]                 = g_i18n:getText("AC_COMBINE_TXT_STOP");
	g_i18n.globalI18N.texts["AC_COMBINE_TXT_WORKWIDTH"]            = g_i18n:getText("AC_COMBINE_TXT_WORKWIDTH");
	g_i18n.globalI18N.texts["AC_COMBINE_STEERING_ON"]              = g_i18n:getText("AC_COMBINE_STEERING_ON");
	g_i18n.globalI18N.texts["AC_COMBINE_STEERING_OFF"]             = g_i18n:getText("AC_COMBINE_STEERING_OFF");
	g_i18n.globalI18N.texts["AC_COMBINE_CONTINUE"]                 = g_i18n:getText("AC_COMBINE_CONTINUE");
	g_i18n.globalI18N.texts["AC_COMBINE_TXT_ACTIVESIDELEFT"]       = g_i18n:getText("AC_COMBINE_TXT_ACTIVESIDELEFT");
	g_i18n.globalI18N.texts["AC_COMBINE_TXT_ACTIVESIDERIGHT"]      = g_i18n:getText("AC_COMBINE_TXT_ACTIVESIDERIGHT");
	g_i18n.globalI18N.texts["AC_COMBINE_WAITMODE_ON"]              = g_i18n:getText("AC_COMBINE_WAITMODE_ON");
	g_i18n.globalI18N.texts["AC_COMBINE_WAITMODE_OFF"]             = g_i18n:getText("AC_COMBINE_WAITMODE_OFF");
	g_i18n.globalI18N.texts["AC_COMBINE_COLLISIONTRIGGERMODE_ON"]  = g_i18n:getText("AC_COMBINE_COLLISIONTRIGGERMODE_ON");
	g_i18n.globalI18N.texts["AC_COMBINE_COLLISIONTRIGGERMODE_OFF"] = g_i18n:getText("AC_COMBINE_COLLISIONTRIGGERMODE_OFF");
	g_i18n.globalI18N.texts["AC_COMBINE_TEXTHELPPANELOFF"]         = g_i18n:getText("AC_COMBINE_TEXTHELPPANELOFF");
	g_i18n.globalI18N.texts["AC_COMBINE_TEXTHELPPANELON"]          = g_i18n:getText("AC_COMBINE_TEXTHELPPANELON");
--g_i18n.globalI18N.texts["AC_COMBINE_STARTSTOP"]                = g_i18n:getText("AC_COMBINE_STARTSTOP");
	g_i18n.globalI18N.texts["AC_COMBINE_COLLISION_OTHER"]          = g_i18n:getText("AC_COMBINE_COLLISION_OTHER");
	g_i18n.globalI18N.texts["AC_COMBINE_COLLISION_BACK"]           = g_i18n:getText("AC_COMBINE_COLLISION_BACK");
	g_i18n.globalI18N.texts["AC_COMBINE_WAITING_WEATHER"]          = g_i18n:getText("AC_COMBINE_WAITING_WEATHER");
	g_i18n.globalI18N.texts["AC_COMBINE_WAITING_TRAILER"]          = g_i18n:getText("AC_COMBINE_WAITING_TRAILER");
	g_i18n.globalI18N.texts["AC_COMBINE_WAITING_DISCHARGE"]        = g_i18n:getText("AC_COMBINE_WAITING_DISCHARGE");
	g_i18n.globalI18N.texts["AC_COMBINE_WAITING_PAUSE"]            = g_i18n:getText("AC_COMBINE_WAITING_PAUSE");
	g_i18n.globalI18N.texts["AC_COMBINE_UTURN_ON"]                 = g_i18n:getText("AC_COMBINE_UTURN_ON");
	g_i18n.globalI18N.texts["AC_COMBINE_UTURN_OFF"]                = g_i18n:getText("AC_COMBINE_UTURN_OFF");
	g_i18n.globalI18N.texts["AC_COMBINE_REVERSE_ON"]               = g_i18n:getText("AC_COMBINE_REVERSE_ON");
	g_i18n.globalI18N.texts["AC_COMBINE_REVERSE_OFF"]              = g_i18n:getText("AC_COMBINE_REVERSE_OFF");
	g_i18n.globalI18N.texts["AC_COMBINE_WIDTH_OFFSET"]             = g_i18n:getText("AC_COMBINE_WIDTH_OFFSET");
	g_i18n.globalI18N.texts["AC_COMBINE_TURN_OFFSET"]              = g_i18n:getText("AC_COMBINE_TURN_OFFSET");
	g_i18n.globalI18N.texts["AC_COMBINE_ERROR"]                    = g_i18n:getText("AC_COMBINE_ERROR");
	g_i18n.globalI18N.texts["AC_COMBINE_TXT_NEXTTURNSTAGE"]        = g_i18n:getText("AC_COMBINE_TXT_NEXTTURNSTAGE");
	g_i18n.globalI18N.texts["AC_COMBINE_TXT_CP_ON"]                = g_i18n:getText("AC_COMBINE_TXT_CP_ON");
	g_i18n.globalI18N.texts["AC_COMBINE_TXT_CP_OFF"]               = g_i18n:getText("AC_COMBINE_TXT_CP_OFF");
	g_i18n.globalI18N.texts["AC_AUTO_STEER"]                       = g_i18n:getText("AC_AUTO_STEER");
	g_i18n.globalI18N.texts["AC_AUTO_STEER_ON"]                    = g_i18n:getText("AC_AUTO_STEER_ON");
	g_i18n.globalI18N.texts["AC_AUTO_STEER_OFF"]                   = g_i18n:getText("AC_AUTO_STEER_OFF");
	
end;

addModEventListener(AutoCombineRegister);


--print("overwritten Foldable.getIsAreaActive I")
--local oldFoldableGetIsAreaActive = Foldable.getIsAreaActive
--Foldable.getIsAreaActive = function( self, superFunc, area )
--	local r = nil
--	if pcall( function() r = oldFoldableGetIsAreaActive( self, superFunc, area ) end ) then 
--		return r
--	else
--		print(tostring(self.name).." "..tostring(self.typeName).." "..tostring(self.customEnvironment))				
--		print(tostring(self.foldAnimTime).." "..tostring(area.foldMaxLimit).." "..tostring(area.foldMinLimit))	
--		Mogli.printCallstack()
--		return false
--	end
--end
