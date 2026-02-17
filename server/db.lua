-- ===== DB Abstraction (oxmysql / mysql-async) =====
local function db_driver()
    local d = (Config.Persistence and Config.Persistence.Driver) or 'auto'
    if d ~= 'auto' then return d end
    if GetResourceState('oxmysql') == 'started' then return 'oxmysql' end
    if GetResourceState('mysql-async') == 'started' then return 'mysql-async' end
    return 'none'
end

function KGW.db_exec(query, params)
    local driver = db_driver()
    params = params or {}

    if driver == 'oxmysql' then
        return exports.oxmysql:execute(query, params)
    elseif driver == 'mysql-async' then
        MySQL.Async.execute(query, params)
        return true
    else
        KGW.dbg('DB disabled / driver not found. Query skipped:', query)
        return false
    end
end

function KGW.db_fetchAll(query, params, cb)
    local driver = db_driver()
    params = params or {}

    if driver == 'oxmysql' then
        local res = exports.oxmysql:query_async(query, params)
        cb(res or {})
    elseif driver == 'mysql-async' then
        MySQL.Async.fetchAll(query, params, function(res)
            cb(res or {})
        end)
    else
        cb({})
    end
end
