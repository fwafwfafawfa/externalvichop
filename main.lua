--[[
    VICHOP Scout Script v2.0
    Reports Vicious and continues scouting!
    
    Change WEBHOOK_URL below to your Discord webhook!
]]

local WEBHOOK_URL = "https://discord.com/api/webhooks/1381495908826349599/hJlDUBqobSMFqjGL-Twv2v4_jdaY6xJZFVAbqwHcxrmV3LdrdVydq87YbAzmGcH7Pju7"

------------------------------------------------------------------------
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local PLACE_ID = 1537690962
local SCOUT_NAME = Players.LocalPlayer.Name
local CHECK_DELAY = 1.5

local reported_servers = {}

print("========================================")
print("[ALT] Started: " .. SCOUT_NAME)
print("[ALT] Mode: Report and Continue")
print("[ALT] JobId: " .. game.JobId)
print("========================================")

local function SendToDiscord(jobId)
    if reported_servers[jobId] then
        print("[SCOUT] Already reported this server, skipping...")
        return true
    end
    
    local success = pcall(function()
        local req = request or http_request or (syn and syn.request) or (http and http.request)
        if req then
            req({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({
                    content = jobId,
                    username = "ALT: " .. SCOUT_NAME
                })
            })
        end
    end)
    
    if success then
        reported_servers[jobId] = true
        print("[ALT] Sent JobId to Discord!")
    else
        warn("[ALT] Failed to send webhook")
    end
    
    return success
end

local function FindVicious()
    local monsters = Workspace:FindFirstChild("Monsters")
    if not monsters then return nil end
    
    for _, mob in pairs(monsters:GetChildren()) do
        if mob.Name:lower():find("vicious") then
            if mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Head") then
                return mob
            end
        end
    end
    return nil
end

local function ServerHop()
    print("[ALT] Hopping to new server...")
    
    local api = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/0?sortOrder=1&excludeFullGames=true&limit=100"
    
    local success, response = pcall(function()
        return game:HttpGet(api)
    end)
    
    if success and response then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(response)
        end)
        
        if ok and data and data.data then
            local servers = data.data
            
            for i = #servers, 2, -1 do
                local j = math.random(i)
                servers[i], servers[j] = servers[j], servers[i]
            end
            
            for _, server in ipairs(servers) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, Players.LocalPlayer)
                    end)
                    return
                end
            end
        end
    end
    
    pcall(function()
        TeleportService:Teleport(PLACE_ID, Players.LocalPlayer)
    end)
end

TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
    if player == Players.LocalPlayer then
        warn("[ALT] Teleport failed: " .. tostring(errorMessage))
        task.wait(3)
        ServerHop()
    end
end)

if not game:IsLoaded() then
    game.Loaded:Wait()
end

while true do
    task.wait(CHECK_DELAY)
    
    local vicious = FindVicious()
    
    if vicious then
        print("")
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
        print("!!! VICIOUS BEE FOUND !!!")
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
        print("JobId: " .. game.JobId)
        print("")
        
        for i = 1, 3 do
            if SendToDiscord(game.JobId) then
                break
            end
            task.wait(0.5)
        end
        
        print("[ALT] Reported! Moving to next server...")
        task.wait(1)
        ServerHop()
        
        task.wait(1.5)
    else
        print("[ALT] No Vicious here, hopping...")
        ServerHop()
        
        task.wait(1.5)
    end
end
