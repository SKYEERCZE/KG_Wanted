function KGW.isHappyHourNow()
    if not (Config.HappyHour and Config.HappyHour.Enabled) then return false end

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
