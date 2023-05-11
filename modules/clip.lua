-- 设置历史记录的最大行数
local MAX_CLIPBOARD_HISTORY = 20

-- 剪贴板历史记录
local clipboardHistory = hs.settings.get("clipboardHistory") or {}

-- 添加剪贴板内容到历史记录
function addToClipboardHistory()
    local clipboardTable = hs.pasteboard.readAllData()
    local clipboardContents = {}
    for k, v in pairs(clipboardTable) do
        if k == "public.utf8-plain-text" then
            local text = v
            if #text > 10 then
                text = string.sub(text, 1, 10) .. "..."
            end
            table.insert(clipboardContents, text)
        elseif k == "public.tiff" then
            local imagePath = os.getenv("HOME") .. "/.hammerspoon/clipboard_history/" .. os.time() .. ".jpg"
            hs.fs.mkdir(os.getenv("HOME") .. "/.hammerspoon/clipboard_history")
            local imageData = hs.pasteboard.readImage()
            imageData:size({w=100, h=100})
            imageData:saveToFile(imagePath)
            table.insert(clipboardContents, "image:" .. imagePath)
        end
    end
    if #clipboardContents > 0 then
        -- 排除重复内容
        for i, v in ipairs(clipboardHistory) do
            if v == clipboardContents then
                table.remove(clipboardHistory, i)
                break
            end
        end
        -- 添加新内容到历史记录
        for i, v in ipairs(clipboardContents) do
            table.insert(clipboardHistory, 1, v)
        end
        -- 保留最近的20行历史记录
        while (#clipboardHistory > MAX_CLIPBOARD_HISTORY) do
            table.remove(clipboardHistory)
        end
        hs.settings.set("clipboardHistory", clipboardHistory)
    end
end

-- 显示剪贴板历史记录
function showClipboardHistory()
    local choices = {}
    for i, v in ipairs(clipboardHistory) do
        local choice = {
            ["text"] = v,
            ["subText"] = "Clipboard history",
            ["uuid"] = hs.host.uuid()
        }
        -- 如果剪贴板内容是图片，则在选择器中显示图片
        if type(v) == "string" and string.sub(v, 1, 6) == "image:" then
            local imagePath = string.sub(v, 7)
            choice["image"] = hs.image.imageFromPath(imagePath)
            choice["imageScaling"] = "scaleProportionallyUpOrDown"
            choice["imageIsTemplate"] = false
            choice["imageSize"] = {w=50, h=50}
            choice["text"] = "Image"
        end
        table.insert(choices, choice)
    end
    -- 添加清除所有内容的按钮
    table.insert(choices, {
        ["text"] = "Clear all",
        ["subText"] = "Clear all clipboard history",
        ["uuid"] = hs.host.uuid(),
        ["textColor"] = {["red"]=1,["blue"]=0,["green"]=0},
        ["image"] = hs.image.imageFromPath(hs.configdir .. "/icons/trash.png")
    })
    local chooser = hs.chooser.new(function(choice)
        if choice ~= nil then
            if type(choice["text"]) == "string" and string.sub(choice["text"], 1, 6) == "image:" then
                local imagePath = string.sub(choice["text"], 7)
                -- 提供选项，让用户可以选择是复制图片还是只查看图片
                local options = {
                    ["Copy to clipboard"] = function()
                        local imageData = hs.image.imageFromPath(imagePath)
                        hs.pasteboard.setContents(imageData)
                    end,
                    ["View image"] = function()
                        hs.osascript.applescript('tell application "Preview" to open "' .. imagePath .. '"')
                    end
                }
                hs.chooser.selectedRow(1)
                hs.chooser.modalBackdrop(true)
                hs.chooser.suppressWarnings(true)
                hs.chooser.new(function(choice)
                    if choice ~= nil then
                        options[choice["text"]]()
                    end
                end):choices(hs.fnutils.imap(hs.fnutils.keys(options), function(k)
                    return {
                        ["text"] = k,
                        ["uuid"] = hs.host.uuid()
                    }
                end)):show()
            elseif choice["text"] == "Clear all" then
                -- 清除所有剪贴板历史记录
                clipboardHistory = {}
                hs.settings.set("clipboardHistory", clipboardHistory)
            else
                hs.pasteboard.setContents(choice["text"])
            end
        end
    end)
    chooser:choices(choices)
    chooser:show()
end

-- 监听剪贴板变化
hs.pasteboard.watcher.new(addToClipboardHistory):start()

-- 绑定快捷键，显示剪贴板历史记录
hs.hotkey.bind({"alt"}, "`", showClipboardHistory)