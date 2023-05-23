
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