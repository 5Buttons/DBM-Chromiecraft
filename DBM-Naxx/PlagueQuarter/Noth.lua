local mod	= DBM:NewMod("Noth", "DBM-Naxx", 3)
local L		= mod:GetLocalizedStrings()

local GetSpellInfo = GetSpellInfo

mod:SetRevision("20251209000001")
mod:SetCreatureID(15954)
mod:SetEncounterID(1117)

mod:RegisterCombat("combat_yell", L.Pull)

mod:RegisterEvents(
	"SPELL_CAST_SUCCESS 29213 54835 29212 29208 29209 29210 29211",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"UNIT_SPELLCAST_SUCCEEDED boss1"
)

local warnTeleportNow	= mod:NewAnnounce("WarningTeleportNow", 3, 46573, nil, nil, nil, 29216)
local warnTeleportSoon	= mod:NewAnnounce("WarningTeleportSoon", 1, 46573, nil, nil, nil, 29216)
local warnCurse			= mod:NewSpellAnnounce(29213, 2)
local warnBlinkSoon		= mod:NewSoonAnnounce(29208, 1)
local warnBlink			= mod:NewSpellAnnounce(29208, 3)

local specWarnAdds		= mod:NewSpecialWarningAdds(29247, "-Healer", nil, nil, 1, 2)

local timerTeleport		= mod:NewTimer(110, "TimerTeleport", 46573, nil, nil, 6, nil, nil, nil, nil, nil, nil, nil, 29216)
local timerTeleportBack	= mod:NewTimer(70, "TimerTeleportBack", 46573, nil, nil, 6, nil, nil, nil, nil, nil, nil, nil, 29231)
local timerCurseCD		= mod:NewCDTimer(25, 29213, nil, nil, nil, 5, nil, DBM_COMMON_L.CURSE_ICON)
local timerAddsCD		= mod:NewAddsTimer(30, 29247, nil, "-Healer")
local timerBlink		= mod:NewNextTimer(30, 29208)

mod:GroupSpells(29216, 29231) -- Teleport, Teleport Return


mod.vb.isOnBalcony = false
local teleportBalconyName = GetSpellInfo(29216) -- Teleport
local teleportBackName = GetSpellInfo(29231) -- Teleport Return

function mod:OnCombatStart(delay)
	self.vb.isOnBalcony = false
	timerAddsCD:Start(10 - delay)
	timerCurseCD:Start(15 - delay)
	if self:IsHeroic() then
	timerBlink:Start(26 - delay)
	warnBlinkSoon:Schedule(21 - delay)
	end
	timerTeleport:Start(110 - delay)
	warnTeleportSoon:Schedule(100 - delay)
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(29213, 54835) then -- Curse of the Plaguebringer
		warnCurse:Show()
		if not self.vb.isOnBalcony then
			timerCurseCD:Start()
		end
	elseif args:IsSpellID(29208, 29209, 29210, 29211) and args:GetDestCreatureID() == 15954 then -- Blink
		warnBlink:Show()
		if not self.vb.isOnBalcony then
			timerBlink:Start()
			warnBlinkSoon:Schedule(25)
		end
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg == L.Adds or msg:find(L.Adds) then
		self:SendSync("Adds")
	elseif msg == L.AddsTwo or msg:find(L.AddsTwo) then
		self:SendSync("AddsTwo")
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
	if spellName == teleportBalconyName then -- Teleport to Balcony
		self.vb.isOnBalcony = true
		warnTeleportNow:Show()
		timerCurseCD:Stop()
		timerAddsCD:Stop()
		timerBlink:Stop()
		warnBlinkSoon:Cancel()
		timerTeleportBack:Start()
		warnTeleportSoon:Schedule(60)
		timerAddsCD:Start(4)
	elseif spellName == teleportBackName then -- Teleport Return to Ground
		self.vb.isOnBalcony = false
		warnTeleportNow:Show()
		timerAddsCD:Stop()
		timerTeleport:Start()
		warnTeleportSoon:Schedule(100)
		timerAddsCD:Start(10)
		timerCurseCD:Start(15)
		if self:IsHeroic() then
		timerBlink:Start(26)
		warnBlinkSoon:Schedule(21)
		end
	end
end

function mod:OnSync(msg)
	if not self:IsInCombat() then return end
	if msg == "Adds" or msg == "AddsTwo" then
		specWarnAdds:Show()
		specWarnAdds:Play("killmob")
		timerAddsCD:Start(30)
	end
end