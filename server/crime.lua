-- KG_Wanted/server/crime.lua
-- Server-side adding stars for:
--  - kill player
--  - runover player
-- No hurt/punch.

local runoverCd = {} -- [src] = os.time()

local function dbg(...)
    if Config.Debug then
        print('[KG_Wanted][crime]', ...)
    end
end

RegisterNetEvent('kg_wanted:crime', function(data)
    local attacker = source
    if type(data) ~= 'table' then return end

    local crimeType = tostring(data.type or '')
    local victim = tonumber(data.victim or -1) or -1
    local dist = tonumber(data.dist or 9999.0) or 9999.0
    local died = (data.died == true)

    dbg('incoming', attacker, crimeType, 'victim', victim, 'dist', dist, 'died', died)

    if victim <= 0 or not GetPlayerName(victim) then return end
    if attacker == victim then return end
    if dist > 450.0 then return end

    local xAttacker = KGW.ESX.GetPlayerFromId(attacker)
    if not xAttacker then return end

    local isCop = KGW.isPolice(xAttacker)
    local victimStars = tonumber(Player(victim).state.kg_wanted or 0) or 0

    local add = 0
    local reason = ''
    local extra = ''

    if crimeType == 'kill' then
        -- policajt zabije wanted = bez hvězd
        if isCop and victimStars > 0 then
            dbg('police killed wanted -> no stars')
            return
        end

        add = tonumber((Config.Stars and Config.Stars.KillPlayer) or 2) or 2
        reason = 'Vražda hráče'

    elseif crimeType == 'runover' then
        -- cooldown ať to nespamuje
        local now = os.time()
        if (runoverCd[attacker] or 0) + 4 > now then return end
        runoverCd[attacker] = now

        -- policajt přejede wanted = bez hvězd
        if isCop and victimStars > 0 then
            dbg('police ran over wanted -> no stars')
            return
        end

        if died then
            add = tonumber((Config.Stars and Config.Stars.KillPlayer) or 2) or 2
            reason = 'Přejetí hráče (smrt)'
        else
            add = tonumber((Config.Stars and Config.Stars.RunOverPlayer) or 1) or 1
            reason = 'Přejetí hráče vozidlem'
        end
    else
        return
    end

    if add <= 0 then return end

    local beforeStars = tonumber(Player(attacker).state.kg_wanted or 0) or 0

    -- Police codex: policajt ublíží nevinnému (0★) -> bonus + vyhazov
    if isCop and victimStars <= 0 then
        add = add + (tonumber((Config.Stars and Config.Stars.PoliceExtraStars) or 1) or 1)

        xAttacker.setJob(Config.UnemployedJob or 'unemployed', 0)
        Player(attacker).state.kg_police_duty = false

        extra = 'Porušil jsi kodex policie.\n(odebrán police job)'
        TriggerClientEvent('kg_wanted:codexTop', attacker, {
            title = 'KODEX PORUSEN',
            desc = 'Porušil jsi kodex policie.'
        })
    end

    dbg('addStars', attacker, add, reason)
    KGW.addStars(attacker, add, reason)

    local afterStars = tonumber(Player(attacker).state.kg_wanted or 0) or 0
    local realAdded = afterStars - beforeStars
    if realAdded < 0 then realAdded = 0 end

    TriggerClientEvent('kg_wanted:crimeNotify', attacker, {
        added = realAdded,
        total = afterStars,
        reason = reason,
        extra = extra
    })
end)
