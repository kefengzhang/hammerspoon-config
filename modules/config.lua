require("modules.base")

-- 默认加载的功能模块
defaultConfig = {
    {
        -- 配置版本号
        -- 每次新增功能项，需将版本号加 1
        configVersion = "9",
    },
    {
        module = "modules.window",
        name = "窗口管理",
        enable = true,
    },
    {
        module = "modules.application",
        name = "应用切换",
        enable = true,
    },
    {
        module = "modules.im-autoSelect",
        name = "自动输入法",
        enable = false,
    },
    {
        module = "modules.hotkey",
        name = "快捷键列表查看",
        enable = true,
    },
    {
        module = "modules.wifi",
        name = "wifi监控",
        enable = false,
    },
    {
        module = "modules.bluetooth",
        name = "蓝牙",
        enable = true,
    },
    {
        module = "modules.otheres",
        name = "其他",
        enable = true,
    },
    {
        module = "modules.mouse_side_buttons",
        name = "JOMAA鼠标映射",
        enable = true,
    },
}

base_path = os.getenv("HOME") .. "/.hammerspoon/"
-- 本地配置文件路径
config_path = base_path .. ".config"

-- 将 defaultConfig 里尚未出现在本地配置中的模块项追加进去，并同步 configVersion（升级仓库后无需点「恢复默认」也能出现新菜单）
local function mergeMissingModulesFromDefault(configStr)
    local ok, cfg = pcall(unserialize, configStr)
    if not ok or type(cfg) ~= "table" then
        return serialize(defaultConfig), true
    end
    local seen = {}
    for _, item in ipairs(cfg) do
        if type(item) == "table" and item.module then
            seen[item.module] = true
        end
    end
    local maxKey = 0
    for k, _ in pairs(cfg) do
        if type(k) == "number" and k > maxKey then
            maxKey = k
        end
    end
    local changed = false
    for i = 2, #defaultConfig do
        local def = defaultConfig[i]
        if type(def) == "table" and def.module and not seen[def.module] then
            maxKey = maxKey + 1
            cfg[maxKey] = {
                module = def.module,
                name = def.name,
                enable = def.enable,
            }
            seen[def.module] = true
            changed = true
        end
    end
    if cfg[1] and type(cfg[1]) == "table" and defaultConfig[1] and defaultConfig[1].configVersion then
        if cfg[1].configVersion ~= defaultConfig[1].configVersion then
            cfg[1].configVersion = defaultConfig[1].configVersion
            changed = true
        end
    end
    return serialize(cfg), changed
end

-- 加载本地配置文件
function loadConfig()
    -- 以可读写方式打开文件
    local file = io.open(config_path, "r+")
    -- 文件不存在
    if file == nil then
        -- 创建文件
        file = io.open(config_path, "w+")
    end
    -- 文件打开失败（例如权限不足）
    if file == nil then
        hs.printf("配置加载失败：无法打开配置文件 %s，使用默认配置", config_path)
        return serialize(defaultConfig)
    end
    -- 读取文件所有内容
    local config = file:read("*a")
    file:close()
    -- 配置文件中不存在配置
    if config == "" then
        return serialize(defaultConfig)
    end
    local merged, didMerge = mergeMissingModulesFromDefault(config)
    if didMerge then
        local wf = io.open(config_path, "w+")
        if wf then
            wf:write(merged)
            wf:close()
        end
    end
    return merged
end

function saveConfig(config)
    -- 清空文件内容，然后写入新的文件内容
    local file = io.open(config_path, "w+")
    if file == nil then
        hs.printf("配置保存失败：无法打开配置文件 %s", config_path)
        return false
    end
    file:write(serialize(config))
    file:close()
    return true
end
