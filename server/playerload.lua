AddEventHandler('playerDropped', function()
    local src = source
    local entry = KGW.Wanted[src]
    if entry and entry.identifier and entry.identifier ~= '' then
        KGW.persistWanted(entry.identifier, entry.stars or 0, entry.lastReason or '')
    end
    KGW.Wanted[src] = nil
    KGW.HurtCooldown[src] = nil
end)

-- ✅ Player loaded -> load wanted from DB + set job flags
RegisterNetEvent('esx:playerLoaded', function(playerId)
    local src = playerId or source
    local entry = KGW.ensureEntry(src)

    local xP = KGW.ESX.GetPlayerFromId(src)
    local identifier = (xP and xP.identifier) or entry.identifier
    entry.identifier = identifier or ''

    Player(src).state.kg_police_duty = false

    if not (Config.Persistence and Config.Persistence.Enabled) then
        KGW.setStatebags(src, entry.stars or 0, entry.lastReason or '')
        return
    end

    KGW.loadWanted(entry.identifier, function(stars, reason)
        entry.stars = KGW.clamp(stars or 0, 0, Config.MaxStars)
        entry.lastReason = reason or ''
        entry.lastUpdate = os.time()
        KGW.setStatebags(src, entry.stars, entry.lastReason)
    end)
end)

-- ✅ IMPORTANT FIX:
-- ESX calls: TriggerEvent('esx:setJob', playerId, job, lastJob)
-- If we catch it with wrong signature, "job" becomes number (playerId) -> crashes.
AddEventHandler('esx:setJob', function(playerId, job, lastJob)
    if type(playerId) ~= 'number' then return end
    if type(job) ~= 'table' then return end

    local src = playerId

    -- update job flags immediately for client filtering
    local stars = tonumber(Player(src).state.kg_wanted or 0) or 0
    local reason = tostring(Player(src).state.kg_wanted_reason or '') or ''
    KGW.setStatebags(src, stars, reason)
end)
