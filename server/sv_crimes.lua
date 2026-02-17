KGW = KGW or {}

local ESX = KGW.Wanted._ESX
local HurtCooldown = KGW.Wanted._HurtCooldown

RegisterNetEvent(KGW.Const.Events.Crime, function(data)
    local attacker = source
    if type(data) ~= 'table' then return end

    local victim = tonumber(data.victim or -1)
    local crimeType = tostring(data.type or '')
    local dist = tonumber(data.dist or 9999.0)

    if victim <= 0 or not GetPlayerName(victim) then return end
    if attacker == victim then return end
    if dist > 200.0 then return end

    local xAttacker = ESX.GetPlayerFromId(attacker)
    if not xAttacker then return end

    local isCop = KGW.Wanted.isPolice(xAttacker)
    local victimStars = tonumber(Player(victim).state.kg_wanted or 0) or 0

    local add = 0
    local reason = ''

    if crimeType == 'kill' then
        add = Config.Stars.KillPlayer or 2
        reason = 'Vrazda hrace'
    elseif crimeType == 'hurt' then
        local now = os.time()
        local cd = HurtCooldown[attacker] or 0
        if now - cd < (Config.HurtCooldownSeconds or 20) then return end
        HurtCooldown[attacker] = now

        add = Config.Stars.HurtPlayer or 1
        reason = 'Napadeni hrace'
    else
        return
    end

    if add <= 0 then return end

    -- POLICE CODEX: jen pokud útočí na nevinného (victimStars <= 0)
    if isCop and victimStars <= 0 then
        add = add + (Config.Stars.PoliceExtraStars or 1)

        xAttacker.setJob(Config.UnemployedJob, 0)
        Player(attacker).state.kg_police_duty = false

        TriggerClientEvent(KGW.Const.Events.CodexTop, attacker, {
            title = 'KODEX PORUSEN',
            desc = 'Porusil jsi kodex policie.'
        })
    end

    KGW.Wanted.addStars(attacker, add, reason)
end)
