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
local UnitGUID, UnitCastingInfo, UnitChannelInfo, GetTime = UnitGUID, UnitCastingInfo, UnitChannelInfo, GetTime
local tremove, tinsert, tmaxn, mfloor, mmax, mmin = table.remove, table.insert, table.maxn, math.floor, math.max, math.min

local CLASSIC_BORDER_TEXTURE = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"
local CLASSIC_BAR_HEIGHT = 20
local PORTRAIT_FALLBACK = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local PORTRAIT_RETRIES = 3 -- SetPortraitTexture renders nothing until the unit's model is loaded
local INNER_GAP = 1 -- between portrait, health bar and cast bar; borders of neighbours overlap into one line
local MAX_AURAS = 6 -- per row
local AURA_GAP = 2
local AURA_OFFSET = 4 -- distance of the auras to the slot
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

-- "Flat" and "Retail" are the modern styles, "Classic" mimics the old health frame and has none of the extras
local function isModern()
	return DBM.Options.HealthFrameStyle ~= "Classic"
end

local function isRetail()
	return DBM.Options.HealthFrameStyle == "Retail"
end

local function showPortrait()
	return isModern() and DBM.Options.HealthFrameShowPortrait
end

local function showCastBar()
	return isModern() and DBM.Options.HealthFrameShowCastBar
end

local function showPowerBar()
	return isModern() and DBM.Options.HealthFrameShowPowerBar
end

local function showDebuffs()
	return isModern() and DBM.Options.HealthFrameShowDebuffs
end

local function showBuffs()
	return isModern() and DBM.Options.HealthFrameShowBuffs
end

-- the retail style shows the name above the health bar
local function getNameRowHeight()
	return isRetail() and DBM.Options.HealthFrameFontSize + 4 or 0
end

-- height of one slot: name row, health bar, power bar and cast bar
local function getBarHeight()
	if not isModern() then
		return CLASSIC_BAR_HEIGHT
	end
	local height = getNameRowHeight() + DBM.Options.HealthFrameBarHeight
	if showPowerBar() then
		height = height + INNER_GAP + DBM.Options.HealthFramePowerBarHeight
	end
	if showCastBar() then
		height = height + INNER_GAP + DBM.Options.HealthFrameCastBarHeight
	end
	return height
end

local function getBarSpacing()
	return isModern() and DBM.Options.HealthFrameSpacing or 0
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

-- draws a 1px border just outside of the given regions
local function applyFlatBorder(border, topLeft, bottomRight)
	border:ClearAllPoints()
	border:SetPoint("TOPLEFT", topLeft, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", bottomRight or topLeft, "BOTTOMRIGHT", 1, -1)
	if DBM.Options.HealthFrameBorder then
		border:SetBackdrop(flatBackdrop)
		border:SetBackdropBorderColor(0, 0, 0, 1)
	else
		border:SetBackdrop(nil)
	end
end

-- the flat style crops the round portrait into a square, the retail style keeps it round
local function applyPortraitCoords(bar)
	if bar.portraitGUID and not isRetail() then
		bar.portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	else
		bar.portrait:SetTexCoord(0, 1, 0, 1)
	end
end

local function updateCastBarStyle(bar, above, font, size, flags)
	local castbar = bar.castbar
	if not showCastBar() then
		castbar:Hide()
		return
	end
	local height = DBM.Options.HealthFrameCastBarHeight
	castbar:ClearAllPoints()
	-- the spell icon sits left of the bar, inside the slot
	castbar:SetPoint("TOPLEFT", above, "BOTTOMLEFT", height + INNER_GAP, -INNER_GAP)
	castbar:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -INNER_GAP)
	castbar:SetHeight(height)
	castbar:SetStatusBarTexture(DBM.Options.HealthFrameTexture)
	castbar.icon:SetWidth(height)
	castbar.icon:SetHeight(height)
	castbar.bg:SetTexture(0, 0, 0, DBM.Options.HealthFrameBgAlpha)
	applyFlatBorder(castbar.border, castbar.icon, castbar)
	size = mmin(size, mmax(height - 1, 6))
	setFont(castbar.text, font, size, flags)
	setFont(castbar.time, font, size, flags)
end

-- returns the lowest bar, the cast bar is placed below it
local function updatePowerBarStyle(bar)
	local powerbar = bar.powerbar
	if not showPowerBar() then
		powerbar:Hide()
		return bar.statusbar
	end
	powerbar:ClearAllPoints()
	powerbar:SetPoint("TOPLEFT", bar.statusbar, "BOTTOMLEFT", 0, -INNER_GAP)
	powerbar:SetPoint("TOPRIGHT", bar.statusbar, "BOTTOMRIGHT", 0, -INNER_GAP)
	powerbar:SetHeight(DBM.Options.HealthFramePowerBarHeight)
	powerbar:SetStatusBarTexture(DBM.Options.HealthFrameTexture)
	powerbar.bg:SetTexture(0, 0, 0, DBM.Options.HealthFrameBgAlpha)
	applyFlatBorder(powerbar.border, powerbar)
	powerbar:Show()
	return powerbar
end

-- auras are shown left of the slot: own debuffs in the first row, buffs of the boss below
local function updateAuraStyle(bar)
	local rows = {}
	bar.debuffs.enabled, bar.buffs.enabled = showDebuffs(), showBuffs()
	for _, row in ipairs({bar.debuffs, bar.buffs}) do
		if row.enabled then
			rows[#rows + 1] = row
		else
			for _, button in ipairs(row) do
				button:Hide()
			end
		end
	end
	if #rows == 0 then return end
	local size = mfloor((getBarHeight() - (#rows - 1) * AURA_GAP) / #rows)
	size = mmin(mmax(size, 10), 30)
	for rowIndex, row in ipairs(rows) do
		for i, button in ipairs(row) do
			button:ClearAllPoints()
			button:SetPoint("TOPRIGHT", bar, "TOPLEFT", -(AURA_OFFSET + (i - 1) * (size + AURA_GAP)), -(rowIndex - 1) * (size + AURA_GAP))
			button:SetWidth(size)
			button:SetHeight(size)
		end
	end
end

local function updateBarStyle(bar)
	local width = DBM.Options.HealthFrameWidth
	local statusbar, border, borderTexture = bar.statusbar, bar.border, bar.borderTexture
	local font, size, flags = getFont()
	bar:SetWidth(width)
	statusbar:ClearAllPoints()
	border:ClearAllPoints()
	bar.icon:ClearAllPoints()
	bar.nameText:ClearAllPoints()
	statusbar:SetStatusBarTexture(DBM.Options.HealthFrameTexture)
	if isRetail() then
		bar.nameText:SetPoint("BOTTOMLEFT", statusbar, "TOPLEFT", 1, 2)
		bar.nameText:SetPoint("BOTTOMRIGHT", statusbar, "TOPRIGHT", -1, 2)
	else
		bar.nameText:SetPoint("LEFT", statusbar, "LEFT", 2, 1)
		bar.nameText:SetPoint("RIGHT", bar.percentText, "LEFT", -2, 0)
	end
	if isModern() then
		local height = DBM.Options.HealthFrameBarHeight
		local slotHeight = getBarHeight()
		bar:SetHeight(slotHeight)
		local left, right = 0, 0
		local portraitFrame = bar.portraitFrame
		if showPortrait() then
			-- retail: round portrait on the right, flat: square portrait on the left
			local side = isRetail() and "RIGHT" or "LEFT"
			portraitFrame:ClearAllPoints()
			portraitFrame:SetPoint("TOP" .. side, bar, "TOP" .. side)
			portraitFrame:SetWidth(slotHeight)
			portraitFrame:SetHeight(slotHeight)
			if isRetail() then
				bar.portraitBorder:SetBackdrop(nil)
				right = slotHeight + INNER_GAP
			else
				applyFlatBorder(bar.portraitBorder, portraitFrame)
				left = slotHeight + INNER_GAP
			end
			applyPortraitCoords(bar)
			portraitFrame:Show()
			-- raid target icon goes on the outer top corner of the portrait, like on unit frames
			local iconSize = mmax(mfloor(slotHeight * 0.4), 8)
			bar.icon:SetWidth(iconSize)
			bar.icon:SetHeight(iconSize)
			bar.icon:SetPoint("TOP" .. side, portraitFrame, "TOP" .. side, 0, 0)
		else
			portraitFrame:Hide()
			bar.icon:SetWidth(height)
			bar.icon:SetHeight(height)
			bar.icon:SetPoint("RIGHT", statusbar, "LEFT", -4, 0)
		end
		statusbar:SetPoint("TOPLEFT", bar, "TOPLEFT", left, -getNameRowHeight())
		statusbar:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -right, -getNameRowHeight())
		statusbar:SetHeight(height)
		borderTexture:Hide()
		applyFlatBorder(border, statusbar)
		updateCastBarStyle(bar, updatePowerBarStyle(bar), font, size, flags)
		updateAuraStyle(bar)
	else
		bar.portraitFrame:Hide()
		bar.castbar:Hide()
		bar.powerbar:Hide()
		bar.debuffs.enabled, bar.buffs.enabled = false, false
		for _, row in ipairs({bar.debuffs, bar.buffs}) do
			for _, button in ipairs(row) do
				button:Hide()
			end
		end
		bar.icon:SetPoint("RIGHT", statusbar, "LEFT", -4, 0)
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

----------------
--  Portrait  --
----------------
local function resetPortrait(bar)
	bar.portraitGUID, bar.portraitTries = nil, nil
	bar.portrait:SetTexture(PORTRAIT_FALLBACK)
	bar.portrait:SetTexCoord(0, 1, 0, 1)
end

local function updatePortrait(bar, unit, guid)
	if guid ~= bar.portraitGUID then
		bar.portraitGUID, bar.portraitTries = guid, 0
	end
	if bar.portraitTries >= PORTRAIT_RETRIES then return end
	bar.portraitTries = bar.portraitTries + 1
	SetPortraitTexture(bar.portrait, unit)
	applyPortraitCoords(bar)
end

local function setPortraitGreyed(bar, greyed)
	bar.portrait:SetDesaturated(greyed)
	local c = greyed and 0.5 or 1
	bar.portrait:SetVertexColor(c, c, c)
end

-- remembers the unit a bar was last seen on, used by the portrait and the cast bar
local function setUnit(bar, unit)
	local guid = unit and UnitGUID(unit)
	bar.unit, bar.unitGUID = guid and unit, guid
	if guid and showPortrait() then
		updatePortrait(bar, unit, guid)
	end
end


----------------
--  Cast Bar  --
----------------
local function onCastUpdate(self)
	local now = GetTime()
	if now >= self.endTime then
		self:Hide()
		return
	end
	local duration = self.endTime - self.startTime
	local progress = duration > 0 and (now - self.startTime) / duration or 1
	self:SetValue(self.channel and 1 - progress or progress)
	self.time:SetFormattedText("%.1f", self.endTime - now)
end

local function startCast(castbar, spell, texture, startTime, endTime, channel, notInterruptible)
	castbar.startTime, castbar.endTime, castbar.channel = startTime, endTime, channel
	castbar.text:SetText(spell)
	castbar.icon:SetTexture(texture)
	if notInterruptible then
		castbar:SetStatusBarColor(0.63, 0.63, 0.63)
	elseif channel then
		castbar:SetStatusBarColor(0, 0.8, 0.2)
	else
		castbar:SetStatusBarColor(1, 0.7, 0)
	end
	castbar:Show()
	onCastUpdate(castbar)
end

local function updateCast(bar, unit)
	if not unit then return end -- a running cast keeps going until its end
	local channel
	local spell, _, _, texture, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(unit)
	if not spell then
		spell, _, _, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
		channel = spell and true
	end
	if spell then
		startCast(bar.castbar, spell, texture, startTime / 1000, endTime / 1000, channel, notInterruptible)
	else
		bar.castbar:Hide()
	end
end


-----------------
--  Power Bar  --
-----------------
local function setPower(bar, value, max, color)
	local powerbar = bar.powerbar
	powerbar:SetMinMaxValues(0, max > 0 and max or 1)
	powerbar:SetValue(max > 0 and value or 0)
	if color then
		powerbar:SetStatusBarColor(color.r, color.g, color.b)
	end
end

local function updatePower(bar, unit)
	if not unit then return end -- keep the last known value
	local powerType, powerToken = UnitPowerType(unit)
	setPower(bar, UnitPower(unit), UnitPowerMax(unit), PowerBarColor[powerToken] or PowerBarColor[powerType] or PowerBarColor.MANA)
end


-------------
--  Auras  --
-------------
local function onAuraEnter(self)
	local bar = self.bar
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	if bar.unit and UnitGUID(bar.unit) == bar.unitGUID and self.index then
		GameTooltip:SetUnitAura(bar.unit, self.index, self.filter)
	elseif self.spellId then
		GameTooltip:SetHyperlink("spell:" .. self.spellId)
	end
	GameTooltip:Show()
end

local function onAuraLeave()
	GameTooltip:Hide()
end

local function createAuraRow(bar, filter, isDebuff)
	local row = {filter = filter}
	for i = 1, MAX_AURAS do
		local button = CreateFrame("Frame", nil, bar)
		button.bar, button.filter, button.isDebuff = bar, filter, isDebuff
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints(button)
		button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		button.border = CreateFrame("Frame", nil, button)
		button.border:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
		button.border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
		button.border:SetBackdrop(flatBackdrop)
		button.cooldown = CreateFrame("Cooldown", nil, button)
		button.cooldown:SetAllPoints(button)
		button.cooldown:SetReverse(true)
		local countFrame = CreateFrame("Frame", nil, button)
		countFrame:SetAllPoints(button)
		countFrame:SetFrameLevel(button.cooldown:GetFrameLevel() + 1)
		button.count = countFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
		button:EnableMouse(true)
		button:SetScript("OnEnter", onAuraEnter)
		button:SetScript("OnLeave", onAuraLeave)
		button:Hide()
		row[i] = button
	end
	return row
end

local function setAura(button, index, icon, count, debuffType, duration, expiration, spellId)
	button.index, button.spellId = index, spellId
	button.icon:SetTexture(icon)
	button.count:SetText(count and count > 1 and count or "")
	if duration and duration > 0 then
		-- restarting the cooldown every poll would make it flicker
		if button.expiration ~= expiration or button.duration ~= duration then
			button.cooldown:SetCooldown(expiration - duration, duration)
		end
		button.cooldown:Show()
	else
		button.cooldown:Hide()
	end
	button.expiration, button.duration = expiration, duration
	local color = button.isDebuff and DebuffTypeColor[debuffType or "none"]
	if color then
		button.border:SetBackdropBorderColor(color.r, color.g, color.b, 1)
	else
		button.border:SetBackdropBorderColor(0, 0, 0, 1)
	end
	button:Show()
end

local function hideAuras(row, from)
	for i = from or 1, MAX_AURAS do
		local button = row[i]
		button:Hide()
		button.expiration, button.duration = nil, nil
	end
end

local function updateAuraRow(row, unit)
	if not row.enabled then return end
	local shown = 0
	if unit then
		local i = 1
		while shown < MAX_AURAS do
			local name, _, icon, count, debuffType, duration, expiration, _, _, _, spellId = UnitAura(unit, i, row.filter)
			if not name then break end
			shown = shown + 1
			setAura(row[shown], i, icon, count, debuffType, duration, expiration, spellId)
			i = i + 1
		end
	end
	hideAuras(row, shown + 1)
end


------------------
--  Unit State  --
------------------
-- forgets the unit of a bar and everything shown about it (except the portrait)
local function clearUnit(bar)
	bar.unit, bar.unitGUID = nil, nil
	bar.castbar:Hide()
	setPower(bar, 0, 0)
	hideAuras(bar.debuffs)
	hideAuras(bar.buffs)
end

-- cast bar, power bar and auras, polled more often than the health
local function updateUnitDetails(bar)
	if not bar.active or type(bar.id) == "function" then return end -- generic bars have no unit
	local unit = bar.unit
	-- unit tokens like raid5target can point to another mob by now, the next health update finds the boss again
	if unit and UnitGUID(unit) ~= bar.unitGUID then return end
	if showCastBar() then
		updateCast(bar, unit)
	end
	if showPowerBar() then
		updatePower(bar, unit)
	end
	updateAuraRow(bar.debuffs, unit)
	updateAuraRow(bar.buffs, unit)
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
	-- portrait
	bar.portraitFrame = CreateFrame("Frame", nil, bar)
	bar.portrait = bar.portraitFrame:CreateTexture(nil, "ARTWORK")
	bar.portrait:SetAllPoints(bar.portraitFrame)
	bar.portraitBorder = CreateFrame("Frame", nil, bar.portraitFrame)
	resetPortrait(bar)
	-- cast bar
	local castbar = CreateFrame("StatusBar", nil, bar)
	castbar:SetMinMaxValues(0, 1)
	castbar.icon = castbar:CreateTexture(nil, "ARTWORK")
	castbar.icon:SetPoint("TOPRIGHT", castbar, "TOPLEFT", -INNER_GAP, 0)
	castbar.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	castbar.bg = castbar:CreateTexture(nil, "BACKGROUND")
	castbar.bg:SetPoint("TOPLEFT", castbar.icon, "TOPLEFT")
	castbar.bg:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT")
	castbar.border = CreateFrame("Frame", nil, castbar)
	local castText = CreateFrame("Frame", nil, castbar)
	castText:SetAllPoints(castbar)
	castText:SetFrameLevel(castbar.border:GetFrameLevel() + 1)
	castbar.time = castText:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	castbar.time:SetPoint("RIGHT", castbar, "RIGHT", -2, 0)
	castbar.text = castText:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	castbar.text:SetPoint("LEFT", castbar, "LEFT", 2, 0)
	castbar.text:SetPoint("RIGHT", castbar.time, "LEFT", -2, 0)
	castbar.text:SetJustifyH("LEFT")
	castbar:SetScript("OnUpdate", onCastUpdate)
	castbar:Hide()
	bar.castbar = castbar
	-- power bar
	local powerbar = CreateFrame("StatusBar", nil, bar)
	powerbar.bg = powerbar:CreateTexture(nil, "BACKGROUND")
	powerbar.bg:SetAllPoints(powerbar)
	powerbar.border = CreateFrame("Frame", nil, powerbar)
	powerbar:Hide()
	bar.powerbar = powerbar
	-- auras
	bar.debuffs = createAuraRow(bar, "HARMFUL|PLAYER", true)
	bar.buffs = createAuraRow(bar, "HELPFUL")
	setPower(bar, 0, 0, PowerBarColor.MANA)
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
	clearUnit(bar)
	resetPortrait(bar)
	setPortraitGreyed(bar, false)
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
	clearUnit(bar)
	-- reserved bars keep the portrait of their boss, greyed out
	setPortraitGreyed(bar, true)
end

local function activateBar(bar, name, id)
	bar.id = id
	bar.value = nil
	bar.active = true
	bar.nameText:SetTextColor(1, 1, 1)
	bar.percentText:SetTextColor(1, 1, 1)
	bar.nameText:SetText(name or "")
	bar.nameused = name and true or nil
	setPortraitGreyed(bar, false)
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
	-- units DBM:GetBossHP doesn't scan: mouseover and, with awesome_wotlk (https://github.com/FrostAtom/awesome_wotlk), nameplates
	local extraUnits = {"mouseover"}
	if C_NamePlate then
		for i = 1, 40 do
			extraUnits[#extraUnits + 1] = "nameplate" .. i
		end
	end

	-- id is a creature ID or a GUID
	local function getExtraUnitHP(id)
		for _, unit in ipairs(extraUnits) do
			local guid = UnitGUID(unit)
			if guid and (guid == id or DBM:GetCIDFromGUID(guid) == id) and UnitHealthMax(unit) ~= 0 then
				return UnitHealth(unit) / UnitHealthMax(unit) * 100, unit, UnitName(unit)
			end
		end
	end

	local function getHP(id)
		local health, unit, name = DBM:GetBossHP(id)
		if not health then
			health, unit, name = getExtraUnitHP(id)
		end
		return health, unit, name
	end

	function updateFrame(self)
		for _, v in ipairs(bars) do
			if type(v.id) == "number" then -- creature ID
				local health, id, name = getHP(v.id)
				setUnit(v, health and id)
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
					if not health then
						health, id, name = getExtraUnitHP(v.id)
					end
				end
				setUnit(v, health and id)
				if health then
					updateBar(v, health, GetRaidTargetIndex(id), nil, name)
				else
					updateBar(v, -1)
				end
			elseif type(v.id) == "table" then -- multi boss
				-- TODO: it would be more efficient to scan all party/raid members for all IDs instead of going over all raid members n times
				-- this is especially important for the cache
				local found
				for _, id in ipairs(v.id) do
					local health, unit = getHP(id)
					if health then
						found = unit
						updateBar(v, health)
						break
					end
				end
				setUnit(v, found)
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
	-- casts, power and auras are polled more often than health so they show up without a noticeable delay
	if not bossHealth.castTicker then
		bossHealth.castTicker = AceTimer:ScheduleRepeatingTimer(function()
			for _, bar in ipairs(bars) do
				updateUnitDetails(bar)
			end
		end, 0.1)
	end
end

-- fake casts, power and auras on the demo bars of the options panel
function bossHealth:ShowDemoDetails()
	if not anchor or not anchor:IsShown() or not isModern() then return end
	local now = GetTime()
	local casts = {
		{133, 3}, -- Fireball
		{5143, 5, true}, -- Arcane Missiles (channel)
		{686, 4, false, true} -- Shadow Bolt (not interruptible)
	}
	local powers = {"MANA", "RAGE", "ENERGY", "MANA"}
	local debuffs = {{172, 18, "Magic"}, {980, 24, "Curse"}, {348, 15, "Magic"}} -- Corruption, Curse of Agony, Immolate
	local buffs = {{12880, 12}, {1459, 0}} -- Enrage, Arcane Intellect
	local function demoAuras(row, list, count)
		if not row.enabled then return end
		for i = 1, count do
			local aura = list[i]
			local _, _, icon = GetSpellInfo(aura[1])
			setAura(row[i], nil, icon, i == 1 and 3 or 0, aura[3], aura[2], now + aura[2], aura[1])
		end
		hideAuras(row, count + 1)
	end
	for i, bar in ipairs(bars) do
		local cast = casts[i]
		if cast and showCastBar() then
			local spell, _, texture = GetSpellInfo(cast[1])
			startCast(bar.castbar, spell, texture, now, now + cast[2], cast[3], cast[4])
		end
		setPower(bar, 100 - i * 20, 100, PowerBarColor[powers[i] or "MANA"])
		demoAuras(bar.debuffs, debuffs, mmin(i, #debuffs))
		demoAuras(bar.buffs, buffs, i % 2 == 0 and #buffs or 1)
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
		if bossHealth.castTicker then
			AceTimer:CancelTimer(bossHealth.castTicker)
			bossHealth.castTicker = nil
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
