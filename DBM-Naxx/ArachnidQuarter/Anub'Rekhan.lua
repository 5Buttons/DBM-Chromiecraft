local mod	= DBM:NewMod("Anub'Rekhan", "DBM-Naxx", 1)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20251208133531")
mod:SetCreatureID(15956)
mod:SetEncounterID(1107)

mod:RegisterCombat("combat_yell", L.Pull1, L.Pull2)

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 28785 54021 28783",
	"SPELL_CAST_SUCCESS 28783 56090",
	"SPELL_AURA_REMOVED 28785 54021",
	"UNIT_SPELLCAST_START"
)

local warningLocustSoon		= mod:NewSoonAnnounce(28785, 2)
local warningLocustFaded	= mod:NewFadesAnnounce(28785, 1)
local warnImpale			= mod:NewTargetNoFilterAnnounce(28783, 3, nil, false)

local specialWarningLocust	= mod:NewSpecialWarningSpell(28785, nil, nil, nil, 2, 2)
local yellImpale 			= mod:NewYell(28783, nil, true)

local timerLocustIn			= mod:NewCDTimer(90, 28785, nil, nil, nil, 6)
local timerLocustFade		= mod:NewBuffActiveTimer(23, 28785, nil, nil, nil, 6)
local timerImpale			= mod:NewCDTimer(20, 56090, nil, nil, nil, 3)

mod:AddBoolOption("ArachnophobiaTimer", true, "timer", nil, nil, nil, "at1859")--Sad caveat that 10 and 25 man have own achievements and we have to show only 1 in GUI

function mod:OnCombatStart(delay)
	timerLocustIn:Start("v70-120")  -- Same for both difficulties
	timerImpale:Start(15-delay)
end

function mod:OnCombatEnd(wipe)
	if not wipe and self.Options.ArachnophobiaTimer then
		DBT:CreateBar(1200, L.ArachnophobiaTimer, "Interface\\Icons\\INV_Misc_MonsterSpiderCarapace_01")
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(28785, 54021) then  -- Locust Swarm
		specialWarningLocust:Show()
		specialWarningLocust:Play("aesoon")
		timerLocustIn:Stop()
		if self:IsDifficulty("normal25") then
			timerLocustFade:Start(23)
		else
			timerLocustFade:Start(19)
		end
	elseif args:IsSpellID(28783, 56090) then  -- Impale
		timerImpale:Start()
	end
end

function mod:UNIT_SPELLCAST_START(unitID, spellName)
	if spellName == GetSpellInfo(28783) or spellName == GetSpellInfo(56090) then  -- Impale
		if self:GetUnitCreatureId("target") == 15956 and self:AntiSpam(3, 1) then
		local targetName = UnitName("targettarget")
			if targetName then
				warnImpale:Show(targetName)
				if targetName == UnitName("player") then
					yellImpale:Yell()
				end
			end
		end
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(28785, 54021)
	and args.auraType == "BUFF" then
		warningLocustFaded:Show()
		timerLocustIn:Start()
		warningLocustSoon:Schedule(80)
	end
end
