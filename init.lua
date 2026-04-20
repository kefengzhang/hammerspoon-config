require("modules.menu")
require("modules.reload")
-- 侧键映射放在最后加载：eventtap 后创建会更靠近链头，优先于先加载模块里注册的 tap，避免侧键 keyDown 被别的监听先处理
require("modules.mouse_side_buttons")
-- require("modules.bluetooth")
-- require("modules.wifi")
-- require("modules.otheres")

-- require("modules.clip")

-- 全部模块加载完成后再启动侧键自动诊断（若在 mouse_side_buttons 内部过早 hs.timer.doAfter，可能被后续 require/重载打断导致不出现提示）
if _G.MOUSE_SIDE_BUTTON_AUTO_DIAG_ON_LOAD and _G.hsSideButtonDiagnostics then
    hs.timer.doAfter(5, function()
        hs.printf("[mouse_side_buttons] auto diagnostic timer fired")
        local ok, err = pcall(_G.hsSideButtonDiagnostics, 12)
        if not ok then
            hs.alert.show("侧键自动诊断执行失败: " .. tostring(err), 8)
        end
    end)
end