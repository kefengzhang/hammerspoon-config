-- 鼠标侧键：默认「浏览器」⌘[ / ⌘]；按 bundle id 指定快捷键见 **BUNDLE_NAV_INLINE**（优先）与 BUNDLE_NAV_PROFILE / NAV_PROFILES
-- 由菜单项「JOMAA鼠标映射」勾选后加载（与其它功能模块相同）

local log = hs.logger.new("mouseSideBtn", "info")

-- true：启动提示、轮询、宽监听、自动诊断（平时请保持 false）
local DEBUG_MOUSE_SIDE = false
-- true：侧键命中时始终在 Console 输出英文日志（用于排查“失效”场景）
local ALWAYS_LOG_SIDE_KEYS = true
-- 侧键日志节流（秒）；避免长按/抖动导致刷屏
local SIDE_LOG_THROTTLE_SEC = 0.12
-- 首次重载后自动跑一次短时诊断；确认完成后改为 false
local AUTO_DIAG_ON_LOAD = false
-- JOMAA 实测：侧键被模拟为方向键 keyDown（见 .mouse_side_diag_last.txt）；若后退/前进反了，对调下面两个 keycode
-- 注意：键盘左/右方向键也是 123/124，会被一并映射；若需区分键盘与鼠标请用 Karabiner 按设备映射
local KEYCODE_SIDE_BACK = 124
local KEYCODE_SIDE_FORWARD = 123
-- 与 otherMouse 的 mouseEventButtonNumber 一致，默认 3/4
local BTN_BACK = 3
local BTN_FORWARD = 4

-- 具名方案：仅当「多个 App 共用一套键」时在 BUNDLE_NAV_PROFILE 里引用；未命中 inline/profile 时用 browser
local NAV_PROFILES = {
    browser = {
        back = { mods = { "cmd" }, key = "[" },
        forward = { mods = { "cmd" }, key = "]" },
    },
}

-- 方式一：bundle id → NAV_PROFILES 中的方案名（无 Cursor 时可留空仅写注释）
-- bundle id：前台打开该 App 后执行 hs.application.frontmostApplication():bundleID()
local BUNDLE_NAV_PROFILE = {
    -- ["com.example.Shared"] = "browser",
}

-- 方式二（优先）：按 bundle id 直接写 back / forward。新增 App 时复制下面 Cursor 块改 bundle id 与 mods/key 即可
-- mods：cmd、alt、shift、ctrl、fn；key：与 hs.eventtap.keyStroke 第二参数一致（如 "up"、"[", "return"）

-- Cursor / VS Code 系：工作台后退 ⌃⌘↑、前进 ⌃⌘↓（多 bundle 共用同一表，改一处即可）
local CURSOR_LIKE_SIDE_NAV = {
    back = { mods = { "ctrl", "cmd" }, key = "up" },
    forward = { mods = { "ctrl", "cmd" }, key = "down" },
}

local BUNDLE_NAV_INLINE = {
    ["com.cursor.Cursor"] = CURSOR_LIKE_SIDE_NAV,
    ["com.todesktop.230313mzl4w4u92"] = CURSOR_LIKE_SIDE_NAV,
    ["com.microsoft.VSCode"] = CURSOR_LIKE_SIDE_NAV,
    ["com.vscodium.VSCodium"] = CURSOR_LIKE_SIDE_NAV,

    -- 复制模板（另起 App 时取消注释并填写 bundle id）：
    -- ["com.apple.Terminal"] = {
    --     back = { mods = { "cmd" }, key = "[" },
    --     forward = { mods = { "cmd" }, key = "]" },
    -- },
}

-- 根据前台应用解析应使用哪套侧键快捷键（inline > 具名 profile > browser）
local function navProfileForApp(app)
    if not app then
        return NAV_PROFILES.browser
    end
    local bid = app:bundleID()
    if not bid then
        return NAV_PROFILES.browser
    end
    local inline = BUNDLE_NAV_INLINE[bid]
    if type(inline) == "table" and inline.back and inline.forward then
        return inline
    end
    local pname = BUNDLE_NAV_PROFILE[bid]
    if pname and NAV_PROFILES[pname] then
        return NAV_PROFILES[pname]
    end
    return NAV_PROFILES.browser
end

-- 在下一帧向前台应用发送「后退」或「前进」对应快捷键（direction 为 "back" | "forward"）
local function postSideNav(direction)
    hs.timer.doAfter(0, function()
        local app = hs.application.frontmostApplication()
        local profile = navProfileForApp(app)
        local stroke = direction == "back" and profile.back or profile.forward
        local microDelay = 80000
        if app then
            hs.eventtap.keyStroke(stroke.mods, stroke.key, microDelay, app)
        else
            hs.eventtap.keyStroke(stroke.mods, stroke.key, microDelay)
        end
        if DEBUG_MOUSE_SIDE then
            log.i(
                "postSideNav "
                    .. direction
                    .. " profile bid="
                    .. tostring(app and app:bundleID())
                    .. " mods="
                    .. table.concat(stroke.mods, ",")
                    .. " key="
                    .. stroke.key
            )
        end
    end)
end

-- 侧键命中日志：始终输出英文（可节流），便于排查“监听未命中/命中但未生效”
local lastSideLogAt = 0
local function logSideKeyHit(source, phase, detail, direction)
    if not ALWAYS_LOG_SIDE_KEYS then
        return
    end
    local now = os.clock()
    if now - lastSideLogAt < SIDE_LOG_THROTTLE_SEC then
        return
    end
    lastSideLogAt = now

    local app = hs.application.frontmostApplication()
    local bid = app and app:bundleID() or "nil"
    local profile = navProfileForApp(app)
    local stroke = direction == "back" and profile.back or profile.forward
    log.i(
        string.format(
            "sideKey hit source=%s phase=%s %s direction=%s frontmostBundleID=%s send=%s+%s",
            tostring(source),
            tostring(phase),
            tostring(detail),
            tostring(direction),
            tostring(bid),
            table.concat(stroke.mods, "+"),
            tostring(stroke.key)
        )
    )
end

local prop = hs.eventtap.event.properties.mouseEventButtonNumber
local types = hs.eventtap.event.types

-- 安全读取滚轮相关属性（不同系统上字段名可能略有差异）
local function scrollDeltas(e)
    local p = hs.eventtap.event.properties
    local a1 = e:getProperty(p.scrollWheelEventDeltaAxis1)
    local a2 = e:getProperty(p.scrollWheelEventDeltaAxis2)
    local pt1 = e:getProperty(p.scrollWheelEventPointDeltaAxis1)
    local pt2 = e:getProperty(p.scrollWheelEventPointDeltaAxis2)
    return a1 or 0, a2 or 0, pt1 or 0, pt2 or 0
end

-- 将 Quartz 事件类型号映射为可读名称（用于诊断摘要）
local function eventTypeName(tn)
    for name, val in pairs(types) do
        if val == tn then
            return name
        end
    end
    return "type_" .. tostring(tn)
end

-- 主映射：otherMouseDown → ⌘[ / ⌘]（仅当未使用键码映射时注册；本鼠标实测走键码 123/124）
local mouseSideRemapTap = nil
local function setupRemapTap()
    if KEYCODE_SIDE_BACK or KEYCODE_SIDE_FORWARD then
        log.i("otherMouse remap skipped (using KEYCODE_SIDE_* remap)")
        return
    end
    mouseSideRemapTap = hs.eventtap.new({ types.otherMouseDown, types.otherMouseUp }, function(e)
        local t = e:getType()
        local isDown = (t == types.otherMouseDown)
        local btn = e:getProperty(prop)
        if isDown then
            log.i("otherMouseDown button=" .. tostring(btn))
            if DEBUG_MOUSE_SIDE then
                hs.alert.show("otherMouse 按下 · 编号=" .. tostring(btn), 1.2)
            end
            if btn == BTN_BACK then
                logSideKeyHit("otherMouse", "down", "button=" .. tostring(btn), "back")
                postSideNav("back")
                return true
            elseif btn == BTN_FORWARD then
                logSideKeyHit("otherMouse", "down", "button=" .. tostring(btn), "forward")
                postSideNav("forward")
                return true
            end
        else
            log.i("otherMouseUp button=" .. tostring(btn))
            if btn == BTN_BACK then
                logSideKeyHit("otherMouse", "up", "button=" .. tostring(btn), "back")
            elseif btn == BTN_FORWARD then
                logSideKeyHit("otherMouse", "up", "button=" .. tostring(btn), "forward")
            end
        end
        return false
    end)
    mouseSideRemapTap:start()
    if not mouseSideRemapTap:isEnabled() then
        log.e("Remap eventtap failed to enable — check Accessibility for Hammerspoon")
        hs.alert.show("侧键映射未启用：请在「辅助功能」中允许 Hammerspoon", 4)
    else
        log.i("Remap eventtap enabled; back=" .. BTN_BACK .. " forward=" .. BTN_FORWARD)
    end
end

-- 侧键表现为 keyDown/keyUp（固件模拟方向键）时：吞掉原键事件再按当前 App 配置发送快捷键；须同时拦截 keyUp
local keycodeRemapTap = nil

local function setupKeycodeRemap()
    if not KEYCODE_SIDE_BACK and not KEYCODE_SIDE_FORWARD then
        log.i("Keycode remap skipped (KEYCODE_SIDE_* not set)")
        return
    end
    keycodeRemapTap = hs.eventtap.new({ types.keyDown, types.keyUp }, function(e)
        local kc = e:getKeyCode()
        local isDown = (e:getType() == types.keyDown)
        if KEYCODE_SIDE_BACK and kc == KEYCODE_SIDE_BACK then
            if isDown then
                if DEBUG_MOUSE_SIDE then
                    log.i("keycode remap back kc=" .. tostring(kc))
                end
                logSideKeyHit("keycode", "down", "keyCode=" .. tostring(kc), "back")
                postSideNav("back")
            else
                logSideKeyHit("keycode", "up", "keyCode=" .. tostring(kc), "back")
            end
            return true
        end
        if KEYCODE_SIDE_FORWARD and kc == KEYCODE_SIDE_FORWARD then
            if isDown then
                if DEBUG_MOUSE_SIDE then
                    log.i("keycode remap forward kc=" .. tostring(kc))
                end
                logSideKeyHit("keycode", "down", "keyCode=" .. tostring(kc), "forward")
                postSideNav("forward")
            else
                logSideKeyHit("keycode", "up", "keyCode=" .. tostring(kc), "forward")
            end
            return true
        end
        return false
    end)
    keycodeRemapTap:start()
    if not keycodeRemapTap:isEnabled() then
        log.e("Keycode remap eventtap failed to enable — check Accessibility / Input Monitoring for Hammerspoon")
        hs.alert.show("侧键键码映射未启用：请在「辅助功能」中允许 Hammerspoon（若仍无效再检查「输入监控」）", 5)
    else
        log.i("Keycode remap tap started (back=" .. tostring(KEYCODE_SIDE_BACK) .. " forward=" .. tostring(KEYCODE_SIDE_FORWARD) .. ")")
    end
end

-- 宽监听：侧键有时表现为滚轮或系统定义事件
local mouseSideBroadTap = nil
local lastScrollLogAt = 0
local function setupBroadDebugTap()
    if not DEBUG_MOUSE_SIDE then
        return
    end
    mouseSideBroadTap = hs.eventtap.new({
        types.scrollWheel,
        types.systemDefined,
    }, function(e)
        local t = e:getType()
        if t == types.scrollWheel then
            local a1, a2, p1, p2 = scrollDeltas(e)
            local now = os.clock()
            if now - lastScrollLogAt > 0.35 then
                lastScrollLogAt = now
                log.i(string.format("scrollWheel axis=(%.3f,%.3f) point=(%.3f,%.3f)", a1, a2, p1, p2))
            end
            if math.abs(a2) > 0.01 or math.abs(p2) > 0.01 then
                hs.alert.show(
                    string.format("scrollWheel（疑为侧键）\naxis=(%.2f,%.2f)\npoint=(%.2f,%.2f)", a1, a2, p1, p2),
                    1.0
                )
            end
        elseif t == types.systemDefined then
            log.i("systemDefined event")
            hs.alert.show("systemDefined（可能是多媒体/特殊键）", 1.0)
        end
        return false
    end)
    mouseSideBroadTap:start()
    log.i("Broad debug tap started (scrollWheel + systemDefined)")
end

-- 轮询 pressedMouseButtons：部分设备不报 otherMouse，但 bitmask 会变
local lastButtonsDump = ""
local pollTimer = nil
local function setupMouseButtonPolling()
    if not DEBUG_MOUSE_SIDE then
        return
    end
    pollTimer = hs.timer.doEvery(0.06, function()
        local b = hs.eventtap.checkMouseButtons()
        local dump = hs.inspect(b)
        if dump ~= lastButtonsDump then
            lastButtonsDump = dump
            log.i("checkMouseButtons changed: " .. dump)
            hs.alert.show("鼠标键位状态变化（轮询）:\n" .. dump, 2.0)
        end
    end)
    log.i("Mouse button polling started (debug only)")
end

-- 诊断结果固定写入路径（勿用 ~ 缩写；部分环境下需展开 HOME）
local function diagFilePath()
    return (os.getenv("HOME") or "") .. "/.hammerspoon/.mouse_side_diag_last.txt"
end

-- 模块是否加载成功（与诊断结果分文件，避免重载时用 module_loaded 覆盖完整诊断）
local function pingFilePath()
    return (os.getenv("HOME") or "") .. "/.hammerspoon/.mouse_side_ping.txt"
end

-- 将文本写入诊断文件；失败时打英文日志
local function writeDiagFile(text)
    local path = diagFilePath()
    local f, openErr = io.open(path, "w")
    if not f then
        log.e("writeDiagFile failed path=" .. tostring(path) .. " err=" .. tostring(openErr))
        return false
    end
    f:write(text)
    f:close()
    log.i("writeDiagFile ok path=" .. path)
    return true
end

-- 仅写入 ping 文件，不覆盖 mouse_side_diag_last.txt
local function writePingFile(text)
    local path = pingFilePath()
    local f, openErr = io.open(path, "w")
    if not f then
        log.e("writePingFile failed path=" .. tostring(path) .. " err=" .. tostring(openErr))
        return false
    end
    f:write(text)
    f:close()
    log.i("writePingFile ok path=" .. path)
    return true
end

-- 诊断用事件类型：只监听与侧键/多媒体相关的常见类型（避免枚举 types 全表导致 eventtap 创建过慢或异常）
local function buildDiagnosticEventTypes()
    local t = types
    local names = {
        "keyDown",
        "keyUp",
        "flagsChanged",
        "scrollWheel",
        "systemDefined",
        "otherMouseDown",
        "otherMouseUp",
        "leftMouseDown",
        "leftMouseUp",
        "rightMouseDown",
        "rightMouseUp",
    }
    local list = {}
    local seen = {}
    for _, name in ipairs(names) do
        local v = t[name]
        if type(v) == "number" and not seen[v] then
            seen[v] = true
            table.insert(list, v)
        end
    end
    return list
end

-- 短时事件采样：捕获侧键可能被映射成的 keyDown / scrollWheel 等
local diagTap = nil
local diagTimer = nil
local function runSideButtonDiagnostics(sec)
    sec = sec or 12
    if diagTap then
        diagTap:stop()
        diagTap = nil
    end
    if diagTimer then
        diagTimer:stop()
        diagTimer = nil
    end

    writeDiagFile("status=starting\nsec=" .. tostring(sec) .. "\nmessage=diagnostic timer scheduled\n")

    log.i("runSideButtonDiagnostics begin sec=" .. tostring(sec))
    -- 先弹窗再创建 eventtap：若定时器从未执行到这里，说明调度有问题（见 init.lua 延后调度）
    hs.alert.show("侧键诊断：正在注册监听…", 2.5)
    if hs.notify then
        hs.notify
            .new({ title = "Hammerspoon 侧键诊断", informativeText = "监听注册中，随后请只按侧键" })
            :send()
    end

    local diagBuf = {}
    local watchList = buildDiagnosticEventTypes()
    local ok, err = pcall(function()
        diagTap = hs.eventtap.new(watchList, function(e)
            local typ = e:getType()
            local rec = {
                name = eventTypeName(typ),
                ty = typ,
            }
            if typ == types.keyDown or typ == types.keyUp then
                rec.kc = e:getKeyCode()
                rec.key = hs.keycodes.map[e:getKeyCode()]
            elseif typ == types.scrollWheel then
                rec.a1, rec.a2, rec.p1, rec.p2 = scrollDeltas(e)
            elseif typ == types.otherMouseDown or typ == types.otherMouseUp then
                rec.btn = e:getProperty(prop)
            end
            table.insert(diagBuf, rec)
            return false
        end)
        diagTap:start()
    end)
    if not ok then
        log.e("Diagnostic eventtap failed: " .. tostring(err))
        writeDiagFile("status=failed\nerror=" .. tostring(err) .. "\n")
        hs.alert.show("全事件诊断无法启动: " .. tostring(err) .. "\n已写入 " .. diagFilePath(), 6)
        return
    end

    hs.alert.show(
        "侧键诊断 " .. sec .. " 秒：请勿打字、勿碰触控板滚轮，只按鼠标侧键 1～2 次",
        3.5
    )

    diagTimer = hs.timer.doAfter(sec, function()
        local okDone, errDone = pcall(function()
            if diagTap then
                diagTap:stop()
                diagTap = nil
            end
            local counts = {}
            for _, r in ipairs(diagBuf) do
                counts[r.name] = (counts[r.name] or 0) + 1
            end
            local lines = {}
            for name, c in pairs(counts) do
                table.insert(lines, name .. "=" .. c)
            end
            table.sort(lines)
            local summary = table.concat(lines, ", ")
            if #summary > 900 then
                summary = summary:sub(1, 900) .. "..."
            end
            local payload = {
                status = "finished",
                eventCount = #diagBuf,
                watchedTypeCount = #watchList,
                summary = lines,
                events = diagBuf,
            }
            local text = "status=finished\neventCount=" .. tostring(#diagBuf) .. "\n"
            local inspOk, serialized = pcall(function()
                return hs.inspect(payload)
            end)
            if inspOk then
                text = text .. serialized
            else
                text = text .. "hs.inspect_error=" .. tostring(serialized) .. "\n"
            end
            writeDiagFile(text)
            log.i("Side button diagnostic done; events=" .. tostring(#diagBuf) .. " file=" .. diagFilePath())
            local msg = "诊断结束：共 " .. #diagBuf .. " 条事件。摘要：\n" .. summary
            if #diagBuf == 0 then
                msg = "诊断期间未捕获任何事件。侧键可能未进入 Quartz，需厂商驱动或 Karabiner。"
            end
            hs.alert.show(msg .. "\n\n完整日志: " .. diagFilePath(), 6)
        end)
        if not okDone then
            log.e("Diagnostic finish callback error: " .. tostring(errDone))
            writeDiagFile("status=error_in_finish_callback\nerror=" .. tostring(errDone) .. "\n")
            hs.alert.show("诊断结束时出错，已写入 " .. diagFilePath(), 6)
        end
    end)
end

-- 在 Hammerspoon 控制台可再次执行：hsSideButtonDiagnostics(15)
_G.hsSideButtonDiagnostics = runSideButtonDiagnostics

-- 入口
if DEBUG_MOUSE_SIDE then
    hs.alert.show("已加载 mouse_side_buttons", 1.0)
end

setupRemapTap()
setupKeycodeRemap()
setupBroadDebugTap()
setupMouseButtonPolling()

-- 自动诊断：在菜单已加载其它模块之后再延迟执行（本模块在 defaultConfig 中通常排在最后）
if DEBUG_MOUSE_SIDE and AUTO_DIAG_ON_LOAD then
    hs.timer.doAfter(5, function()
        hs.printf("[mouse_side_buttons] auto diagnostic timer fired")
        local ok, err = pcall(runSideButtonDiagnostics, 12)
        if not ok then
            hs.alert.show("侧键自动诊断执行失败: " .. tostring(err), 8)
        end
    end)
end

log.i("mouse_side_buttons module initialized")
-- 调试模式下写入 ping，避免无调试时频繁写盘
if DEBUG_MOUSE_SIDE then
    writePingFile(
        "status=module_loaded\n"
            .. "autoDiag="
            .. tostring(DEBUG_MOUSE_SIDE and AUTO_DIAG_ON_LOAD)
            .. "\ndiagFile="
            .. diagFilePath()
            .. "\n"
    )
end

-- 供控制台或外部脚本判断（自动诊断已在上方直接调度）
_G.MOUSE_SIDE_BUTTON_AUTO_DIAG_ON_LOAD = DEBUG_MOUSE_SIDE and AUTO_DIAG_ON_LOAD
