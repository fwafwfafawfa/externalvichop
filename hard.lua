local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientStatCache = require(ReplicatedStorage.ClientStatCache)
local WaxTypes = require(ReplicatedStorage.WaxTypes)

-- Load Game Modules
local BeequipFile = require(ReplicatedStorage.Beequips.BeequipFile)
local BeequipCaseEntry = require(ReplicatedStorage.Beequips.BeequipCaseEntry)

-- Try to load Stat Mods helper to get clean names
local BeeStatMods
pcall(function()
    BeeStatMods = require(ReplicatedStorage.BeeStats.BeeStatMods)
end)

print("--- VISUAL HARD WAX PREDICTION ---")

-- 1. SETUP
local stats = ClientStatCache:Get()
if not stats or not stats.Beequips or not stats.Beequips.Case then
    warn("Could not read Beequip Case.")
    return
end

-- CHANGED: Find Hard Wax ID instead of Caustic
local HardID = 0
for id, data in pairs(WaxTypes.TypeByID) do
    if string.find(data.Name, "Hard") then
        HardID = id
        break
    end
end
print("Hard Wax ID: " .. HardID)

-- 2. HELPER FUNCTIONS

local function DeepCopy(orig)
    local copy = {}
    if type(orig) ~= "table" then return orig end
    for k, v in pairs(orig) do copy[k] = DeepCopy(v) end
    return copy
end

-- This function extracts the actual stats from the item
local function GetItemStats(itemFile)
    local finalStats = {}
    
    local rawMods = itemFile:GenerateModifiers() 
    if not rawMods then return {} end

    for _, mod in ipairs(rawMods) do
        local statNames = {mod.Stat}
        if BeeStatMods and BeeStatMods.GetTags then
            local tags = BeeStatMods.GetTags(mod.Stat, mod.Params)
            if tags then statNames = tags end
        end
        
        for _, name in ipairs(statNames) do
            local val = mod.Value
            if type(val) == "number" then
                finalStats[name] = (finalStats[name] or 0) + val
            end
        end
    end
    
    return finalStats
end

-- Formats the numbers nicely
local function FormatDiff(name, val)
    local isPercent = string.find(name, "Rate") or string.find(name, "Percent") or 
                      string.find(name, "Chance") or string.find(name, "Amount") or 
                      string.find(name, "Capacity") or string.find(name, "Bond")
    
    if isPercent or (math.abs(val) < 1 and math.abs(val) > 0.0001) then
        return string.format("%+.1f%%", val * 100)
    else
        return string.format("%+.2f", val)
    end
end

print("-------------------------------------------------")

-- 3. MAIN LOOP
for i, rawEntryData in ipairs(stats.Beequips.Case) do
    
    -- A. Load Item
    local entryObject = BeequipCaseEntry.FromData(DeepCopy(rawEntryData))
    local foundItemFile = entryObject:FetchBeequip(stats)
    
    if foundItemFile then
        local itemData = DeepCopy(foundItemFile)
        local simulatedItem = BeequipFile.FromData(itemData)
        
        local name = simulatedItem:GetDisplayName()
        local waxCount = simulatedItem:GetWaxUseCount() or 0
        local statusText = (entryObject:IsEquipped() and "[Equipped]") or "[Case]"

        -- B. GET STATS BEFORE
        local statsBefore = GetItemStats(simulatedItem)

        -- C. SIMULATE WAX (Using Hard Wax ID)
        math.randomseed(tick() + i * 999) 
        local success, msg, broken = simulatedItem:ApplyUpgradeWax(HardID)

        -- D. GET STATS AFTER
        local statsAfter = GetItemStats(simulatedItem)

        -- E. COMPARE
        if broken then
            print(string.format("[%d] %s %s -> 💀 DESTROYED", i, statusText, name))
        elseif not success then
            -- Hard wax can fail without breaking, or fail because max waxes
            print(string.format("[%d] %s %s -> ❌ FAIL (%s)", i, statusText, name, tostring(msg)))
        else
            -- Calculate differences
            local changes = {}
            for statName, newVal in pairs(statsAfter) do
                local oldVal = statsBefore[statName] or 0
                
                local diff = newVal - oldVal
                if math.abs(diff) > 0.0001 then
                    table.insert(changes, FormatDiff(statName, diff) .. " " .. statName)
                end
            end
            
            -- Check for lost stats (stats that existed before but not after)
            for statName, oldVal in pairs(statsBefore) do
                if not statsAfter[statName] then
                    table.insert(changes, FormatDiff(statName, -oldVal) .. " " .. statName)
                end
            end
            
            local resultStr = table.concat(changes, ", ")
            if resultStr == "" then resultStr = "No Stat Changes (Rolled same stats or failed)" end
            
            print(string.format("[%d] %s %s (Wax: %d)", i, statusText, name, waxCount))
            warn("    ↳ " .. resultStr)
        end
    end
end

print("-------------------------------------------------")
