RegisterNetEvent('kg_wanted:rewardBig', function(amount, mult)
    amount = tonumber(amount) or 0
    mult = tonumber(mult) or 1.0

    local title = '~b~ZLOCINEC DOPADEN~s~'
    local subtitle = (mult and mult > 1.01)
        and ('Odmena: ~g~$%s~s~  ~b~(HAPPY HOURS x%s)~s~'):format(amount, mult)
        or  ('Odmena: ~g~$%s~s~'):format(amount)

    KGW.showBigWasted(title, subtitle, 5000)
end)

RegisterNetEvent('kg_wanted:lawyerBig', function(amount, removed, newStars, mult)
    amount = tonumber(amount) or 0
    removed = tonumber(removed) or 0
    newStars = tonumber(newStars) or 0
    mult = tonumber(mult) or 1.0

    local title = '~g~OBHAJOBA USPESNA~s~'
    local subtitle = (mult and mult > 1.01)
        and ('Sundano: ~w~%d*~s~ | Nove: ~w~%d*~s~\nOdmena: ~g~$%s~s~  ~b~(HAPPY HOURS x%s)~s~'):format(removed, newStars, amount, mult)
        or  ('Sundano: ~w~%d*~s~ | Nove: ~w~%d*~s~\nOdmena: ~g~$%s~s~'):format(removed, newStars, amount)

    KGW.showBigWasted(title, subtitle, 5000)
end)

RegisterNetEvent('kg_wanted:lawyerDenied', function(remainingSec)
    remainingSec = tonumber(remainingSec) or 0
    local mm = math.floor(remainingSec / 60)
    local ss = remainingSec % 60
    lib.notify({ type = 'error', description = ('Cooldown: %02d:%02d'):format(mm, ss), position = 'top' })
end)

RegisterNetEvent('kg_wanted:codexTop', function(data)
    data = data or {}
    local title = data.title or 'KODEX PORUSEN'
    local desc  = data.desc  or 'Porušil jsi kodex policie.'
    KGW.showBigWasted(('~r~%s~s~'):format(title), desc, 5000)
end)

-- ✅ NOUZOVÉ PROPUŠTĚNÍ
RegisterNetEvent('kg_wanted:forceRelease', function()
    if not KGW.jailActive then return end
    KGW.jailEndTime = 0
end)

-- ✅ NOVÉ: prohřešky / získání hvězd -> ox_lib notify nahoře uprostřed
RegisterNetEvent('kg_wanted:crimeNotify', function(payload)
    payload = payload or {}
    local added = tonumber(payload.added or 0) or 0
    local total = tonumber(payload.total or 0) or 0
    local reason = tostring(payload.reason or 'Přestupek')
    local extra = tostring(payload.extra or '')

    local title
    if added > 0 then
        title = ('🚨 WANTED +%d★  (celkem %d★)'):format(added, total)
    else
        title = ('🚨 WANTED  (celkem %d★)'):format(total)
    end

    local desc = reason
    if extra ~= '' then
        desc = desc .. '\n' .. extra
    end

    lib.notify({
        title = title,
        description = desc,
        type = 'error',
        position = 'top',
        duration = 6500,
    })
end)
