-- KG_Wanted/server/crime.lua

local theftCd = {}   -- theftCd[src][plate] = os.time()
local runoverCd = {} -- runoverCd[src] = os.time()

local function plateOfVeh(vehNetId)
    local ent = NetworkGetEntityFromNetworkId(vehNetId or 0)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        local p = GetVehicleNumberPlateText(ent)
        if p then return (p:gsub('%s+', '')) end
    end
    return nil
end

RegisterNetEvent('kg_wanted:crime', function(data)
    local attacker = source
    if type(data) ~= 'table' then return end

    local crimeType = tostring(data.type or '')
    local dist = tonumber(data.dist or 9999.0)
    if dist > 400.0 then return end

    local xAttacker = KGW.ESX.GetPlayerFromId(attacker)
    if not xAttacker then return end

    local isCop = KGW.isPolice(xAttacker)

    -- =========================
    -- 1) KILL PLAYER
    -- =========================
    if crimeType == 'kill' then
        local victim = tonumber(data.victim or -1)
        if victim <= 0 or not GetPlayerName(victim) then return end
        if attacker == victim then return end

        local victimStars = tonumber(Player(victim).state.kg_wanted or 0) or 0

        -- ✅ policajt nezíská hvězdy za zabití wanted
        if isCop and victimStars > 0 then return end

        local add = tonumber(Config.Stars.KillPlayer or 2) or 2
        if add <= 0 then return end

        local beforeStars = tonumber(Player(attacker).state.kg_wanted or 0) or 0
        local extra = ''

        -- Police codex: policajt zabije nevinného
        if isCop and victimStars <= 0 then
            add = add + (Config.Stars.PoliceExtraStars or 1)

            xAttacker.setJob(Config.UnemployedJob, 0)
            Player(attacker).state.kg_police_duty = false

            extra = 'Porušil jsi kodex policie.\n(odebrán police job)'
            TriggerClientEvent('kg_wanted:codexTop', attacker, {
                title = 'KODEX PORUSEN',
                desc = 'Porušil jsi kodex policie.'
            })
        end

        KGW.addStars(attacker, add, 'Vražda hráče')

        local afterStars = tonumber(Player(attacker).state.kg_wanted or 0) or 0
        local realAdded = afterStars - beforeStars
        if realAdded < 0 then realAdded = 0 end

        TriggerClientEvent('kg_wanted:crimeNotify', attacker, {
            added = realAdded,
            total = afterStars,
            reason = 'Vražda hráče',
            extra = extra
        })
        return
    end

    -- =========================
    -- 2) RUN OVER PLAYER
    -- =========================
    if crimeType == 'runover' then
        local victim = tonumber(data.victim or -1)
        if victim <= 0 or not GetPlayerName(victim) then return end
        if attacker == victim then return end

        -- cooldown aby to nespamovalo při každém tiku dmg
        local now = os.time()
        if (runoverCd[attacker] or 0) + 5 > now then return end
        runoverCd[attacker] = now

        local victimStars = tonumber(Player(victim).state.kg_wanted or 0) or 0

        -- ✅ policajt nezíská hvězdy za přejetí wanted (zásah proti pachateli)
        if isCop and victimStars > 0 then return end

        local died = (data.died == true)

        local add
        local reason
        if died then
            add = tonumber(Config.Stars.KillPlayer or 2) or 2
            reason = 'Přejetí hráče (smrt)'
        else
            add = tonumber(Config.Stars.RunOverPlayer or 1) or 1
            reason = 'Přejetí hráče vozidlem'
        end
        if add <= 0 then return end

        local beforeStars = tonumber(Player(attacker).state.kg_wanted or 0) or 0
        local extra = ''

        -- Police codex: policajt přejede nevinného
        if isCop and victimStars <= 0 then
            add = add + (Config.Stars.PoliceExtraStars or 1)

            xAttacker.setJob(Config.UnemployedJob, 0)
            Player(attacker).state.kg_police_duty = false

            extra = 'Porušil jsi kodex policie.\n(odebrán police job)'
            TriggerClientEvent('kg_wanted:codexTop', attacker, {
                title = 'KODEX PORUSEN',
                desc = 'Porušil jsi kodex policie.'
            })
        end

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
        return
    end

    -- =========================
    -- 3) NPC VEHICLE THEFT
    -- =========================
    if crimeType == 'veh_theft_npc' then
        local vehNetId = tonumber(data.vehNetId or 0) or 0
        if vehNetId <= 0 then return end

        local add = tonumber(Config.Stars.StealNpcVehicle or 1) or 1
        if add <= 0 then return end

        local p = plateOfVeh(vehNetId) or ('net:' .. tostring(vehNetId))

        theftCd[attacker] = theftCd[attacker] or {}
        local now = os.time()
        if (theftCd[attacker][p] or 0) + 60 > now then
            -- 60s cooldown na stejné auto, ať to nejde farmit
            return
        end
        theftCd[attacker][p] = now

        local beforeStars = tonumber(Player(attacker).state.kg_wanted or 0) or 0
        KGW.addStars(attacker, add, 'Krádež vozidla (NPC)')

        local afterStars = tonumber(Player(attacker).state.kg_wanted or 0) or 0
        local realAdded = afterStars - beforeStars
        if realAdded < 0 then realAdded = 0 end

        TriggerClientEvent('kg_wanted:crimeNotify', attacker, {
            added = realAdded,
            total = afterStars,
            reason = 'Krádež vozidla (NPC)',
            extra = ''
        })
        return
    end

    -- ❌ hurt / punch / běžný hit se ignoruje
end)
