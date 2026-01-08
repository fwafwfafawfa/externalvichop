print("e")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientStatCache = require(ReplicatedStorage.ClientStatCache)
local BeequipFile = require(ReplicatedStorage.Beequips.BeequipFile)
local BeequipTypes = require(ReplicatedStorage.Beequips.BeequipTypes)
local WaxTypes = require(ReplicatedStorage.WaxTypes)

-- !!! CONFIGURATION !!!
local QUANTITY = 20 -- Generates 20 God Items
local WAX_POWER = 45 -- 1 Caustic Wax = 50 Upgrades (Instant God Mode)
-- !!!!!!!!!!!!!!!!!!!!!

print("--- ACTIVATING FINAL STABLE RANDOMIZER ---")

-- 1. MODIFY CAUSTIC WAX (LOCAL MEMORY HACK)
-- We find Caustic Wax and make it powerful.
-- This allows us to use 1 wax for 50 rolls, preventing lag.
local CausticID = nil
for id, data in pairs(WaxTypes.TypeByID) do
if string.find(data.Name, "Caustic") then
CausticID = id
data.Upgrades = WAX_POWER
break
end
end
-- Safety fallback
if not CausticID then CausticID = 3; if WaxTypes.TypeByID[3] then WaxTypes.TypeByID[3].Upgrades = WAX_POWER end end

-- 2. HARVEST VALID ITEMS
local ValidItems = {}
for name, def in pairs(BeequipTypes.Types) do
-- Must support upgrades AND have a GetEligableBeeTypes method
if def.Upgrades and #def.Upgrades > 0 and type(def.GetEligableBeeTypes) == "function" then
table.insert(ValidItems, name)
end
end

print("ValidItems count:", #ValidItems)

-- 3. HELPER: SAFE DEFINITION PROXY
-- This is the specific fix for the "number < nil" crash.
-- It wraps the real definition and forces Potential to be 5.
local function GetSafeDefinition(realDef)
local proxy = {}
-- Copy all real data
for k,v in pairs(realDef) do proxy[k] = v end

-- FORCE SAFETY VALUES
proxy.Potential = 5
proxy.MaxPotential = 5

return proxy
end

-- 4. GENERATE ITEMS
local Rng = Random.new()
getgenv().FinalCache = {}

local function cloneWithMeta(original)
local copy = {}
for k, v in pairs(original) do
copy[k] = v
end
local mt = getmetatable(original)
if mt then
setmetatable(copy, mt)
end
return copy
end

local function CreateSafeGodItem(index)
-- Pick Random Item
local randomItemName = ValidItems[math.random(1, #ValidItems)]
local originalDef = BeequipTypes.Get(randomItemName)

-- copy + keep methods via metatable
local SafeDef = cloneWithMeta(originalDef)
SafeDef.Potential = 5
SafeDef.MaxPotential = 5

local myUserId = game.Players.LocalPlayer.UserId
local creationId = 880000 + index
local randomId = Rng:NextInteger(1, 9007199254740991)
local timeNow = os.time()

local waxHistory = {
    { 
        CausticID,
        true,
        Rng:NextInteger(1, 100000)
    }
}

local rawItem = {
    ["T"] = randomItemName,
    ["Q"] = 1,
    ["S"] = Rng:NextInteger(1, 2199023255551),
    ["OS"] = nil,
    ["IDs"] = { myUserId, creationId, randomId, timeNow },
    ["UC"] = 0,
    ["RC"] = 0,
    ["W"] = waxHistory,
    ["TC"] = 0
}

-- use BeequipFile as metatable, like real items
setmetatable(rawItem, BeequipFile)

-- override GetTypeDef but return the *cloned-with-meta* SafeDef
rawItem.GetTypeDef = function()
    return SafeDef
end

return rawItem
end
for i = 1, QUANTITY do
table.insert(getgenv().FinalCache, CreateSafeGodItem(i))
end

-- 5. HOOK STAT CACHE (SANITIZED)
if not getgenv().OldStatGet then
getgenv().OldStatGet = ClientStatCache.Get
end

-- External tracker to keep game tables clean
local Processed = setmetatable({}, {__mode = "k"})

ClientStatCache.Get = function(self)
local stats = getgenv().OldStatGet(self)

if not stats or not stats.Beequips then return stats end

-- REPAIR DAMAGE FROM PREVIOUS SCRIPTS
-- If StorageSize is messed up (nil or huge number), reset it to a safe default.
-- This fixes the "pairs expected table got number" crash in HoneycombFileTools.
if stats.Beequips.StorageSize == nil or stats.Beequips.StorageSize > 100000 then 
    stats.Beequips.StorageSize = 500 
end

if not stats.Beequips.Storage then stats.Beequips.Storage = {} end
local storage = stats.Beequips.Storage

if not Processed[storage] then
    for _, item in ipairs(getgenv().FinalCache) do
        table.insert(storage, item)
    end
    Processed[storage] = true
end

return stats
end

-- 6. REFRESH UI
task.delay(0.5, function()
local success, menuScript = pcall(function() return require(ReplicatedStorage.Gui.BeequipMenus) end)
if success and menuScript then
if menuScript.UpdateAll then pcall(function() menuScript.UpdateAll() end) end
    local storageMenu = menuScript.GetByName and menuScript.GetByName("Beequip Storage")
    if storageMenu and storageMenu.Open then
        pcall(function() storageMenu:Update() end)
    end
end
end)

print("SUCCESS! Generated Safe God Items. MonsterTimer crash patched.")
