local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientStatCache = require(ReplicatedStorage.ClientStatCache)
local BeequipFile = require(ReplicatedStorage.Beequips.BeequipFile)
local BeequipTypes = require(ReplicatedStorage.Beequips.BeequipTypes)
local WaxTypes = require(ReplicatedStorage.WaxTypes)

-- !!! CONFIGURATION !!!
local TARGET_NAME = "Candy Ring"
local QUANTITY = 50
local CAUSTIC_COUNT = 1 -- How many Caustic Waxes to apply (0 to 5)
-- !!!!!!!!!!!!!!!!!!!!!

print("--- ACTIVATING 5 POT CUSTOM BEEQUIPS ---")

-- 1. GET CAUSTIC WAX ID
-- We need the correct ID to apply the wax properly
local CausticID = 1
for id, data in pairs(WaxTypes.TypeByID) do
    if string.find(data.Name, "Caustic") then
        CausticID = id
        break
    end
end

-- 2. PREPARE THE FAKE ITEMS
local FakeItemsList = {}
local RealDefinition = BeequipTypes.Get(TARGET_NAME)
local Rng = Random.new() -- Use Random.new for large IDs to prevent errors

if not RealDefinition then
    warn("Definition not found, using fallback.")
    RealDefinition = {
        Name = TARGET_NAME, DisplayName = TARGET_NAME, Description = "Injected Item",
        Rarity = "Legendary", Modifiers = {}, Upgrades = {}, StorageSize = 1
    }
end

for i = 1, QUANTITY do
    -- Generate IDs safely
    local myUserId = game.Players.LocalPlayer.UserId
    local creationId = 500000 + i
    local randomId = Rng:NextInteger(1, 9007199254740991)
    local timeNow = os.time()

    -- Apply Waxes based on Config
    local waxHistory = {}
    for _ = 1, CAUSTIC_COUNT do
        table.insert(waxHistory, {
            CausticID,  -- The ID of Caustic Wax
            true,       -- Success = True
            math.random(1, 10000) -- Random Seed for the stat roll
        })
    end

    -- CORRECT DATA STRUCTURE (Keys must be T, Q, S, IDs, W)
    local rawItem = {
        ["T"] = TARGET_NAME,
        ["Q"] = 1, -- Quality 1 = Perfect
        ["S"] = Rng:NextInteger(1, 2199023255551), -- Stat Seed
        ["OS"] = nil,
        ["IDs"] = { myUserId, creationId, randomId, timeNow },
        ["UC"] = 0, -- Upgrade Count
        ["RC"] = 0, -- Turpentine Count
        ["W"] = waxHistory, -- Waxes applied here
        ["TC"] = 0
    }

    -- Apply Metatable
    setmetatable(rawItem, BeequipFile)
    
    -- Force Definition (Prevents crashes)
    rawItem.GetTypeDef = function() return RealDefinition end
    
    -- 5 POTENTIAL VISUAL TRICK
    -- This function tells the UI "I have used 0 waxes", so it draws 5 empty stars.
    -- However, the stats are calculated from the ["W"] table above, so you keep the stats.
    rawItem.GetWaxUseCount = function() return 0 end
    
    table.insert(FakeItemsList, rawItem)
end

-- 3. HOOK THE STAT CACHE
if not getgenv().OldStatGet then
    getgenv().OldStatGet = ClientStatCache.Get
end

-- We use a tracking table to ensure we inject exactly once per storage instance
-- This prevents the "infinite loop" lag.
local ProcessedTables = setmetatable({}, {__mode = "k"})

ClientStatCache.Get = function(self)
    local stats = getgenv().OldStatGet(self)
    
    if stats and stats.Beequips then
        -- Fix StorageSize if it was corrupted by previous scripts
        if stats.Beequips.StorageSize == nil or stats.Beequips.StorageSize > 100000 then 
            stats.Beequips.StorageSize = 500 
        end
        
        if not stats.Beequips.Storage then stats.Beequips.Storage = {} end
        local storage = stats.Beequips.Storage
        
        -- Only inject if we haven't touched this table yet
        if not ProcessedTables[storage] then
            for _, fake in ipairs(FakeItemsList) do
                table.insert(storage, fake)
            end
            ProcessedTables[storage] = true
        end
    end
    
    return stats
end

-- 4. REFRESH UI
local success, menuScript = pcall(function() return require(ReplicatedStorage.Gui.BeequipMenus) end)
if success and menuScript then
    if menuScript.UpdateAll then pcall(function() menuScript.UpdateAll() end) end
    local storageMenu = menuScript.GetByName and menuScript.GetByName("Beequip Storage")
    if storageMenu and storageMenu.Open then
        pcall(function() storageMenu:Update() end)
    end
end

print("SUCCESS! " .. CAUSTIC_COUNT .. " Caustics applied with 5 Pot Visual.")
