---------------
--  Globals  --
---------------
DBM.BossHealth = {}


-------------
--  Locals --
-------------
local L = DBM_CORE_L
local bossHealth = DBM.BossHealth
local bars = {}
local layout = {}
local reserved = {}
local slots	
local armedMod
local barCache = {}
local overlays = {}
local updateFrame
local getBarId
local updateBar
local anchor
local header
local dropdownFrame
local pendingSync
local AceTimer = LibStub("AceTimer-3.0")

local InCombatLockdown = InCombatLockdown
local tremove, tinsert, tmaxn, mfloor, mmax = table.remove, table.insert, table.maxn, math.floor, math.max

local CLASSIC_BORDER_TEXTURE = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"
local CLASSIC_BAR_HEIGHT = 20
local flatBackdrop = {
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1
}

do
	local id = 0
	function getBarId()
		id = id + 1
		return id
	end
end

-- checks if a given value is in an array
-- returns true if it finds the value, false otherwise
local function checkEntry(t, val)
	for _, v in ipairs(t) do
		if v == val then
			return true
		end
	end
	return false
end

local function isFlat()
	return DBM.Options.HealthFrameStyle == "Flat"
end

local function getBarHeight()
	return isFlat() and DBM.Options.HealthFrameBarHeight or CLASSIC_BAR_HEIGHT
end

local function getBarSpacing()
	return isFlat() and DBM.Options.HealthFrameSpacing or 0
end

local function getFont()
	local font = DBM.Options.HealthFrameFont
	if not font or font == "standardFont" then
		font = GameFontHighlightSmall:GetFont()
	end
	local flags = DBM.Options.HealthFrameFontStyle
	if not flags or flags == "None" then
		flags = ""
	end
	return font, DBM.Options.HealthFrameFontSize, flags
end

local function setFont(fontString, font, size, flags)
	if not fontString:SetFont(font, size, flags) then
		fontString:SetFont(GameFontHighlightSmall:GetFont(), size, flags)
	end
end

local function numReserved()
	return slots and #slots or 0
end


------------
--  Menu  --
------------
local menu
menu = {
	{
		text = L.RANGECHECK_LOCK,
		checked = false, -- requires DBM.Options which is not available yet
		func = function()
			menu[1].checked = not menu[1].checked
			DBM.Options.HealthFrameLocked = menu[1].checked
		end
	},
	{
		text = L.BOSSHEALTH_HIDE_FRAME,
		notCheckable = true,
		func = function() bossHealth:Hide() end
	}
}


----------------------
--  Click overlays  --
----------------------

local function getClickInfo(bar)
	if type(bar.id) == "string" and bar.id:match("^boss%d$") then
		return "unit", bar.id
	end
	local name = bar.nameText:GetText()
	if name and name ~= "" then
		return "name", name
	end
end

local function getSlotClickInfo(index)
	if index <= numReserved() then
		local slot = slots[index]
		local target = slot.target or slot.name
		if target and target ~= "" then
			return "name", target
		end
		return
	end
	local bar = layout[index]
	if bar then
		return getClickInfo(bar)
	end
end

local function getClickKey(bar)
	local kind, value = getClickInfo(bar)
	return kind and (kind .. ":" .. value)
end

local function getActiveOverlayKey(index)
	local overlay = overlays[index]
	return overlay and overlay:IsShown() and overlay.key
end

local function anyOverlayShown()
	for _, overlay in ipairs(overlays) do
		if overlay:IsShown() then
			return true
		end
	end
	return false
end

-- returns the slot rect (left, top, width, height) in UIParent coordinates
local function getSlotRect(index)
	local scale = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local left, right, top, bottom = anchor:GetLeft(), anchor:GetRight(), anchor:GetTop(), anchor:GetBottom()
	if not left then return end
	local width, height = DBM.Options.HealthFrameWidth, getBarHeight()
	local offset = (index - 1) * (height + getBarSpacing())
	local slotTop
	if DBM.Options.HealthFrameGrowUp then
		slotTop = top + offset + height
	else
		slotTop = bottom - offset
	end
	return ((left + right) / 2 - width / 2) * scale, slotTop * scale, width * scale, height * scale
end

local function positionOverlays()
	if InCombatLockdown() or not anchor then return end
	-- overlays of an armed mod are placed while the frame is hidden; make sure its rect is valid
	local wasHidden = not anchor:IsShown()
	if wasHidden then
		anchor:Show()
	end
	for index, overlay in ipairs(overlays) do
		if overlay.mode ~= "hide" then
			local left, top, width, height = getSlotRect(index)
			if left then
				overlay:ClearAllPoints()
				overlay:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
				overlay:SetWidth(width)
				overlay:SetHeight(height)
				overlay:SetFrameLevel(anchor:GetFrameLevel() + 10)
			end
		end
	end
	if wasHidden then
		anchor:Hide()
	end
end

local onMouseDown, onMouseUp

local function getOverlay(index)
	local overlay = overlays[index]
	if not overlay then
		overlay = CreateFrame("Button", "DBM_BossHealth_Click" .. index, UIParent, "SecureActionButtonTemplate")
		overlay:RegisterForClicks("AnyUp")
		overlay:SetFrameStrata("MEDIUM")
		local highlight = overlay:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints(overlay)
		highlight:SetTexture(1, 1, 1, 0.15)
		overlay:SetScript("OnMouseDown", onMouseDown)
		overlay:SetScript("OnMouseUp", onMouseUp)
		overlay:Hide()
		overlay.mode = "hide"
		overlays[index] = overlay
	end
	return overlay
end

local function configureOverlay(overlay, kind, value)
	if kind == "unit" then
		overlay:SetAttribute("type1", "target")
		overlay:SetAttribute("shift-type1", "focus")
		overlay:SetAttribute("unit", value)
		overlay:SetAttribute("macrotext1", nil)
		overlay:SetAttribute("shift-macrotext1", nil)
	else
		overlay:SetAttribute("type1", "macro")
		overlay:SetAttribute("shift-type1", "macro")
		overlay:SetAttribute("unit", nil)
		overlay:SetAttribute("macrotext1", "/targetexact " .. value)
		overlay:SetAttribute("shift-macrotext1", "/targetexact " .. value .. "\n/focus\n/targetlasttarget")
	end
	overlay.key = kind .. ":" .. value
end

-- "show": visible now, "driver": visible whenever the player is in combat, "hide": hidden
local function setOverlayMode(overlay, mode)
	if overlay.mode == "driver" and mode ~= "driver" then
		UnregisterStateDriver(overlay, "visibility")
	end
	if mode == "driver" then
		if overlay.mode ~= "driver" then
			RegisterStateDriver(overlay, "visibility", "[combat] show; hide")
		end
	elseif mode == "show" then
		overlay:Show()
	else
		overlay:Hide()
	end
	overlay.mode = mode
end

local function syncOverlays()
	if InCombatLockdown() then
		pendingSync = true
		return
	end
	pendingSync = nil
	local enabled = DBM.Options.HealthFrameClickable and anchor
	local shown = anchor and anchor:IsShown()
	for index = 1, mmax(tmaxn(layout), #overlays, numReserved()) do
		local mode, kind, value = "hide", nil, nil
		if enabled then
			kind, value = getSlotClickInfo(index)
			if kind then
				if shown and layout[index] then
					mode = "show"
				elseif not shown and armedMod and index <= numReserved() then
					mode = "driver"
				end
			end
		end
		if mode ~= "hide" then
			local overlay = getOverlay(index)
			if overlay.key ~= kind .. ":" .. value then
				configureOverlay(overlay, kind, value)
			end
			setOverlayMode(overlay, mode)
		elseif overlays[index] then
			setOverlayMode(overlays[index], "hide")
			overlays[index].key = nil
		end
	end
	positionOverlays()
end


-----------------------
--  Script Handlers  --
-----------------------
local function onUpdateMoving()
	positionOverlays()
end

function onMouseDown(self, button)
	-- moving the bars away from their (locked) click overlays would make them target the wrong boss
	if button == "LeftButton" and not DBM.Options.HealthFrameLocked and not (InCombatLockdown() and anyOverlayShown()) then
		anchor.moving = true
		anchor:StartMoving()
		anchor:SetScript("OnUpdate", onUpdateMoving)
	end
end

function onMouseUp(self, button)
	if anchor.moving then
		anchor.moving = nil
		anchor:StopMovingOrSizing()
		anchor:SetScript("OnUpdate", nil)
		local point, _, _, x, y = anchor:GetPoint(1)
		DBM.Options.HPFramePoint = point
		DBM.Options.HPFrameX = x
		DBM.Options.HPFrameY = y
		positionOverlays()
	end
	if button == "RightButton" then
		menu[1].checked = DBM.Options.HealthFrameLocked
		EasyMenu(menu, dropdownFrame, "cursor", nil, nil, "MENU")
	end
end

local function onHide()
	onMouseUp()
end


-----------------
-- Apply Style --
-----------------
local function updateBarColor(bar, percent)
	if percent <= 0 then
		bar.statusbar:SetStatusBarColor(0, 0, 0)
	elseif DBM.Options.HealthFrameColorMode == "Custom" then
		bar.statusbar:SetStatusBarColor(DBM.Options.HealthFrameColorR, DBM.Options.HealthFrameColorG, DBM.Options.HealthFrameColorB)
	else
		bar.statusbar:SetStatusBarColor((100 - percent) / 100, percent / 100, 0)
	end
end

local function updateBarStyle(bar)
	local width = DBM.Options.HealthFrameWidth
	local statusbar, border, borderTexture = bar.statusbar, bar.border, bar.borderTexture
	bar:SetWidth(width)
	statusbar:ClearAllPoints()
	border:ClearAllPoints()
	statusbar:SetStatusBarTexture(DBM.Options.HealthFrameTexture)
	if isFlat() then
		local height = DBM.Options.HealthFrameBarHeight
		bar:SetHeight(height)
		statusbar:SetAllPoints(bar)
		borderTexture:Hide()
		border:SetPoint("TOPLEFT", statusbar, "TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", statusbar, "BOTTOMRIGHT", 1, -1)
		if DBM.Options.HealthFrameBorder then
			border:SetBackdrop(flatBackdrop)
			border:SetBackdropBorderColor(0, 0, 0, 1)
		else
			border:SetBackdrop(nil)
		end
		bar.icon:SetWidth(height)
		bar.icon:SetHeight(height)
	else
		-- these health frames really suck :(
		local borderWidth
		bar:SetHeight(CLASSIC_BAR_HEIGHT)
		statusbar:SetHeight(12)
		if width < 175 then
			statusbar:SetPoint("CENTER", bar, "CENTER", -6, 0)
			statusbar:SetWidth(width * 0.95)
			borderWidth = width * 0.99
		elseif width >= 225 then
			statusbar:SetPoint("CENTER", bar, "CENTER", 5, 0)
			statusbar:SetWidth(width * 0.965)
			borderWidth = width * 0.995
		else
			statusbar:SetPoint("CENTER", bar, "CENTER", 2, 0)
			statusbar:SetWidth(width * 0.95)
			borderWidth = width * 0.99
		end
		border:SetBackdrop(nil)
		border:SetPoint("LEFT", statusbar, "LEFT", -4, 0)
		border:SetWidth(borderWidth)
		border:SetHeight(32)
		borderTexture:Show()
		bar.icon:SetWidth(12)
		bar.icon:SetHeight(12)
	end
	bar.bg:SetTexture(0, 0, 0, DBM.Options.HealthFrameBgAlpha)
	local font, size, flags = getFont()
	setFont(bar.nameText, font, size, flags)
	setFont(bar.percentText, font, size, flags)
	if bar.value then
		updateBarColor(bar, bar.value)
	end
end

local function positionBar(bar)
	local offset = (bar.slot - 1) * (getBarHeight() + getBarSpacing())
	bar:ClearAllPoints()
	if DBM.Options.HealthFrameGrowUp then
		bar:SetPoint("BOTTOM", anchor, "TOP", 0, offset)
	else
		bar:SetPoint("TOP", anchor, "BOTTOM", 0, -offset)
	end
end


-----------------------
-- Create the Frame  --
-----------------------
local function updateHeaderStyle()
	local font, size, flags = getFont()
	setFont(header, font, size, flags)
	if DBM.Options.HealthFrameShowHeader then
		header:Show()
	else
		header:Hide()
	end
end

local function createFrame(self)
	anchor = CreateFrame("Frame", "DBMBossHealthAnchor", UIParent)
	anchor:SetWidth(60)
	anchor:SetHeight(10)
	anchor:SetMovable(1)
	anchor:EnableMouse(1)
	anchor:SetFrameStrata("MEDIUM")
	anchor:SetClampedToScreen(true)
	anchor:SetScale(DBM.Options.HealthFrameScale)
	anchor:SetPoint(DBM.Options.HPFramePoint, UIParent, DBM.Options.HPFramePoint, DBM.Options.HPFrameX, DBM.Options.HPFrameY)
	header = anchor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	header:SetPoint("BOTTOM", anchor, "BOTTOM")
	updateHeaderStyle()
	anchor:SetScript("OnMouseDown", onMouseDown)
	anchor:SetScript("OnMouseUp", onMouseUp)
	anchor:SetScript("OnHide", onHide)
	dropdownFrame = CreateFrame("Frame", "DBMBossHealthDropdown", anchor, "UIDropDownMenuTemplate")
	menu[1].checked = DBM.Options.HealthFrameLocked
end

local function createBarFrame()
	local bar = CreateFrame("Frame", "DBM_BossHealth_Bar_" .. getBarId(), anchor)
	bar:EnableMouse(true)
	bar:SetScript("OnMouseDown", onMouseDown)
	bar:SetScript("OnMouseUp", onMouseUp)
	bar:SetScript("OnHide", onHide)
	local statusbar = CreateFrame("StatusBar", nil, bar)
	statusbar:SetMinMaxValues(0, 100)
	bar.statusbar = statusbar
	bar.bg = statusbar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(statusbar)
	-- border and text live on their own frames so they are drawn above the bar texture
	bar.border = CreateFrame("Frame", nil, statusbar)
	bar.borderTexture = bar.border:CreateTexture(nil, "ARTWORK")
	bar.borderTexture:SetTexture(CLASSIC_BORDER_TEXTURE)
	bar.borderTexture:SetAllPoints(bar.border)
	local textFrame = CreateFrame("Frame", nil, statusbar)
	textFrame:SetAllPoints(statusbar)
	textFrame:SetFrameLevel(bar.border:GetFrameLevel() + 1)
	bar.percentText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.percentText:SetPoint("RIGHT", statusbar, "RIGHT", -2, 1)
	bar.nameText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.nameText:SetPoint("LEFT", statusbar, "LEFT", 2, 1)
	bar.nameText:SetPoint("RIGHT", bar.percentText, "LEFT", -2, 0)
	bar.nameText:SetJustifyH("LEFT")
	bar.icon = textFrame:CreateTexture(nil, "OVERLAY")
	bar.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	bar.icon:SetPoint("RIGHT", statusbar, "LEFT", -4, 0)
	return bar
end

local function acquireBar()
	local bar = tremove(barCache, #barCache) or createBarFrame()
	updateBarStyle(bar)
	return bar
end

local function releaseBar(bar)
	bar:Hide()
	bar:ClearAllPoints()
	if bar.slot and layout[bar.slot] == bar then
		layout[bar.slot] = false
	end
	bar.slot, bar.reservedIndex, bar.active, bar.id, bar.value = nil, nil, nil, nil, nil
	barCache[#barCache + 1] = bar
end

-- greyed out bar for a reserved slot whose unit is not (or no longer) part of the fight
local function showPlaceholder(bar, slot)
	bar.active, bar.id, bar.value, bar.nameused = nil, nil, nil, nil
	bar.nameText:SetText(slot.name or "")
	bar.nameText:SetTextColor(0.5, 0.5, 0.5)
	bar.percentText:SetText("-")
	bar.percentText:SetTextColor(0.5, 0.5, 0.5)
	bar.statusbar:SetValue(100)
	bar.statusbar:SetStatusBarColor(0.3, 0.3, 0.3)
	bar.icon:Hide()
end

local function activateBar(bar, name, id)
	bar.id = id
	bar.value = nil
	bar.active = true
	bar.nameText:SetTextColor(1, 1, 1)
	bar.percentText:SetTextColor(1, 1, 1)
	bar.nameText:SetText(name or "")
	bar.nameused = name and true or nil
	bar:Show()
	if type(bar.id) == "function" then
		local health, icon = bar.id()
		updateBar(bar, health, icon, true)
	else
		updateBar(bar, 100)
	end
end

-- puts the reserved bars into the first slots of the layout
local function buildReserved()
	if not slots then return end
	for i, slot in ipairs(slots) do
		local bar = reserved[i]
		if not bar then
			bar = acquireBar()
			bar.reservedIndex = i
			reserved[i] = bar
		end
		if not bar.active then
			showPlaceholder(bar, slot)
		end
		layout[i] = bar
		bar.slot = i
		positionBar(bar)
		bar:Show()
	end
end

-- replaces the reserved slot definitions, which resets the whole layout
local function setSlots(newSlots)
	for i = #bars, 1, -1 do
		bars[i] = nil
	end
	for i = tmaxn(layout), 1, -1 do
		if layout[i] then
			releaseBar(layout[i])
		end
		layout[i] = nil
	end
	for i = #reserved, 1, -1 do
		if reserved[i].reservedIndex then
			releaseBar(reserved[i])
		end
		reserved[i] = nil
	end
	slots = newSlots
	if anchor and anchor:IsShown() then
		buildReserved()
	end
end

local function findReservedSlot(id)
	if not slots then return end
	for i, slot in ipairs(slots) do
		if id == slot.cid or type(id) == "table" and checkEntry(id, slot.cid) then
			return i
		end
	end
end

local function getModSlots(mod)
	if mod.healthFrameSlots then
		return mod.healthFrameSlots
	end
	-- derive the slots from what DBM-Core adds on pull
	if not mod.generatedHealthFrameSlots then
		local list = {}
		if mod.bossHealthInfo then
			for i = 1, #mod.bossHealthInfo, 2 do
				local cid, name = mod.bossHealthInfo[i], mod.bossHealthInfo[i + 1]
				if type(cid) == "number" then
					list[#list + 1] = {cid = cid, name = name}
				end
			end
		elseif mod.combatInfo and type(mod.combatInfo.mob) == "number" then
			list[1] = {cid = mod.combatInfo.mob, name = mod.localization.general.name}
		end
		mod.generatedHealthFrameSlots = list
	end
	return #mod.generatedHealthFrameSlots > 0 and mod.generatedHealthFrameSlots or nil
end

local function wantsFrame(mod)
	return mod.Options and mod.Options.Enabled and (DBM.Options.AlwaysShowHealthFrame or mod.Options.HealthFrame)
end


--------------
--  Layout  --
--------------
-- removes the gaps left behind by dynamic bars that were removed during combat
local function compactLayout()
	local first = numReserved() + 1
	local dynamic = {}
	for i = first, tmaxn(layout) do
		if layout[i] then
			dynamic[#dynamic + 1] = layout[i]
		end
		layout[i] = nil
	end
	for i, bar in ipairs(dynamic) do
		layout[first + i - 1] = bar
		bar.slot = first + i - 1
		positionBar(bar)
	end
end

-- the layout can be changed freely as long as no click overlay could end up on top of the wrong bar
local function canReflow()
	return not InCombatLockdown() or not anyOverlayShown()
end

local function refreshLayout()
	if canReflow() then
		compactLayout()
		syncOverlays()
	else
		pendingSync = true
	end
end

-- places a bar that has no reserved slot after the reserved ones
local function placeBar(bar)
	if canReflow() then
		compactLayout()
		local index = mmax(tmaxn(layout), numReserved()) + 1
		layout[index] = bar
		bar.slot = index
		positionBar(bar)
		syncOverlays()
		return
	end
	-- locked down: use the first free slot whose overlay is either inactive or already targets this bar
	local key = getClickKey(bar)
	local index = numReserved() + 1
	while true do
		if not layout[index] then
			local overlayKey = getActiveOverlayKey(index)
			if not overlayKey or overlayKey == key then
				break
			end
		end
		index = index + 1
	end
	for i = numReserved() + 1, index - 1 do
		layout[i] = layout[i] or false
	end
	layout[index] = bar
	bar.slot = index
	positionBar(bar)
	pendingSync = true
end

local function removeBar(index)
	local bar = tremove(bars, index)
	if bar.reservedIndex then
		showPlaceholder(bar, slots[bar.reservedIndex])
	else
		releaseBar(bar)
	end
end


------------------
--  Bar Update  --
------------------
function updateBar(bar, percent, icon, dontShowDead, name)
	if not percent then return end
	local percentText = bar.percentText
	if percent >= 1 then
		if DBM.Options.HealthFrameDecimals then
			percentText:SetFormattedText("%.1f%%", percent)
		else
			percentText:SetText(mfloor(percent) .. "%")
		end
		bar.statusbar:SetValue(percent)
		updateBarColor(bar, percent)
		bar.value = percent
	elseif (bar.value == 0) or (percent >= 0) then
		if percent == 0 or percent == -1 then
			percentText:SetText(dontShowDead and "0%" or DEAD)
		else
			percentText:SetText("0%")
		end
		bar.statusbar:SetValue(0)
		updateBarColor(bar, 0)
		bar.value = 0
	else--can't detect health. show unknown
		if not bar.value or bar.value >= 1 then
			-- percentText:SetText(DBM_COMMON_L.UNKNOWN)
			-- don't update when no target
		else
			percentText:SetText(dontShowDead and "0%" or DEAD)
		end
	end
	if not icon or type(icon) ~= "number" or icon < 1 or icon > 8 then
		bar.icon:Hide()
	else
		bar.icon:Show()
		bar.icon:SetTexCoord((icon - 1) % 4 / 4, (icon - 1) % 4 / 4 + 0.25, icon < 5 and 0 or 0.25, icon < 5 and 0.25 or 0.5)
	end
	if name and not bar.nameused then
		bar.nameText:SetText(name)
	end
end

do
	function updateFrame(self)
		for _, v in ipairs(bars) do
			if type(v.id) == "number" then -- creature ID
				local health, id, name = DBM:GetBossHP(v.id)
				if health then
					updateBar(v, health, GetRaidTargetIndex(id), nil, name)
				else
					updateBar(v, -1)
				end
			elseif type(v.id) == "string" then -- UnitID or GUID
				local health, id, name
				if v.id:match("boss") then
					health, id, name = DBM:GetBossHPByUnitID(v.id)
				else
					health, id, name = DBM:GetBossHPByGUID(v.id)
				end
				if health then
					updateBar(v, health, GetRaidTargetIndex(id), nil, name)
				else
					updateBar(v, -1)
				end
			elseif type(v.id) == "table" then -- multi boss
				-- TODO: it would be more efficient to scan all party/raid members for all IDs instead of going over all raid members n times
				-- this is especially important for the cache
				for _, id in ipairs(v.id) do
					local health = DBM:GetBossHP(id)
					if health then
						updateBar(v, health)
						break
					end
				end
			elseif type(v.id) == "function" then -- generic bars
				local health, icon = v.id()
				updateBar(v, health, icon, true)
			end
		end
	end
end


---------------
--  Arming  --
---------------
local function arm(mod)
	if InCombatLockdown() or armedMod == mod or anchor and anchor:IsShown() then return end
	if not DBM.Options.HealthFrameClickable or not wantsFrame(mod) then return end
	local modSlots = getModSlots(mod)
	if not modSlots then return end
	armedMod = mod
	if not anchor then
		createFrame(bossHealth)
		anchor:Hide()
	end
	setSlots(modSlots)
	syncOverlays()
end

local findModByCid
do
	local modIndex, indexedMods = {}, 0
	local function add(cid, mod)
		if type(cid) == "number" and not modIndex[cid] then
			modIndex[cid] = mod
		end
	end
	function findModByCid(cid)
		if indexedMods ~= #DBM.Mods then -- boss mods are loaded on demand
			table.wipe(modIndex)
			for _, mod in ipairs(DBM.Mods) do
				if mod.combatInfo then
					add(mod.creatureId, mod)
					add(mod.combatInfo.mob, mod)
					for _, id in ipairs(mod.multiMobPullDetection or {}) do
						add(id, mod)
					end
					for _, slot in ipairs(mod.healthFrameSlots or {}) do
						add(slot.cid, mod)
					end
				end
			end
			indexedMods = #DBM.Mods
		end
		return modIndex[cid]
	end
end

-- prepares the click overlays as soon as someone in the raid looks at a boss
local function armFromUnit(unit)
	if InCombatLockdown() or anchor and anchor:IsShown() then return end
	local guid = UnitGUID(unit)
	if not guid then return end
	local cid = DBM:GetCIDFromGUID(guid)
	local mod = cid and cid ~= 0 and findModByCid(cid)
	if mod and not mod.inCombat then
		arm(mod)
	end
end


--------------
--  Events  --
--------------
do
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	eventFrame:SetScript("OnEvent", function(self, event)
		if event == "PLAYER_REGEN_ENABLED" then
			if pendingSync and anchor then
				pendingSync = nil
				compactLayout()
				syncOverlays()
			end
		elseif event == "PLAYER_TARGET_CHANGED" then
			armFromUnit("target")
		elseif event == "UPDATE_MOUSEOVER_UNIT" then
			armFromUnit("mouseover")
		elseif event == "ZONE_CHANGED_NEW_AREA" then
			bossHealth:Disarm()
		end
	end)
end


-----------------------
--  General Methods  --
-----------------------
function bossHealth:Show(name)
	if not anchor then createFrame(bossHealth) end
	header:SetText(name)
	anchor:Show()
	bossHealth:Clear()
	updateFrame(bossHealth)
	if not bossHealth.ticker then
		bossHealth.ticker = AceTimer:ScheduleRepeatingTimer(function() updateFrame(bossHealth) end, 0.5)
	end
end

function bossHealth:SetHeaderText(name)
	if not anchor then return end
	header:SetText(name)
end

function bossHealth:Clear()
	if not anchor or not anchor:IsShown() then return end
	for i = #bars, 1, -1 do
		removeBar(i)
	end
	buildReserved()
	refreshLayout()
end

function bossHealth:Hide()
	if anchor then
		if bossHealth.ticker then
			AceTimer:CancelTimer(bossHealth.ticker)
			bossHealth.ticker = nil
		end
		anchor:Hide()
		syncOverlays()
	end
end

function bossHealth:IsShown()
	return anchor and anchor:IsShown()
end

-- called by DBM-Core on pull, before the frame is shown: switches to the reserved slots of the mod
function bossHealth:PrepareCombat(mod)
	armedMod = mod
	local modSlots = getModSlots(mod)
	if modSlots ~= slots then
		setSlots(modSlots)
	end
end

-- stops showing the click overlays of a mod (or of any mod) in combat while the frame is hidden
function bossHealth:Disarm(mod)
	if mod and armedMod ~= mod then return end
	armedMod = nil
	if anchor and not anchor:IsShown() then
		setSlots(nil)
	end
	syncOverlays()
end

-- HACK to support the old API cId, name. TODO: change API to name, cId and update _all_ boss mods (or: add new method AddSharedHealthBoss or something but this would also be ugly...) (or: use addBoss({cId1, cId2, ...}, name) for multi-cId bosses but that's just ugly)
-- for now: using this ugly code here instead of ugly code in all boss mods that make use of multi-cId health bars

-- hack to support shared health bosses
local function addBoss(self, name, ...) -- name, cId1, cId2, ..., cIdN, name
	if not anchor or not anchor:IsShown() then
		return
	end
	local id
	if select("#", ...) <= 2 then -- 2 as the name is in the vararg
		id = ...
	else
		id = {...}
		id[#id] = nil -- we don't want the name in here
	end
	local index = findReservedSlot(id)
	if index then
		local bar = reserved[index]
		for i = #bars, 1, -1 do
			if bars[i] == bar then
				tremove(bars, i)
			end
		end
		activateBar(bar, name or slots[index].name, id)
		tinsert(bars, bar)
	else
		local bar = acquireBar()
		activateBar(bar, name, id)
		tinsert(bars, bar)
		placeBar(bar)
	end
end

-- the signature of this method is (cId1, cId2, ..., cIdN, name) for compatibility reasons (used to be cId, name)
function bossHealth:AddBoss(...)
	-- copy the name to the front of the arg list
	-- note: name is now twice in the arg list but we can't really fix that in an efficient way (this is handled in addBoss()
	if select("#", ...) == 1 then
		return addBoss(self, nil, ...)
	else
		return addBoss(self, select(select("#", ...), ...), ...)
	end
end

local function barMatches(bar, id)
	return bar.id == id or type(bar.id) == "table" and checkEntry(bar.id, id) or type(bar.id) == "function" and bar.nameText:GetText() == id
end

-- just pass any of the creature IDs for shared health bosses
-- also accepts the name of the bar for generic bars (i.e. id == function) as you probably don't have access to the specific closure when removing something later
function bossHealth:RemoveBoss(cId)
	if not anchor or not anchor:IsShown() then return end
	for i = #bars, 1, -1 do
		if barMatches(bars[i], cId) then
			removeBar(i)
		end
	end
	refreshLayout()
end

--workaround for stuff
function bossHealth:RemoveLowest()
	if not anchor or not anchor:IsShown() then return end
	local lowest = 100
	local index
	for i = #bars, 1, -1 do
		local bar = bars[i]
		if bar.value < lowest then
			lowest = bar.value
			index = bar.id
		end
	end
	if index ~= nil then
		bossHealth:RemoveBoss(index)
	end
end

-- any ID for shared health bosses
function bossHealth:HasBoss(id)
	if not anchor or not anchor:IsShown() then return end
	for _, bar in ipairs(bars) do
		if bar.id == id or type(bar.id) == "table" and checkEntry(bar.id, id) then
			return true
		end
	end
	return false
end

-- renames an entry in the health frame
-- just pass any of the creature IDs for shared health bosses
function bossHealth:RenameBoss(cId, newName)
	if not anchor or not anchor:IsShown() then return end -- TODO: the entries should still be added even if the frame was never created if someone enables the frame mid-combat...
	for i = #bars, 1, -1 do
		local bar = bars[i]
		if bar.id == cId or type(bar.id) == "table" and checkEntry(bar.id, cId) then
			bar.nameText:SetText(newName)
		end
	end
	-- the click target of dynamic bars follows the name, which can only be updated outside of combat
	syncOverlays()
end

function bossHealth:UpdateSettings()
	if not anchor then return end -- createFrame() applies the current settings
	anchor:SetScale(DBM.Options.HealthFrameScale)
	anchor:ClearAllPoints()
	anchor:SetPoint(DBM.Options.HPFramePoint, UIParent, DBM.Options.HPFramePoint, DBM.Options.HPFrameX, DBM.Options.HPFrameY)
	menu[1].checked = DBM.Options.HealthFrameLocked
	updateHeaderStyle()
	for _, bar in ipairs(barCache) do
		updateBarStyle(bar)
	end
	for _, bar in ipairs(reserved) do
		updateBarStyle(bar)
		if not bar.active then
			showPlaceholder(bar, slots[bar.reservedIndex])
		end
	end
	for i = 1, tmaxn(layout) do
		local bar = layout[i]
		if bar then
			if not bar.reservedIndex then
				updateBarStyle(bar)
			end
			positionBar(bar)
		end
	end
	if not DBM.Options.HealthFrameClickable then
		armedMod = nil
	end
	syncOverlays()
end

function bossHealth:Update()
	if not anchor or not anchor:IsShown() then return end
	updateFrame(self)
end
