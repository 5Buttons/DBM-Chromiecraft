local _, private = ...

-- unit tokens of nameplates, only available with awesome_wotlk (https://github.com/FrostAtom/awesome_wotlk)
local C_NamePlate = C_NamePlate
local UnitGUID, UnitHealthMax = UnitGUID, UnitHealthMax

local module = private:NewModule("Nameplates")

local function getPlateUnits()
	local units, plates = {}, 0
	for _, plate in pairs(C_NamePlate.GetNamePlates() or {}) do
		plates = plates + 1
		if plate.unit then
			units[#units + 1] = plate.unit
		end
	end
	-- older awesome_wotlk versions don't store the token on the nameplate
	if plates > 0 and #units == 0 then
		for i = 1, 40 do
			units[i] = "nameplate" .. i
		end
	end
	return units
end

function module:IsAvailable()
	return C_NamePlate ~= nil
end

-- returns the token of a visible nameplate for a GUID
function module:GetUnitByGUID(guid)
	if not guid or not C_NamePlate then return end
	if C_NamePlate.GetNamePlateTokenByGUID then
		local unit = C_NamePlate.GetNamePlateTokenByGUID(guid)
		if unit and UnitGUID(unit) == guid then
			return unit
		end
		return
	end
	for _, unit in ipairs(getPlateUnits()) do
		if UnitGUID(unit) == guid then
			return unit
		end
	end
end

-- returns the token of the first visible nameplate of a creature ID
function module:GetUnitByCID(cid)
	if not cid or not C_NamePlate then return end
	for _, unit in ipairs(getPlateUnits()) do
		local guid = UnitGUID(unit)
		if guid and DBM:GetCIDFromGUID(guid) == cid and UnitHealthMax(unit) ~= 0 then
			return unit
		end
	end
end

