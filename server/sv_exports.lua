KGW = KGW or {}

exports('GetStars', function(src)
    return KGW.Wanted.getStars(tonumber(src))
end)

exports('SetStars', function(src, stars, reason)
    return KGW.Wanted.setStars(tonumber(src), tonumber(stars) or 0, tostring(reason or ''))
end)

exports('AddStars', function(src, add, reason)
    return KGW.Wanted.addStars(tonumber(src), tonumber(add) or 0, tostring(reason or ''))
end)

exports('ClearWanted', function(src)
    return KGW.Wanted.clearWanted(tonumber(src))
end)

exports('IsWanted', function(src)
    local s = select(1, KGW.Wanted.getStars(tonumber(src)))
    return (tonumber(s) or 0) > 0
end)
