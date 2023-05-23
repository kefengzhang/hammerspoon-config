require("modules.menu")
require("modules.reload")
require("modules.bluetooth")
require("modules.wifi")

--锁屏
hs.hotkey.bind({'ctrl', 'alt', 'cmd'}, 'L', function() hs.caffeinate.startScreensaver() end)

-- require("modules.clip")