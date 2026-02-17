KGW = KGW or {}

local ESX = KGW.Wanted._ESX

local function lawyerTable()
    return (Config.Lawyer and Config.Lawyer.CooldownTable) or 'kg_wanted_lawyer'
end

local function persistLawyerCooldown(identifier, unixTs)
    if not (Config.Persistence and Config.Persistence.Enabled) then return end
    if not (Config.Lawyer and Config.Lawyer.Enabled) then return end
    if not identifier or identifier == '' then return end

    unixTs = tonumber(unixTs) or 0
    local t = lawyerTable()

    KGW.DB.exec(
        ('INSERT INTO %s (identifier, last_help_unix) VALUES (?, ?) ON DUPLICATE KEY UPDATE last_help_unix = VALUES(last_help_unix), updated_at = CURRENT_TIMESTAMP'):format(t),
        { identifier, unixTs }
    )
end

local function loadLawyerCooldown(identifier, cb)
    if not (Config.Persistence and Config.Persistence.Enabled) then cb(0) return end
    if not (Config.Lawyer and Config.Lawyer.Enabled) then cb(0) return end
    if not identifier or identifier == '' then cb(0) return end

    local t = lawyerTable()
    KGW.DB.fetchAll(('SELECT last_help_unix FROM %s WHERE identifier = ? LIMIT 1'):format(t), { identifier }, function(rows)
        if rows and rows[1] then cb(tonumber(rows[1].last_help_unix) or 0) else cb(0) end
    end)
end

-- Server -> wanted hráčům posílá seznam aktivních právníků (aby šlo filtrovat ox_target + šipka)
CreateThread(function()
    if not (Config.Lawyer and Config.Lawyer.Enabled) then return end

    local syncSeconds = tonumber(Config.Lawyer.SyncSeconds) or 5
    if syncSeconds < 2 then syncSeconds = 2 end

    while true do
        Wait(syncSeconds * 1000)

        local lawyers = {}
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            local x = ESX.GetPlayerFromId(src)
            if x and KGW.Wanted.isLawyer(x) then
                local stars = tonumber(Player(src).state.kg_wanted or 0) or 0
                if stars <= 0 then
                    lawyers[#lawyers+1] = src
                end
            end
        end

        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            local myStars = tonumber(Player(src).state.kg_wanted or 0) or 0
            if myStars > 0 then
                TriggerClientEvent(KGW.Const.Events.SyncLawyers, src, lawyers)
            end
        end
    end
end)

RegisterNetEvent(KGW.Const.Events.LawyerRequestClean, function(lawyerSrc)
    local suspectSrc = source
    lawyerSrc = tonumber(lawyerSrc)

    if not (Config.Lawyer and Config.Lawyer.Enabled) then return end
    if not lawyerSrc or not GetPlayerName(lawyerSrc) then return end
    if suspectSrc == lawyerSrc then return end

    local xLawyer = ESX.GetPlayerFromId(lawyerSrc)
    if not KGW.Wanted.isLawyer(xLawyer) then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Tenhle hrac neni pravnik.' })
        return
    end

    local lawyerStars = tonumber(Player(lawyerSrc).state.kg_wanted or 0) or 0
    if lawyerStars > 0 then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Pravnik ma wanted - nemuze te ocistit.' })
        TriggerClientEvent('ox_lib:notify', lawyerSrc, { type = 'error', description = 'Mas wanted - nemuzes poskytovat pravni sluzby.' })
        return
    end

    local suspectStars = tonumber(Player(suspectSrc).state.kg_wanted or 0) or 0
    if suspectStars <= 0 then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Nemas wanted.' })
        return
    end

    local suspectEntry = KGW.Wanted.ensureEntry(suspectSrc)
    local identifier = suspectEntry.identifier or KGW.Wanted.getIdentifier(suspectSrc) or ''
    if identifier == '' then return end

    local cdMin = tonumber(Config.Lawyer.CooldownMinutes) or 30
    local cdSec = cdMin * 60
    local now = os.time()

    local done = false
    local remaining = 0
    loadLawyerCooldown(identifier, function(last)
        last = tonumber(last) or 0
        local diff = now - last
        if diff < cdSec then remaining = cdSec - diff else remaining = 0 end
        done = true
    end)
    while not done do Wait(0) end

    if remaining > 0 then
        TriggerClientEvent(KGW.Const.Events.LawyerDenied, suspectSrc, remaining)
        return
    end

    local sp = GetEntityCoords(GetPlayerPed(suspectSrc))
    local lp = GetEntityCoords(GetPlayerPed(lawyerSrc))
    local dist = #(sp - lp)
    if dist > (Config.Lawyer.Distance or 2.2) + 0.5 then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Musis byt bliz u pravnika.' })
        return
    end

    local newStars = 0
    local removed = 0
    local mode = Config.Lawyer.Mode or 'clear'
    if mode == 'reduce' then
        local reduceBy = tonumber(Config.Lawyer.ReduceBy) or 1
        newStars = math.max(0, suspectStars - reduceBy)
        removed = suspectStars - newStars
    else
        newStars = 0
        removed = suspectStars
    end

    local pay, mult = KGW.Rewards.rewardLawyer(lawyerSrc, suspectStars)
    persistLawyerCooldown(identifier, now)

    if newStars <= 0 then
        KGW.Wanted.clearWanted(suspectSrc)
    else
        KGW.Wanted.setStars(suspectSrc, newStars, 'Obhajoba')
    end

    TriggerClientEvent(KGW.Const.Events.LawyerBig, lawyerSrc, pay, removed, newStars, mult)
    TriggerClientEvent('ox_lib:notify', suspectSrc, {
        type = 'success',
        description = ('Pravnik ti upravil wanted (%d★ -> %d★).'):format(suspectStars, newStars)
    })
end)
