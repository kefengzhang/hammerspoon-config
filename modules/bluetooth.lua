-- 休眠自动关闭蓝牙
function bluetoothSwitch(state)
    -- state: 0(off), 1(on)
    local cmd = "/usr/local/bin/blueutil --power " .. tostring(state)
    local result = hs.osascript.applescript(string.format('do shell script "%s"', cmd))
    hs.printf("蓝牙切换：%s", tostring(state))
    hs.printf("蓝牙切换结果：%s", tostring(result))
end

-- 休眠自动关闭代理
function closeVPN()
    local cmd = "/usr/local/bin/warp-cli disconnect"
    local result = hs.osascript.applescript(string.format('do shell script "%s"', cmd))
    hs.printf("VPN 断开")
    hs.printf("VPN 断开结果：%s", tostring(result))
end

function caffeinateCallback(eventType)
    if (eventType == hs.caffeinate.watcher.screensDidSleep) then
      hs.printf("屏幕已休眠")
    elseif (eventType == hs.caffeinate.watcher.screensDidWake) then
      hs.printf("屏幕已唤醒")
    elseif (eventType == hs.caffeinate.watcher.screensDidLock) then
      hs.printf("屏幕已锁定")
    --   switch_wallpaper()
      -- bluetoothSwitch(0)
      -- closeVPN()
      -- local chrome = hs.application.get("Google Chrome")
      -- print(chrome)
      -- if chrome ~= nil then
      --     chrome:kill()
      -- end
    elseif (eventType == hs.caffeinate.watcher.screensDidUnlock) then
      hs.printf("屏幕已解锁")
      -- bluetoothSwitch(1)
      -- switch_wallpaper()
    end
end

caffeinateWatcher = hs.caffeinate.watcher.new(caffeinateCallback)
caffeinateWatcher:start()