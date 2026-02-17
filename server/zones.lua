local function broadcastZones()
    local payload = {}
    for src, entry in pairs(KGW.Wanted) do
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
        local xPlayer = KGW.ESX.GetPlayerFromId(id)
        if KGW.isPolice(xPlayer) then
            TriggerClientEvent('kg_wanted:policeZones', id, payload)
        end
    end
end

CreateThread(function()
    while true do
        Wait((Config.Visibility.ZoneUpdateSeconds or 8) * 1000)
        broadcastZones()
    end
end)

RegisterNetEvent('kg_wanted:updatePos', function(pos)
    local src = source
    if type(pos) ~= 'table' or pos.x == nil or pos.y == nil or pos.z == nil then return end
    local entry = KGW.ensureEntry(src)
    entry.lastPos = vec3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
end)
