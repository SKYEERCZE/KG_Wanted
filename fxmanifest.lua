fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'KafickoGaming'
description 'KG_Wanted modular'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/sh_constants.lua',
    'shared/sh_utils.lua',
}

server_scripts {
    'server/sv_db.lua',
    'server/sv_wanted.lua',
    'server/sv_rewards.lua',
    'server/sv_crimes.lua',
    'server/sv_police.lua',
    'server/sv_lawyer.lua',
    'server/sv_exports.lua',
    'server/sv_main.lua',
}

client_scripts {
    'client/cl_main.lua',
    'client/cl_ui.lua',
    'client/cl_crimes.lua',
    'client/cl_3d.lua',
    'client/cl_police_zones.lua',
    'client/cl_target.lua',
    'client/cl_markers.lua',
    'client/cl_jail.lua',
    'client/cl_exports.lua',
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target' 
}
