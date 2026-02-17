fx_version 'cerulean'
game 'gta5'

name 'KG_Wanted'
author 'Kaficko Gaming'
description 'Simple GTA-style wanted stars + police send-to-jail interaction (ESX job)'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'ox_lib',
    'es_extended',
    'oxmysql',
    'ox_target'
}
