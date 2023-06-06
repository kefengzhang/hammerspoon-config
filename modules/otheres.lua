-- 其他

require 'modules.shortcut'


-- ⌘⌃⌥L 锁屏
hs.hotkey.bind(otheres.lock_screen.prefix, otheres.lock_screen.key,otheres.lock_screen.message, function() hs.caffeinate.startScreensaver() end)
