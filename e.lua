local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientStatCache = require(ReplicatedStorage.ClientStatCache)
local BeequipFile = require(ReplicatedStorage.Beequips.BeequipFile)
local BeequipTypes = require(ReplicatedStorage.Beequips.BeequipTypes)
local WaxTypes = require(ReplicatedStorage.WaxTypes)

-- !!! CONFIGURATION !!!
-- List the items you want here. It will generate QUANTITY of EACH.
local TARGET_LIST = {
    "Whistle", 
    "Poinsettia", 
    "Elf Cap",
    "Candy Ring" -- Added this too just in case
}

local QUANTITY = 50      -- How many of EACH item to generate
local CAUSTIC_COUNT = 5  -- How many Caustic Waxes to apply (0 to 5)
local CAUSTIC_POWER = 50 -- Power Level (1 = Normal, 50 = God Stats)
-- !!!!!!!!!!!!!!!!!!!!!

print("--- ACTIVATING MULTI-ITEM GENERATOR ---")

-- 1. APPLY CAUSTIC POWER HACK
local CausticID = nil
for id, data in pairs(WaxTypes.TypeByID) do
    if string.find(data.Name, "Caustic") then
        CausticID = id
        data.Upgrades = CAUSTIC_POWER -- Apply the Power Config
        break
    end
end
if not CausticID then CausticID = 3 end

-- 2. PREPARE THE FAKE ITEMS
local FakeItemsList = {}
local Rng = Random.new() 

-- Loop through every item in your config list
for _, itemName in pairs(TARGET_LIST) do
    
    local RealDefinition = BeequipTypes.Get(itemName)
    
    -- Fallback if item name is wrong
    if not RealDefinition then
        warn("Could not find definition for: " .. itemName)
        RealDefinition = {
            Name = itemName, DisplayName = itemName, Description = "Injected",
            Rarity = "Legendary", Modifiers = {}, Upgrades = {}, StorageSize = 1,
            Icon = "rbxassetid://0", Texture = "rbxassetid://0"
        }
    end

    -- DEFINITION CONSTRUCTOR (Prevents Crashing on simple items)
    local function GetSafeDef()
        local copy = {}
        -- Copy Visuals
        for k,v in pairs(RealDefinition) do copy[k] = v end
        
        -- Copy Upgrades
        copy.Upgrades = {}
        if RealDefinition.Upgrades then
            for _, v in ipairs(RealDefinition.Upgrades) do
                table.insert(copy.Upgrades, v)
            end
        end

        -- INJECT SAFETY STAT (Prevents "nil index" crash if stats run out)
        table.insert(copy.Upgrades, {
            Type = "Convert Rate", Amount = 1.01, Weight = 99999999
        })

        setmetatable(copy, getmetatable(RealDefinition))
        return copy
    end

    print("Generating " .. QUANTITY .. " x " .. itemName)

    for i = 1, QUANTITY do
        local myUserId = game.Players.LocalPlayer.UserId
        local creationId = 300000 + i + (#FakeItemsList * 1000) -- Unique IDs
        local randomId = Rng:NextInteger(1, 9007199254740991)
        local timeNow = os.time()

        -- Apply Waxes
        local waxHistory = {}
        for _ = 1, CAUSTIC_COUNT do
            table.insert(waxHistory, {
                CausticID,  
                true,       
                Rng:NextInteger(1, 100000) 
            })
        end

        local rawItem = {
            ["T"] = itemName, -- Set the specific name
            ["Q"] = 1, 
            ["S"] = Rng:NextInteger(1, 2199023255551), 
            ["OS"] = nil,
            ["IDs"] = { myUserId, creationId, randomId, timeNow },
            ["UC"] = 0, 
            ["RC"] = 0, 
            ["W"] = waxHistory, 
            ["TC"] = 0
        }

        setmetatable(rawItem, BeequipFile)
        
        -- Assign Safe Definition
        rawItem.GetTypeDef = function() return GetSafeDef() end
        
        -- Visual Trick
        rawItem.GetWaxUseCount = function() return 0 end
        
        table.insert(FakeItemsList, rawItem)
    end
end

-- 3. HOOK THE STAT CACHE
if not getgenv().OldStatGet then
    getgenv().OldStatGet = ClientStatCache.Get
end

local ProcessedTables = setmetatable({}, {__mode = "k"})

ClientStatCache.Get = function(self)
    local stats = getgenv().OldStatGet(self)
    
    if stats and stats.Beequips then
        if stats.Beequips.StorageSize == nil or stats.Beequips.StorageSize > 100000 then 
            stats.Beequips.StorageSize = 500 
        end
        
        if not stats.Beequips.Storage then stats.Beequips.Storage = {} end
        local storage = stats.Beequips.Storage
        
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
task.spawn(function()
    task.wait(0.5)
    local success, menuScript = pcall(function() return require(ReplicatedStorage.Gui.BeequipMenus) end)
    if success and menuScript then
        if menuScript.UpdateAll then pcall(function() menuScript.UpdateAll() end) end
        local storageMenu = menuScript.GetByName and menuScript.GetByName("Beequip Storage")
        if storageMenu and storageMenu.Open then
            pcall(function() storageMenu:Update() end)
        end
    end
end)

print("SUCCESS! Generated multiple item types.")
