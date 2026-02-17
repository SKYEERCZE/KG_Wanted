local function removeZoneBlip(src)
    local b = KGW.zoneBlips[src]
    if not b then return end
    if b.radius and DoesBlipExist(b.radius) then RemoveBlip(b.radius) end
    if b.center and DoesBlipExist(b.center) then RemoveBlip(b.center) end
    KGW.zoneBlips[src] = nil
end

local function upsertZoneBlip(wantedSrc, pos, stars)
    if not pos then return end

    local x, y, z = pos.x + 0.0, pos.y + 0.0, pos.z + 0.0
    if Config.Visibility.ZoneRandomize then
        local r = Config.Visibility.ZoneRandomizeMeters or 60.0
        x = x + math.random(-r, r)
        y = y + math.random(-r, r)
    end

    KGW.zoneBlips[wantedSrc] = KGW.zoneBlips[wantedSrc] or {}

    if KGW.zoneBlips[wantedSrc].radius and DoesBlipExist(KGW.zoneBlips[wantedSrc].radius) then RemoveBlip(KGW.zoneBlips[wantedSrc].radius) end
    if KGW.zoneBlips[wantedSrc].center and DoesBlipExist(KGW.zoneBlips[wantedSrc].center) then RemoveBlip(KGW.zoneBlips[wantedSrc].center) end

    local radius = AddBlipForRadius(x, y, z, Config.Visibility.ZoneRadius or 220.0)
    SetBlipAlpha(radius, 90)

    local center = AddBlipForCoord(x, y, z)
    SetBlipSprite(center, 161)
    SetBlipScale(center, 0.8)
    SetBlipAsShortRange(center, false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('WANTED %s'):format(string.rep('★', stars)))
    EndTextCommandSetBlipName(center)

    KGW.zoneBlips[wantedSrc].radius = radius
    KGW.zoneBlips[wantedSrc].center = center
end

RegisterNetEvent('kg_wanted:policeZones', function(payload)
    if not KGW.cache.isPolice then return end
    if type(payload) ~= 'table' then return end

    local alive = {}
    for _, item in ipairs(payload) do
        if item and item.src and item.stars and item.pos then
            alive[item.src] = true
            upsertZoneBlip(item.src, item.pos, item.stars)
        end
    end

    for src, _ in pairs(KGW.zoneBlips) do
        if not alive[src] then removeZoneBlip(src) end
    end
end)
