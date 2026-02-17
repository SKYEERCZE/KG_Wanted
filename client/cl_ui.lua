KGW = KGW or {}

local function showBigWasted(title, subtitle, durationMs)
    durationMs = tonumber(durationMs) or 5000

    local scaleform = RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
    while not HasScaleformMovieLoaded(scaleform) do Wait(0) end

    BeginScaleformMovieMethod(scaleform, 'SHOW_SHARD_WASTED_MP_MESSAGE')
    PushScaleformMovieMethodParameterString(title)
    PushScaleformMovieMethodParameterString(subtitle)
    PushScaleformMovieMethodParameterInt(5)
    EndScaleformMovieMethod()

    local endTime = GetGameTimer() + durationMs
    while GetGameTimer() < endTime do
        DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
        Wait(0)
    end

    SetScaleformMovieAsNoLongerNeeded(scaleform)
end

KGW.UI = KGW.UI or {}
KGW.UI.showBigWasted = showBigWasted

RegisterNetEvent(KGW.Const.Events.RewardBig, function(amount, mult)
    amount = tonumber(amount) or 0
    mult = tonumber(mult) or 1.0

    local title = '~b~ZLOCINEC DOPADEN~s~'
    local subtitle = (mult and mult > 1.01)
        and ('Odmena: ~g~$%s~s~  ~b~(HAPPY HOUR x%s)~s~'):format(amount, mult)
        or  ('Odmena: ~g~$%s~s~'):format(amount)

    showBigWasted(title, subtitle, 5000)
end)

RegisterNetEvent(KGW.Const.Events.LawyerBig, function(amount, removed, newStars, mult)
    amount = tonumber(amount) or 0
    removed = tonumber(removed) or 0
    newStars = tonumber(newStars) or 0
    mult = tonumber(mult) or 1.0

    local title = '~g~OBHAJOBA USPELA~s~'
    local subtitle = (mult and mult > 1.01)
        and ('Sundano: ~w~%d★~s~ | Nove: ~w~%d★~s~\nOdmena: ~g~$%s~s~  ~b~(HAPPY HOUR x%s)~s~'):format(removed, newStars, amount, mult)
        or  ('Sundano: ~w~%d★~s~ | Nove: ~w~%d★~s~\nOdmena: ~g~$%s~s~'):format(removed, newStars, amount)

    showBigWasted(title, subtitle, 5000)
end)

RegisterNetEvent(KGW.Const.Events.LawyerDenied, function(remainingSec)
    remainingSec = tonumber(remainingSec) or 0
    local mm = math.floor(remainingSec / 60)
    local ss = remainingSec % 60
    lib.notify({ type = 'error', description = ('Cooldown: %02d:%02d'):format(mm, ss) })
end)

RegisterNetEvent(KGW.Const.Events.CodexTop, function(data)
    data = data or {}
    local title = data.title or 'KODEX PORUSEN'
    local desc  = data.desc  or 'Porusil jsi kodex policie.'
    showBigWasted(('~r~%s~s~'):format(title), desc, 5000)
end)
