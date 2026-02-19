-- KG_Wanted/server/crime.lua

KGW = KGW or {}
KGW.HurtCooldown = KGW.HurtCooldown or {}
KGW.RunoverCooldown = KGW.RunoverCooldown or {}
KGW.TheftCooldown = KGW.TheftCooldown or {}

RegisterNetEvent('kg_wanted:crime', function(data)
    local attacker = source
    if type(data) ~= 'table' then return end

    local crimeType = tostring(data.type or '')
    local dist = tonumber(data.dist or 9999.0)

    -- attacker musí existovat v ESX
    local xAttacker = KGW.ESX.GetPlayerFromId(attacker)
    if not xAttacker then return end

    local isCop = KGW.isPolice(xAttacker)

    -- =========================================
    -- NPC VEHICLE THEFT (nemá victim)
    -- =========================================
    if crimeType == 'veh_theft_npc' then
        -- distance check (optional; theft většinou posíláš s dist=0)
        if dist > 200.0 then return end

        local now = os.time()
        local cd = KGW.TheftCooldown[attacker] or 0
        if now - cd < 8 then return end
        KGW.TheftCooldown[attacker] = now

        local add = (Config.Stars and Config.Stars.StealNpcVehicle) or 1
        if add <= 0 then return end

        local reason = 'Krádež vozidla (NPC)'
        local extra = ''

        -- před
        local beforeStars = tonumber(Player(attacker).state.kg_wanted or 0) or 0

        -- POLICE CODEX LOGIKA (volitelně i pro theft – nechávám OFF podle tvého stylu):
        -- pokud chceš, aby policajt krádeží porušil kodex, odkomentuj:
        -- if isCop then
        --     add = add + (Config.Stars.PoliceExtraStars or 1)
        --     xAttacker.setJob(Config.UnemployedJob, 0)
        --     Player(attacker).state.kg_police_duty = false
        --     extra = 'Porušil jsi kodex policie.\n(odebrán police job)'
        --     TriggerClientEvent('kg_wanted:codexTop', attacker, {
        --         title = 'KODEX PORUSEN',
        --         desc = 'Porušil jsi kodex policie.'
        --     })
        -- end

        KGW.addStars(attacker, add, reason)

        -- po
        local afterStars = tonumber(Player(attacker).state.kg_wanted or 0) or 0
        local realAdded = afterStars - beforeStars
        if realAdded < 0 then realAdded = 0 end

        TriggerClientEvent('kg_wanted:crimeNotify', attacker, {
            added = realAdded,
            total = afterStars,
            reason = reason,
            extra = extra
        })
        return
    end

    -- =========================================
    -- KILL / HURT / RUNOVER (mají victim)
    -- =========================================
    local victim = tonumber(data.victim or -1)
    if victim <= 0 or not GetPlayerName(victim) then return end
    if attacker == victim then return end

    -- distance limit (zachováno)
    if dist > 200.0 then return end

    local victimStars = tonumber(Player(victim).state.kg_wanted or 0) or 0

    local add = 0
    local reason = ''
    local extra = ''

    if crimeType == 'kill' then
        add = (Config.Stars and Config.Stars.KillPlayer) or 2
        reason = 'Vražda hráče'

    elseif crimeType == 'hurt' then
        -- cooldown hurt (zachováno)
        local now = os.time()
        local cd = KGW.HurtCooldown[attacker] or 0
        if now - cd < (Config.HurtCooldownSeconds or 20) then return end
        KGW.HurtCooldown[attacker] = now

        add = (Config.Stars and Config.Stars.HurtPlayer) or 1
        reason = 'Napadení hráče'

    elseif crimeType == 'runover' then
        -- runover cooldown (nové, ale v duchu tvého hurt)
        local now = os.time()
        local cd = KGW.RunoverCooldown[attacker] or 0
        if now - cd < 4 then return end
        KGW.RunoverCooldown[attacker] = now

        local died = (data.died == true)
        if died then
            add = (Config.Stars and Config.Stars.KillPlayer) or 2
            reason = 'Přejetí hráče (smrt)'
        else
            add = (Config.Stars and Config.Stars.RunOverPlayer) or 1
            reason = 'Přejetí hráče vozidlem'
        end
    end

    if add <= 0 then return end

    -- ✅ Policie nedostává wanted za zásah proti hráči, který už je wanted
    if isCop and victimStars > 0 then
        return
    end

    -- před
    local beforeStars = tonumber(Player(attacker).state.kg_wanted or 0) or 0

    -- POLICE CODEX LOGIKA:
    -- Policajt útočí na nevinného -> bonus hvězdy + okamžité odebrání jobu
    if isCop and victimStars <= 0 then
        add = add + ((Config.Stars and Config.Stars.PoliceExtraStars) or 1)

        -- shodit z práce
        xAttacker.setJob(Config.UnemployedJob, 0)
        Player(attacker).state.kg_police_duty = false

        extra = 'Porušil jsi kodex policie.\n(odebrán police job)'
        TriggerClientEvent('kg_wanted:codexTop', attacker, {
            title = 'KODEX PORUSEN',
            desc = 'Porušil jsi kodex policie.'
        })
    end

    KGW.addStars(attacker, add, reason)

    -- po
    local afterStars = tonumber(Player(attacker).state.kg_wanted or 0) or 0
    local realAdded = afterStars - beforeStars
    if realAdded < 0 then realAdded = 0 end

    -- ✅ OX_LIB notify nahoře uprostřed s reason
    TriggerClientEvent('kg_wanted:crimeNotify', attacker, {
        added = realAdded,
        total = afterStars,
        reason = reason,
        extra = extra
    })
end)
