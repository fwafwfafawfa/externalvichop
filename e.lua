local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientStatCache = require(ReplicatedStorage.ClientStatCache)
local BeequipFile = require(ReplicatedStorage.Beequips.BeequipFile)
local BeequipTypes = require(ReplicatedStorage.Beequips.BeequipTypes)
local WaxTypes = require(ReplicatedStorage.WaxTypes)

-- !!! CONFIGURATION !!!
local TARGETS = {
    ["Whistle"] = 10,
    ["Poinsettia"] = 10,
    ["Elf Cap"] = 10
}

local CAUSTIC_COUNT = 5 -- How many Waxes to apply (0-5)
-- !!!!!!!!!!!!!!!!!!!!!

print("--- ACTIVATING STANDARD GENERATOR (NO POWER HACKS) ---")

-- 1. GET CAUSTIC WAX ID (NO MODIFICATION)
-- We just find the ID. We do NOT touch the power.
local CausticID = 1
for id, data in pairs(WaxTypes.TypeByID) do
    if string.find(data.Name, "Caustic") then
        CausticID = id
        break
    end
end

-- 2. GENERATOR LOOP
local FakeItemsList = {}
local Rng = Random.new() 
local GlobalIndex = 0 

for itemName, quantity in pairs(TARGETS) do
    
    local RealDefinition = BeequipTypes.Get(itemName)
    
    -- Fallback
    if not RealDefinition then
        RealDefinition = {
            Name = itemName, DisplayName = itemName, Description = "Injected",
            Rarity = "Legendary", Modifiers = {}, Upgrades = {}, StorageSize = 1,
            Icon = "rbxassetid://0", Texture = "rbxassetid://0"
        }
    end

    -- SAFE DEFINITION CONSTRUCTOR
    -- Even without power hacks, we must clone the definition
    -- so the items don't share memory and crash the UI.
    local function GetSafeDef()
        local copy = {}
        
        -- Copy Visuals
        for k, v in pairs(RealDefinition) do copy[k] = v end

        -- Copy Upgrades (Isolated Copy)
        copy.Upgrades = {}
        if RealDefinition.Upgrades then
            for _, v in ipairs(RealDefinition.Upgrades) do
                table.insert(copy.Upgrades, v)
            end
        end

        -- Safety Stat: Prevents "nil index" error if item runs out of stats
        table.insert(copy.Upgrades, {
            Type = "Convert Rate", Amount = 1.01, Weight = 99999999
        })

        setmetatable(copy, getmetatable(RealDefinition))
        return copy
    end

    print("Generating " .. quantity .. " x " .. itemName)

    for i = 1, quantity do
        GlobalIndex = GlobalIndex + 1
        local myUserId = game.Players.LocalPlayer.UserId
        local creationId = 500000 + GlobalIndex
        local randomId = Rng:NextInteger(1, 9007199254740991)
        
        -- Apply Waxes (Normal Game Logic)
        local waxHistory = {}
        for _ = 1, CAUSTIC_COUNT do
            table.insert(waxHistory, {
                CausticID,  
                true,       
                Rng:NextInteger(1, 100000) 
            })
        end

        local rawItem = {
            ["T"] = itemName,
            ["Q"] = 1, 
            ["S"] = Rng:NextInteger(1, 2199023255551),
            ["OS"] = nil,
            ["IDs"] = { myUserId, creationId, randomId, os.time() },
            ["UC"] = 0,
            ["RC"] = 0,
            ["W"] = waxHistory, 
            ["TC"] = 0
        }

        setmetatable(rawItem, BeequipFile)
        
        -- Assign Safe Definition
        rawItem.GetTypeDef = function() return GetSafeDef() end
        
        -- VISUAL TRICK:
        -- Returns 0, so UI draws 5 Empty Stars. 
        -- Real stats come from the ["W"] table above.
        rawItem.GetWaxUseCount = function() return 0 end
        
        table.insert(FakeItemsList, rawItem)
    end
end

-- 3. HOOK STAT CACHE
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

print("SUCCESS! Generated items with standard stats.")
