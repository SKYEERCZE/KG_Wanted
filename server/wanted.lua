local function getIdentifier(src)
    local xPlayer = KGW.ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier or nil
end

function KGW.ensureEntry(src)
    if not KGW.Wanted[src] then
        KGW.Wanted[src] = {
            identifier = getIdentifier(src) or '',
            stars = 0,
            lastReason = '',
            lastPos = vec3(0.0, 0.0, 0.0),
            lastUpdate = os.time(),
        }
    end
    if KGW.Wanted[src].identifier == '' then
        KGW.Wanted[src].identifier = getIdentifier(src) or ''
    end
    return KGW.Wanted[src]
end

function KGW.setStatebags(src, stars, reason)
    Player(src).state.kg_wanted = stars
    Player(src).state.kg_wanted_reason = reason or ''

    -- ✅ job flags for client (ox_target filters + marker)
    local xPlayer = KGW.ESX.GetPlayerFromId(src)
    local jobName = xPlayer and xPlayer.job and xPlayer.job.name or ''
    Player(src).state.kg_isPolice = (jobName == Config.PoliceJob)
    Player(src).state.kg_isLawyer = (Config.Lawyer and Config.Lawyer.Enabled and jobName == (Config.Lawyer.JobName or 'lawyer'))
end

function KGW.setStars(src, stars, reason)
    local entry = KGW.ensureEntry(src)
    local oldStars = entry.stars or 0

    entry.stars = KGW.clamp(tonumber(stars) or 0, 0, Config.MaxStars)
    entry.lastReason = reason or entry.lastReason or ''
    entry.lastUpdate = os.time()

    KGW.setStatebags(src, entry.stars, entry.lastReason)
    KGW.persistWanted(entry.identifier, entry.stars, entry.lastReason)

    if Config.NotifyOnStarsGain and entry.stars > oldStars then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            title = '🚨 WANTED',
            description = ('Získal jsi %d★ - %s'):format(entry.stars, (entry.lastReason ~= '' and entry.lastReason or 'Přestupek'))
        })
    end
end

function KGW.addStars(src, add, reason)
    local entry = KGW.ensureEntry(src)
    KGW.setStars(src, (entry.stars or 0) + (tonumber(add) or 0), reason)
end

function KGW.clearWanted(src)
    KGW.setStars(src, 0, '')
end

function KGW.getStars(src)
    local entry = KGW.ensureEntry(src)
    return entry.stars or 0, entry.lastReason or ''
end

