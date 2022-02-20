-- Author      : nihilianth
-- Create Date : 4/6/2021 3:48:07 PM
EnchantListFrameAddon = LibStub("AceAddon-3.0"):NewAddon("EnchantListFrameAddon", "AceConsole-3.0", "AceEvent-3.0", "AceSerializer-3.0", "AceComm-3.0", "AceHook-3.0", "AceTimer-3.0");
if not DataStore_AscensionRE then return end

LibDeflate = LibStub:GetLibrary("LibDeflate")

local addon = EnchantListFrameAddon
local LAST_SUPPORTED_MINOR = 0
local LAST_SUPPORTED_PATCH = 5
local LAST_SUPPORTED_VER = format("%02x%02x", LAST_SUPPORTED_MINOR, LAST_SUPPORTED_PATCH)
local RESpellList_indexed = {}
local RESpellList_data = {}
local RESpellList_filtered = {}

local playerName = ""
local selectedIdx = 1
local nameFilter = ""
local addonPrefix = "[RETB]: "
local linkExpirationThr = 60 * 5

local reApply = false
local reExtract = false
local reReforge = false
local reReforgeLoopToggle = false
local reToggle = false

local ITEM_BAG = 0
local ITEM_SLOT = 0

local version = {0, 0, 4}

function EnchantListFrame_OnLoad(self)
	EnchantListFrame:Hide()
	for i=1,3 do
		local currBtn = _G["RECurrencyButton"..i]
		currBtn.Text = currBtn:CreateFontString(nil)
		currBtn.Text:SetShadowOffset(0, 0)
		currBtn.Text:SetPoint("BOTTOM", 0, -10)
		currBtn.Text:SetSize(64, 32)
		currBtn.Text:SetJustifyH("CENTER")
		currBtn.Text:SetJustifyV("CENTER")
		currBtn.Text:SetFont("Fonts\\FRIZQT__.TTF", 10, "THICKOUTLINE")
	end
	EnchantListFrame_SetREList(UnitName("player"), {})
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE")
	self:RegisterEvent("COMMENTATOR_SKIRMISH_QUEUE_REQUEST")
	EnchantListFrame_CreateSkillButtons()
	table.insert(UISpecialFrames, "EnchantListFrame")
end

function EnchantListFrame_Show()
	SetREUtilButton(false, false, false)
	EnchantListSetButtonToggle()
	RESpellList_filtered = RESpellList_data[1]
	if playerName == "" then
		EnchantListFrameTitleText:SetText("REToolbox: All "..#RESpellList_data[1].." REs")
		SetPortraitToTexture(EnchantListFramePortrait, "Interface\\LFGFrame\\UI-LFG-PORTRAIT")
	else
		EnchantListFrameTitleText:SetText("REToolbox: "..playerName.." ("..#RESpellList_data[1]..")")
		SetPortraitTexture(EnchantListFramePortrait, playerName);
	end

	if playerName == UnitName("player") then
		EnchantListLinkButton:Show()
		EnchantListApplyREButton:Show()
		EnchantListExtractButton:Show()
	else
		EnchantListLinkButton:Hide()
		EnchantListApplyREButton:Hide()
		EnchantListExtractButton:Hide()
	end
	-- apply filters
	FauxScrollFrame_SetOffset(EnchantListListScrollFrame, 0)
	EnchantListFrame_Update()
	EnchantListFrame_SetSelection(1)
	--print("show: setting texture for "..playerName)
	--EnchantListFramePortrait:SetTexture("Interface\\BattlefieldFrame\\UI-Battlefield-Icon")

	
	EnchantListFrame:Show()
	EnchantListFrameEditBox:SetFocus()
end

local tooltip = CreateFrame("GameTooltip", "DescParseTooltip", UIParent, "GameTooltipTemplate")
local inspectTooltip = CreateFrame("GameTooltip", "EnchantListFrameInspectTooltip", UIParent, "GameTooltipTemplate")
function EnchantListFrame_SetTooltip(id)
	if id == 0 then
		inspectTooltip:Hide()
	else
		inspectTooltip:SetOwner(EnchantListFrame, "ANCHOR_NONE")
		inspectTooltip:SetPoint("TOPLEFT", EnchantListFrame, "TOPRIGHT")
		inspectTooltip:SetHyperlink("spell:"..id)
		HandleTooltipSet(inspectTooltip, id)
		inspectTooltip:Show()
	end
end

--- Called on Click
---@param list_id any
function EnchantListFrame_SetSelection(list_id)
	
	--addon:Print("selection "..list_id)
	selectedIdx = list_id

	if #RESpellList_filtered == 0 then
		return
	end

	-- addon:Print("selecting "..list_id)
	local id = RESpellList_filtered[list_id][1]
	local name, rank, icon = GetSpellInfo(id)
	
	tooltip:SetOwner(WorldFrame, "ACHOR_NONE")
	tooltip:SetHyperlink("spell:"..id)
	local desc =_G[tooltip:GetName().."TextLeft"..tooltip:NumLines()]:GetText()

	
	EnchantListSkillIcon:SetNormalTexture(icon);
	EnchantListSkillName:SetText(name)
	EnchantListSpellIdText:SetText(tostring(id))
	EnchantListDescription:SetText(desc)
    tooltip:Hide()
end

function EnchantListFrame_Update()
	local offset = FauxScrollFrame_GetOffset(EnchantListListScrollFrame);
	
	FauxScrollFrame_Update(EnchantListListScrollFrame, #RESpellList_filtered, 8, 16, nil, nil, nil, EnchantListHighlightFrame, 293, 316 );
	EnchantListHighlightFrame:Hide();

	for i = 1, 8 do
		skillBtn = _G["EnchantListSpellButton"..i];
		if i + offset <= #RESpellList_filtered then
			skillBtn:SetID(RESpellList_filtered[i + offset][1]);
			skillBtn:SetText(GetSkillLink(RESpellList_filtered[i + offset][1]));
			skillBtn:SetNormalTexture("");
			skillBtn:Show();
			if i + offset == selectedIdx then
				EnchantListHighlightFrame:SetPoint("TOPLEFT", "EnchantListSpellButton"..i, "TOPLEFT", 0, 0);
				EnchantListHighlightFrame:Show();
				skillBtn:LockHighlight();
				skillBtn.isHighlighted = true;
			else
				skillBtn:UnlockHighlight();
				skillBtn.isHighlighted = false;
			end
		else
			skillBtn:Hide()
			skillBtn:UnlockHighlight();
			skillBtn.isHighlighted = false;
		end
	end
end

-- ** Search implementation

function EnchantListApplyFilter()
	local qualityId = UIDropDownMenu_GetSelectedID(EnchantListQualityDropDown)
	local hideKnown = EnchantListHideKnownFilterCheckButton:GetChecked() ~= nil
	local includeDesc = EnchantListIncludeDescButton:GetChecked() ~= nil

	dataSet = {qualityId, hideKnown, nameFilter}
	-- print(qualityId, hideKnown, nameFilter)
	assert(qualityId >= 1 and qualityId <= 5)

	RESpellList_filtered = {}

	for idx, data in pairs(RESpellList_data[qualityId]) do
		if hideKnown == false or not (hideKnown == true and KnownREs[1][data[1]] ~= nil) then
			local nameLower = string.lower(data[2])
			local searchLower = string.lower(nameFilter)
			if string.find(nameLower, searchLower) ~= nil then
				table.insert(RESpellList_filtered, data)			
			elseif includeDesc then
				--local descLower = string.lower(REDescriptionForSpell[data[1]])
				local descLower = string.lower(C_Spell:GetSpellDescription(data[1]))
				if string.find(descLower, searchLower) ~= nil then
					table.insert(RESpellList_filtered, data)
				end
			end
		end
	end


	if #RESpellList_filtered == 0 then
		EnchantListSkillIcon:SetNormalTexture("");
		EnchantListSkillName:SetText("No RE selected")
		EnchantListSpellIdText:SetText("")
		EnchantListDescription:SetText("")
	else
		EnchantListFrame_SetSelection(1)
	end
	EnchantListListScrollFrameScrollBar:SetValue(0);
	FauxScrollFrame_SetOffset(EnchantListListScrollFrame, 0)
	EnchantListFrame_Update()
end

function EnchantListFilter_OnTextChanged(self, input)
	local text = self:GetText()

	if text == SEARCH then return end

	-- addon:Print("Searching for :"..text)
	nameFilter = text
	EnchantListApplyFilter()
end

-- ** RE util button handling

function EnchantListSetButtonToggle()
	local state = EnchantListToggleButtonsCheckButton:GetChecked()
	reToggle = state and true or false
end

function addon:UpdateRETokens()

	local currency = {
		98570,
		98462,
		98463,
	}
	
	for id = 1,3 do
		local currText = _G["RECurrencyButton"..id]
		local cnt = GetItemCount(currency[id])
		if currText ~= nil and currText.Text ~= nil then
			 currText.Text:SetText(cnt) 
		end
	end

end

function SetREUtilButton(apply, extract, reforge)
	addon:UpdateRETokens()

	if apply ~= nil then
		reApply = apply
		reExtract = false
		reReforge = false
	elseif extract ~= nil then
		reExtract = extract
		reApply = false
		reReforge = false
	elseif reforge ~= nil then
		reReforge = reforge
		reApply = false
		reExtract = false
	end

	local tarButtons = {
		EnchantListApplyREButton,
		EnchantListExtractButton,
		EnchantListReforgeButton
	}

	local tarData = {
		reApply,
		reExtract,
		reReforge
	}

	for id, btn in pairs(tarButtons) do
		if tarData[id] == true then
			btn.PulseAnim:Play()
			btn.flashTexture:Show()
			btn:SetButtonState("PUSHED", true);
		else
			btn.PulseAnim:Stop()
			btn.flashTexture:Hide()
			btn:SetButtonState("NORMAL");
		end
	end

	if reApply == false and reExtract == false and reReforge == false then
		ResetCursor()
	end
end

function ReforgeREButton_OnClick(self, btn)
	SetREUtilButton(nil, nil, not reReforge)
end

function ExtractREButton_OnClick(self, btn)
	SetREUtilButton(nil, not reExtract, nil)
end

function ApplyREButton_OnClick(self, btn)
	SetREUtilButton(not reApply, nil, nil)
end

function ReforgeRELoopButton_OnClick(self, btn)
	reReforgeLoopToggle = not reReforgeLoopToggle
	if reReforgeLoopToggle then
		self.PulseAnim:Play()
		self.flashTexture:Show()
		self:SetButtonState("PUSHED", true)
	else
		self.PulseAnim:Stop()
		self.flashTexture:Hide()
		self:SetButtonState("NORMAL")
	end
end
-- ** List button handling

function EnchantListFrame_OnHide()
	SetREUtilButton(false, false, false)
	EnchantListFrameInspectTooltip:Hide()
	EnchantListReforgeLoopButton.PulseAnim:Stop()
	EnchantListReforgeLoopButton.flashTexture:Hide()
	EnchantListReforgeLoopButton:SetButtonState("NORMAL")
	reReforgeLoopToggle = false
	PlaySound("igCharacterInfoClose");
end

function EnchantListApplyREButton_OnUpdate(self, elapsed)
	local cursorTypes = 
	{
		{"CAST_CURSOR", "CAST_ERROR_CURSOR"}, -- apply
		{"TRAINER_CURSOR", "TRAINER_ERROR_CURSOR"}, -- extract
		{"MINE_CURSOR", "MINE_ERROR_CURSOR"}, -- reforge
	}
	local btnState = {reApply, reExtract, reReforge}

	for idx, state in pairs(btnState) do
		if state == true then
			if GameTooltip and GameTooltip:GetItem() then
				SetCursor(cursorTypes[idx][1]);
			else
				SetCursor(cursorTypes[idx][2]);
			end
		end
	end
end

-- ** Enchant Application / Extraction

local function GetRESkillId(spellId)
	local skillId = spellId

	if CollectionsFrame.EnchantList[spellId] == nil then
		for id, data in pairs(CollectionsFrame.EnchantList) do
			if data[1][2] == spellId then
				if spellId ~= id then
					-- print("correcting id "..spellId.." -> "..id)
					skillId = id
					break
				end
			end
		end
	end

	return skillId
end

local function EventBypass(state)
	local ASC_EVENT = "COMMENTATOR_SKIRMISH_QUEUE_REQUEST"
	if state == true then
		AscensionUI.MysticEnchant:UnregisterEvent(ASC_EVENT)
	else
		AscensionUI.MysticEnchant:RegisterEvent(ASC_EVENT)
	end
end

local function HandleItemPickup(tarBag, tarSlot, link)
	-- print(tarBag, tarSlot, link)
	if link ~= nil then
		if reApply then
			local offset = FauxScrollFrame_GetOffset(EnchantListListScrollFrame);
			local skillBtn = _G["EnchantListSpellButton"..selectedIdx - offset]
			local reId = GetRESkillId(skillBtn:GetID()) -- spell ID
			local RE = GetREData(reId) 
			-- local data = CollectionsFrame.EnchantList[reId]
			if RE and RE.enchantID > 0 then
				RETBPrint("Applying RE ("..GetSkillLink(skillBtn:GetID()).."|cffffff00) to item "..link)
				PlaySound(13829)
				_RequestSlotReforgeEnchantment(tarBag, tarSlot, RE.enchantID)
				--AIO.Handle("EnchantReRoll", "ReforgeItem_Collection", tarBag, tarSlot, reId)
			else
				RETBPrint("Failed to apply invalid RE: "..reId)
			end
			if reToggle == false then
				SetREUtilButton(false, nil, nil)
			end
			addon:ScheduleTimer("UpdateRETokens", 0.5)
		elseif reExtract then
			local spellId = tonumber(string.match(link, "v4:(%d+)"))
			
			EventBypass(true)
			_RequestSlotReforgeExtraction(tarBag, tarSlot)
			--AIO.Handle("EnchantReRoll", "DisenchantItem", tarBag, tarSlot)
			if reToggle == false then
				SetREUtilButton(nil, false, nil)
			end
			addon:ScheduleTimer("UpdateRETokens", 0.5)
			addon:ScheduleTimer(EventBypass, 2, false)
		elseif reReforge then
			ITEM_BAG = tarBag
			ITEM_SLOT = tarSlot
			_RequestSlotReforgeEnchantment(tarBag, tarSlot)
			--DEFAULT_CHAT_FRAME:AddMessage(format("Reforging %s %s", ITEM_BAG, ITEM_SLOT))
			--AIO.Handle("EnchantReRoll", "ReforgeItem_Prep", tarBag, tarSlot)
			if reToggle == false then
				SetREUtilButton(nil, nil, false)
			end
			addon:ScheduleTimer("UpdateRETokens", 2.5)
		else
			return
		end

	end
end


local function EnchantList_PickupInventoryItem(slotId)
	if reApply == true or reExtract == true or reReforge == true then
		-- Ascension uses custom Bag / slotIDs to send both inventory and bag items
		local tarSlot = slotId
		local tarBag = 255
		local link = GetInventoryItemLinkWithRE("player",slotId)
		ClearCursor()
		HandleItemPickup(tarBag, tarSlot, link)
	else
		--oldPickupInventory(slotId)
	end
end

local function EnchantList_PickupContainerItem(bagId, slotId)
	if reApply == true or reExtract == true or reReforge == true then
		local tarSlot = 0
		local tarBag = 0
		if bagId == 0 then
			tarBag = 255
			tarSlot = slotId + 22
		else
			tarBag = bagId + 18
			tarSlot = slotId - 1
		end

		local link = GetContainerItemLinkWithRE(bagId, slotId)
		ClearCursor()
		HandleItemPickup(tarBag, tarSlot, link)
	else
		--oldPickupContainer(bagId, slotId)
	end
	
end


function EnchantListSkillButton_OnClick(self, btn)
	-- addon:Print("clicked "..self:GetID())
	if ( btn == "LeftButton" ) then
		local offset = FauxScrollFrame_GetOffset(EnchantListListScrollFrame);
		-- get button id
		local prefix_len = string.len("EnchantListSpellButton")
		local id = string.sub(self:GetName(), prefix_len + 1, prefix_len + 1)
		-- print(id, offset, prefix_len, self:GetName())
		EnchantListFrame_SetSelection(tonumber(id) + offset);
		EnchantListFrame_Update();
	end
end

-- FIXME: this is completely deprecated
function GetSkillLink(entry)
	local colors = {"|cffff8000","|cff1eff00","|cff0070dd","|cffa335ee","|cffff8000"}
	local name, rank, icon = GetSpellInfo(entry)
    local rank_str = string.match(rank, "(%d+)")
		
	local link = ""
	if rank_str then
		link = colors[tonumber(rank_str)] .. "|Hspell:" .. entry .. "|h[" .. name .. "]|h|r"
	end
	return link
end

function EnchantListFrame_CreateSkillButtons()
	
	local num = 8
	local btnPrefix = "EnchantListSpellButton"

	for i=1,num do

		local skillButton = CreateFrame("Button", btnPrefix..i, EnchantListFrame, "EnchantListSkillButtonTemplate")
		if i == 1 then
			skillButton:SetPoint("TOPLEFT", "EnchantListFrame", "TOPLEFT", 22, -96)
		else
			skillButton:SetPoint("TOPLEFT", btnPrefix..(i-1), "BOTTOMLEFT")
		end

		skillButton:Hide()
	end
end

local reforgeLoopStartTime = 0
local REFORGE_RETRY_DELAY = 0.1 -- seconds

function ReforgeLoop()
	-- check item_bag item_slot ?
	local spellName = UnitCastingInfo("player")
	local delta = (GetTime() - reforgeLoopStartTime)

	if not spellName or spellName ~= "Enchanting" then
		if delta > 2.0 then
			RETBPrint("Failed to trigger reforge loop. Are you lagging?")
		else
			--addon:Print("Retrying reforging. Delta: "..delta)
			_RequestSlotReforgeEnchantment(ITEM_BAG, ITEM_SLOT)
			addon:ScheduleTimer(ReforgeLoop, REFORGE_RETRY_DELAY)
		end
	else
		--addon:Print("Loop successful. Delta: "..delta)
	end
end

function EnchantListFrame_OnEvent(self, event, msg, sender, ...)
	if ( event == "UNIT_PORTRAIT_UPDATE" ) then
		--DEFAULT_CHAT_FRAME:AddMessage("UNIT_PORTRAIT_UPDATE "..msg)
		--if msg ~= nil and sender ~= nil then return end
		if ( msg == playerName or UnitName(msg) == playerName ) then
			
			--print("setting texture for "..playerName)
			SetPortraitTexture(EnchantListFramePortrait, playerName);
			
			local tex = EnchantListFramePortrait:GetTexture()
			if tex == nil or tex == "" then
				SetPortraitToTexture(EnchantListFramePortrait, "Interface\\LFGFrame\\UI-LFG-PORTRAIT")
			end
		end
	elseif event == "COMMENTATOR_SKIRMISH_QUEUE_REQUEST" and
			msg == "ASCENSION_REFORGE_ENCHANT_RESULT" then
				--DEFAULT_CHAT_FRAME:AddMessage("Got reforge result")
		-- TODO: whitelist, stop on quality, loop through bags etc.
		--local enchantID = select(1, ...)
		addon:UpdateRETokens()
		--RE = GetREData(enchantID)
		if reReforgeLoopToggle == true then
			--if RE.quality ~= 5 then
			--DEFAULT_CHAT_FRAME:AddMessage(format("Looping %s %s", ITEM_BAG, ITEM_SLOT))
				-- addon:ScheduleTimer(_RequestSlotReforgeEnchantment, 0.6, ITEM_BAG, ITEM_SLOT) -- todo: find a way to hook spell completion
				reforgeLoopStartTime = GetTime()
				addon:ScheduleTimer(ReforgeLoop, 0.6)
			--_RequestSlotReforgeEnchantment(tarBag, tarSlot)
			--else
			--	PlaySound("LFG_RoleCheck")
			--end
		end
	end
end


function EnchantListQualityDropDown_OnLoad(self)
	local info = UIDropDownMenu_CreateInfo()
	-- addon:Print("OnLoad")
	UIDropDownMenu_Initialize(self, EnchantListQualityDropDown_Initialize);
end

local filters = {"Any","|cff1eff00Uncommon","|cff0070ddRare","|cffa335eeEpic","|cffff8000Legendary"}
EnchantQualityIdx = 1
	
function EnchantListQualityDropDownBtn_OnClick(self, arg1, arg2, checked)
	-- print("onclick id: "..self:GetID())
	local id = self:GetID()
	UIDropDownMenu_SetSelectedID(EnchantListQualityDropDown, id);
	EnchantListQualityDropDown.selected = filters[id]
	EnchantQualityIdx = id
	-- apply filter
	assert (id >= 1 and id <= 5)
	RESpellList_filtered = RESpellList_data[id]
	-- update frame
	FauxScrollFrame_SetOffset(EnchantListListScrollFrame, 0)
	if #RESpellList_filtered > 0 then
		EnchantListFrame_SetSelection(1)
	end
	EnchantListApplyFilter()
end

function EnchantListQualityDropDown_Initialize()
	local info = UIDropDownMenu_CreateInfo()
	for i, text in pairs(filters) do
		info.text = text
		info.checked = EnchantQualityIdx == i
		info.func = EnchantListQualityDropDownBtn_OnClick

		UIDropDownMenu_AddButton(info)
	end
	
	UIDropDownMenu_SetText(EnchantListQualityDropDown, filters[EnchantQualityIdx])
	UIDropDownMenu_SetSelectedID(EnchantListQualityDropDown, EnchantQualityIdx);
end


function EnchantListFrame_SetREList(name, newList)
	playerName = name
	-- sort by quality
	knownList= {}
	for i=1,5 do knownList[i] = {} end
	sum = 0

	for id, entry in pairs(newList) do
		RE =GetREData(entry)
        if RE and RE.enchantID > 0 then
			--addon:Print("adding RE:"..RE.quality.." "..RE.spellName)
			table.insert(knownList[RE.quality], {RE.spellID, RE.spellName})
			sum = sum + 1
			--addon:Print("adding RE: "..RE.spellName)
		else
			addon:Print("no data for RE: "..entry)
		end

		--[[local spellName, rank, icon = GetSpellInfo(entry)
		local rank_str = string.match(rank, "(%d+)")
		if rank_str then
			local rank_num = tonumber(rank_str)
			assert(rank_num > 1 and rank_num <= 5)
			-- print(entry, spellName)
			table.insert(knownList[rank_num], {entry, spellName} )
		else
			addon:Print("Invalid Rank data for spell "..rank)
		end]]--
	end

	-- sorted list stored in first element
	for i=2,5 do
		for idx, data in pairs(knownList[i]) do
			table.insert(knownList[1], {data[1], data[2], i})
		end
	end

	RESpellList_data = knownList
end


local floor = math.floor 
local tostring = tostring
local table_insert = table.insert

-- https://github.com/rayaman/bin/blob/master/base91.lua


local function decimalToBinary(num)
	local base = 2
	local bits = 8 

	local final = ""
	while num > 0 do
		final = "" ..  (num % base ) .. final
		num = floor(num / base)
	end

	local l = final:len()
	if l == 0 then 
		final = "0"..final 
	end

	while final:len()%8 ~=0 do 
		final = "0"..final 
	end 

	return final
end


local function binaryToDecimal(bin)
	local base = 2 

	local l = bin:len()
	local final = 0

	for i=l,1,-1 do 
		local digit = bin:sub(i,i)
		local val = digit * base^(l-i)
		final = final + val
	end 
	return final 
end 

function RETBPrint(message)
	print(format ("|cffffff00%s%s|r", addonPrefix, message))
end

function addon:SlashCmdCb(input)
	if input == "" then
		RETBPrint("Available Commands:")
		RETBPrint("|cffff8000/re show|r - Show REcollection: Current character")
		RETBPrint("|cffff8000/re show all|r - All Ascension REs")
		RETBPrint("|cffff8000/re show <Name>|r - Guild member or Alt on the same account")
		RETBPrint("|cffff8000/re search <searchItem>|r - Search for a RE by name/description")
		RETBPrint("|cffff8000/re link|r - Create a link to your character's RE collection. Expires after "..linkExpirationThr.." seconds.")
		return
	end

	if string.sub(input, 1, 4) == "link" then
		RETBPrint(RETBGetNewLink())
	elseif string.sub(input, 1, 6) == "search" then
		local word = input:match("search (.+)") 
		if word == nil then word = "" end
		local AllList = {}
		for enchantID, RE in pairs(AscensionUI.REList) do
			if RE.enchantID > 0 then
				table.insert(AllList, RE.spellID) 
			end
		end
		
		EnchantListFrame_SetREList("", AllList)
		EnchantListFrame_Show()
		EnchantListFrameEditBox:SetText(word)
		EnchantListFilter_OnTextChanged(EnchantListFrameEditBox, word)
		EnchantListFrameEditBox:ClearFocus()
	elseif string.sub(input, 1, 4) == "show" then
		local word = input:match("show (%a+)")
		if word ~= nil and word == "all" then
			local AllList = {}
			for enchantID, RE in pairs(AscensionUI.REList) do
				if RE.enchantID > 0 then
					table.insert(AllList, RE.spellID) 
				end
			end
			
			if #AllList == 0 then RETBPrint("Not initialized yet.") return end
			EnchantListFrame_SetREList("", AllList)
			EnchantListFrame_Show()
		elseif word ~=nil then
			local typeStr = "(Alt)"
			charData = DataStore:GetCharacterREs(word)
			if not charData or type(charData) ~= "table" or #charData == 0 then
				--RETBPrint("No alt with name "..word.." found.")
				charData = DataStore:GetGuildieREs(word)
				typeStr = "(Guild)"
			end
			if charData ~= nil and type(charData) == "table" and #charData > 0 then
				spellids = {}
				for _, enchantID in pairs(charData) do
					RE = GetREData(enchantID)
					if RE.enchantID > 0 then
						table.insert(spellids, RE.spellID)
					else
						RETBPrint("Character "..word.." has broken enchant"..enchantID)
					end
				end
				EnchantListFrame_SetREList(word, spellids)
				EnchantListFrame_Show()
			else
				addon:Print("No valid data for character: "..word)
			end
		else
			local KnownList = {}
			for id, _ in pairs(KnownREs[1]) do
				table.insert(KnownList, id)
			end

			
			if #KnownList == 0 then RETBPrint("No known enchants.") return end
			EnchantListFrame_SetREList(UnitName("player"), KnownList)
			EnchantListFrame_Show()
		end
	end
	
end

--- Encode known string + deflate
function EncodeKnownEnchants()
	local encodedStr = ""
	RESpellList_indexed = {} -- todo init elsewhere (after receiving known)

	-- TODO: check if known enchants are available

	--encode state string
	-- todo:change this to use enchantID
	knownStr = ""
	local cnt = 0
	for id, _ in pairs(RESpellList) do -- from REToolbox
		table.insert(RESpellList_indexed, id)
		RE = GetREData(id)
		knownStr = knownStr .. ( KnownREs[1][RE.enchantID] and "1" or "0")
		if (KnownREs[1][RE.enchantID]) then
			cnt = cnt + 1
		end
	end
	--print("total REs: "..cnt, #RESpellList_indexed)
	
	if (string.len(knownStr) % 8 ~=0) then
		local additional = 8-(string.len(knownStr)%8)
		for i = 1, additional do
			knownStr = knownStr .. "0"
		end
	end 
	-- compress state string

	knownCharStr = ""
	for i=0, math.ceil(string.len(knownStr) / 8) do
		
		local idx = math.max(i * 8) + 1
		local lastIdx = idx + 7
		if lastIdx > #knownStr then lastIdx = #knownStr print ("last index greater than str by "..(lastIdx - knownStr)) end
		local sub_8bytes = string.sub(knownStr, idx, lastIdx)
		local decimal = binaryToDecimal(sub_8bytes)
		-- table.insert(knownTable, decimal)
		-- print(sub_8bytes, decimal)
		knownCharStr = knownCharStr .. string.char(decimal)
		if lastIdx >= #knownStr then
		break
		end
	end

	-- encode data
	compress_deflate = LibDeflate:CompressDeflate(knownCharStr, {level = 9})
	encodedStr = LibDeflate:EncodeForPrint(compress_deflate)
	
	--print("size: ", string.len(encodedStr), string.len(knownStr))
	return encodedStr
end

function DecodeKnownEnchants(message)
	local decodedData = {}
	if (#RESpellList_indexed == 0) then
		RESpellList_indexed = {}
		for id, _ in pairs(RESpellList) do -- from REToolbox
			table.insert(RESpellList_indexed, id)
		end
	end

	--addon:Print("Decoding")
	-- Decode for wow
	local data_decoded_WoW_addon = LibDeflate:DecodeForPrint(message)
	inflated = LibDeflate:DecompressDeflate(data_decoded_WoW_addon)

	local	combined = ""
	for i=1, string.len(inflated) do 
		local char = inflated:sub(i,i)
		local byte = char:byte()
		local bin = decimalToBinary(byte)
		combined = combined..bin
	end 
	-- END REVERSE STR TO BITS
	
	--addon:Print("decoding done")
	--print(string.len(message), string.len(knownStr))
	if false then
		-- print(string.len(combined), string.len(knownStr))

		for i = 1, string.len(combined) do
			if not combined[i] == knownStr[i] then
				print("Mismatch at index "..i)
			end
		end
	end

	--addon:Print("decoded data size")
	--print(string.len(message), #RESpellList_indexed)
	local sum = 0
	for idx, id in pairs(RESpellList_indexed) do
		if combined:sub(idx,idx) == "1" then
			RE = GetREData(RESpellList_indexed[idx])
			table.insert(decodedData, RE.spellID)
		end
	end
	--print("total REs: "..#decodedData, #RESpellList_indexed)

	return decodedData
end

function GetVersionHexString()
	local version = GetAddOnMetadata("REToolbox", "Version")
	-- local lastCompatibleVersion = format("%02x%02x", 0, 5) -- TODO: Move this to top
	local major, minor, patch = string.match(version, "(%d+)%.(%d+)%.(%d+)")
	return format("aa%02x%02x%02x-%s", tonumber(major), tonumber(minor), tonumber(patch), LAST_SUPPORTED_VER)
end

function ParseVersionHexString(version)
	-- aa is stripped before this function
	versionData = {}
	for item in string.gmatch(version, "%x%x") do 
		table.insert(versionData, tonumber(item, 16))
		--print(#versionData, tonumber(item, 16))
	end

	assert(#versionData == 5)
	return versionData
end

--- Generates random UUID with length of 36. See https://gist.github.com/jrus/3197011
function GenerateLinkUUID()
	-- math.randomseed( time() ) -- TODO: Is seed needed?
	-- TODO: Version check
	-- local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
	local template = GetVersionHexString().."-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

function CheckUUIDVersion(uuid)
	if #uuid ~= 36 then
		RETBPrint("Malformed link UUID, length: "..#uuid)
		return false
	end

	local valid = string.sub(uuid, 1, 2) == "aa"

	if valid == true then
		local localVersion = GetAddOnMetadata("REToolbox", "Version")
		local parsedVersion = ParseVersionHexString(string.sub(uuid, 3, 13))
		local major, minor, patch = string.match(localVersion, "(%d+)%.(%d+)%.(%d+)")

		if tonumber(major) < parsedVersion[1] then
			RETBPrint(format("User has a newer REToolbox major version: (%s) vs. yours: (%s). Latest version can be found at https://github.com/Nihilianth/REToolbox", major, parsedVersion[1]))
			return false
		end
		local senderVersion = format("%s.%s.%s", parsedVersion[1], parsedVersion[2], parsedVersion[3])

		if tonumber(minor) < parsedVersion[4] or tonumber(patch) < parsedVersion[5] then
			RETBPrint(format("Update REToolbox to view this link. Sender: version (%s) You: (%s). Latest version can be found at https://github.com/Nihilianth/REToolbox", senderVersion, localVersion))
			return false
		end

		if LAST_SUPPORTED_MINOR > parsedVersion[2] or LAST_SUPPORTED_PATCH > parsedVersion[3] then
			RETBPrint(format("Player is using an incompatible (old) version of REToolbox. Sender: version (%s) You: (%s)", senderVersion, localVersion))
			return false
		end

		if tonumber(minor) < parsedVersion[2] or tonumber(patch) < parsedVersion[3] then
			RETBPrint(format("Player is using a newer version or REToolbox (%s). Consider updating at https://github.com/Nihilianth/REToolbox", senderVersion))
		end
	else
		RETBPrint("Link from an outdated version")
		return false
	end

	return true
end

-- contains a list of active chat links (uuid : creationTime)
local activeLinkData = {}

--- Creates a new link with random uuid.
function RETBGetNewLink()
	local uuid = GenerateLinkUUID()
	local curTime = time()
	local link = ""
	if uuid and curTime then 
		link = format("|cffabd473|Hretbl:%s:%s|h[Mystic Enchanting (REToolbox)]|h|r", uuid, UnitName("player"))
		activeLinkData[uuid] = curTime
	end
	return link
end

-- Remove links that surpass the expiration time threshold. See linkExpirationThr
function ClearExpiredLinks()
	local newActive = {}
	for uuid, curTime in pairs(activeLinkData) do
		if time() - curTime < linkExpirationThr then
			newActive[uuid] = curTime
		else
			-- print ("Skipping expired link")
		end
	end

	activeLinkData = newActive
end
--- Opens chat frame and inserts a chat link
---@param message format string containing "%s"  
function RETBLinkPrint(message)
	ClearExpiredLinks()
	local editBox = DEFAULT_CHAT_FRAME.editBox
	ChatEdit_ActivateChat(editBox)
	local link = RETBGetNewLink()
	
	editBox:SetText(editBox:GetText()..format(message, link))
end


function addon:OnCommReceived(prefix, message, dist, sender)
	if prefix == "RETB_ENCH_REQ" then
		ClearExpiredLinks()
		-- checkGUID
		-- todo: cache last RE data im compressed fmt
		RETBPrint("Request from |cffff7c0a"..sender.."|r")
		if string.len(message) ~= 36 or activeLinkData[message] == nil then
			addon:Print("Expired link request from "..sender..". Consider using a macro for world channel announcements.")
			return
		end
		local encodedStr = EncodeKnownEnchants()
		-- todo: cache
		--local known_serialized = addon:Serialize(KnownREs)
		--compress_deflate = LibDeflate:CompressDeflate(known_serialized, {level = 9})
		--data_wow_transmit = LibDeflate:EncodeForPrint(compress_deflate)

		addon:SendCommMessage("RETB_ENCH_RESP", encodedStr, "WHISPER", sender)
	end

	if prefix == "RETB_ENCH_RESP" then
		-- addon:Print("Received Enchant List from "..sender)
		enchantList = DecodeKnownEnchants(message)

		if #enchantList > 0 then
			RETBPrint("Received "..#enchantList.." REs from |cffff7c0a"..sender.."|r.")
			EnchantListFrame_SetREList(sender, enchantList)
			EnchantListFrame_Show()
		else
			RETBPrint("|cffff7c0a"..sender.."|r |cffffff00doesn't know any REs yet.")
		end
	end		
end

addon:RegisterComm("RETB_ENCH_REQ")
addon:RegisterComm("RETB_ENCH_RESP")
addon:RegisterChatCommand("re", "SlashCmdCb")
-- addon:RegisterChatCommand("reshow", "ShowSlashCmdCb")


local a = ChatFrame_OnHyperlinkShow
function ChatFrame_OnHyperlinkShow(e, l, o, n)

	local e, t = l:match("(%a+):(.+)")
	if (e == "retbl") then
		if (IsModifiedClick("CHATLINK")) then
			local link = "|cffabd473|Hretbl:" .. t .. "|h[Mystic Enchanting (REToolbox)]|h|r"
			ChatEdit_InsertLink(link)
			return
		end
		local uuid, name = strsplit(":", t)

		if CheckUUIDVersion(uuid) == true then
			if name == UnitName("player") then
				local KnownList = {}
				for id, _ in pairs(KnownREs[1]) do
					table.insert(KnownList, id)
				end

				EnchantListFrame_SetREList(UnitName("player"), KnownList)
				EnchantListFrame_Show()
			else
				addon:SendCommMessage("RETB_ENCH_REQ", uuid, "WHISPER", name)
				RETBPrint("Requesting RE List from: |cffff7c0a"..name.."|r")
			end
		end
		
    else
        a(self, l, o, n)
    end
end
function EnchantListDetailScrollChildFrame_OnLoad()
	
end

function addon:OnInitialize()
	for i=1,5 do RESpellList_data[i] = {} end
end

function addon:OnEnable()
	hooksecurefunc("PickupContainerItem", EnchantList_PickupContainerItem)
	hooksecurefunc("PickupInventoryItem", EnchantList_PickupInventoryItem)
end
