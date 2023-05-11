require("modules.menu")
require("modules.reload")

--锁屏
hs.hotkey.bind({'ctrl', 'alt', 'cmd'}, 'L', function() hs.caffeinate.startScreensaver() end)

--休眠自动关闭蓝牙
function bluetoothSwitch(state)
    -- state: 0(off), 1(on)
    cmd = "/usr/local/bin/blueutil --power "..(state)
    result = hs.osascript.applescript(string.format('do shell script "%s"', cmd))
end

function caffeinateCallback(eventType)
    if (eventType == hs.caffeinate.watcher.screensDidSleep) then
      print("screensDidSleep")
    elseif (eventType == hs.caffeinate.watcher.screensDidWake) then
      print("screensDidWake")
    elseif (eventType == hs.caffeinate.watcher.screensDidLock) then
      print("screensDidLock")
    --   switch_wallpaper()
      bluetoothSwitch(0)
      local chrome = hs.application.get("Google Chrome")
      print(chrome)
      if chrome ~= nil then
          chrome:kill()
      end
    elseif (eventType == hs.caffeinate.watcher.screensDidUnlock) then
      print("screensDidUnlock")
      bluetoothSwitch(1)
      -- switch_wallpaper()
    end
end

caffeinateWatcher = hs.caffeinate.watcher.new(caffeinateCallback)
caffeinateWatcher:start()

-- 当连接上shoot开头的wifi时关闭声音
function ssidChanged()
  local wifiName = hs.wifi.currentNetwork()
  if wifiName ~= nil and string.match(wifiName, "^shoot") then
      hs.audiodevice.defaultOutputDevice():setMuted(true)
  else
      hs.audiodevice.defaultOutputDevice():setMuted(false)
  end
end

wifiWatcher = hs.wifi.watcher.new(ssidChanged)
wifiWatcher:start()

-- require("modules.clip")