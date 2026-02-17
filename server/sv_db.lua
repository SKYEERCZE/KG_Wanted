KGW = KGW or {}

local function dbg(...)
    if Config and Config.Debug then
        print('[KG_Wanted]', ...)
    end
end

local function clamp(v, a, b)
    v = tonumber(v) or 0
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    if v < a then return a end
    if v > b then return b end
    return v
end

local function isHappyHourNow()
    if not (Config and Config.HappyHour and Config.HappyHour.Enabled) then return false end

    local startH = tonumber(Config.HappyHour.StartHour) or 18
    local endH = tonumber(Config.HappyHour.EndHour) or 22
    local h = tonumber(os.date('%H')) or 0

    if startH == endH then return true end
    if startH < endH then
        return h >= startH and h < endH
    else
        return (h >= startH) or (h < endH)
    end
end

local function happyHourMultiplier()
    if isHappyHourNow() then
        return tonumber(Config.HappyHour.Multiplier) or 2.0
    end
    return 1.0
end

KGW.Utils = {
    dbg = dbg,
    clamp = clamp,
    isHappyHourNow = isHappyHourNow,
    happyHourMultiplier = happyHourMultiplier,
}
