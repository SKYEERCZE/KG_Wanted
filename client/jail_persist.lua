local jailThreadRunning = false
local jailEndAt = 0

local function getJailCoords()
    -- uprav si podle sebe (nebo to dej do configu)
    if Config and Config.JailCoords then
        return vec3(Config.JailCoords.x, Config.JailCoords.y, Config.JailCoords.z)
    end
    -- fallback (když zapomeneš)
    return vec3(458.6, -994.0, 24.9)
end

local function teleportToJail()
    local ped = PlayerPedId()
    local coords = getJailCoords()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
end

local function startJailLoop()
    if jailThreadRunning then return end
    jailThreadRunning = true

    CreateThread(function()
        while jailEndAt > 0 do
            Wait(500)

            local now = os.time()
            if now >= jailEndAt then
                jailEndAt = 0
                break
            end

            -- když se pokusí utéct / respawn / relog spawnne mimo -> přitáhneme zpět
            local ped = PlayerPedId()
            if ped ~= 0 and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                local jail = getJailCoords()
                if #(coords - jail) > 60.0 then
                    teleportToJail()
                end
            end
        end

        jailThreadRunning = false
    end)
end

RegisterNetEvent('kg_wanted:jail:apply', function(endAt, reason)
    endAt = tonumber(endAt or 0) or 0
    if endAt <= 0 then return end

    jailEndAt = endAt

    -- počkej na ped, pak teleport
    CreateThread(function()
        local tries = 0
        while tries < 30 do
            tries += 1
            local ped = PlayerPedId()
            if ped ~= 0 and DoesEntityExist(ped) then break end
            Wait(100)
        end

        teleportToJail()
        startJailLoop()

        lib.notify({
            type = 'error',
            position = 'top',
            description = ('Jsi ve vězení: %s'):format(tostring(reason or 'VĚZENÍ'))
        })
    end)
end)

RegisterNetEvent('kg_wanted:jail:clear', function()
    jailEndAt = 0
end)

-- když client naběhne a statebag už je nastavený (např. relog), tak to aplikuj
CreateThread(function()
    Wait(2000)
    local endAt = tonumber(LocalPlayer.state.kg_jail_endAt or 0) or 0
    if endAt > os.time() then
        TriggerEvent('kg_wanted:jail:apply', endAt, LocalPlayer.state.kg_jail_reason or 'VĚZENÍ')
    end
end)
