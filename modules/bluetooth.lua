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
      -- local chrome = hs.application.get("Google Chrome")
      -- print(chrome)
      -- if chrome ~= nil then
      --     chrome:kill()
      -- end
    elseif (eventType == hs.caffeinate.watcher.screensDidUnlock) then
      print("screensDidUnlock")
      bluetoothSwitch(1)
      -- switch_wallpaper()
    end
end

caffeinateWatcher = hs.caffeinate.watcher.new(caffeinateCallback)
caffeinateWatcher:start()