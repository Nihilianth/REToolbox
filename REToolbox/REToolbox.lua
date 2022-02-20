if not DataStore_AscensionRE then return end

local addonName = "REToolbox"
local initialized = false

local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0",
                                               "AceEvent-3.0", "AceTimer-3.0")

RESpellList = {}
RESpellDescription = {}
REDescriptionForSpell = {}
RESpellNames = {}
local REByRank = {}
local NumKnownREs = 0
KnownREs = {}
-- Addon.EnchantTooltipTable[entry] = id


local function ShowLoadedInfo()
    addon:Print("REToolbox Version "..GetAddOnMetadata(addonName, "Version").. ". Updates at http://github.com/Nihilianth/REToolbox")
    local colorData = AscensionUI.MysticEnchant.EnchantQualitySettings
    addon:Print("Loaded known REs: "..NumKnownREs.." ("..colorData[2][1]..#KnownREs[2]..
                                                                "|r "..colorData[3][1]..#KnownREs[3]..
                                                                "|r "..colorData[4][1]..#KnownREs[4]..
                                                                "|r "..colorData[5][1]..#KnownREs[5].."|r)");
end

-- *** Tooltip hooks ***
-- Helper functions
local function GetEnchantLinkColored(entry)
    local name, rank, o = GetSpellInfo(entry)
    --local c = GetEnchantColor(rank)
    --local c = AscensionUI.MysticEnchant.EnchantQualitySettings[re.quality][1]
    local c = ""
    RE = GetREData(entry)
    if RE and RE.enchantID > 0 then
        c = AscensionUI.MysticEnchant.EnchantQualitySettings[RE.quality][1]
    end
    local link = c .. "|Hspell:" .. RE.spellID .. "|h[" .. name .. "]|h|r"
    if (link) then
        return link
    else
        return "<Unknown Enchant>"
    end
end

local charColors = {"cff00FF7F","cffADFF2F","cffffffff", "cffffffff"}
local charLineLabels = { "|cffFF0000Mystic Enchant:|r", "Alts (%u):", "Guild (%u):", "Shared (%u):"}

function HandleTooltipSet(ref, entry) 
    if not ref then print("ref invalid") end
    if not RESpellList[entry] or RESpellList[entry] ~= true then return end
    if KnownREs[1] == nil then return end -- not yet initialized

    RE =GetREData(entry)
    if not RE or RE.enchantID == 0 then
        addon:Print("No RE found for entry: "..entry)
        return 
    else
        -- Color the name in tooltip
        if ref:GetObjectType() == "GameTooltip" and select(3 , ref:GetSpell()) == RE.spellID then
            local name, rank, o = GetSpellInfo(RE.spellID)
            --local c = GetEnchantColor(rank)
            local c = AscensionUI.MysticEnchant.EnchantQualitySettings[RE.quality][1]
            _G[ref:GetName() .. "TextLeft" .. 1]:SetText(format("%s%s|r", c, name))
        end

        local charNamesWithColor = {} -- {1 - character, 2 - alts, 3 - guild (online first)}
        local chars = DataStore:GetCharactersWithRE(RE.enchantID)
        local guildies = DataStore:GetGuildiesWithRE(RE.enchantID)
        -- local shared = DataStore:GetSharedWithRE(entry)
        local maxDisplayCnt = 4 -- TODO:Option

        --addon:Print(format("TT for entry: %s -> re id: %s", RE.spellID, RE.enchantID))
        
        -- player
        charNamesWithColor[1] = {}
        local line1 = _G[ref:GetName().."TextLeft1"]
        local texture = ""
        if KnownREs[1][RE.enchantID] ~= nil then
            texture = CreateTextureMarkup("Interface\\Icons\\ability_felarakkoa_feldetonation_green", 64, 64, 16, 16, 0, 1, 0, 1)
            table.insert(charNamesWithColor[1], "|cff1eff00Known|r")
        else
            texture = CreateTextureMarkup("Interface\\Icons\\ability_felarakkoa_feldetonation_red", 64, 64, 16, 16, 0, 1, 0, 1)
            table.insert(charNamesWithColor[1], "|cffFF0000Unknown|r")
        end
        if texture ~= nil and line1:GetText() ~= nil then 
            line1:SetText(format("%s  %s", line1:GetText(), texture))
        end
    
        -- alts
        charNamesWithColor[2] = {}
        for id, name in pairs(chars) do
            if maxDisplayCnt == 0 then break end
            if name ~= UnitName("player") then
                table.insert(charNamesWithColor[2], name)
                maxDisplayCnt = maxDisplayCnt - 1
            end
        end

        -- guild
        charNamesWithColor[3] = {}
        local offlineList = {}
        for id, name in pairs(guildies) do
            if maxDisplayCnt == 0 then break end
            local online = select(9, DataStore:GetGuildMemberInfo(name))
            local _, _, _, _, _, _, _, _, online, status, _ = DataStore:GetGuildMemberInfo(name)
            --addon:Print("checking offline")
            if online and online == 1 then 
                table.insert(charNamesWithColor[3], name)
                maxDisplayCnt = maxDisplayCnt - 1
            else
                table.insert(offlineList, name)
            end
        end

        -- offline guild members
        for id, name in pairs(offlineList) do
            if maxDisplayCnt == 0 then break end
            table.insert(charNamesWithColor[3], format("|%s%s|r", "cff888888", name))
            maxDisplayCnt = maxDisplayCnt - 1
        end

        -- charNamesWithColor = demoSet
        for id, set in pairs(charNamesWithColor) do
            for set_id, name in pairs(set) do
                if set_id == 1 then
                    ref:AddDoubleLine(format(charLineLabels[id], #set), format("|%s%s|r", charColors[id], name))
                else
                    ref:AddDoubleLine(" ", format("|%s%s|r", charColors[id], name))
                end
            end
        end
        ref:Show()
    end
end

local function EnumerateTooltipLines_helper(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region:GetObjectType() == "FontString" then
            local text = region:GetText() -- string or nil
            if text then 
                print(i.." : "..text)
            end
        elseif region and region:GetObjectType() == "Texture" then
            local tex = region:GetTexture()
            if tex then 
                print(i.." texture "..tex)
            end
        end

    end
end

local function attachItemTooltip(self)
    for l = 1, self:NumLines() do
        local ttLine = _G[self:GetName() .. "TextLeft" .. l]:GetText()
        if ttLine then 
            if (ttLine) and (string.len(ttLine) > 40) then
                if not string.find(ttLine, "^Equip:") and string.find(ttLine, "Equip:") then
                    -- Strings found in the chat links are already colored. Strip before processing
                    -- Handling in SetItemRef is possible but breaks the displayed view
                    -- TODO: Check how this affects performance
                    
                    local colStart = (ttLine:find("|c"))
                    local colEnd = (ttLine:find("|r"))
                    -- "Requires Level" and the RE description are in the same tooltip line
                    if colStart and colEnd then
                        ttLine = ttLine:sub(1, colEnd + 1)
                        local colorStr = ttLine:sub(colStart, 10)
                        ttLine = ttLine:gsub(colorStr, "")

                        ttLine = ttLine:gsub("|r", "")
                        ttLine = ttLine:gsub("\r", "")
                    end
                end

                if string.find(ttLine, "^Equip:")  then
                    
                    -- FIXME: this is broken af
                    local re = GetEnchantFromTooltipLine(ttLine)
                    local descString = string.sub(ttLine, 8)
                    local descEntry = 0
                    
                    if re and re.enchantID > 0 then
                        --addon:Print("Ascension RE: "..re.spellID)
                        descEntry = re.spellID -- TODO: change this and processing to enchant ID
                    else
                        spellID = RESpellDescription[descString]

                        if not spellID then
                            --addon:Print("Failed to get description ")
                            --addon:Print(descString)
                            -- Ascension sometimes shows outdated RE descriptions in item tooltips
                            -- Try to parse Enchant name instead
                            local spellName
                            local descStart = descString:find("( )(\-)( )") -- TODO: Verify pattern for " - "
                            if descStart then
                                spellName = descString:sub(1, descStart - 1)
                            end
                            --addon:Print(spellName)
                            if spellName then spellID = RESpellNames[spellName] end
                            re = GetREData(spellID)
                            if re and re.enchantID > 0 then
                                descEntry = re.spellID -- TODO: change this and processing to enchant ID
                            end
                        end
                    end


                    if (descEntry ~= 0) then
                        HandleTooltipSet(self, descEntry)
                        return
                    else   
                        -- self:AddDoubleLine("|cffFF0000Mystic Enchant:|r", "invalid description")
                        -- self:Show()
                        return
                        -- print("No Entry for description")
                    end
                end
            end
        end
    end
end

-- hook spell icon tooltip
GameTooltip:HookScript("OnTooltipSetSpell", function(self)
    if not initialized then return end
    --addon:Print("OnTooltipSetSpell")
    local entry = select(3 , self:GetSpell())
    --print(select(3, self:GetSpell()))
    HandleTooltipSet(self, entry)
end)

-- hook spell info from chat links
hooksecurefunc("SetItemRef", function(link, ...)
    if not initialized or IsModifierKeyDown () then return end
    -- print(IsModifiedClick("CHATLINK"))
    --addon:Print("SetItemRef")
    local entry = tonumber(link:match("spell:(%d+)"))
    -- if not entry then entry = tonumber(link:match("v4:(%d+)")) end
    --print(select(3, self:GetSpell()))
    if entry then
        HandleTooltipSet(ItemRefTooltip, entry)
    end
end)

-- *** End Tooltip hooks ***

-- *** DataStore_AscensionRE processing ***

function addon:ASC_COLLECTION_UPDATE(event, knownList, init)
    --addon:Print("Collection Update received "..#knownList)
    KnownREs = {}
    for n = 1, 5 do KnownREs[n] = {} end
    
    if init == false then
        REByRank = {}
        for n = 1, 5 do REByRank[n] = {} end
    end
    
    -- TODO: check for duplicates?

    for _, enchantID in pairs(knownList) do
        RE = GetREData(enchantID)
        if RE and RE.enchantID > 0 then
            KnownREs[1][RE.enchantID] = true
            table.insert(KnownREs[RE.quality], RE.enchantID)
            NumKnownREs = NumKnownREs + 1
        end
    end
    
    --addon:Print("Update: Got "..NumKnownREs)

    if init == false then
        local numtotalREs = 0
        for enchantID, RE in pairs(AscensionUI.REList) do
            if RE.enchantID > 0 then
                REByRank[1][RE.enchantID] = true
                numtotalREs = numtotalREs + 1
                table.insert(REByRank[RE.quality], RE.enchantID)
                RESpellList[RE.spellID] = true
                RESpellNames[RE.spellName] = RE.spellID
                desc = C_Spell:GetSpellDescription(RE.spellID)
                RESpellDescription[RE.spellName.." - "..desc] = entry
            end
        end
        
        --addon:Print("init: Got "..numtotalREs)
        ShowLoadedInfo()
    end

    initialized = true
end

function addon:ASC_COLLECTION_RE_UNLOCKED(event, entry)
    --local link = GetEnchantLinkColored(entry)
    --addon:Print("New Mystic Enchant: "..link..".")
    RE = GetREData(entry)
    if RE and RE.enchantID > 0 then
        local _, _, icon = GetSpellInfo(RE.spellID)
        texture = CreateTextureMarkup(icon, 64, 64, 64, 64, 0, 1, 0, 1)
        local enchantColor = AscensionUI.MysticEnchant.EnchantQualitySettings[RE.quality][1]
        DEFAULT_CHAT_FRAME:AddMessage(format("%s|Hspell:%s|h%s[%s]|r|h RE unlocked!", texture, RE.spellID, enchantColor, RE.spellName))
    end
end

local function InitAscensionData()
    AscRESpellIds = AscensionUI.REListSpellID
    local knownList = {}

    KnownREs = {}
    for n = 1, 5 do KnownREs[n] = {} end
    REByRank = {}
    for n = 1, 5 do REByRank[n] = {} end
    
    for enchantID, RE in pairs(AscensionUI.REList) do
        if RE.enchantID > 0 then
            spellid = RE.spellID

            --addon:Print("parsing enchant "..spellid)
            if (IsReforgeEnchantmentKnown(RE.enchantID)) then
                KnownREs[1][spellid] = true
                table.insert(knownList, spellid)
                table.insert(KnownREs[RE.quality], spellid)
            end       
            RESpellList[spellid] = true
            RESpellNames[RE.spellName] = spellid
            if RE.quality > 5 or RE.quality < 1 then
                addon:Print("quality: "..RE.quality..RE.spellName)
            else
                table.insert(REByRank[RE.quality], spellid)
                desc = C_Spell:GetSpellDescription(spellid)
                RESpellDescription[RE.spellName.." - "..desc] = entry
            end
        else
            addon:Print("skipped "..RE.enchantID)
        end
    end
    --C_Spell:GetSpellDescription(spellID) 
    initialized = true
    NumKnownREs = #knownList
    ShowLoadedInfo()
    
end

-- *** DataStore_AscensionRE processing ***

function addon:OnInitialize()
    addon:RegisterMessage("ASC_COLLECTION_UPDATE")
    --addon:RegisterMessage("ASC_COLLECTION_INIT")
    addon:RegisterMessage("ASC_COLLECTION_RE_UNLOCKED")
end

-- *** Slot Highlighting ***

local SlotButtons = {
    [1] = CharacterHeadSlot,
    [2] = CharacterNeckSlot,
    [3] = CharacterShoulderSlot,
    [15] = CharacterBackSlot,
    [5] = CharacterChestSlot,
    [4] = CharacterShirtSlot,
    [19] = CharacterTabardSlot,
    [9] = CharacterWristSlot,
    [10] = CharacterHandsSlot,
    [6] = CharacterWaistSlot,
    [7] = CharacterLegsSlot,
    [8] = CharacterFeetSlot,
    [11] = CharacterFinger0Slot,
    [12] = CharacterFinger1Slot,
    [13] = CharacterTrinket0Slot,
    [14] = CharacterTrinket1Slot,
    [16] = CharacterMainHandSlot,
    [17] = CharacterSecondaryHandSlot,
    [18] = CharacterRangedSlot
}

function AscCharRE_HighlightSlot(tt, self, slots) 
	for idx, slot in pairs(slots) do
        if SlotButtons[slot] ~= nil then
            SlotButtons[slot]:SetHighlightTexture("Interface\\Buttons\\CheckButtonHilight");            
            SlotButtons[slot]:LockHighlight()
		end
	end
    GameTooltip:SetOwner(tt, "ANCHOR_RIGHT", 0, 0)
    
    GameTooltip:SetHyperlink(GetEnchantLinkColored(tt.Spell))
    GameTooltip:Show()
end

function AscCharRE_RemoveHighlight(tt, self, slots)
	for idx, slot in pairs(slots) do
        if SlotButtons[slot] ~= nil then
		    SlotButtons[slot]:UnlockHighlight()
		end
	end
	GameTooltip:Hide()
end

hooksecurefunc("UpdatePaperDollEnchantList", function()
    local index = 0
    local enchantSlots = AscensionUI.CharacterFrame.Extension.EnchantPanel.Enchants

    for enchantID, count in pairs(AscensionUI.MysticEnchant.EquippedEnchantStacks) do
       index = index + 1
       local enchantSlot = enchantSlots[index]
       local itemSlots = {}
       local RE = GetREData(enchantID)

       for idx = 1, 19 do
        -- M.PaperDoll.Slot4.Slot = "BackSlot"
        -- M.PaperDoll.Slot4.SlotID = 15
        local slot = AscensionUI.MysticEnchant.PaperDoll["Slot"..idx]
        if slot and slot.SlotID ~= nil and slot.enchantID ~= 0 then
            if slot.enchantID == enchantID then
                table.insert(itemSlots, slot.SlotID)
            end
        end
       end

       enchantSlot.Button:SetScript("OnEnter", function(e) AscCharRE_HighlightSlot (e, idx, itemSlots) end)
       enchantSlot.Button:SetScript("OnLeave", function(e) AscCharRE_RemoveHighlight (e, idx, itemSlots) end)

    end
 end);

-- *** End Slot Highlighting ***

hooksecurefunc(StaticPopupDialogs["ASC_BC_SELECT_MAXLEVEL_SELECT2"],"OnAccept",function(self,data)
    local loadCurrent = StaticPopupDialogs["ASC_BC_SELECT_MAXLEVEL_SELECT2"].loadCurrent
    
    if loadCurrent == true then
        for spellId, cnt in pairs(AscensionUI.MysticEnchant.EquippedEnchantStacks) do
            RE = GetREData(spellId) -- not sure if its an enchant ID, anyway..
            HandleEnchantAddToBuildCreator("Hspell:"..RE.spellID)
        end
    end
end);


-- Derived from Ascension UI (LoadBuildFromLink)
-- RERank is #REs
function LoadREsFromLink(link)

    if not(link) then
        link = ""
    end
  
    local REs = {}
  
    local startpos,endpos,REstring

    startpos,endpos,talentstring = string.find(link, ":(%d+e%d+):")
  
    while startpos do
        startpos,endpos,REstring = string.find(link, ":(%d+e%d+):")
        if (startpos) then
          local startrank,endrank,RECntstring = string.find(REstring, "(e%d+)")
          local RE = tonumber(string.sub(REstring, 1, startrank-1))
          local RECnt = tonumber(string.sub(RECntstring, 2, -1))
  
          table.insert(REs, {RE, RECnt})
          link = string.sub(link, 1, startpos-1)..string.sub(link, endpos)
        end
    end
  
    if #REs > 0 then
        return REs
    else
        StaticPopupDialogs["ASC_ERROR"].text = "No proper build data found."
        StaticPopup_Show("ASC_ERROR")
    end
  
    return false
end

-- *** URL IMPORT (HA) ***

-- DecodeBuilderURL("https://ascension.gg/builder/FwRgDGoGwBzALFArMWB2Ya0E5MxMEgExi7FFlFaHwwZQ4qxgYwsExEDMRoXIULtBhIMJIiDFF8vItPizRbYFy5p4TIlAh8YAFxQ54eoTmwm+YLhYFybXfPexIbC60JALzHpGBA20bgCka15JbGMPHCg9AhAYBljQbHAkkBTvUFokiQc9WTl9ITl4f2KiBQs5XwtgGA0wGABTDg0cFuBsZC0oDq6Q2D7kNTA+nDQobBagA?cost_type=1")
-- This requires a new build to be created first. Mb disable the button until it's shown?
function DecodeBuilderURL(url)
    if url==nil or #url == 0 then
      DEFAULT_CHAT_FRAME:AddMessage("invalid URL")
      return
    end

    -- strip unneeded data, decompress
    url = url:gsub("?cost_type=1", "") -- only parameter. if more are introduced, perhaps better to strip all of them
    hash = string.match(url, "ascension.gg/builder/(%S+)")
    decoded = _M.decompressFromBase64(hash)

    -- "<spells,talents>::<REs>"
    local  sp_end, re_start = string.find(decoded, "::")  
    local decoded_sp = string.sub(decoded, 1, sp_end)
    local decoded_re = string.sub(decoded, re_start, -1)
  
    -- Link Parsing
    local spells, talents = LoadBuildFromLink(":"..decoded_sp) -- AscensionUI
    local res = LoadREsFromLink(decoded_re)
  
    -- DEFAULT_CHAT_FRAME:AddMessage("Spells: "..decoded_sp)
    -- DEFAULT_CHAT_FRAME:AddMessage("REs: ".. decoded_re)
    -- print(format("Loaded %s spells, %s talents, %s REs", #spells, #talents, #res))
  
    -- There is no exposed function like HandleEnchantAddToBuildCreator for spells
    -- Hacky way to still load it
    StaticPopup1.wideEditBox:SetText(":"..decoded_sp) -- prefix required for parsing
    StaticPopupDialogs["ASC_LOADBUILDFROMLINK"].wideEditBox = StaticPopup1.wideEditBox
    StaticPopupDialogs["ASC_LOADBUILDFROMLINK"]:OnAccept()

    -- Fill Mystic Enchants
    for _, REData in pairs(res) do
      RE = GetREData(REData[1]) -- not sure if its an enchant ID, anyway..
      HandleEnchantAddToBuildCreator("Hspell:"..RE.spellID)
    end
    
end

StaticPopupDialogs["ASC_LOADBUILDFROMURLLINK"] = {
    text = "Enter build URL",
    button1 = ACCEPT,
    button2 = CANCEL,
    whileDead = 1,
    hasEditBox = 1,
    hasWideEditBox = 1,
    OnAccept = function(self)
        local text = self.wideEditBox:GetText()
        DecodeBuilderURL(text)
    end,
    timeout = 0,
    EditBoxOnEnterPressed = function(self, data)
        local text = self:GetText()
        DecodeBuilderURL(text)
    end,
    EditBoxOnEscapePressed = function (self)
        self:GetParent():Hide();
    end,
    OnHide = function (self)
        self.wideEditBox:SetText("");
    end,
    hideOnEscape = 1
};

function ImportHALink()
    --DEFAULT_CHAT_FRAME:AddMessage("ImportHALink")
    StaticPopup_Show("ASC_LOADBUILDFROMURLLINK")
end

HAimportBtn = CreateFrame("Button","ASCHAImportURLButton", BuildCreator, "UIPanelButtonTemplate")
HAimportBtn:SetPoint("TOPLEFT", 80, -35)
HAimportBtn:SetWidth(100)
HAimportBtn:SetHeight(22)
HAimportBtn:SetText("Import URL")
HAimportBtn:SetScript("OnClick", ImportHALink)
HAimportBtn:Show()

--[[
HAexportBtn = CreateFrame("Button","ASCHAExportURLButton", BuildCreator, "UIPanelButtonTemplate")
HAexportBtn:SetPoint("TOPLEFT", 185, -35)
HAexportBtn:SetWidth(100)
HAexportBtn:SetHeight(22)
HAexportBtn:SetText("Export URL")
HAexportBtn:Show()
]]--

-- *** URL EXPORT (CA) ***

-- QR code generation
-- fixme: qrencode( changed to global in qrencode
--local _, ADDONSELF = ...
--local qrcode = ADDONSELF.qrcode
local qrencode

-- Copypasta from https://github.com/tg123/qrcode-wow/blob/master/core.lua
local BLOCK_SIZE = 8

local function CreateQRTip(qrsize)
    local f = CreateFrame("Frame", nil, UIParent)

    local function CreateBlock(idx)
        local t = CreateFrame("Frame", nil, f)

        t:SetWidth(BLOCK_SIZE)
        t:SetHeight(BLOCK_SIZE)
        t.texture = t:CreateTexture(nil, "OVERLAY")
        t.texture:SetAllPoints(t)

        local x = (idx % qrsize) * BLOCK_SIZE
        local y = (math.floor(idx / qrsize)) * BLOCK_SIZE

        t:SetPoint("TOPLEFT", f, 20 + x, - 20 - y);

        return t
    end


    do
        f:SetFrameStrata("TOOLTIP")
        f:SetWidth(qrsize * BLOCK_SIZE + 40)
        f:SetHeight(qrsize * BLOCK_SIZE + 40)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:SetBackdrop({ 
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileEdge = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },    
        })

        --f:SetBackdropColor(0,0,0)--; <- cant read codes with that
        f:SetBackdropColor(1, 1, 1);

        f:SetPoint("CENTER", 0, 0)
        f:RegisterForDrag("LeftButton") 
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    end

    do
        local b = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        b:SetPoint("TOPRIGHT", f, 0, 0);
    end

    f.boxes = {}

    f.SetBlack = function(idx)
        f.boxes[idx].texture:SetTexture(0, 0, 0)
    end

    f.SetWhite = function(idx)
        f.boxes[idx].texture:SetTexture(1, 1, 1)
    end

    for i = 1, qrsize * qrsize do
        tinsert(f.boxes, CreateBlock(i - 1))
    end

    return f
end
-- Copypasta end

local function MakeQRCode(url)
    -- semi-copypasta (QR generation)
    local ok, tab_or_message = qrcode(url, 1) -- error correction

    if not ok then 
        DEFAULT_CHAT_FRAME:AddMessage("qr generation failed")
    else
        local tab = tab_or_message
        local size = #tab
        --DEFAULT_CHAT_FRAME:AddMessage("QR Generation, size: "..size)
        local f = CreateQRTip(size)
        
        f:Show()

        for x = 1, #tab do
            for y = 1, #tab do

                if tab[x][y] > 0 then
                    f.SetBlack((y - 1) * size + x - 1 + 1)
                else
                    f.SetWhite((y - 1) * size + x - 1 + 1)
                end
            end
        end
    end
end

StaticPopupDialogs["ASC_URL_LINK_EDITBOX"] = {
    text = "Copy this link for further use",
    button1 = ACCEPT,
    button2 = CANCEL,
    button3 = "QR Code",
    whileDead = 1,
    hasEditBox = 1,
    hasWideEditBox = 1,
    hasItemFrame = 1,
    timeout = 0,
    OnAlt = function(self)
        local text = self.wideEditBox:GetText()
        MakeQRCode(text)
        self:Hide();
    end,
    EditBoxOnEnterPressed = function(self, data)
        self:Hide();
    end,
    EditBoxOnEscapePressed = function (self)
        self:GetParent():Hide();
    end,
    OnHide = function (self)
        self.wideEditBox:SetText("");
    end,
    hideOnEscape = 1
};

local function GenerateCALink()
    local re_str = ":"
    local spell_str = ":"
    local talent_str = "" -- parsed together with spells
  
    -- from BC_CLIENT
    -- generate spell string. Split to have spells first (like web export)
    for spellId, _ in pairs(CAO_Known) do
      local TalentId = CAO_Talent_References[spellId]
      local SpellInfo = CAO_Spells[spellId]
  
      if (TalentId) then
          local CurrentRank = CAO_Talent_Ranks[spellId]
          talent_str = talent_str..TalentId.."t"..CurrentRank..":"
      else
        spell_str = spell_str..spellId..":"
      end
    end
  
    -- RE list
    for enchantID, cnt in pairs(AscensionUI.MysticEnchant.EquippedEnchantStacks) do
      re_str = re_str..format("%se%s:", enchantID, cnt)
    end
  
    local compressed = _M.compressToEncodeURIComponent(spell_str..talent_str..re_str)
    local url = "https://ascension.gg/builder/"..compressed
  
    StaticPopupDialogs["ASC_URL_LINK_EDITBOX"].OnShow = function(self) self.wideEditBox:SetText(url); end
    StaticPopup_Show("ASC_URL_LINK_EDITBOX")
end

CAexportBtn = CreateFrame("Button","ASCCAExportURLButton", CA2.CharacterAdvancementMain.Main.ShareButton, "UIPanelButtonTemplate")
CAexportBtn:SetPoint("CENTER", -150, 0)
CAexportBtn:SetWidth(100)
CAexportBtn:SetHeight(22)
CAexportBtn:SetText("Export URL")
CAexportBtn:SetScript("OnClick", GenerateCALink)
CAexportBtn:Show()


function addon:OnEnable() end
function addon:OnDisable() end

GameTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefShoppingTooltip3:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip3:HookScript("OnTooltipSetItem", attachItemTooltip)




