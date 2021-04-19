if not DataStore_AscensionRE then return end

local addonName = "REToolbox"
local initialized = false

local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0",
                                               "AceEvent-3.0")

RESpellList = {}
RESpellDescription = {}
REDescriptionForSpell = {}
RESpellNames = {}
local REByRank = {}
local NumKnownREs = {}
KnownREs = {}

-- Helper functions
local function GetEnchantLinkColored(entry)
    local name, rank, o = GetSpellInfo(entry)
    local c = GetEnchantColor(rank)
    local link = c .. "|Hspell:" .. entry .. "|h[" .. name .. "]|h|r"
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

    -- Color the name in tooltip
    if ref:GetObjectType() == "GameTooltip" and select(3 , ref:GetSpell()) == entry then
        local name, rank, o = GetSpellInfo(entry)
        local c = GetEnchantColor(rank)
        _G[ref:GetName() .. "TextLeft" .. 1]:SetText(format("%s%s|r", c, name))
    end

    local charNamesWithColor = {} -- {1 - character, 2 - alts, 3 - guild (online first)}
    local chars = DataStore:GetCharactersWithRE(entry)
    local guildies = DataStore:GetGuildiesWithRE(entry)
    -- local shared = DataStore:GetSharedWithRE(entry)
    local maxDisplayCnt = 4 -- TODO:Option

    charNamesWithColor[1] = {}
    if KnownREs[1][entry] ~= nil then
        table.insert(charNamesWithColor[1], "|cff1eff00Known|r")
    else
        table.insert(charNamesWithColor[1], "|cffFF0000Unknown|r")
    end
    
    charNamesWithColor[2] = {}
    for id, name in pairs(chars) do
        if maxDisplayCnt == 0 then break end
        if name ~= UnitName("player") then
            table.insert(charNamesWithColor[2], name)
            maxDisplayCnt = maxDisplayCnt - 1
        end
    end

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

local function ShowLoadedInfo()
    addon:Print("You are running a development version of \"REToolbox\", consider updating at http://github.com/Nihilianth/REToolbox")
    addon:Print("Total known Mystic Enchants: "..NumKnownREs.." (|cff1eff00"..#KnownREs[2]..
                                                      "|r |cff0070dd"..#KnownREs[3]..
                                                      "|r |cffa335ee"..#KnownREs[4]..
                                                      "|r |cffff8000"..#KnownREs[5].."|r)")
  end

-- *** Tooltip hooks ***
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
                    
                    local descString = string.sub(ttLine, 8)       
                    local descEntry = RESpellDescription[descString]

                    if not descEntry then
                        -- Ascension sometimes shows outdated RE descriptions in item tooltips
                        -- Try to parse Enchant name instead
                        local spellName
                        local descStart = descString:find("( )(\-)( )") -- TODO: Verify pattern for " - "
                        if descStart then
                            spellName = descString:sub(1, descStart - 1)
                        end
                        if spellName then descEntry = RESpellNames[spellName] end
                    end


                    if (descEntry) then
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

-- *** DataStore_AscensionRE processing ***

function addon:ASC_COLLECTION_UPDATE(event, knownList, init)
    -- addon:Print("Collection Update received " .. #knownList)

    KnownREs = {}
    NumKnownREs = #knownList
    for n = 1, 5 do KnownREs[n] = {} end

    for _, entry in pairs(knownList) do
        local name, rank, icon = GetSpellInfo(entry)
        if not rank or rank == "" then
            addon:Print("Unknown Enchant Id: " .. entry)
        else
            KnownREs[1][entry] = true
            local rank_str = string.match(rank, "(%d+)")
            if tonumber(rank_str) == 1 then addon:Print("Got RE with rank 1 : "..entry) end
            if rank_str and tonumber(rank_str) > 1 then
                
                -- addon:Print(rank.." "..rank_str..":"..entry)
                table.insert(KnownREs[tonumber(rank_str)], entry)
            else
                addon:Print("Could not parse rank for :" .. entry)
            end
        end
    end

    if not init then ShowLoadedInfo() end
end

function addon:ASC_COLLECTION_INIT(event, spellList)
    -- addon:Print("Collection init received")
    -- RESpellList = spellList
    REByRank = {}
    for n = 1, 5 do REByRank[n] = {} end

    
  local tooltip = CreateFrame("GameTooltip", "DescParseTooltip", UIParent, "GameTooltipTemplate")

    for _, entry in pairs(spellList) do
        local name, rank, icon = GetSpellInfo(entry)
        if not rank or rank == "" then
            addon:Print("Unknown Enchant Id: " .. entry)
        else
            -- Extract descriptions for item tooltips

            tooltip:SetOwner(WorldFrame, "ACHOR_NONE")
            tooltip:SetHyperlink("spell:"..entry)
            local desc =_G[tooltip:GetName().."TextLeft"..tooltip:NumLines()]:GetText()
            
            desc = desc:gsub("\r", "") -- required to parse multi-line descriptions
            if desc then 
                RESpellDescription[name.." - "..desc] = entry
                REDescriptionForSpell[entry] = desc
                RESpellNames[name] = entry

            else
                addon:Print("No description for spell "..entry.. " : "..name)
            end

            -- Set up spell list

            local rank_str = string.match(rank, "(%d+)")
            if rank_str then
                -- addon:Print(rank.." "..rank_str..":"..entry)
                table.insert(REByRank[tonumber(rank_str)], entry)
                RESpellList[entry] = true
            else
                addon:Print("Could not parse rank for :" .. entry)
            end
        end
    end
    initialized = true
    tooltip:Hide()
end

function addon:ASC_COLLECTION_RE_UNLOCKED(event, entry)
    local link = GetEnchantLinkColored(entry)
    addon:Print("New Mystic Enchant: "..link..".")
end

function addon:OnInitialize()
    addon:RegisterMessage("ASC_COLLECTION_UPDATE")
    addon:RegisterMessage("ASC_COLLECTION_INIT")
    addon:RegisterMessage("ASC_COLLECTION_RE_UNLOCKED")
    addon:RegisterEvent("CHAT_MSG_ADDON")
end


local slotNames = {
    [0] =  "Head",
    [1] =  "Neck",
    [2] =  "Shoulder",
    [3] =  "Shirt",
    [4] =  "Chest",
    [5] =  "Waist",
    [6] =  "Legs",
    [7] =  "Feet",
    [8] =  "Wrist",
    [9] =  "Hands",
    [10] = "Finger0",
    [11] = "Finger1",
    [12] = "Trinket0",
    [13] = "Trinket1",
    [14] = "Back",
    [15] = "MainHand",
    [16] = "SecondaryHand",
    [17] = "Ranged",
    [18] = "Tabard",
}

function AscCharRE_HighlightSlot(tt, self, slots) 
	for idx, slot in pairs(slots) do
		local parentSlot = _G["Character" .. slotNames[slot] .. "Slot"]
		if parentSlot == nil then print("no parent slot") else
		-- parentSlot:SetAlpha(0.5)
		parentSlot:SetHighlightTexture("Interface\\Buttons\\CheckButtonHilight");
		--parentSlot:SetHighlightTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Flash")
		
		parentSlot:LockHighlight()
		end
	end
    GameTooltip:SetOwner(tt, "ANCHOR_RIGHT", 0, 0)
    
    GameTooltip:SetHyperlink(GetEnchantLinkColored(tt.Spell))
    -- GameTooltip:SetHyperlink("|cff71d5ff|Hspell:" .. tt.Spell ..
                                -- "|h[SpellName]|h|r")
    GameTooltip:Show()
end

function AscCharRE_RemoveHighlight(tt, self, slots)
	for idx, slot in pairs(slots) do
		local parentSlot = _G["Character" .. slotNames[slot] .. "Slot"]
		if parentSlot == nil then print("no parent slot") else
		parentSlot:UnlockHighlight()
		end
	end
	GameTooltip:Hide()
end

function addon:CHAT_MSG_ADDON(event, prefix,message,form,player)
    if message:find("UpdatePaperDoll") then
        if _G["CharFrameNewPart_EnchantsFrame1TextFrame1Icon"] == nil then
            return
        end
        recvTable = Smallfolk.loads(string.sub(message, 3))
        if not type(recvTable) == "table" then return end
        -- print(#(recvTable[1])) -- [1][5] slot : spellid

        spellSlots = {}
        -- print(#recvTable[1][4], #recvTable[1][5])
        for slotId, spellId in pairs(recvTable[1][5]) do
            if not spellSlots[spellId] then spellSlots[spellId] = {slotId} 
            else
                table.insert(spellSlots[spellId], slotId)
            end
            -- print("adding spell "..spellId)
        end
    
        local idx = 1
        
        for spellId, data in pairs(recvTable[1][4]) do
            _G["CharFrameNewPart_EnchantsFrame1TextFrame" .. idx.."Icon"]:SetScript("OnEnter", function(e) AscCharRE_HighlightSlot (e, idx, spellSlots[spellId]) end)
            _G["CharFrameNewPart_EnchantsFrame1TextFrame" .. idx.."Icon"]:SetScript("OnLeave", function(e) AscCharRE_RemoveHighlight (e, idx, spellSlots[spellId]) end)
            idx = idx + 1
        end
    end
end


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




