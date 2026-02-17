RegisterNetEvent('kg_wanted:crime', function(data)
    local attacker = source
    if type(data) ~= 'table' then return end

    local victim = tonumber(data.victim or -1)
    local crimeType = tostring(data.type or '')
    local dist = tonumber(data.dist or 9999.0)

    if victim <= 0 or not GetPlayerName(victim) then return end
    if attacker == victim then return end
    if dist > 200.0 then return end

    local xAttacker = KGW.ESX.GetPlayerFromId(attacker)
    if not xAttacker then return end

    local isCop = KGW.isPolice(xAttacker)
    local victimStars = tonumber(Player(victim).state.kg_wanted or 0) or 0

    local add = 0
    local reason = ''

    if crimeType == 'kill' then
        add = Config.Stars.KillPlayer or 2
        reason = 'Vražda hráče'
    elseif crimeType == 'hurt' then
        local now = os.time()
        local cd = KGW.HurtCooldown[attacker] or 0
        if now - cd < (Config.HurtCooldownSeconds or 20) then return end
        KGW.HurtCooldown[attacker] = now

        add = Config.Stars.HurtPlayer or 1
        reason = 'Napadení hráče'
    end

    if add <= 0 then return end

    -- 🔴 POLICE CODEX LOGIKA
    if isCop and victimStars <= 0 then
        add = add + (Config.Stars.PoliceExtraStars or 1)

        -- shodit z práce
        xAttacker.setJob(Config.UnemployedJob, 0)
        Player(attacker).state.kg_police_duty = false

        -- červená GTA hláška
        TriggerClientEvent('kg_wanted:codexTop', attacker, {
            title = 'KODEX PORUSEN',
            desc = 'Porušil jsi kodex policie.'
        })
    end

    KGW.addStars(attacker, add, reason)
end)
