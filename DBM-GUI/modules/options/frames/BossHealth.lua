local L = DBM_GUI_L
local DBM = DBM

local function updateSettings()
	DBM.BossHealth:UpdateSettings()
end

local hpPanel = DBM_GUI.Cat_Frames:CreateNewPanel(L.Panel_HPFrame, "option")

--------------
-- General  --
--------------
local hpArea = hpPanel:CreateArea(L.Area_HPFrame)

hpArea:CreateCheckButton(L.HP_Enabled, true, nil, "AlwaysShowHealthFrame")
local growbttn = hpArea:CreateCheckButton(L.HP_GrowUpwards, true)
growbttn:SetScript("OnShow",  function(self) self:SetChecked(DBM.Options.HealthFrameGrowUp) end)
growbttn:SetScript("OnClick", function(self)
		DBM.Options.HealthFrameGrowUp = not not self:GetChecked()
		updateSettings()
end)
local lockbttn = hpArea:CreateCheckButton(L.HP_Locked, true, nil, "HealthFrameLocked")
lockbttn:HookScript("OnClick", updateSettings)
local clickbttn = hpArea:CreateCheckButton(L.HP_Clickable, true, nil, "HealthFrameClickable")
clickbttn:HookScript("OnClick", updateSettings)
local headerbttn = hpArea:CreateCheckButton(L.HP_ShowHeader, true, nil, "HealthFrameShowHeader")
headerbttn:HookScript("OnClick", updateSettings)
local decimalsbttn = hpArea:CreateCheckButton(L.HP_Decimals, true, nil, "HealthFrameDecimals")
decimalsbttn:HookScript("OnClick", function() DBM.BossHealth:Update() end)

local function createDummyFunc(i) return function() return i end end
local showbutton = hpArea:CreateButton(L.HP_ShowDemo, 120, 16)
showbutton:SetPoint("TOPRIGHT", hpArea.frame, "TOPRIGHT", -5, -5)
showbutton:SetNormalFontObject(GameFontNormalSmall)
showbutton:SetHighlightFontObject(GameFontNormalSmall)
showbutton.myheight = 0
showbutton:SetScript("OnClick", function()
		DBM.BossHealth:Hide()
		DBM.BossHealth:Disarm()
		DBM.BossHealth:Show("Health Frame")
		DBM.BossHealth:AddBoss(createDummyFunc(25), "TestBoss 1")
		DBM.BossHealth:AddBoss(createDummyFunc(50), "TestBoss 2")
		DBM.BossHealth:AddBoss(createDummyFunc(75), "TestBoss 3")
		DBM.BossHealth:AddBoss(createDummyFunc(100), "TestBoss 4")
end)

------------
-- Style  --
------------
local styleArea = hpPanel:CreateArea(L.Area_Style)

local Styles = {
	{
		text	= L.HP_StyleClassic,
		value	= "Classic"
	},
	{
		text	= L.HP_StyleFlat,
		value	= "Flat"
	}
}

local StyleDropDown = styleArea:CreateDropdown(L.HP_Style, Styles, "DBM", "HealthFrameStyle", function(value)
	DBM.Options.HealthFrameStyle = value
	updateSettings()
end, 160)
StyleDropDown:SetPoint("TOPLEFT", styleArea.frame, "TOPLEFT", 0, -20)

local Textures = DBM_GUI:MixinSharedMedia3("statusbar", {
	{
		text	= "Blizzard",
		value	= "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
	},
	{
		text	= "DBM",
		value	= "Interface\\AddOns\\DBM-Core\\textures\\default.blp"
	},
	{
		text	= "Glaze",
		value	= "Interface\\AddOns\\DBM-Core\\textures\\glaze.blp"
	},
	{
		text	= "Otravi",
		value	= "Interface\\AddOns\\DBM-Core\\textures\\otravi.blp"
	},
	{
		text	= "Smooth",
		value	= "Interface\\AddOns\\DBM-Core\\textures\\smooth.blp"
	}
})

local TextureDropDown = styleArea:CreateDropdown(L.BarTexture, Textures, "DBM", "HealthFrameTexture", function(value)
	DBM.Options.HealthFrameTexture = value
	updateSettings()
end, 160)
TextureDropDown:SetPoint("TOPLEFT", styleArea.frame, "TOPLEFT", 220, -20)

local Fonts = DBM_GUI:MixinSharedMedia3("font", {
	{
		text	= DEFAULT,
		value	= "standardFont"
	},
	{
		text	= "Arial",
		value	= "Fonts\\ARIALN.TTF"
	},
	{
		text	= "Skurri",
		value	= "Fonts\\SKURRI.TTF"
	},
	{
		text	= "Morpheus",
		value	= "Fonts\\MORPHEUS.TTF"
	}
})

local FontDropDown = styleArea:CreateDropdown(L.FontType, Fonts, "DBM", "HealthFrameFont", function(value)
	DBM.Options.HealthFrameFont = value
	updateSettings()
end, 160)
FontDropDown:SetPoint("TOPLEFT", StyleDropDown, "BOTTOMLEFT", 0, -20)

local FontStyles = {
	{
		text	= L.None,
		value	= "None"
	},
	{
		text	= L.Outline,
		value	= "OUTLINE",
		flag	= true
	},
	{
		text	= L.ThickOutline,
		value	= "THICKOUTLINE",
		flag	= true
	},
	{
		text	= L.MonochromeOutline,
		value	= "MONOCHROME,OUTLINE",
		flag	= true
	},
	{
		text	= L.MonochromeThickOutline,
		value	= "MONOCHROME,THICKOUTLINE",
		flag	= true
	}
}

local FontStyleDropDown = styleArea:CreateDropdown(L.FontStyle, FontStyles, "DBM", "HealthFrameFontStyle", function(value)
	DBM.Options.HealthFrameFontStyle = value
	updateSettings()
end, 160)
FontStyleDropDown:SetPoint("TOPLEFT", TextureDropDown, "BOTTOMLEFT", 0, -20)

local ColorModes = {
	{
		text	= L.HP_ColorGradient,
		value	= "Gradient"
	},
	{
		text	= L.HP_ColorCustom,
		value	= "Custom"
	}
}

local ColorModeDropDown = styleArea:CreateDropdown(L.HP_ColorMode, ColorModes, "DBM", "HealthFrameColorMode", function(value)
	DBM.Options.HealthFrameColorMode = value
	updateSettings()
end, 160)
ColorModeDropDown:SetPoint("TOPLEFT", FontDropDown, "BOTTOMLEFT", 0, -20)

local colorSelect = styleArea:CreateColorSelect(64)
colorSelect:SetPoint("TOPLEFT", FontStyleDropDown, "BOTTOMLEFT", 20, -20)
local colorText = styleArea.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
colorText:SetPoint("BOTTOMLEFT", colorSelect, "TOPLEFT", 0, 4)
colorText:SetText(L.HP_ColorCustom)
local colorReset = styleArea:CreateButton(L.Reset, 64, 14, nil, GameFontNormalSmall)
colorReset:SetPoint("LEFT", colorSelect, "RIGHT", 15, 0)
colorReset.myheight = 0
local function updateColorText()
	colorText:SetTextColor(DBM.Options.HealthFrameColorR, DBM.Options.HealthFrameColorG, DBM.Options.HealthFrameColorB)
end
colorSelect:SetScript("OnShow", function(self)
	self:SetColorRGB(DBM.Options.HealthFrameColorR, DBM.Options.HealthFrameColorG, DBM.Options.HealthFrameColorB)
	updateColorText()
end)
colorSelect:SetScript("OnColorSelect", function(self)
	DBM.Options.HealthFrameColorR, DBM.Options.HealthFrameColorG, DBM.Options.HealthFrameColorB = self:GetColorRGB()
	updateColorText()
	updateSettings()
end)
colorReset:SetScript("OnClick", function()
	colorSelect:SetColorRGB(DBM.DefaultOptions.HealthFrameColorR, DBM.DefaultOptions.HealthFrameColorG, DBM.DefaultOptions.HealthFrameColorB)
end)

local function createOptionSlider(text, low, high, step, option)
	local slider = styleArea:CreateSlider(text, low, high, step, 180)
	slider:SetScript("OnShow", function(self) self:SetValue(DBM.Options[option]) end)
	slider:HookScript("OnValueChanged", function(self)
		DBM.Options[option] = self:GetValue()
		updateSettings()
	end)
	slider.myheight = 0
	return slider
end

local BarWidthSlider = createOptionSlider(L.BarWidth, 100, 400, 1, "HealthFrameWidth")
BarWidthSlider:SetPoint("TOPLEFT", ColorModeDropDown, "BOTTOMLEFT", 20, -55)
local BarHeightSlider = createOptionSlider(L.Bar_Height, 8, 40, 1, "HealthFrameBarHeight")
BarHeightSlider:SetPoint("LEFT", BarWidthSlider, "RIGHT", 40, 0)
local ScaleSlider = createOptionSlider(L.Slider_BarScale, 0.5, 2, 0.05, "HealthFrameScale")
ScaleSlider:SetPoint("TOPLEFT", BarWidthSlider, "BOTTOMLEFT", 0, -30)
local SpacingSlider = createOptionSlider(L.HP_Spacing, 0, 20, 1, "HealthFrameSpacing")
SpacingSlider:SetPoint("LEFT", ScaleSlider, "RIGHT", 40, 0)
local FontSizeSlider = createOptionSlider(L.FontSize, 6, 24, 1, "HealthFrameFontSize")
FontSizeSlider:SetPoint("TOPLEFT", ScaleSlider, "BOTTOMLEFT", 0, -30)
local BgAlphaSlider = createOptionSlider(L.HP_BgAlpha, 0, 1, 0.1, "HealthFrameBgAlpha")
BgAlphaSlider:SetPoint("LEFT", FontSizeSlider, "RIGHT", 40, 0)

local borderbttn = styleArea:CreateCheckButton(L.HP_Border, false, nil, "HealthFrameBorder")
borderbttn:SetPoint("TOPLEFT", FontSizeSlider, "BOTTOMLEFT", -10, -20)
borderbttn:HookScript("OnClick", updateSettings)

local resetbutton = styleArea:CreateButton(L.Reset, 120, 16)
resetbutton:SetPoint("BOTTOMRIGHT", styleArea.frame, "BOTTOMRIGHT", -5, 5)
resetbutton:SetNormalFontObject(GameFontNormalSmall)
resetbutton:SetHighlightFontObject(GameFontNormalSmall)
resetbutton.myheight = 0
resetbutton:SetScript("OnClick", function()
	for _, option in ipairs({
		"HPFramePoint", "HPFrameX", "HPFrameY", "HealthFrameGrowUp", "HealthFrameWidth", "HealthFrameScale", "HealthFrameStyle",
		"HealthFrameBarHeight", "HealthFrameSpacing", "HealthFrameBorder", "HealthFrameTexture", "HealthFrameBgAlpha",
		"HealthFrameFont", "HealthFrameFontSize", "HealthFrameFontStyle", "HealthFrameColorMode",
		"HealthFrameColorR", "HealthFrameColorG", "HealthFrameColorB", "HealthFrameShowHeader", "HealthFrameDecimals"
	}) do
		DBM.Options[option] = DBM.DefaultOptions[option]
	end
	-- refresh all widgets of the panel from the new values
	for _, widget in ipairs({growbttn, headerbttn, decimalsbttn, borderbttn, StyleDropDown, TextureDropDown, FontDropDown, FontStyleDropDown,
		ColorModeDropDown, colorSelect, BarWidthSlider, BarHeightSlider, ScaleSlider, SpacingSlider, FontSizeSlider, BgAlphaSlider}) do
		widget:GetScript("OnShow")(widget)
	end
	updateSettings()
end)

-- every widget above is placed manually, so the area height is accounted for here
StyleDropDown.myheight = 400
for _, widget in ipairs({TextureDropDown, FontDropDown, FontStyleDropDown, ColorModeDropDown, colorSelect, borderbttn}) do
	widget.myheight = 0
end
