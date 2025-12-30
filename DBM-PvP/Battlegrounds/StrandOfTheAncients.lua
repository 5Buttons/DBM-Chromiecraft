local mod	= DBM:NewMod("StrandoftheAncients", "DBM-PvP")
local L		= mod:GetLocalizedStrings()

local GetCurrentMapAreaID = GetCurrentMapAreaID

mod:SetRevision("20251231220503")
mod:SetZone(DBM_DISABLE_ZONE_DETECTION)

mod:RemoveOption("HealthFrame")

mod:RegisterEvents(
	"ZONE_CHANGED_NEW_AREA"
)

do
	local bgzone = false
	local function Init()
		local zoneID = GetCurrentMapAreaID()
		if not bgzone and zoneID == 513 then
			bgzone = true
			local generalMod = DBM:GetModByName("PvPGeneral")
			generalMod:SubscribeAssault(zoneID, 0)
			-- Fixed HP values based on AzerothCore gameobject_template database
			generalMod:TrackHealth(190722, "GreenEmerald", 2000)
			generalMod:TrackHealth(190724, "BlueSapphire", 2000)
			generalMod:TrackHealth(190723, "PurpleAmethyst", 4000)
			generalMod:TrackHealth(190726, "RedSun", 4000)
			generalMod:TrackHealth(190727, "YellowMoon", 5000)
			generalMod:TrackHealth(192549, "ChamberAncientRelics", 5000)
		elseif bgzone and zoneID ~= 513 then
			bgzone = false
			DBM:GetModByName("PvPGeneral"):StopTrackHealth()
		end
	end
	function mod:ZONE_CHANGED_NEW_AREA()
		Init()
	end
	mod.PLAYER_ENTERING_WORLD	= mod.ZONE_CHANGED_NEW_AREA
	mod.OnInitialize			= mod.ZONE_CHANGED_NEW_AREA
end