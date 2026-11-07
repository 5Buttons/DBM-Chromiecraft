local mod	= DBM:NewMod("UlduarTrash", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20261011000000")
mod.isTrashMod = true

mod:RegisterEvents(
	"SPELL_CAST_START 63527 64717 64943 64944 63722 62344 62325 62932",
	"SPELL_CAST_SUCCESS 64897 64968 64847 64988 64779",
	"SPELL_AURA_APPLIED 63539 63630 64740 64903 64970 64989 62310 62928",
	"SPELL_AURA_REMOVED 62310 62928",
	"SPELL_DAMAGE 64940",
	"SPELL_MISSED 64940"
)

--Storm Tempered Keeper (33699 / 33722)
local specWarnSphere			= mod:NewSpecialWarningSwitch(63527, "Dps", nil, nil, 1, 2)
local specWarnSeparation		= mod:NewSpecialWarningSpell(63539, nil, nil, nil, 1, 2)
local specWarnVengeful			= mod:NewSpecialWarningSpell(63630, "Tank|Healer", nil, nil, 1, 2)
--Arachnopod Destroyer
local specWarnFlameSpray		= mod:NewSpecialWarningDodge(64717, nil, nil, nil, 1, 2)
local warnChargedLeap			= mod:NewTargetAnnounce(64779, 3)
--Energy Sap (25 man ID missing)
local warnEnergySap				= mod:NewTargetAnnounce(64740, 2)
--Antechamber: Rune Etched Sentry (34196)
local specWarnFlameJets			= mod:NewSpecialWarningDodge(64988, nil, nil, nil, 2, 2)
local specWarnFlamingRune		= mod:NewSpecialWarningMove(64989, nil, nil, nil, 1, 2)
--Antechamber: Iron Mender (34198)
local warnFuseLightning			= mod:NewTargetNoFilterAnnounce(64970, 3)
local yellFuseLightning			= mod:NewYell(64970)
local specWarnFuseMetal			= mod:NewSpecialWarningInterrupt(64968, "HasInterrupt", nil, nil, 1, 2)
--Antechamber: Chamber Overseer (34197)
local specWarnDisplacementGTFO	= mod:NewSpecialWarningGTFO(64940, nil, nil, nil, 1, 8)
local warnStaggeringRoar		= mod:NewCastAnnounce(64944, 3)
--Faceless Horror (33772)
local warnShadowCrash			= mod:NewTargetAnnounce(63722, 3)
local specWarnShadowCrash		= mod:NewSpecialWarningMoveAway(63722, nil, nil, nil, 1, 2)
local yellShadowCrash			= mod:NewYell(63722)
--Freya's Elders: Elder Ironbranch (32913), Elder Stonebark (32914)
local specWarnImpale			= mod:NewSpecialWarningTaunt(62928, nil, nil, nil, 1, 2)
local specWarnFistofStone		= mod:NewSpecialWarningRun(62344, "Tank", nil, nil, 4, 2)
local specWarnGroundTremor		= mod:NewSpecialWarningCast(62932, "SpellCaster", nil, nil, 1, 2)

local timerImpale				= mod:NewTargetTimer(5, 62928, nil, "Healer|Tank", nil, 5)

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 63527 then
		specWarnSphere:Show()
		specWarnSphere:Play("targetchange")
	elseif spellId == 64717 then
		specWarnFlameSpray:Show()
		specWarnFlameSpray:Play("shockwave")
	elseif (spellId == 64943 or spellId == 64944) and self:AntiSpam(3, 3) then
		warnStaggeringRoar:Show()
	elseif spellId == 63722 then
		-- no destName in CLEU, Horror switches target at cast start
		self:BossTargetScanner(args.sourceGUID, "ShadowCrashTarget", 0.1, 10, nil, nil, nil, nil, true)
	elseif spellId == 62344 then
		specWarnFistofStone:Show()
		specWarnFistofStone:Play("justrun")
	elseif spellId == 62325 or spellId == 62932 then
		specWarnGroundTremor:Show()
		specWarnGroundTremor:Play("stopcast")
	end
end

function mod:ShadowCrashTarget(targetname)
	if not targetname then return end
	if targetname == UnitName("player") then
		specWarnShadowCrash:Show()
		specWarnShadowCrash:Play("runout")
		yellShadowCrash:Yell()
	else
		warnShadowCrash:Show(targetname)
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if (spellId == 64897 or spellId == 64968) and self:CheckInterruptFilter(args.sourceGUID, false, true) then
		specWarnFuseMetal:Show(args.sourceName) -- channel, 5s
		specWarnFuseMetal:Play("kickcast")
	elseif (spellId == 64847 or spellId == 64988) and self:AntiSpam(10, 2) then
		specWarnFlameJets:Show()
		specWarnFlameJets:Play("watchstep")
	elseif spellId == 64779 then
		warnChargedLeap:Show(args.destName) -- CLEU cast start has no destName on 3.3.5
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 63539 and self:AntiSpam(5, 1) then
		specWarnSeparation:Show() -- Keepers more than 45 yards apart
		specWarnSeparation:Play("runin")
	elseif spellId == 63630 then
		specWarnVengeful:Show() -- other Keeper died
	elseif spellId == 64740 and args:IsDestTypePlayer() then
		warnEnergySap:Show(args.destName)
	elseif spellId == 64903 or spellId == 64970 then
		if args:IsPlayer() then
			yellFuseLightning:Yell()
		else
			warnFuseLightning:Show(args.destName)
		end
	elseif spellId == 64989 and args:IsPlayer() and self:AntiSpam(3, 5) then
		specWarnFlamingRune:Show()
		specWarnFlamingRune:Play("runaway")
	elseif spellId == 62310 or spellId == 62928 then
		if not args:IsPlayer() then
			specWarnImpale:Show(args.destName)
			specWarnImpale:Play("tauntboss")
		end
		timerImpale:Start(args.destName)
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 62310 or spellId == 62928 then
		timerImpale:Stop(args.destName)
	end
end

function mod:SPELL_DAMAGE(_, _, _, destGUID, _, _, spellId)
	if spellId == 64940 and destGUID == UnitGUID("player") and self:AntiSpam(3, 4) then
		specWarnDisplacementGTFO:Show()
		specWarnDisplacementGTFO:Play("watchfeet")
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE
