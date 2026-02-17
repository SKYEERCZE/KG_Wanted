KGW = KGW or {}

local ESX = KGW.Wanted._ESX
local Wanted = KGW.Wanted._Wanted

-- pos update (pro police zóny)
RegisterNetEvent(KGW.Const.Events.UpdatePos, function(pos)
    local src = source
    if type(pos) ~= 'table' or pos.x == nil or pos.y == nil or pos.z == nil then return end
    local entry = KGW.Wanted.ensureEntry(src)
    entry.lastPos = vec3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
end)

-- broadcast police zón
local function broadcastZones()
    local payload = {}
    for src, entry in pairs(Wanted) do
        if entry.stars and entry.stars >= (Config.Visibility.ZoneMinStars or 2) then
            payload[#payload+1] = {
                src = src,
                stars = entry.stars,
                pos = entry.lastPos,
                reason = entry.lastReason or '',
            }
        end
    end

    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        local xPlayer = ESX.GetPlayerFromId(id)
        if KGW.Wanted.isPolice(xPlayer) then
            TriggerClientEvent(KGW.Const.Events.PoliceZones, id, payload)
        end
    end
end

CreateThread(function()
    while true do
        Wait((Config.Visibility.ZoneUpdateSeconds or 8) * 1000)
        broadcastZones()
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local entry = Wanted[src]
    if entry and entry.identifier and entry.identifier ~= '' then
        KGW.Wanted.persistWanted(entry.identifier, entry.stars or 0, entry.lastReason or '')
    end
    Wanted[src] = nil
    KGW.Wanted._HurtCooldown[src] = nil
end)

-- init statebags při loadu
RegisterNetEvent('esx:playerLoaded', function(playerId)
    local src = playerId or source
    local entry = KGW.Wanted.ensureEntry(src)

    local identifier = KGW.Wanted.getIdentifier(src) or entry.identifier
    entry.identifier = identifier or ''

    Player(src).state.kg_police_duty = false

    if not (Config.Persistence and Config.Persistence.Enabled) then
        KGW.Wanted.setStatebags(src, entry.stars or 0, entry.lastReason or '')
        return
    end

    KGW.Wanted.loadWanted(entry.identifier, function(stars, reason)
        entry.stars = KGW.Utils.clamp(stars or 0, 0, Config.MaxStars)
        entry.lastReason = reason or ''
        entry.lastUpdate = os.time()
        KGW.Wanted.setStatebags(src, entry.stars, entry.lastReason)
    end)
end)
