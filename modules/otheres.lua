-- 其他

require 'modules.shortcut'


-- ⌘⌃⌥L 锁屏
hs.hotkey.bind(otheres.lock_screen.prefix, otheres.lock_screen.key,otheres.lock_screen.message, function() hs.caffeinate.startScreensaver() end)
-- alt + o 
hs.hotkey.bind(otheres.open_vpn.prefix, otheres.open_vpn.key,otheres.open_vpn.message, function() hs.execute("/usr/local/bin/warp-cli connect") end)
-- alt + g
hs.hotkey.bind(otheres.close_vpn.prefix, otheres.close_vpn.key,otheres.close_vpn.message, function() hs.execute("/usr/local/bin/warp-cli disconnect") end)
