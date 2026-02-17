local function pickRandomCell()
    local cells = (Config.Jail and Config.Jail.Cells) or nil
    if type(cells) == 'table' and #cells > 0 then
        local idx = math.random(1, #cells)
        local c = cells[idx]
        return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, w = c.w + 0.0, index = idx }
    end
    local jc = (Config.Jail and Config.Jail.JailCoords) or vector4(0,0,0,0)
    return { x = jc.x + 0.0, y = jc.y + 0.0, z = jc.z + 0.0, w = jc.w + 0.0, index = 0 }
end

RegisterNetEvent('kg_wanted:policeJail', function(targetSrc)
    local src = source
    targetSrc = tonumber(targetSrc)

    local xPolice = KGW.ESX.GetPlayerFromId(src)
    if not KGW.isPolice(xPolice) then return end
    if not targetSrc or not GetPlayerName(targetSrc) then return end

    local stars = KGW.getStars(targetSrc)
    stars = tonumber(stars) or 0
    if stars < (Config.Interaction.MinStarsToJail or 1) then return end

    local minutes = math.max(Config.Jail.MinMinutes or 2, (Config.Jail.MinutesPerStar or 2) * stars)

    KGW.rewardPolice(src, stars)

    local officerName = GetPlayerName(src) or 'Policista'
    local cell = pickRandomCell()

    KGW.clearWanted(targetSrc)
    TriggerClientEvent('kg_wanted:goJail', targetSrc, minutes, { officer = officerName, cell = cell })
end)

RegisterNetEvent('kg_wanted:lawyerRequestClean', function(lawyerSrc)
    local suspectSrc = source
    lawyerSrc = tonumber(lawyerSrc)

    if not (Config.Lawyer and Config.Lawyer.Enabled) then return end
    if not lawyerSrc or not GetPlayerName(lawyerSrc) then return end
    if suspectSrc == lawyerSrc then return end

    local xLawyer = KGW.ESX.GetPlayerFromId(lawyerSrc)
    if not KGW.isLawyer(xLawyer) then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Tenhle hráč není právník.' })
        return
    end

    local lawyerStars = tonumber(Player(lawyerSrc).state.kg_wanted or 0) or 0
    if lawyerStars > 0 then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Právník má wanted – nemůže tě očistit.' })
        TriggerClientEvent('ox_lib:notify', lawyerSrc, { type = 'error', description = 'Máš wanted – nemůžeš poskytovat právní služby.' })
        return
    end

    local suspectStars = tonumber(Player(suspectSrc).state.kg_wanted or 0) or 0
    if suspectStars <= 0 then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Nemáš wanted.' })
        return
    end

    local suspectEntry = KGW.ensureEntry(suspectSrc)
    local identifier = suspectEntry.identifier or (KGW.ESX.GetPlayerFromId(suspectSrc) and KGW.ESX.GetPlayerFromId(suspectSrc).identifier) or ''
    if identifier == '' then return end

    local cdMin = tonumber(Config.Lawyer.CooldownMinutes) or 30
    local cdSec = cdMin * 60
    local now = os.time()

    local done = false
    local remaining = 0
    KGW.loadLawyerCooldown(identifier, function(last)
        last = tonumber(last) or 0
        local diff = now - last
        if diff < cdSec then remaining = cdSec - diff else remaining = 0 end
        done = true
    end)
    while not done do Wait(0) end

    if remaining > 0 then
        TriggerClientEvent('kg_wanted:lawyerDenied', suspectSrc, remaining)
        return
    end

    local sp = GetEntityCoords(GetPlayerPed(suspectSrc))
    local lp = GetEntityCoords(GetPlayerPed(lawyerSrc))
    local dist = #(sp - lp)
    if dist > (Config.Lawyer.Distance or 2.2) + 0.5 then
        TriggerClientEvent('ox_lib:notify', suspectSrc, { type = 'error', description = 'Musíš být blíž u právníka.' })
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

    local pay, mult = KGW.rewardLawyer(lawyerSrc, suspectStars)
    KGW.persistLawyerCooldown(identifier, now)

    if newStars <= 0 then
        KGW.clearWanted(suspectSrc)
    else
        KGW.setStars(suspectSrc, newStars, 'Obhajoba')
    end

    TriggerClientEvent('kg_wanted:lawyerBig', lawyerSrc, pay, removed, newStars, mult)
    TriggerClientEvent('ox_lib:notify', suspectSrc, {
        type = 'success',
        description = ('Právník ti upravil wanted (%d★ → %d★).'):format(suspectStars, newStars)
    })
end)
