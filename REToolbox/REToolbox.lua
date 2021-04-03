if not DataStore_AscensionRE then return end

local addonName = "REToolbox"
local initialized = false

local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0",
                                               "AceEvent-3.0")

local RESpellList = {}
local REByRank = {}
NumKnownREs = {}
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
local charLineLabels = { "Mystic Enchant:", "Alts (%u):", "Guild (%u):", "Shared (%u):"}

local function HandleTooltipSet(ref, entry) 
    if not RESpellList[entry] or RESpellList[entry] ~= true then return end
    if KnownREs[1] == nil then return end -- not yet initialized

    local charNamesWithColor = {}
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

-- Tooltip hooks

-- hook spell icon tooltip
GameTooltip:HookScript("OnTooltipSetSpell", function(self)
    if not initialized then return end
    -- addon:Print("OnTooltipSetSpell")
    local entry = select(3, self:GetSpell())
    HandleTooltipSet(self, entry)
end)

-- hook spell info from chat links
hooksecurefunc("SetItemRef", function(link, ...)
    if not initialized then return end
    -- addon:Print("SetItemRef")
    local entry = tonumber(link:match("spell:(%d+)"))
    HandleTooltipSet(ItemRefTooltip, entry)
end)

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

    for _, entry in pairs(spellList) do
        local name, rank, icon = GetSpellInfo(entry)
        if not rank or rank == "" then
            addon:Print("Unknown Enchant Id: " .. entry)
        else
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
end

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

function addon:ASC_COLLECTION_RE_UNLOCKED(event, entry)
    local link = GetEnchantLinkColored(entry)
    addon:Print("New Mystic Enchant: "..link..".")
end

function addon:OnInitialize()
    addon:RegisterMessage("ASC_COLLECTION_UPDATE")
    addon:RegisterMessage("ASC_COLLECTION_INIT")
    addon:RegisterMessage("ASC_COLLECTION_RE_UNLOCKED")
end

function addon:OnEnable() end

function addon:OnDisable() end

