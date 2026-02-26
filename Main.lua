
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")



local ToggleAPI = setmetatable({}, { __mode = "k" })
local DropdownAPI = setmetatable({}, { __mode = "k" })
local KeybindAPI = setmetatable({}, { __mode = "k" })
local SliderAPI = setmetatable({}, { __mode = "k" })
local ButtonAPI = setmetatable({}, { __mode = "k" })
local ColorPickerAPI = setmetatable({}, { __mode = "k" })
local NotificationAPI 



local RECENT_NOTIFS = setmetatable({}, { __mode = "k" })

local COLORS = {
    accent     = Color3.fromRGB(200, 80, 180),
    panel      = Color3.fromRGB(28, 24, 38),
    panelAlt   = Color3.fromRGB(38, 30, 50),
    panelDark  = Color3.fromRGB(18, 16, 25),
    divider    = Color3.fromRGB(70, 50, 80),
    text       = Color3.fromRGB(240, 240, 245),
    white      = Color3.fromRGB(255, 255, 255),
}

local function ApplyTheme() end      -- stub (AppleHub handles themes)
local function RegisterThemed() end  -- stub (not needed with AppleHub)

local makeDebugLabel_offset = 0
local DEBUG_LABELS = {}
local function makeDebugLabel(initialText)
    local txt = Drawing.new("Text")
    txt.Text = tostring(initialText or "")
    txt.Size = 16
    txt.Color = Color3.new(1,1,1)
    txt.Position = Vector2.new(8, 8 + makeDebugLabel_offset)
    txt.Visible = false
    txt.Center = false
    txt.Outline = true
    txt.ZIndex = 10
    makeDebugLabel_offset = makeDebugLabel_offset + 28
    local api = {}
    api.Set = function(text) txt.Text = tostring(text or "") end
    api.Show = function(v) txt.Visible = not not v end
    api.Destroy = function()
        txt:Remove()
        for i,v in ipairs(DEBUG_LABELS) do if v==api then table.remove(DEBUG_LABELS,i); break end end
    end
    table.insert(DEBUG_LABELS, api)
    return api
end

local NOTIFICATIONS_ENABLED = true

local gui = (function()
    local sg = Instance.new("ScreenGui")
    sg.Name = "Rivals_EngineGui"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local ok = pcall(function() sg.Parent = game:GetService("CoreGui") end)
    if not ok then
        local lp = Players.LocalPlayer
        if lp then sg.Parent = lp:WaitForChild("PlayerGui") end
    end
    return sg
end)()
local localPlayer = Players.LocalPlayer
local player = Players.LocalPlayer
local projSpeed = 900      -- default projectile speed for aimbot prediction
local leadScale = 1        -- default lead scale
local initialZone = 900    -- default target zone
local targetBehindWallsEnabled = false  -- will be set by engine


local function makeNotification(text, duration, parent, invoker)
    if NOTIFICATIONS_ENABLED == false then return end
    local dur = (type(duration)=="number" and duration>0) and duration or 3
    pcall(function()
        local AH = getgenv().AppleHub
        if AH and AH.Assets and AH.Assets.Notifications and AH.Assets.Notifications.Send then
            AH.Assets.Notifications.Send({
                Description = tostring(text or ""),
                Duration = dur
            })
        end
    end)
end




local CONFIG_FILE = "Rivals-Config.json"
local function readConfig()
    local ok, contents = pcall(function() return readfile(CONFIG_FILE) end)
    if not ok or not contents then return {} end
    local success, decoded = pcall(function() return HttpService:JSONDecode(contents) end)
    if not success then return {} end
    return decoded or {}
end

local function writeConfig(tbl)
    local ok, encoded = pcall(function() return HttpService:JSONEncode(tbl) end)
    if not ok then return false end
    pcall(function() writefile(CONFIG_FILE, encoded) end)
    return true
end

local Config = readConfig()
local NOTIFICATIONS_ENABLED = nil

local function SaveConfig()
    writeConfig(Config)
end

local function SetConfig(key, value)
    Config[key] = value
    SaveConfig()
end

do
    local ok, v = pcall(function() return Config["settings.enableNotifications"] end)
    if ok and type(v) == "boolean" then
        NOTIFICATIONS_ENABLED = v
    else
        NOTIFICATIONS_ENABLED = true
    end
    local _origSetConfig = SetConfig
    SetConfig = function(key, value)
        Config[key] = value
        if key == "settings.enableNotifications" then
            NOTIFICATIONS_ENABLED = not not value
        end
        if key == "settings.debugMode" then
            for _, api in ipairs(DEBUG_LABELS) do
                pcall(function() if api and type(api.Show) == "function" then api.Show(not not value) end end)
            end
        end
        SaveConfig()
    end
end

local function GetConfig(key, default)
    if Config[key] == nil then return default end
    return Config[key]
end

local function BindToggleToConfig(toggleFrame, key, default)
    if not toggleFrame then return end
    local api = ToggleAPI[toggleFrame]
    if not api then return end
    local initial = GetConfig(key, default)
    api.Set(initial)
    api.OnToggle = function(state)
        SetConfig(key, state)
    end
end

local function BindKeybindToConfig(keybindFrame, key, default)
    if not keybindFrame then return end
    local api = KeybindAPI[keybindFrame]
    if not api then return end

    local saved = GetConfig(key, nil)
    if type(saved) == "string" and Enum.KeyCode[saved] then
        api.Set(Enum.KeyCode[saved])
    else
        if default and typeof(default) == "EnumItem" and default.EnumType == Enum.KeyCode then
            api.Set(default)
        elseif type(default) == "string" and Enum.KeyCode[default] then
            api.Set(Enum.KeyCode[default])
        end
    end

    do
        local prev = api.OnBind
        api.OnBind = function(k)
            local name = nil
            if typeof(k) == "EnumItem" then name = k.Name elseif type(k) == "string" then name = tostring(k) end
            if name then SetConfig(key, name) end
            if type(prev) == "function" then
                pcall(prev, k)
            end
        end
    end
end

local function BindSliderToConfig(sliderFrame, key, default)
    if not sliderFrame then return end
    local api = SliderAPI[sliderFrame]
    if not api then return end

    local saved = GetConfig(key, nil)
    local n = nil
    if type(saved) == "number" then
        n = saved
    elseif type(saved) == "string" then
        n = tonumber(saved)
    end
    if n ~= nil then
        if api.Set then api.Set(n) end
    else
        if default ~= nil and api.Set then api.Set(default) end
    end

    do
        local prev = api.OnChange
        api.OnChange = function(v)
            SetConfig(key, v)
            if type(prev) == "function" then prev(v) end
        end
    end
end

local function BindDropDownToConfig(dropdownFrame, key, defaultIndex)
    if not dropdownFrame then return end
    local api = DropdownAPI[dropdownFrame]
    if not api then return end

    local saved = GetConfig(key, nil)
    if type(saved) == "number" then
        pcall(function() if api.Set then api.Set(saved) end end)
    elseif type(saved) == "string" then
        local orig = nil
        pcall(function() orig = (api.Get and api.Get()) end)
        local found = false
        for i = 1, 50 do
            if api.Set then
                local ok, err = pcall(function() api.Set(i) end)
                if not ok then break end
            end
            local sel = nil
            pcall(function() sel = (api.Get and api.Get()) end)
            if sel and sel.value and tostring(sel.value) == tostring(saved) then
                found = true
                break
            end
        end
        if not found then
            pcall(function() if orig and orig.index and api.Set then api.Set(orig.index) end end)
        end
    else
        if defaultIndex and api.Set then pcall(function() api.Set(defaultIndex) end) end
    end

    do
        local prev = api.OnSelect
        api.OnSelect = function(index, value, on)
            if type(value) == "string" then
                SetConfig(key, value)
            else
                SetConfig(key, index)
            end
            if type(prev) == "function" then pcall(prev, index, value, on) end
        end
    end
end



local function showUnsupportedPopup()
    local warn = GetConfig("settings.warnIfUnsupportedGame", false)

    local ALLOWED_PLACE_IDS = {17625359962, 17625359963}
    local function isPlaceAllowed()
        for _, id in ipairs(ALLOWED_PLACE_IDS) do
            if game.PlaceId == id then return true end
        end
        return false
    end
    if isPlaceAllowed() then return true end
    if not warn then return true end

    local dlg = Instance.new("ScreenGui")
    dlg.Name = "RivalsUnsupportedGame"
    dlg.ResetOnSpawn = false
    dlg.IgnoreGuiInset = true
    dlg.DisplayOrder = 99999
    local ok = pcall(function() dlg.Parent = game:GetService("CoreGui") end)
    if not ok then
        local lp = Players.LocalPlayer
        if lp then dlg.Parent = lp:WaitForChild("PlayerGui") end
    end
    local bg = Instance.new("Frame", dlg)
    bg.Size = UDim2.fromScale(1,1)
    bg.BackgroundColor3 = Color3.fromRGB(10,10,15)
    bg.BackgroundTransparency = 0.3
    bg.BorderSizePixel = 0
    local card = Instance.new("Frame", bg)
    card.AnchorPoint = Vector2.new(0.5,0.5)
    card.Position = UDim2.fromScale(0.5,0.5)
    card.Size = UDim2.fromOffset(360,180)
    card.BackgroundColor3 = Color3.fromRGB(28,24,38)
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0,16)
    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1,0,0,40)
    title.Position = UDim2.new(0,0,0,16)
    title.BackgroundTransparency = 1
    title.Text = "⚠ Unsupported Game"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(200,80,180)
    local sub = Instance.new("TextLabel", card)
    sub.Size = UDim2.new(1,-32,0,60)
    sub.Position = UDim2.new(0,16,0,56)
    sub.BackgroundTransparency = 1
    sub.Text = "This script may not be supported in this game.\nProceed with caution."
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 14
    sub.TextColor3 = Color3.fromRGB(200,190,210)
    sub.TextWrapped = true
    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0,140,0,36)
    btn.Position = UDim2.new(0.5,-70,1,-52)
    btn.BackgroundColor3 = Color3.fromRGB(200,80,180)
    btn.Text = "Continue Anyway"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,10)
    local result = false
    btn.MouseButton1Click:Connect(function()
        result = true
        dlg:Destroy()
    end)
    while dlg.Parent do task.wait(0.1) end
    return result
end


do
    local ok, res = pcall(function() if type(showUnsupportedPopup) == "function" then return showUnsupportedPopup() end end)
    if ok and res == false then return end
end



local AppleHubLib
do
    if not getgenv().AppleHub then
        getgenv().AppleHub = {
            Notifications = { Active = {}, Objects = {} },
            Connections = {},
            Corners = {},
            Config = {
                UI = {
                    Position = {X = 0.5, Y = 0.5},
                    Size = {X = 0.24, Y = 0.52},
                    FullScreen = false,
                    ToggleKeyCode = "Insert",
                    Scale = 1,
                    Notifications = true,
                    Anim = true,
                    ArrayList = false,
                    TabColor = {value1 = 40, value2 = 40, value3 = 40},
                    TabTransparency = 0.07,
                    KeybindTransparency = 0.7,
                    KeybindColor = {value1 = 0, value2 = 0, value3 = 0},
                },
                Game = {
                    Modules = {}, Keybinds = {}, Sliders = {}, TextBoxes = {},
                    MiniToggles = {}, Dropdowns = {}, ToggleLists = {},
                    ModuleKeybinds = {}, Other = {}
                }
            },
            Mobile = (UserInputService.TouchEnabled and not UserInputService.MouseEnabled),
            Pages = {},
            Tabs = { Tabs = {}, TabBackground = nil },
            ArrayList = { Objects = {}, Loaded = false },
            Background = nil, Pageselector = nil, Dashboard = nil,
            CurrentOpenTab = {}, ControlsVisible = false,
            IsAllowedToHoverTabButton = false,
            CurrntInputChangeCallback = function() end,
            InputEndFunc = nil,
            GameSave = "Rivals",
            Dev = false,
        }
    end

    if isfile("AppleHub/Config/UI.json") then
        pcall(function()
            local data = HttpService:JSONDecode(readfile("AppleHub/Config/UI.json"))
            if data then getgenv().AppleHub.Config.UI = data end
        end)
    end

    AppleHubLib = (function()
    ╔═══════════════════════════════════════════════╗
    ║              APPLE HUB UI LIBRARY             ║
    ║           Roblox Executor UI Framework        ║
    ╚═══════════════════════════════════════════════╝

    CÁCH SỬ DỤNG:
        local AppleHub = loadstring(readfile("AppleHub.lua"))()
        local AppleHub = loadstring(game:HttpGet("RAW_LINK"))()

    KHỞI TẠO:
        local UI = AppleHub.Main.Load("TenGameSave")
        AppleHub.Main.ToggleVisibility(true)

    TẠO TAB:
        local Tab = AppleHub.Dashboard.NewTab({...})

    TẠO MODULE:
        local Module = Tab.Functions.NewModule({...})

    SETTINGS TRONG MODULE:
        Module.Functions.Settings.Slider({...})
        Module.Functions.Settings.MiniToggle({...})
        Module.Functions.Settings.TextBox({...})
        Module.Functions.Settings.Dropdown({...})
        Module.Functions.Settings.Keybind({...})
        Module.Functions.Settings.Button({...})
        Module.Functions.Settings.NewSection({...})

    PHÍM MẶC ĐỊNH: Left Alt để ẩn/hiện UI

    VERSION: 1.0.0
    ORIGINAL: Night UI (open source)
    MODIFIED: Apple Hub

local Assets = {
    Functions = {},
    Config = {},
    Notifications = {},
    MainBackground = {},
    Pages = {},
    Dashboard = {},
    SettingsPage = {},
    ArrayList = {},
    Font = {},
    Main = {ToggleVisibility = nil}
}

if not getgenv().AppleHub then
    getgenv().AppleHub = {
        Notifications = { Active = {}, Objects = {} },
        Connections = {},
        Corners = {},
        Config = {
            UI = {
                Position = {X = 0.5, Y = 0.5},
                Size = {X = 0.24, Y = 0.52},
                FullScreen = false,
                ToggleKeyCode = "LeftAlt",
                Scale = 1,
                Notifications = true,
                Anim = true,
                ArrayList = false,
                TabColor = {value1 = 40, value2 = 40, value3 = 40},
                TabTransparency = 0.07,
                KeybindTransparency = 0.7,
                KeybindColor = {value1 = 0, value2 = 0, value3 = 0},
            },
            Game = {
                Modules = {},
                Keybinds = {},
                Sliders = {},
                TextBoxes = {},
                MiniToggles = {},
                Dropdowns = {},
                ToggleLists = {},
                ModuleKeybinds = {},
                Other = {}
            }
        },
        Mobile = (game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").MouseEnabled),
        Pages = {},
        Tabs = { Tabs = {}, TabBackground = nil },
        ArrayList = { Objects = {}, Loaded = false },
        Background = nil,
        Pageselector = nil,
        Dashboard = nil,
        CurrentOpenTab = {},
        ControlsVisible = false,
        IsAllowedToHoverTabButton = false,
        CurrntInputChangeCallback = function() end,
        InputEndFunc = nil,
        GameSave = "GameSave",
        Dev = false,
    }
end
local AppleHub = getgenv().AppleHub
Assets.Functions.cloneref = cloneref or function(ref: Instance) return ref end

local PlayersSV = Assets.Functions.cloneref(game:GetService("Players")) :: Players
local HttpService = Assets.Functions.cloneref(game:GetService("HttpService")) :: HttpService
local TweenService = Assets.Functions.cloneref(game:GetService("TweenService")) :: TweenService
local UserInputService = Assets.Functions.cloneref(game:GetService("UserInputService")) :: UserInputService
local Workspace = Assets.Functions.cloneref(game:GetService("Workspace")) :: Workspace
local TextService = Assets.Functions.cloneref(game:GetService("TextService")) :: TextService

local UserCamera = Workspace.CurrentCamera :: Camera
local LocalPlayer = PlayersSV.LocalPlayer :: Player

do
    Assets.Functions.clonefunction = clonefunction or function(func: any) return func end

    Assets.Functions.gethui = gethui or function() return LocalPlayer:FindFirstChildWhichIsA("PlayerGui") end
    Assets.Functions.GenerateString = function(chars : number) : string
        local str = ""
        for i = 0, chars do
            str = str..string.char(math.random(33,126))
        end
        return str
    end
    Assets.Functions.GetGameInfo = function()
        local gameinfo = game:HttpGet("https://games.roblox.com/v1/games?universeIds="..tostring(game.GameId))
        if gameinfo then
            local dencgameinfo = HttpService:JSONDecode(gameinfo)
            if dencgameinfo and dencgameinfo.data and dencgameinfo.data[1] then
                return dencgameinfo.data[1]                
            else
                return "no game info after json"
            end
        else
            return "no game info returned"
        end
    end
    Assets.Functions.LoadFile = function(file : string, githublink : string)
        if AppleHub.Dev and isfile(file) then
            return loadstring(readfile(file))()
        else
            local suc, err = pcall(function() 
                file = http.request({
                    Url = githublink,
                    Method = "GET"
                }).Body
            end)
            if suc and not err and file and not tostring(file):lower():find("404: not found") then
                return loadstring(file)()
            end
        end
        return "error"
    end
    Assets.Functions.IsAlive = function(plr: Player)
        plr = plr or LocalPlayer
        if plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hum = plr.Character:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.Health > 0.1 then
                return true
            end
        end
        return false
    end
    Assets.Functions.GetModule = function(name: string)
        if name and AppleHub and AppleHub.Tabs and AppleHub.Tabs.Tabs then
            for i,v in AppleHub.Tabs.Tabs do
                if v.Modules and v.Modules[name] then
                    return v.Modules[name]
                end
            end
        end
        return
    end
    Assets.Functions.GetAllModules = function()
        local modules = {}
        if AppleHub and AppleHub.Tabs and AppleHub.Tabs.Tabs then
            for i,v in AppleHub.Tabs.Tabs do
                if v.Modules then
                    for i2, v2 in v.Modules do 
                        modules[i2] = v2
                    end
                end
            end
        end
        return modules
    end
    Assets.Functions.GetNearestPlr = function(tplr, teamcheck)
        tplr = tplr or LocalPlayer
        local lastpos, plr = math.huge, nil
        for i,v in PlayersSV:GetPlayers() do
            if teamcheck and v.Team ~= tplr.Team or not teamcheck then
                if v and v ~= tplr and Assets.Functions.IsAlive(v) and Assets.Functions.IsAlive(tplr) then
                    local dist = (tplr.Character.HumanoidRootPart.Position - v.Character.HumanoidRootPart.Position).Magnitude
                    if lastpos > dist then
                        lastpos = dist
                        plr = v
                    end
                end
            end
        end
        return plr, lastpos
    end
    Assets.Functions.GetNearestPlrToMouse = function(Data: {Team: boolean, Limit: number, Exclude: {}, Extras: {}})
        Data = {
            Team = Data and Data.Team or false,
            Limit = Data and Data.Limit or math.huge,
            Exclude = Data and Data.Exclude or {},
            Extras = Data and Data.Extras or {}
        }

        local RData = {Player = nil, Distance = math.huge, PlayerDist = math.huge}
        local Players = {}
        for i,v in PlayersSV:GetPlayers() do
            if Assets.Functions.IsAlive(v) then
                if Data.Team and v.Team ~= LocalPlayer.Team or not Data.Team then
                    table.insert(Players, v.Character)
                end
            end
        end

        for i,v in Data.Extras do
            table.insert(Players, v)
        end

        for i,v in Players do
            if not table.find(Data.Exclude, v) then
                local Part = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                if Part then
                    local screenpos, onscreen = UserCamera:WorldToScreenPoint(Part.Position)
                    if screenpos and onscreen then
                        local mouse = LocalPlayer:GetMouse()
                        local mousepos = mouse.Hit.Position
                        local mag = (mousepos - Part.Position).Magnitude
                        local plrdist = (Part.Position - Part.Position).Magnitude
                        if Data.Limit >= mag and RData.Distance >= mag and (RData.Distance == mag and RData.PlayerDist >= plrdist or RData.Distance ~= mag) then
                            RData = {
                                Player = PlayersSV:GetPlayerFromCharacter(v) :: Player,
                                Character = v,
                                Distance = mag :: number,
                                PlayerDist = plrdist :: number
                            }
                        end
                    end
                end
            end
        end
        return RData :: {Player: Player, Distance: number, PlayerDist: number}
    end
end

do
    Assets.Config.Save = function(File, data)
        writefile("AppleHub/Config/"..File..".json", HttpService:JSONEncode(data))
    end
    
    Assets.Config.Load = function(File, set)
        if isfile("AppleHub/Config/"..File..".json") then
            local data = readfile("AppleHub/Config/"..File..".json")
            local data2 = HttpService:JSONDecode(data)
            if set then
                AppleHub.Config[set] = data2
                if set == "Game" then
                    local allmodules = Assets.Functions.GetAllModules()
                    for i,v in allmodules do
                        for i2, v2 in v.Settings do
                            if v2.Type then
                                if data2[v2.Type] then
                                    if data2[v2.Type][v2.Flag] ~= nil then
                                        v2.Functions.SetValue(data2[v2.Type][v2.Flag], false)
                                    elseif data2[v2.Type][v2.Flag] == nil and v2.Default ~= nil then
                                        v2.Functions.SetValue(v2.Default, false)
                                    elseif data2[v2.Type][v2.Flag] == false then
                                        v2.Functions.SetValue(false, false)
                                    end
                                else
                                    if v2.Default ~= nil then
                                        v2.Functions.SetValue(v2.Default, false)
                                    end
                                end
                            end
                        end

                        if data2.Keybinds and data2.Keybinds[i] then
                            if v.Functions and v.Functions.BindKeybind then
                                v.Functions.BindKeybind(data2.Keybinds[i], false)
                            end
                        end
                        if data2.Modules and data2.Modules[i] or data2.Modules and v.Default and data2.Modules[i] == nil then
                            if not v.Data.Enabled then
                                v.Functions.Toggle(true, false, false, false, true)
                            end
                        else
                            if v.Data.Enabled then
                                v.Functions.Toggle(false, false, false, false, true)
                            end
                        end
                    end

                    if AppleHub.Config.Game.Other.TabPos then
                        for i,v in AppleHub.Tabs.Tabs do
                            local tabpos = AppleHub.Config.Game.Other.TabPos[i]
                            if tabpos and v.Objects and v.Objects.ActualTab then
                                local tab = v.Objects.ActualTab
                                if tabpos.X then
                                    tab.Position = UDim2.fromScale(tabpos.X, tab.Position.Y.Scale)
                                end
                                if tabpos.Y then
                                    tab.Position = UDim2.fromScale(tab.Position.X.Scale, tabpos.Y)
                                end
                            end
                        end
                    end
                end
            end
            return data2
        end
        return "no file"
    end
    
end

local function GetTextBounds(str: string, font: Font, textsize: number)
    local Params = Instance.new("GetTextBoundsParams")
    Params.Text = str
    Params.Font = font
    Params.Size = textsize
    Params.Width = 1e9
    Params.RichText = false
    
    return TextService:GetTextBoundsAsync(Params)
end

do
    type FontFamily = {
        name: string,
        faces: { FontFace },
    }
    
    type FontFace = {
        name: string,
        file: string,
        weight: number,
        style: string?,
    }

    Assets.Font.Download = function(Name: string, Font: string)
        local data = game:HttpGet(Font)
        if not isfile("AppleHub/Assets/Fonts/"..Name..".ttf") then
            if data and not tostring(data):find("404") then
                writefile("AppleHub/Assets/Fonts/"..Name..".ttf", data)
            else
                return false
            end
        end
        return true
    end

    local family_cache = {}
    Assets.Font.create_family = function(name: string, faces: { FontFace })
        local family = { name = name, faces = {} }

        for i, face in next, faces do
            local rbx_face = {
                name = assert(face.name, `Face #{i} is invalid (no name field)`),
                weight = assert(face.weight, `Face #{i} is invalid (no weight field)`),
                style = face.style or "normal",
                assetId = getcustomasset(face.file),
            }

            table.insert(family.faces, rbx_face)
        end

        writefile("AppleHub/Assets/Fonts/"..name..".json", HttpService:JSONEncode(family))

        local id = getcustomasset("AppleHub/Assets/Fonts/"..name..".json")
        family_cache[name] = id

        return id
    end

    Assets.Font.get_family = function(name: string)
        local id = assert(family_cache[name], `Family {name} not found!`)

        return id
    end
end

do

        AppleHub.Notifications.Send(data: table)
        ► Hiện thông báo popup góc trên màn hình
        ► data.Description : string  - nội dung thông báo
        ► data.Duration    : number  - thời gian hiện (giây), mặc định 5
        ► data.Flag        : string  - ID unique (tùy chọn)
        Ví dụ:
            AppleHub.Notifications.Send({
                Description = "Aimbot đã bật!",
                Duration = 3
            })
    Assets.Notifications.Send = function(data: any)
        local NotificationData = {
            Description = data.Description or "This is a notification",
            Duration = data.Duration or 5,
            Flag = data.Flag,
            Running = true,
            Objects = {},
            Functions = {},
            Connections = {}
        }

        local flag = NotificationData.Flag or NotificationData.Description
        for i, v in AppleHub.Notifications.Active do
            if v.Objects.Notification then
                TweenService:Create(v.Objects.Notification, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Position = UDim2.new(v.Objects.Notification.Position.X.Scale, v.Objects.Notification.Position.X.Offset, v.Objects.Notification.Position.Y.Scale, v.Objects.Notification.Position.Y.Offset + 50)}):Play()
            end
        end
        

        NotificationData.Objects.Notification = Instance.new("ImageButton", AppleHub.Notifications.Objects.NotificationGui)
        NotificationData.Objects.Notification.AnchorPoint = Vector2.new(0.5, 0)
        NotificationData.Objects.Notification.AutoButtonColor = false
        NotificationData.Objects.Notification.AutomaticSize = Enum.AutomaticSize.X
        NotificationData.Objects.Notification.BackgroundColor3 = Color3.fromRGB(79, 79, 79)
        NotificationData.Objects.Notification.BackgroundTransparency = 0.05
        NotificationData.Objects.Notification.Position = UDim2.new(0.5, 0, -1, 30)
        NotificationData.Objects.Notification.Size = UDim2.new(0, 0, 0, 32)
        NotificationData.Objects.Notification.ZIndex = 10
        NotificationData.Objects.Notification.Image = "rbxassetid://16294030997"
        NotificationData.Objects.Notification.ScaleType = Enum.ScaleType.Crop
        NotificationData.Objects.Notification.ImageColor3 = Color3.fromRGB(80, 80, 80)
        NotificationData.Objects.Notification.ClipsDescendants = true
        Instance.new("UICorner", NotificationData.Objects.Notification).CornerRadius = UDim.new(0, 100)

        local NotificationPadding = Instance.new("UIPadding", NotificationData.Objects.Notification)
        NotificationPadding.PaddingBottom = UDim.new(0, 4)
        NotificationPadding.PaddingLeft = UDim.new(0, 12)
        NotificationPadding.PaddingRight = UDim.new(0, 12)
        NotificationPadding.PaddingTop = UDim.new(0, 4)

        local NotificationStroke = Instance.new("UIStroke", NotificationData.Objects.Notification)
        NotificationStroke.Color = Color3.fromRGB(255, 255, 255)
        local NotificationStrokeGradient = Instance.new("UIGradient", NotificationStroke)
        NotificationStrokeGradient.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0, 0.694, 0), NumberSequenceKeypoint.new(1, 0.869, 0)}
        NotificationStrokeGradient.Rotation = 80

        local CloseButton = Instance.new("ImageButton", NotificationData.Objects.Notification)
        CloseButton.AnchorPoint = Vector2.new(0.5, 0.5)
        CloseButton.BackgroundTransparency = 1
        CloseButton.Position = UDim2.new(0, 6, 0.5, 0)
        CloseButton.Size = UDim2.new(0, 12, 0, 12)
        CloseButton.ZIndex = 10
        CloseButton.Image = "rbxassetid://11295275950"
        CloseButton.ScaleType = Enum.ScaleType.Fit
        CloseButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
        CloseButton.AutoButtonColor = false


        local TimeLine = Instance.new("ImageLabel", NotificationData.Objects.Notification)
        TimeLine.AnchorPoint = Vector2.new(0.5, 1)
        TimeLine.BackgroundTransparency = 1
        TimeLine.Position = UDim2.fromScale(0.5, 1)
        TimeLine.Size = UDim2.new(0.1, 50, 0, 2)
        TimeLine.ZIndex = 10
        TimeLine.Image = "rbxassetid://16294678871"
        TimeLine.ScaleType = Enum.ScaleType.Slice
        TimeLine.SliceCenter = Rect.new(206, 206, 206, 206)
        TimeLine.ImageColor3 = Color3.fromRGB(255, 255, 255)
        TimeLine.ImageTransparency = 0.8
        TimeLine.Visible = false

        local TimeLineBar = Instance.new("ImageLabel", TimeLine)
        TimeLineBar.AnchorPoint = Vector2.new(0, 0.5)
        TimeLineBar.BackgroundTransparency = 1
        TimeLineBar.Position = UDim2.fromScale(0, 0.5)
        TimeLineBar.Size = UDim2.fromScale(0, 2)
        TimeLineBar.Image = "rbxassetid://16294678871"
        TimeLineBar.BorderSizePixel = 0
        TimeLineBar.ScaleType = Enum.ScaleType.Slice
        TimeLineBar.SliceCenter = Rect.new(206, 206, 206, 206)
        TimeLineBar.ImageTransparency = 0.2
        TimeLineBar.ZIndex = 10

        NotificationData.Objects.NotificationDescription = Instance.new("TextLabel", NotificationData.Objects.Notification)
        NotificationData.Objects.NotificationDescription.AutomaticSize = Enum.AutomaticSize.X
        NotificationData.Objects.NotificationDescription.BackgroundTransparency = 1
        NotificationData.Objects.NotificationDescription.Position = UDim2.fromOffset(20, 0)
        NotificationData.Objects.NotificationDescription.Size = UDim2.fromScale(0, 1)
        NotificationData.Objects.NotificationDescription.ZIndex = 10
        NotificationData.Objects.NotificationDescription.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
        NotificationData.Objects.NotificationDescription.Text = NotificationData.Description
        NotificationData.Objects.NotificationDescription.TextColor3 = Color3.fromRGB(255, 255, 255)
        NotificationData.Objects.NotificationDescription.TextSize = 12
        NotificationData.Objects.NotificationDescription.TextTransparency = 0.2

        NotificationData.Functions.Remove = function(anim: boolean)
            if not AppleHub or not AppleHub.Notifications or not AppleHub.Notifications.Active then return end
            for i,v in NotificationData.Connections do
                v:Disconnect()
                if table.find(AppleHub.Connections, v) then
                    table.remove(AppleHub.Connections, table.find(AppleHub.Connections, v))
                end
            end

            for i, v in AppleHub.Notifications.Active do
                if v.Objects.Notification and v.Objects.Notification.Position.Y.Offset > NotificationData.Objects.Notification.Position.Y.Offset then
                    TweenService:Create(v.Objects.Notification, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Position = UDim2.new(v.Objects.Notification.Position.X.Scale, v.Objects.Notification.Position.X.Offset, v.Objects.Notification.Position.Y.Scale, v.Objects.Notification.Position.Y.Offset - 50)}):Play()
                end
            end

            if anim then
                TweenService:Create(TimeLineBar, TweenInfo.new(0.15), {ImageTransparency = 1}):Play()
                for i,v in NotificationData.Objects.Notification:GetChildren() do
                    if v:IsA("ImageButton") or v:IsA("ImageLabel") then
                        TweenService:Create(v, TweenInfo.new(0.15), {ImageTransparency = 1, BackgroundTransparency = 1}):Play()
                    elseif v:IsA("TextLabel") then
                        TweenService:Create(v, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
                    end
                end
                task.wait(0.05)
                TweenService:Create(NotificationData.Objects.Notification, TweenInfo.new(0.2), {ImageTransparency = 1, BackgroundTransparency = 1}):Play()
                task.wait(0.22)
            end

            NotificationData.Objects.Notification:Destroy()
            if AppleHub and AppleHub.Notifications and AppleHub.Notifications.Active then
                AppleHub.Notifications.Active[flag] = nil
            end
            table.clear(NotificationData)
        end
        
        NotificationData.Connections.conhover = NotificationData.Objects.Notification.MouseEnter:Connect(function()
            TimeLine.Visible = true
            CloseButton.Image = "rbxassetid://11293981586"
        end)
        
        NotificationData.Connections.unconhover = NotificationData.Objects.Notification.MouseLeave:Connect(function()
            TimeLine.Visible = false
            CloseButton.Image = "rbxassetid://11295275950"
        end)

        NotificationData.Connections.closecon = CloseButton.MouseButton1Click:Connect(function() NotificationData.Functions.Remove(true) end)

        table.insert(AppleHub.Connections, NotificationData.Connections.conhover)
        table.insert(AppleHub.Connections, NotificationData.Connections.unconhover)
        table.insert(AppleHub.Connections, NotificationData.Connections.closecon)

        TweenService:Create(NotificationData.Objects.Notification, TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 30)}):Play()
        if AppleHub.Notifications.Active[flag] then
            flag = NotificationData.Description..tostring(math.random(0, 1000000000))
            AppleHub.Notifications.Active[flag] = NotificationData
        else
            AppleHub.Notifications.Active[flag] = NotificationData
        end

        local start = os.clock()
        task.spawn(function()
            repeat 
                TimeLineBar.Size = UDim2.new((os.clock() - start) / AppleHub.Notifications.Active[flag].Duration, 0, 0, 2)
                task.wait()
            until AppleHub and AppleHub.Notifications and AppleHub.Notifications.Active[flag] and (os.clock() - start) >= AppleHub.Notifications.Active[flag].Duration or AppleHub and AppleHub.Notifications and AppleHub.Notifications.Active and not AppleHub.Notifications.Active[flag] or not AppleHub or not AppleHub.Notifications
            if AppleHub and AppleHub.Notifications and AppleHub.Notifications.Active and AppleHub.Notifications.Active[flag] then
                NotificationData.Functions.Remove(true)
            end
        end)

        return NotificationData
    end
end


do    
    Assets.MainBackground.Init = function()
        local InitInfo = {
            Functions = {Resize = nil, Drag = nil}, 
            Data = {Resizing = false, Dragging = false, LastInputPosition = nil, IsToggleAnimating = false}, 
            Objects = {},
            NavigationButtons = {},
            WindowControls = {IsOpened = false, Instances = {}},
            MobileButtons = {indxs = {}, Buttons = {}}
        }
    
        AppleHub.Notifications.Objects.NotificationGui = Instance.new("ScreenGui", Assets.Functions.gethui())
        AppleHub.Notifications.Objects.NotificationGui.ResetOnSpawn = false
        AppleHub.Notifications.Objects.NotificationGui.IgnoreGuiInset = true
        AppleHub.Notifications.Objects.NotificationGui.DisplayOrder = 10000
        if AppleHub.Mobile then
            Instance.new("UIScale", AppleHub.Notifications.Objects.NotificationGui).Scale = AppleHub.Config.UI.Scale
        end

        AppleHub.ArrayList.Objects.ArrayGui = Instance.new("ScreenGui", Assets.Functions.gethui())
        AppleHub.ArrayList.Objects.ArrayGui.ResetOnSpawn = false
        AppleHub.ArrayList.Objects.ArrayGui.DisplayOrder = 10000
        AppleHub.ArrayList.Objects.ArrayGui.Enabled = false
        if AppleHub.Config.UI.ArrayList == nil then
            AppleHub.Config.UI.ArrayList = false
        end
    
        InitInfo.Objects.MainScreenGui = Instance.new("ScreenGui", Assets.Functions.gethui())
        InitInfo.Objects.MainScreenGui.ResetOnSpawn = false
        InitInfo.Objects.MainScreenGui.IgnoreGuiInset = true
        InitInfo.Objects.MainScreenGui.DisplayOrder = 10000
        InitInfo.Objects.MainScreenGuiScale = Instance.new("UIScale", InitInfo.Objects.MainScreenGui)
        InitInfo.Objects.MainScreenGuiScale.Scale = AppleHub.Config.UI.Scale
            
        InitInfo.Objects.MainFrame = Instance.new("ImageButton", InitInfo.Objects.MainScreenGui)
        InitInfo.Objects.MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        InitInfo.Objects.MainFrame.AutoButtonColor = false
        InitInfo.Objects.MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        InitInfo.Objects.MainFrame.BackgroundTransparency = 1
        InitInfo.Objects.MainFrame.Position = UDim2.fromScale(AppleHub.Config.UI.Position.X, AppleHub.Config.UI.Position.Y)
        InitInfo.Objects.MainFrame.Size = UDim2.fromScale(AppleHub.Config.UI.Size.X, AppleHub.Config.UI.Size.Y)
        InitInfo.Objects.MainFrame.Image = "rbxassetid://16255699706"
        InitInfo.Objects.MainFrame.ImageTransparency = 1
        InitInfo.Objects.MainFrame.ScaleType = Enum.ScaleType.Crop
        InitInfo.Objects.MainFrame.Visible = false
        local mainframecorner = Instance.new("UICorner", InitInfo.Objects.MainFrame)
        mainframecorner.CornerRadius = UDim.new(0, 20)
        InitInfo.Objects.MainFrameScale = Instance.new("UIScale", InitInfo.Objects.MainFrame)
        InitInfo.Objects.MainFrameScale.Scale = 1.2
        table.insert(AppleHub.Corners, mainframecorner)
    
        InitInfo.Objects.PageHolder = Instance.new("Frame", InitInfo.Objects.MainFrame)
        InitInfo.Objects.PageHolder.BackgroundTransparency = 1
        InitInfo.Objects.PageHolder.AnchorPoint = Vector2.new(0.5, 0.5)
        InitInfo.Objects.PageHolder.Size = UDim2.fromScale(1, 1)
        InitInfo.Objects.PageHolder.Position = UDim2.fromScale(0.5, 0.5)
        InitInfo.Objects.PageHolder.ClipsDescendants = true
    
        do
            local TOGGLE_BUTTON_ASSET_ID = "11295285432"

            InitInfo.Objects.ToggleButton = Instance.new("ImageButton", AppleHub.Notifications.Objects.NotificationGui)
            InitInfo.Objects.ToggleButton.AnchorPoint = Vector2.new(0.5, 0)
            InitInfo.Objects.ToggleButton.AutoButtonColor = false
            InitInfo.Objects.ToggleButton.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
            InitInfo.Objects.ToggleButton.BackgroundTransparency = 0.1
            InitInfo.Objects.ToggleButton.BorderSizePixel = 0
            InitInfo.Objects.ToggleButton.Position = UDim2.fromScale(0.5, 0)
            InitInfo.Objects.ToggleButton.Size = UDim2.fromOffset(40, 40)
            InitInfo.Objects.ToggleButton.Draggable = true
            InitInfo.Objects.ToggleButton.Visible = false
            Instance.new("UICorner", InitInfo.Objects.ToggleButton).CornerRadius = UDim.new(1, 0)

            local ToggleStroke = Instance.new("UIStroke", InitInfo.Objects.ToggleButton)
            ToggleStroke.Color = Color3.fromRGB(255, 255, 255)
            ToggleStroke.Transparency = 0.75
            ToggleStroke.Thickness = 1

            local HubIcon = Instance.new("ImageLabel", InitInfo.Objects.ToggleButton)
            HubIcon.AnchorPoint = Vector2.new(0.5, 0.5)
            HubIcon.BackgroundTransparency = 1
            HubIcon.Position = UDim2.fromScale(0.5, 0.5)
            HubIcon.Size = UDim2.fromScale(1, 1)
            HubIcon.ScaleType = Enum.ScaleType.Fit
            HubIcon.Image = "rbxassetid://" .. TOGGLE_BUTTON_ASSET_ID
            Instance.new("UICorner", HubIcon).CornerRadius = UDim.new(1, 0)

            table.insert(AppleHub.Connections, InitInfo.Objects.ToggleButton.MouseButton1Click:Connect(function()
                Assets.Main.ToggleVisibility(not InitInfo.Objects.MainFrame.Visible)
            end))
        end -- end toggle button do block

        if AppleHub.Mobile then
            InitInfo.Objects.MobileKeybindFolder = Instance.new("Folder", InitInfo.Objects.MainScreenGui)
            InitInfo.Functions.CreateMobileButton = function(info)
                local MobileButtonInfo = {
                    Name = info.Name or "mobile button",
                    Flag = info.Flag or "flagbutton",
                    Callbacks = info.Callbacks or {Began = function() end, End = function() end},
                    Instances = {},
                    Connections = {},
                    Functions = {},
                    Data = {Position = {X = 0.062, Y = 0.418}, CurrIndex = 1, NextChange = "Y", Dragging = false},
                }

                if not MobileButtonInfo.Callbacks.Began then
                    MobileButtonInfo.Callbacks.Began = function() end
                end

                if not MobileButtonInfo.Callbacks.End then
                    MobileButtonInfo.Callbacks.End = function() end
                end
    
                if #InitInfo.MobileButtons.indxs > 0 then
                    MobileButtonInfo.Data.CurrIndex = #InitInfo.MobileButtons.indxs + 1
                    local curinfo = InitInfo.MobileButtons.indxs[#InitInfo.MobileButtons.indxs]
                    if curinfo and curinfo.Data and curinfo.Data.Position then
                        local pos = curinfo.Data.Position
                        MobileButtonInfo.Data.Position.X = pos.X
                        if curinfo.Data.NextChange == "Y" then
                            MobileButtonInfo.Data.Position.Y = pos.Y + 0.082
                            MobileButtonInfo.Data.NextChange = "X"
                        else
                            MobileButtonInfo.Data.Position.X = pos.X + 0.048
                        end
                    end
                end
    
                MobileButtonInfo.Instances.MainBG = Instance.new("TextButton", InitInfo.Objects.MobileKeybindFolder)
                MobileButtonInfo.Instances.MainBG.AutoButtonColor = false
                MobileButtonInfo.Instances.MainBG.AnchorPoint = Vector2.new(0.5,0.5)
                MobileButtonInfo.Instances.MainBG.BackgroundTransparency = 0.2
                MobileButtonInfo.Instances.MainBG.BackgroundColor3 = Color3.fromRGB(40,40,40)
                MobileButtonInfo.Instances.MainBG.BorderSizePixel = 0
                MobileButtonInfo.Instances.MainBG.Position = UDim2.fromScale(MobileButtonInfo.Data.Position.X, MobileButtonInfo.Data.Position.Y)
                MobileButtonInfo.Instances.MainBG.Size = UDim2.fromScale(0.049, 0.086)
                MobileButtonInfo.Instances.MainBG.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
                MobileButtonInfo.Instances.MainBG.Text = MobileButtonInfo.Name
                MobileButtonInfo.Instances.MainBG.TextScaled = true
                MobileButtonInfo.Instances.MainBG.ZIndex = 1000000
                MobileButtonInfo.Instances.MainBG.TextColor3 = Color3.fromRGB(255,255,255)
                MobileButtonInfo.Instances.MainBG.Draggable = true
    
                Instance.new("UICorner", MobileButtonInfo.Instances.MainBG).CornerRadius = UDim.new(0, 5)

                local button = Instance.new("ImageButton", MobileButtonInfo.Instances.MainBG)
                button.AnchorPoint = Vector2.new(0.5, 0.5)
                button.Size = UDim2.fromScale(1, 1)
                button.Position = UDim2.fromScale(0.5, 0.5)
                button.ZIndex = 10000000
                button.ImageTransparency = 1
                button.BackgroundTransparency = 1
    
                MobileButtonInfo.Functions.Destroy = function()
                    InitInfo.MobileButtons.Buttons[MobileButtonInfo.Flag] = nil
                    InitInfo.MobileButtons.indxs[MobileButtonInfo.Data.CurrIndex] = nil
    
                    MobileButtonInfo.Instances.MainBG:Destroy()
                    for i,v in MobileButtonInfo.Connections do
                        if table.find(AppleHub.Connections, v) then
                            table.remove(AppleHub.Connections, table.find(AppleHub.Connections, v))
                        end
                        v:Disconnect()
                    end
    
                    local nextbutton = InitInfo.MobileButtons[MobileButtonInfo.Data.CurrIndex + 1]
                    if nextbutton and nextbutton.Data then
                        nextbutton.Data.CurrIndex -= 1
                    end
    
                    
                    table.clear(MobileButtonInfo)
                end

                MobileButtonInfo.Functions.Drag = function(mouseStart: Vector2 | Vector3 | nil, frameStart: UDim2, input: InputObject?)
                    pcall(function()
                        if UserCamera then
                            local Viewport = UserCamera.ViewportSize
                            local Delta = Vector2.new(0, 0)
                            local FrameSize = MobileButtonInfo.Instances.MainBG.AbsoluteSize
                            if mouseStart and input then
                                Delta = (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(mouseStart.X, mouseStart.Y :: Vector2 & Vector3))
                            end
                
                            local newX = math.clamp(frameStart.X.Scale + (Delta.X / Viewport.X), FrameSize.X / Viewport.X / 2, 1 - FrameSize.X / Viewport.X / 2)
                            local newY = math.clamp(frameStart.Y.Scale + (Delta.Y / Viewport.Y), FrameSize.Y / Viewport.Y / 2, 1 - FrameSize.Y / Viewport.Y / 2)
                
                            local Position = UDim2.new(newX, 0, newY, 0)
                            MobileButtonInfo.Instances.MainBG.Position = Position 
                            MobileButtonInfo.Data.Position = {X = newX, Y = newY}           
                        end
                    end)
                end

                local InputStarting, FrameStarting, HoldTime = nil, nil, 0
                local dragcon = button.InputBegan:Connect(function(input)
                    if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then

                        MobileButtonInfo.Callbacks.Began(MobileButtonInfo)

                        AppleHub.InputEndFunc = function(input)
                            if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
                                local hold = (tick()-HoldTime) >= 0.8
                                MobileButtonInfo.Callbacks.End(MobileButtonInfo, hold)
                                HoldTime = 0
                                AppleHub.CurrntInputChangeCallback = function() end
                                AppleHub.InputEndFunc = nil
                                
                                if hold then
                                    MobileButtonInfo.Data.Dragging, InputStarting, FrameStarting = false, input.Position, MobileButtonInfo.Instances.MainBG.Position

                                    if not AppleHub.Config.Game.Other.MobileButtonPos then 
                                        AppleHub.Config.Game.Other.MobileButtonPos = {}
                                    end

                                    AppleHub.Config.Game.Other.MobileButtonPos[MobileButtonInfo.Flag] = {X = FrameStarting.X.Scale, Y = FrameStarting.Y.Scale}
                                    Assets.Config.Save(AppleHub.GameSave, AppleHub.Config.Game)
                                end
                            end
                        end

                        HoldTime = tick()
                        repeat task.wait() until tick() - HoldTime >= 0.8 or HoldTime == 0
                        if HoldTime >= 0.8 then
                            MobileButtonInfo.Data.Dragging, InputStarting, FrameStarting = true, input.Position, MobileButtonInfo.Instances.MainBG.Position
                            AppleHub.CurrntInputChangeCallback = function(input)
                                if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then  
                                    if MobileButtonInfo.Data.Dragging and not AppleHub.Config.UI.FullScreen then
                                        MobileButtonInfo.Functions.Drag(InputStarting, FrameStarting, input)
                                    end
                                end
                            end
                        end

                    end
                end)

                table.insert(AppleHub.Connections, dragcon)
                table.insert(MobileButtonInfo.Connections, dragcon)

                if AppleHub.Config.Game.Other.MobileButtonPos and AppleHub.Config.Game.Other.MobileButtonPos[MobileButtonInfo.Flag] then
                    local pos = AppleHub.Config.Game.Other.MobileButtonPos[MobileButtonInfo.Flag]
                    if pos.X then
                        MobileButtonInfo.Instances.MainBG.Position = UDim2.fromScale(pos.X, MobileButtonInfo.Instances.MainBG.Position.Y.Scale)
                    end
                    if pos.Y then
                        MobileButtonInfo.Instances.MainBG.Position = UDim2.fromScale(MobileButtonInfo.Instances.MainBG.Position.X.Scale, pos.Y)
                    end
                end
            
    
                InitInfo.MobileButtons.indxs[MobileButtonInfo.Data.CurrIndex] = MobileButtonInfo
                InitInfo.MobileButtons.Buttons[MobileButtonInfo.Flag] = MobileButtonInfo
                return MobileButtonInfo
            end
        end
    
        InitInfo.Objects.DropShadow = Instance.new("ImageLabel", InitInfo.Objects.MainFrame)
        InitInfo.Objects.DropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
        InitInfo.Objects.DropShadow.BackgroundTransparency = 1
        InitInfo.Objects.DropShadow.BorderSizePixel = 0
        InitInfo.Objects.DropShadow.Position = UDim2.fromScale(0.5, 0.5)
        InitInfo.Objects.DropShadow.Size = UDim2.new(1, 88, 1, 88)
        InitInfo.Objects.DropShadow.ZIndex = -10
        InitInfo.Objects.DropShadow.Image = "rbxassetid://16286730454"
        InitInfo.Objects.DropShadow.ScaleType = Enum.ScaleType.Slice
        InitInfo.Objects.DropShadow.SliceCenter = Rect.new(512, 512, 512, 512)
        InitInfo.Objects.DropShadow.SliceScale = 0.19
    
        local ZoomFrame = Instance.new("Frame", InitInfo.Objects.MainFrame)
        ZoomFrame.Size = UDim2.fromScale(1, 1)
        ZoomFrame.BackgroundTransparency = 1
        ZoomFrame.ZIndex = 100000
        table.insert(AppleHub.Connections, ZoomFrame.MouseWheelForward:Connect(function()
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) and AppleHub.Background.Objects.MainFrame.Visible then
                AppleHub.Config.UI.Scale = AppleHub.Config.UI.Scale + 0.05
                if AppleHub.Config.UI.Scale > 3 then
                    AppleHub.Config.UI.Scale = 3
                end
                InitInfo.Objects.MainScreenGuiScale.Scale = AppleHub.Config.UI.Scale
                Assets.Config.Save("UI", AppleHub.Config.UI)
            end
        end))
    
        table.insert(AppleHub.Connections, ZoomFrame.MouseWheelBackward:Connect(function()
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) and AppleHub.Background.Objects.MainFrame.Visible then
                AppleHub.Config.UI.Scale = AppleHub.Config.UI.Scale - 0.05
                if AppleHub.Config.UI.Scale < 0.4 then
                    AppleHub.Config.UI.Scale = 0.4
                end
                InitInfo.Objects.MainScreenGuiScale.Scale = AppleHub.Config.UI.Scale
                Assets.Config.Save("UI", AppleHub.Config.UI)
            end
        end))
    
        InitInfo.Objects.NavigationButtons = Instance.new("Frame", InitInfo.Objects.MainFrame)
        InitInfo.Objects.NavigationButtons.BackgroundTransparency = 1
        InitInfo.Objects.NavigationButtons.Position = UDim2.fromScale(0.025, 0.091)
        InitInfo.Objects.NavigationButtons.Size = UDim2.fromScale(0.074, 0.058)
        InitInfo.Objects.NavigationButtons.BorderSizePixel = 0
        local navlist = Instance.new("UIListLayout", InitInfo.Objects.NavigationButtons)
        navlist.Padding = UDim.new(0, 10)
        navlist.FillDirection = Enum.FillDirection.Horizontal
    
        InitInfo.Objects.WindowControls = Instance.new("CanvasGroup", InitInfo.Objects.MainFrame)
        InitInfo.Objects.WindowControls.AnchorPoint = Vector2.new(0.5, 0.5)
        InitInfo.Objects.WindowControls.BackgroundTransparency = 1
        InitInfo.Objects.WindowControls.Position = UDim2.fromScale(0.5, 0.5)
        InitInfo.Objects.WindowControls.Size = UDim2.fromScale(1, 1)
        InitInfo.Objects.WindowControls.ZIndex = 2
    
        local MainControlsWindow = Instance.new("Frame", InitInfo.Objects.WindowControls)
        MainControlsWindow.AnchorPoint = Vector2.new(1, 1)
        MainControlsWindow.BackgroundTransparency = 1
        MainControlsWindow.Position = UDim2.fromScale(1, 1)
        MainControlsWindow.Size = UDim2.fromOffset(100, 50)
    
        local MainWindowControlList = Instance.new("UIListLayout", MainControlsWindow)
        MainWindowControlList.FillDirection = Enum.FillDirection.Horizontal
        MainWindowControlList.SortOrder = Enum.SortOrder.LayoutOrder
        MainWindowControlList.HorizontalFlex = Enum.UIFlexAlignment.Fill
    
    
        InitInfo.Functions.CreateNavigationButton = function(Data: any)
            local buttondata = {
                Button = nil,
                Name = Data.Name or "Button",
                Icon = Data.Icon or "",
                Callback = Data.Callback or function() end
            }
    
            buttondata.Button = Instance.new("ImageButton", InitInfo.Objects.NavigationButtons)
            buttondata.Button.AutoButtonColor = false
            buttondata.Button.BackgroundTransparency = 0.9
            buttondata.Button.Size = UDim2.fromOffset(40, 40)
            buttondata.Button.Image = ""
            Instance.new("UICorner",buttondata.Button).CornerRadius = UDim.new(1,0)
    
            local hovergradient = Instance.new("UIGradient", buttondata.Button)
            hovergradient.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0,0,0), NumberSequenceKeypoint.new(1, 0.331, 0)}
            hovergradient.Enabled = false
    
            local iconimage = Instance.new("ImageLabel", buttondata.Button)
            iconimage.AnchorPoint = Vector2.new(0.5, 0.5)
            iconimage.BackgroundTransparency = 1
            iconimage.BorderSizePixel = 0
            iconimage.Position = UDim2.fromScale(0.5, 0.5)
            iconimage.Size = UDim2.fromScale(0.45, 0.45)
            iconimage.Image = buttondata.Icon
            local iconscale = Instance.new("UIScale", iconimage)
    
            table.insert(AppleHub.Connections, buttondata.Button.MouseEnter:Connect(function()
                hovergradient.Enabled = true
                TweenService:Create(iconscale, TweenInfo.new(0.15), {Scale = 1.2}):Play()
            end))
            table.insert(AppleHub.Connections, buttondata.Button.MouseLeave:Connect(function()
                hovergradient.Enabled = false
                TweenService:Create(iconscale, TweenInfo.new(0.15), {Scale = 1}):Play()
            end))
            table.insert(AppleHub.Connections, buttondata.Button.MouseButton1Click:Connect(function() 
                buttondata.Callback(buttondata)
                TweenService:Create(iconscale, TweenInfo.new(0.15), {Scale = 1.4}):Play()
                task.wait(0.15)
                TweenService:Create(iconscale, TweenInfo.new(0.15), {Scale = 1}):Play()
            end))
    
            InitInfo.NavigationButtons[Data.Name] = buttondata
            return buttondata
        end
    
        InitInfo.Functions.CreateWindowControlButton = function(Data: any)
            local buttondata = {
                Name = Data.Name or "Button",
                Icon = Data.Icon or "",
                Drag = Data.IsDrag or false,
                LayoutOrder = Data.LayoutOrder or 1,
                Visible = Data.Visible or false,
                Objects = {Button = nil, Selection = nil},
                Callbacks = Data.Callbacks or {Clicked = function() end, InputBegan = function() end}
            }
    
            local HasInput = true
            if not buttondata.Callbacks.Clicked then
                buttondata.Callbacks.Clicked = function() end
            elseif not buttondata.Callbacks.InputBegan then
                HasInput = false
                buttondata.Callbacks.InputBegan = function() end
            elseif not buttondata.Callbacks.InputBegan and not buttondata.Callbacks.Clicked then
                HasInput = false
                buttondata.Callbacks.InputBegan = function() end
                buttondata.Callbacks.Clicked = function() end
            end
    
            if buttondata.Drag then
                buttondata.Objects.Button = Instance.new("ImageButton", InitInfo.Objects.WindowControls)
                buttondata.Objects.Button.AnchorPoint = Vector2.new(0.5, 0)
                buttondata.Objects.Button.AutoButtonColor = false
                buttondata.Objects.Button.BackgroundTransparency = 1
                buttondata.Objects.Button.BorderSizePixel = 0
                buttondata.Objects.Button.Position = UDim2.fromScale(0.5, 0)
                buttondata.Objects.Button.Size = UDim2.fromOffset(60, 40)
                buttondata.Objects.Button.ZIndex = 10
                
                local dragicon = Instance.new("ImageLabel", buttondata.Objects.Button)
                dragicon.AnchorPoint = Vector2.new(0.5, 0)
                dragicon.BackgroundTransparency = 1
                dragicon.BorderSizePixel = 0
                dragicon.Position = UDim2.fromScale(0.5, 0)
                dragicon.Size = UDim2.fromScale(1, 0.75)
                dragicon.ZIndex = 10
                dragicon.Image = "rbxassetid://12974354535"
                dragicon.ImageTransparency = 0.5
                dragicon.ScaleType = Enum.ScaleType.Fit
    
                table.insert(AppleHub.Connections, buttondata.Objects.Button.MouseButton1Click:Connect(function()
                    buttondata.Callbacks.Clicked(buttondata)
                end))
            else
                buttondata.Objects.Button = Instance.new("ImageButton", MainControlsWindow)
                buttondata.Objects.Button.AutoButtonColor = false
                buttondata.Objects.Button.BackgroundTransparency = 1
                buttondata.Objects.Button.LayoutOrder = buttondata.LayoutOrder
                buttondata.Objects.Button.Size = UDim2.fromOffset(50, 50)
                buttondata.Objects.Button.ZIndex = 10
        
                buttondata.Objects.ActualIcon = Instance.new("ImageLabel", buttondata.Objects.Button)
                buttondata.Objects.ActualIcon.AnchorPoint = Vector2.new(0.5, 0.5)
                buttondata.Objects.ActualIcon.BackgroundTransparency = 1
                buttondata.Objects.ActualIcon.BorderSizePixel = 0
                buttondata.Objects.ActualIcon.Position = UDim2.fromScale(0.5, 0.5)
                buttondata.Objects.ActualIcon.Size = UDim2.fromOffset(20, 20)
                buttondata.Objects.ActualIcon.Image = buttondata.Icon
                buttondata.Objects.ActualIcon.ImageTransparency = 0.2
                buttondata.Objects.ActualIcon.ScaleType = Enum.ScaleType.Fit
                local ActualIconScale = Instance.new("UIScale", buttondata.Objects.ActualIcon)
        
                buttondata.Objects.Selection = Instance.new("ImageLabel", buttondata.Objects.Button)
                buttondata.Objects.Selection.AnchorPoint = Vector2.new(0.5, 0.5)
                buttondata.Objects.Selection.BackgroundTransparency = 1
                buttondata.Objects.Selection.BorderSizePixel = 0
                buttondata.Objects.Selection.Position = UDim2.fromScale(0.5, 0.5)
                buttondata.Objects.Selection.Size = UDim2.fromOffset(40, 40)
                buttondata.Objects.Selection.Image = "rbxassetid://18412474498"
                buttondata.Objects.Selection.ImageTransparency = 1
                buttondata.Objects.Selection.ScaleType = Enum.ScaleType.Fit
    
                table.insert(AppleHub.Connections, buttondata.Objects.Button.MouseButton1Click:Connect(function()
                    buttondata.Callbacks.Clicked(buttondata)
                    TweenService:Create(ActualIconScale, TweenInfo.new(0.15), {Scale = 0.5}):Play()
        
                    TweenService:Create(buttondata.Objects.Selection, TweenInfo.new(0.15), {ImageTransparency = 0.9}):Play()
                    TweenService:Create(ActualIconScale, TweenInfo.new(0.15), {Scale = 1}):Play()
                end))
    
                if not AppleHub.Mobile then
                    table.insert(AppleHub.Connections, buttondata.Objects.Button.MouseEnter:Connect(function()
                        buttondata.Objects.Selection.ImageTransparency = 1
                        ActualIconScale.Scale = 1.2
    
                        TweenService:Create(ActualIconScale, TweenInfo.new(0.15), {Scale = 1.2}):Play()
                        TweenService:Create(buttondata.Objects.Selection, TweenInfo.new(0.15), {ImageTransparency = 0.8}):Play()
                    end))
    
                    table.insert(AppleHub.Connections, buttondata.Objects.Button.MouseLeave:Connect(function()
                        TweenService:Create(ActualIconScale, TweenInfo.new(0.15), {Scale = 1}):Play()
                        TweenService:Create(buttondata.Objects.Selection, TweenInfo.new(0.15), {ImageTransparency = 1}):Play()
                        task.wait(0.15)
                        buttondata.Objects.Selection.ImageTransparency = 1
                        ActualIconScale.Scale = 1
                    end))
                end
    
            end
    
            if HasInput then
                table.insert(AppleHub.Connections, buttondata.Objects.Button.InputBegan:Connect(buttondata.Callbacks.InputBegan))
            end
        
            InitInfo.WindowControls.Instances[buttondata.Name] = buttondata
            return buttondata
        end
    
        table.insert(AppleHub.Connections, UserInputService.InputEnded:Connect(function(input)
            if AppleHub.InputEndFunc then
                AppleHub.InputEndFunc(input)
            end
        end))
    
        InitInfo.Functions.Resize = function(input : InputObject)
            if InitInfo.Data.Resizing and not AppleHub.Config.UI.FullScreen then
                if not UserCamera then return end
                local delta = input.Position - InitInfo.Data.LastInputPosition
        
                local sensitivity = 0.008
        
                local scaleX = delta.X * sensitivity
                local scaleY = delta.Y * sensitivity
        
                local minScale = 0.15
                local maxScaleX = 0.95
                local maxScaleY = 0.95
        
                local newScaleX = math.clamp(InitInfo.Objects.MainFrame.Size.X.Scale + scaleX, minScale, maxScaleX)
                local newScaleY = math.clamp(InitInfo.Objects.MainFrame.Size.Y.Scale + scaleY, minScale, maxScaleY)
        
                TweenService:Create(InitInfo.Objects.MainFrame, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Size = UDim2.fromScale(newScaleX, newScaleY)}):Play()
                InitInfo.Data.LastInputPosition = input.Position
                AppleHub.Config.UI.Size = {X = newScaleX, Y = newScaleY}
            end
        end
    
        InitInfo.Functions.Drag = function(mouseStart: Vector2 | Vector3 | nil, frameStart: UDim2, input: InputObject?)
            pcall(function()
                if UserCamera then
                    local Viewport = UserCamera.ViewportSize
                    local Delta = Vector2.new(0, 0)
                    local FrameSize = InitInfo.Objects.MainFrame.AbsoluteSize
                    if mouseStart and input then
                        Delta = (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(mouseStart.X, mouseStart.Y :: Vector2 & Vector3))
                    end
        
                    local newX = math.clamp(frameStart.X.Scale + (Delta.X / Viewport.X), FrameSize.X / Viewport.X / 2, 1 - FrameSize.X / Viewport.X / 2)
                    local newY = math.clamp(frameStart.Y.Scale + (Delta.Y / Viewport.Y), FrameSize.Y / Viewport.Y / 2, 1 - FrameSize.Y / Viewport.Y / 2)
        
                    local Position = UDim2.new(newX, 0, newY, 0)
                    InitInfo.Objects.MainFrame.Position = Position
    
                    AppleHub.Config.UI.Position = {X = newX, Y = newY}
                end
            end)
        end
    
    
        AppleHub.CurrntInputChangeCallback = function() end 
        table.insert(AppleHub.Connections, UserInputService.InputChanged:Connect(function(input)
            AppleHub.CurrntInputChangeCallback(input)
        end))
    
    
        InitInfo.Functions.CreateNavigationButton({
            Name = "Close", 
            Icon = "rbxassetid://11293981586", 
            Callback = function()
                if AppleHub and AppleHub.Assets then
                    if Assets.Main and Assets.Main.ToggleVisibility then
                        Assets.Main.ToggleVisibility(false)
                        Assets.Notifications.Send({
                            Description = "Night has been minimized!",
                            Duration = 5
                        })
                    else
                        Assets.Notifications.Send({
                            Description = "Missing close function, send this to a dev!",
                            Duration = 5
                        })
                    end
                end
            end
        })
    
        local forcefullscreen = false
        InitInfo.Functions.CreateWindowControlButton({
            Name = "FullScreen", 
            Icon = "rbxassetid://11295287158", 
            LayoutOrder = 1, 
            Callbacks = {
                Clicked = function(self)
                    if not forcefullscreen then
                        AppleHub.Config.UI.FullScreen = not AppleHub.Config.UI.FullScreen
                    end
                    
                    if AppleHub.Config.UI.FullScreen or forcefullscreen then
                        if not forcefullscreen then
                            AppleHub.Config.UI.Position = {X = InitInfo.Objects.MainFrame.Position.X.Scale, Y = InitInfo.Objects.MainFrame.Position.Y.Scale}
                            AppleHub.Config.UI.Size = {X = InitInfo.Objects.MainFrame.Size.X.Scale, Y = InitInfo.Objects.MainFrame.Size.Y.Scale}
                            AppleHub.Config.UI.Scale = InitInfo.Objects.MainFrameScale.Scale
                        else
                            AppleHub.Config.UI.FullScreen = true
                            forcefullscreen = false
                        end
    
                        TweenService:Create(InitInfo.Objects.MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(1, 1)}):Play()
                        for i,v in AppleHub.Corners do
                            TweenService:Create(v, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {CornerRadius = UDim.new(0, 0)}):Play()
                        end
                        TweenService:Create(InitInfo.Objects.MainFrameScale, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Scale = 1}):Play()
                        self.Objects.ActualIcon.Image = "rbxassetid://11422140434"
                        InitInfo.WindowControls.Instances.Resize.Objects.ActualIcon.ImageTransparency = 0.5
                    else
                        self.Objects.ActualIcon.Image = "rbxassetid://11295287158"
                        InitInfo.WindowControls.Instances.Resize.Objects.ActualIcon.ImageTransparency = 0.2
                        TweenService:Create(InitInfo.Objects.MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(AppleHub.Config.UI.Position.X, AppleHub.Config.UI.Position.Y), Size = UDim2.fromScale(AppleHub.Config.UI.Size.X, AppleHub.Config.UI.Size.Y)}):Play()
                        for i,v in AppleHub.Corners do
                            TweenService:Create(v, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {CornerRadius = UDim.new(0, 20)}):Play()
                        end
                        TweenService:Create(InitInfo.Objects.MainFrameScale, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Scale = AppleHub.Config.UI.Scale}):Play()
                    end
                
                    Assets.Config.Save("UI", AppleHub.Config.UI)
                    
                end
            }
        })
    
    
        local InputStarting, FrameStarting = nil, nil
        InitInfo.Functions.CreateWindowControlButton({
            Name = "Drag", 
            IsDrag = true, 
            Callbacks = {
                InputBegan = function(input)
                    if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
                        if AppleHub.Config.UI.FullScreen then 
    
                            AppleHub.Config.UI.FullScreen = false
    
                            InitInfo.WindowControls.Instances.FullScreen.Objects.ActualIcon.Image = "rbxassetid://11295287158"
                            InitInfo.WindowControls.Instances.Resize.Objects.ActualIcon.ImageTransparency = 0.2
    
                            TweenService:Create(InitInfo.Objects.MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(AppleHub.Config.UI.Position.X, AppleHub.Config.UI.Position.Y), Size = UDim2.fromScale(AppleHub.Config.UI.Size.X, AppleHub.Config.UI.Size.Y)}):Play()
                            for i,v in AppleHub.Corners do
                                TweenService:Create(v, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {CornerRadius = UDim.new(0, 20)}):Play()
                            end
                            TweenService:Create(InitInfo.Objects.MainFrameScale, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Scale = AppleHub.Config.UI.Scale}):Play()
                        end
    
                        InitInfo.Data.Dragging, InputStarting, FrameStarting = true, input.Position, InitInfo.Objects.MainFrame.Position
                        AppleHub.CurrntInputChangeCallback = function(input)
                            if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then  
                                if InitInfo.Data.Dragging and not AppleHub.Config.UI.FullScreen then
                                    InitInfo.Functions.Drag(InputStarting, FrameStarting, input)
                                end
                            end
                        end
                        AppleHub.InputEndFunc = function(input)
                            if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
                                InitInfo.Data.Dragging, InputStarting, FrameStarting = false, input.Position, InitInfo.Objects.MainFrame.Position
                                AppleHub.CurrntInputChangeCallback = function() end
                                Assets.Config.Save("UI", AppleHub.Config.UI)
                                AppleHub.InputEndFunc = nil
                            end
                        end
                    end
                end,
                Clicked = function(self)
                    AppleHub.ControlsVisible = not AppleHub.ControlsVisible
                    if AppleHub.ControlsVisible then
                        MainControlsWindow.Visible = true
                        TweenService:Create(MainControlsWindow, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(100, 50)}):Play()
                    else
                        TweenService:Create(MainControlsWindow, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Position = UDim2.new(1, 100, 1, 0), Size = UDim2.fromOffset(50, 50)}):Play()
                        task.wait(0.5)
                        MainControlsWindow.Visible = false
                    end
                end
            }
        })
    
        InitInfo.Functions.CreateWindowControlButton({
            Name = "Resize", 
            Icon = "rbxassetid://11295287825", 
            LayoutOrder = 2, 
            Callbacks = {
                InputBegan = function(input)
                    if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
                        InitInfo.Data.LastInputPosition, InitInfo.Data.Resizing = input.Position, true
                        AppleHub.CurrntInputChangeCallback = function(input)
                            if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                                InitInfo.Functions.Resize(input)
                            end
                        end
                        AppleHub.InputEndFunc = function(input)
                            if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
                                InitInfo.Data.Resizing = false
                                AppleHub.CurrntInputChangeCallback = function() end
                                Assets.Config.Save("UI", AppleHub.Config.UI)
                                AppleHub.InputEndFunc = function() end
                            end
                        end
                    end
                end
            }
        })
    
        if AppleHub.Config.UI.FullScreen then
            forcefullscreen = true
            InitInfo.WindowControls.Instances.FullScreen.Callbacks.Clicked(InitInfo.WindowControls.Instances.FullScreen)
        end
    
        return InitInfo
    end
        
end

do 
    Assets.ArrayList.Init = function()
        local Data = {
            Entries = {},
            Connections = {},
            Functions = {},
            RainbowSpeed = 5000,
            Loaded = true,
            Objects = AppleHub.ArrayList.Objects
        }


        local Create = function(Class: string, Properties: { [string]: any }): Instance
            local Inst = Instance.new(Class)
            
            for Index, Value in next, Properties do
                if Index == 'Children' then continue end
                Inst[Index] = Value
            end
            
            if Properties.Children then
                for Index, Child in Properties.Children do
                    Child.Name = Index
                    Child.Parent = Inst
                end
            end
            
            return Inst
        end

        local TEXT_SIZE = if AppleHub.Mobile then 16 else 24
        
        local font = Font.new("rbxasset://fonts/families/GothamSSm.json")

        type EntryInstance = Frame & {
            Line: Frame,
            MainText: TextLabel
        }
        
        type ModuleEntry = {
            Name: string,
            Instance: EntryInstance?,
        }
        
        local Template: EntryInstance = Create("Frame", {
            BackgroundColor3 = Color3.new(),
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(0, 30),
            
            Children = {
                Line = Create("Frame", {
                    AnchorPoint = Vector2.new(1, 0),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Position = UDim2.fromScale(1, 0),
                    Size = UDim2.new(0, 2, 1, 0),
                    BorderSizePixel = 0,
                }),
                MainText = Create("TextLabel", {
                    BackgroundTransparency = 1,
                    FontFace = font,
                    Text = '',
                    TextColor3 = Color3.fromRGB(239, 239, 239),
                    TextSize = TEXT_SIZE,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.fromScale(1, 1),
                }),
                UIPadding = Create("UIPadding", {
                    PaddingLeft = UDim.new(0, 6)
                })
            }
        })
        
        local Holder: Frame = Create("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 10),
            Size = UDim2.new(0.5, 0, 1, -10),
            Children = {
                UIListLayout = Create("UIListLayout", {
                    HorizontalAlignment = Enum.HorizontalAlignment.Right,
                    SortOrder = Enum.SortOrder.LayoutOrder
                })
            },
        })


        function Data.Functions.PushModule(Entry: ModuleEntry)
            local EntryInstance = Template:Clone()
            local MainText = EntryInstance.MainText
            local MainSize = GetTextBounds(Entry.Name, font, TEXT_SIZE)
            
            MainText.Text = Entry.Name
            
            local XSize = MainSize.X + 14
            local YSize = TEXT_SIZE + 6
            
            MainText.Size = UDim2.new(0, MainSize.X, 1, 0)
            
            EntryInstance.Size = UDim2.fromOffset(XSize, YSize)
            EntryInstance.LayoutOrder = #Data.Entries
            EntryInstance.Parent = Holder
                        
            local Index = #Data.Entries + 1
            local _Entry
            _Entry = {
                Name = Entry.Name,
                Instance = EntryInstance,
                Index = Index,
                Deconstruct = function()
                    _Entry.Instance:Destroy()
                    Entry.Instance = nil
                    local Index = table.find(Data.Entries, _Entry)
                    if Index then
                        table.remove(Data.Entries, Index)
                    end
                    Data.Functions.Resort()
                end
                
            }
            
            Data.Entries[Index] = _Entry
            
            Data.Functions.Resort()
            
            return _Entry
        end


        function Data.Functions.Resort()
            table.sort(Data.Entries, function(a: ModuleEntry, b: ModuleEntry)
                local TotalTextA = a.Name
                local TotalTextB = b.Name
                
                local SizeA = GetTextBounds(TotalTextA, font, TEXT_SIZE)
                local SizeB = GetTextBounds(TotalTextB, font, TEXT_SIZE)
        
                return SizeA.X > SizeB.X
            end)
            
            for Index, Entry in next, Data.Entries do
                Entry.Instance.LayoutOrder = Index
            end
        end

        local function Rainbow(Delay: number)
            local time = (os.clock() * 1000 + Delay) / 1000
            local hue = (math.sin(time * 0.5) * 40 + 240) 
            local saturation = math.sin(time * 0.3) * 0.1 + 0.35
            local value = 0.95
            
            return Color3.fromHSV(hue / 360, saturation, value)
        end
        
        local function ArrayListRainbow()
            local Speed = Data.RainbowSpeed
            
            for i, Module in Data.Entries do
                local Color = Rainbow(Speed - i * 250) 
                Module.Instance.MainText.TextColor3 = Color
                Module.Instance.Line.BackgroundColor3 = Color
            end
        end

        function Data.Functions.Toggle(visible: boolean)
            AppleHub.ArrayList.Objects.ArrayGui.Enabled = visible
            if not visible then
                for i,v in Data.Connections do
                    if table.find(AppleHub.Connections, v) then
                        table.remove(AppleHub.Connections, table.find(AppleHub.Connections, v))
                    end
                    v:Disconnect()
                    Data.Connections[i] = nil
                end
            else
                if not Data.Connections.Rainbow then
                    local r = game:GetService("RunService").RenderStepped:Connect(ArrayListRainbow)
                    table.insert(Data.Connections, r)
                    table.insert(AppleHub.Connections, r)
                end
            end
        end

        Holder.Parent = AppleHub.ArrayList.Objects.ArrayGui

        AppleHub.ArrayList = Data
        return Data
    end
end

do
    
    Assets.Pages.Init = function()
        local InitInfo = {
            Objects = {},
            Data = {},
            Functions = {},
            Connections = {}
        }  
    
        InitInfo.Objects.Pageselector = Instance.new("Frame", AppleHub.Background.Objects.MainFrame)
        InitInfo.Objects.Pageselector.AnchorPoint = Vector2.new(0.5, 0.5)
        InitInfo.Objects.Pageselector.BackgroundTransparency = 0.9
        InitInfo.Objects.Pageselector.Position = UDim2.fromScale(0.5, 0.5)
        InitInfo.Objects.Pageselector.Size = UDim2.fromScale(1, 1)
        InitInfo.Objects.Pageselector.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        InitInfo.Objects.Pageselector.ZIndex = 40
        InitInfo.Objects.Pageselector.Visible = false
        InitInfo.Objects.Pageselector.ClipsDescendants = false
        InitInfo.Objects.Pageselector.BackgroundTransparency = 1
    
    
        InitInfo.Objects.PageselectorCorner = Instance.new("UICorner", InitInfo.Objects.Pageselector)
        InitInfo.Objects.PageselectorCorner.CornerRadius = UDim.new(0, 20)
        table.insert(AppleHub.Corners, InitInfo.Objects.PageselectorCorner)
    
        local MainPageselectorMenu = Instance.new("ImageLabel", InitInfo.Objects.Pageselector)
        MainPageselectorMenu.AnchorPoint = Vector2.new(0.5, 0.5)
        MainPageselectorMenu.BackgroundColor3 = Color3.fromRGB(62, 62, 62)
        MainPageselectorMenu.Position = UDim2.new(0, -10, 0.5, 0)
        MainPageselectorMenu.Size = UDim2.new(0, 60, 0, 180)
        MainPageselectorMenu.Image = "rbxassetid://16255699706"
        MainPageselectorMenu.ImageTransparency = 0.8
        MainPageselectorMenu.ScaleType = Enum.ScaleType.Crop
        Instance.new("UICorner", MainPageselectorMenu).CornerRadius = UDim.new(1, 0)
        InitInfo.Objects.MainPageselectorScale = Instance.new("UIScale", MainPageselectorMenu)
        InitInfo.Objects.MainPageselectorScale.Scale = 0.5
        MainPageselectorMenu.ZIndex = 40
        
        local PageselectorShadow = Instance.new("ImageLabel", MainPageselectorMenu)
        PageselectorShadow.AnchorPoint = Vector2.new(0.5, 0.5)
        PageselectorShadow.BackgroundTransparency = 1
        PageselectorShadow.Position = UDim2.fromScale(0.5, 0.5)
        PageselectorShadow.Size = UDim2.new(1, 50, 1, 50)
        PageselectorShadow.Image = "rbxassetid://16264499577"
        PageselectorShadow.ImageTransparency = 0.8
        PageselectorShadow.ScaleType = Enum.ScaleType.Slice
        PageselectorShadow.SliceCenter = Rect.new(379, 379, 379, 379)
    
        InitInfo.Objects.PageselectorButtons = Instance.new("Frame", MainPageselectorMenu)
        InitInfo.Objects.PageselectorButtons.AnchorPoint = Vector2.new(0.5, 0.5)
        InitInfo.Objects.PageselectorButtons.BackgroundTransparency = 1
        InitInfo.Objects.PageselectorButtons.Position = UDim2.fromScale(0.5, 0.5)
        InitInfo.Objects.PageselectorButtons.Size = UDim2.fromScale(1, 1)
        InitInfo.Objects.PageselectorButtons.ZIndex = 40
    
        local PageselectorButtonsLayout = Instance.new("UIListLayout", InitInfo.Objects.PageselectorButtons)
        PageselectorButtonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageselectorButtonsLayout.Padding = UDim.new(0, 10)
        PageselectorButtonsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        PageselectorButtonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
        InitInfo.Functions.ToggleSelectorVisibility = function(visible)
            if visible then
                InitInfo.Objects.Pageselector.Visible = true
                InitInfo.Objects.MainPageselectorScale.Scale = 0.5
                InitInfo.Objects.PageselectorButtons.Parent.Position = UDim2.new(0,0,0.5,0)
                InitInfo.Objects.Pageselector.ClipsDescendants = true
                InitInfo.Objects.Pageselector.BackgroundTransparency = 1
        
                TweenService:Create(InitInfo.Objects.Pageselector, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.9}):Play()
                TweenService:Create(InitInfo.Objects.PageselectorButtons.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 60, 0.5, 0)}):Play()
                TweenService:Create(InitInfo.Objects.MainPageselectorScale, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Scale = 1}):Play()
        
            else
                TweenService:Create(InitInfo.Objects.Pageselector, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
                TweenService:Create(InitInfo.Objects.PageselectorButtons.Parent, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, -10, 0.5, 0)}):Play()
                TweenService:Create(InitInfo.Objects.MainPageselectorScale, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Scale = 0.5}):Play()
                task.wait(0.15)
                InitInfo.Objects.Pageselector.Visible = false
                InitInfo.Objects.Pageselector.ClipsDescendants = false
            end
        end

    
        AppleHub.Background.Functions.CreateNavigationButton({
            Name = "Menu", 
            Icon = "rbxassetid://11295285432", 
            Callback = function()
                InitInfo.Functions.ToggleSelectorVisibility(not AppleHub.Pageselector.Objects.Pageselector.Visible)
            end
        })
    
        AppleHub.Pageselector = InitInfo
        return InitInfo
    end
    
        AppleHub.Pages.NewPage(Data: table)
        ► Tạo 1 trang mới trong navigation (bên cạnh Dashboard)
        ► Data.Name    : string  - tên trang
        ► Data.Icon    : string  - rbxassetid icon
        ► Data.Default : boolean - trang mặc định khi mở (chỉ 1 trang được default)
        Ví dụ:
            local Settings = AppleHub.Pages.NewPage({
                Name = "Settings",
                Icon = "rbxassetid://11293977610",
                Default = false
            })
    Assets.Pages.NewPage = function(Data)
        local PageData = {
            Name = Data.Name or "New Page",
            Icon = Data.Icon or "",
            Objects = {},
            Connections = {},
            Default = Data.Default,
            Selected = Data.Default
        }
    
        if not AppleHub.Pageselector then Assets.Pages.Init() end
        PageData.Objects.PageselectorButton = Instance.new("ImageButton", AppleHub.Pageselector.Objects.PageselectorButtons)
        PageData.Objects.PageselectorButton.BackgroundColor3 = Color3.fromRGB(255,255,255)
        PageData.Objects.PageselectorButton.BackgroundTransparency = 1
        PageData.Objects.PageselectorButton.Position = UDim2.fromScale(0.5, 0.5)
        PageData.Objects.PageselectorButton.Size = UDim2.new(0, 50, 0, 50)
        PageData.Objects.PageselectorButton.AutoButtonColor = false
        PageData.Objects.PageselectorButton.ZIndex = 40
        PageData.Objects.PageselectorButton.AutoButtonColor = false
        Instance.new("UICorner", PageData.Objects.PageselectorButton).CornerRadius = UDim.new(1, 0)
        
        local PageselectorButtonIcon = Instance.new("ImageLabel", PageData.Objects.PageselectorButton)
        PageselectorButtonIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        PageselectorButtonIcon.BackgroundTransparency = 1
        PageselectorButtonIcon.Position = UDim2.fromScale(0.5, 0.5)
        PageselectorButtonIcon.Size = UDim2.new(0, 24, 0, 24)
        PageselectorButtonIcon.Image = PageData.Icon
        PageselectorButtonIcon.ImageTransparency = 0.2
        PageselectorButtonIcon.ScaleType = Enum.ScaleType.Fit
        PageselectorButtonIcon.ZIndex = 40
    
        local PageSelectorButtonIconScale = Instance.new("UIScale", PageselectorButtonIcon) 
    
        PageData.Objects.ActualPage = Instance.new("CanvasGroup", AppleHub.Background.Objects.PageHolder)
        PageData.Objects.ActualPage.AnchorPoint = Vector2.new(0.5, 1)
        PageData.Objects.ActualPage.BackgroundTransparency = 1
        PageData.Objects.ActualPage.Position = UDim2.fromScale(0.5, 1)
        PageData.Objects.ActualPage.Size = UDim2.fromScale(1, 1)
        PageData.Objects.ActualPage.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        PageData.Objects.ActualPage.Visible = PageData.Default
        PageData.Objects.ActualPage.ClipsDescendants = true
        if not PageData.Default then
            PageData.Objects.ActualPage.GroupTransparency = 1
            PageData.Objects.ActualPage.Position = UDim2.new(0.5, 0, 1.2, 0)
        end
        
        local Pagepad = Instance.new("UIPadding", PageData.Objects.ActualPage)
        Pagepad.PaddingBottom = UDim.new(0, 20)
        Pagepad.PaddingLeft = UDim.new(0, 10)
        Pagepad.PaddingRight = UDim.new(0, 10)
        Pagepad.PaddingTop = UDim.new(0, 10)
    
        local Header = Instance.new("TextLabel", PageData.Objects.ActualPage)
        Header.AnchorPoint = Vector2.new(0.5, 0)
        Header.BackgroundTransparency = 1
        Header.Position = UDim2.new(0.5, 0, 0, 20)
        Header.Size = UDim2.new(1, 0, 0, 40)
        Header.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold)
        Header.Text = PageData.Name
        Header.TextColor3 = Color3.fromRGB(255, 255, 255)
        Header.TextSize = 22
        Header.TextXAlignment = Enum.TextXAlignment.Center
    
        local MainFrameScrollPage = Instance.new("ScrollingFrame", PageData.Objects.ActualPage)
        MainFrameScrollPage.AnchorPoint = Vector2.new(0.5, 1)
        MainFrameScrollPage.BackgroundTransparency = 1
        MainFrameScrollPage.Position = UDim2.new(0.5, 0, 1, 30)
        MainFrameScrollPage.Size = UDim2.new(1, 0, 0.87, 0)
        MainFrameScrollPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
        MainFrameScrollPage.ScrollBarThickness = 2
        MainFrameScrollPage.ScrollBarImageTransparency = 0.8
        MainFrameScrollPage.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
        MainFrameScrollPage.BorderSizePixel = 0
        MainFrameScrollPage.ClipsDescendants = true
        MainFrameScrollPage.CanvasSize = UDim2.new(0,0,0,0)
        MainFrameScrollPage.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
    
        local ScrollPad = Instance.new("UIPadding", MainFrameScrollPage)
        ScrollPad.PaddingBottom = UDim.new(0, 20)
        ScrollPad.PaddingLeft = UDim.new(0, 10)
        ScrollPad.PaddingRight = UDim.new(0, 10)
        ScrollPad.PaddingTop = UDim.new(0, 5)
    
        local ScrollList = Instance.new("UIListLayout", MainFrameScrollPage)
        ScrollList.SortOrder = Enum.SortOrder.LayoutOrder
        ScrollList.Padding = UDim.new(0, 10)
        ScrollList.VerticalAlignment = Enum.VerticalAlignment.Top
        ScrollList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
        table.insert(AppleHub.Connections, PageData.Objects.PageselectorButton.MouseEnter:Connect(function()
            TweenService:Create(PageData.Objects.PageselectorButton, TweenInfo.new(0.1), {BackgroundTransparency = 0.8}):Play()
            TweenService:Create(PageSelectorButtonIconScale, TweenInfo.new(0.1), {Scale = 1.4}):Play()
        end))
    
        table.insert(AppleHub.Connections, PageData.Objects.PageselectorButton.MouseLeave:Connect(function()
            TweenService:Create(PageData.Objects.PageselectorButton, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
            TweenService:Create(PageSelectorButtonIconScale, TweenInfo.new(0.1), {Scale = 1}):Play()
        end))
    
        table.insert(AppleHub.Connections, PageData.Objects.PageselectorButton.MouseButton1Click:Connect(function()  
            AppleHub.Pageselector.Functions.ToggleSelectorVisibility(false)
            for i,v in AppleHub.Pages do
                if v.Objects and v.Objects.ActualPage then
                    if v.Objects.ActualPage ~= PageData.Objects.ActualPage then
                        v.Selected = false
                        v.Objects.ActualPage.Visible = false
                        TweenService:Create(v.Objects.ActualPage, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.5, 0, 1.2, 0), GroupTransparency = 1}):Play()
                    else
                        PageData.Selected = true
                        v.Objects.ActualPage.Visible = true
                        TweenService:Create(v.Objects.ActualPage, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.5, 0, 1, 0), GroupTransparency = 0}):Play()
                    end
                end
            end
        end))
    
        AppleHub.Pages[PageData.Name] = PageData
        return PageData
    end

end

do
        AppleHub.Dashboard.NewTab(data: table)
        ► Tạo 1 tab mới hiển thị trong Dashboard
        ► data.Name      : string - tên tab (hiện trong list)
        ► data.Icon      : string - rbxassetid icon
        ► data.TabInfo   : string - mô tả ngắn bên dưới tên (có thể nil)
        ► data.Dashboard : page   - page chứa tab, thường là AppleHub.Pages["Dashboard"]
        ► Trả về Tab object, dùng Tab.Functions.NewModule() để thêm module
        Ví dụ:
            local CombatTab = AppleHub.Dashboard.NewTab({
                Name = "Combat",
                Icon = "rbxassetid://11295285432",
                TabInfo = "Combat modules",
                Dashboard = AppleHub.Pages["Dashboard"]
            })
    Assets.Dashboard.NewTab = function(data)
        local tab = {
            Name = data and data.Name or "Tab",
            Icon = data and data.Icon or "",
            Dashboard = data and data.Dashboard or AppleHub.Pages.Dashboard,
            TabInfo = data and data.TabInfo or "Tab",
            Opened = false,
            Objects = {},
            ClipNeeded = false,
            Tweens = {SearchBackGround = nil},
            Connections = {},
            Modules = {},
            Functions = {}, 
            Data = {Dragging = false, SettingsOpen = false}
        }

        if not tab.Dashboard then return end
        tab.Objects.DashBoardButton = Instance.new("TextButton", tab.Dashboard.Objects.ActualPage:FindFirstChildWhichIsA("ScrollingFrame"))
        tab.Objects.DashBoardButton.AnchorPoint = Vector2.new(0.5, 0)
        tab.Objects.DashBoardButton.AutoButtonColor = false
        tab.Objects.DashBoardButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        tab.Objects.DashBoardButton.BackgroundTransparency = 0.7
        tab.Objects.DashBoardButton.Size = UDim2.new(1, 0, 0, 80)
        tab.Objects.DashBoardButton.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
        tab.Objects.DashBoardButton.Text = tab.Name
        tab.Objects.DashBoardButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        tab.Objects.DashBoardButton.TextSize = 16
        tab.Objects.DashBoardButton.TextTransparency = 0.2
        tab.Objects.DashBoardButton.TextXAlignment = Enum.TextXAlignment.Left
        tab.Objects.DashBoardButton.TextYAlignment = Enum.TextYAlignment.Top
        Instance.new("UICorner", tab.Objects.DashBoardButton).CornerRadius = UDim.new(0, 12)
        local DashBoardButtonPad = Instance.new("UIPadding", tab.Objects.DashBoardButton)
        DashBoardButtonPad.PaddingBottom = UDim.new(0, 20)
        DashBoardButtonPad.PaddingLeft = UDim.new(0, 80)
        DashBoardButtonPad.PaddingRight = UDim.new(0, 15)
        DashBoardButtonPad.PaddingTop = UDim.new(0, 20)

        local uistroke = Instance.new("UIStroke", tab.Objects.DashBoardButton)
        uistroke.Color = Color3.fromRGB(255, 255, 255)
        uistroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local strokegradient = Instance.new("UIGradient", uistroke)
        strokegradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(135, 135, 135)), ColorSequenceKeypoint.new(1, Color3.fromRGB(135, 135, 135))}
        strokegradient.Offset = Vector2.new(-1, 0)
        strokegradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1, 0), NumberSequenceKeypoint.new(0.5, 0, 0), NumberSequenceKeypoint.new(1, 1, 0)})

        local ButtonArrow = Instance.new("ImageLabel", tab.Objects.DashBoardButton)
        ButtonArrow.AnchorPoint = Vector2.new(1, 0.5)
        ButtonArrow.BackgroundTransparency = 1
        ButtonArrow.Position = UDim2.fromScale(1, 0.5)
        ButtonArrow.Size = UDim2.new(0, 20, 0, 20)
        ButtonArrow.Image = "rbxassetid://11419703997"
        ButtonArrow.ImageColor3 = Color3.fromRGB(255, 255, 255)
        ButtonArrow.ImageTransparency = 0.5
        ButtonArrow.ScaleType = Enum.ScaleType.Fit

        local UserIcon = Instance.new("ImageLabel", tab.Objects.DashBoardButton)
        UserIcon.AnchorPoint = Vector2.new(0, 0.5)
        UserIcon.BackgroundTransparency = 1
        UserIcon.BorderSizePixel = 0
        UserIcon.Position = UDim2.new(0, -55, 0.5, 0)
        UserIcon.Size = UDim2.fromOffset(35, 35)
        UserIcon.Image = tab.Icon
        UserIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        UserIcon.ImageTransparency = 0.2
        UserIcon.ScaleType = Enum.ScaleType.Fit

        if not tab.TabInfo then 
            tab.Objects.DashBoardButton.TextYAlignment = Enum.TextYAlignment.Center
            tab.Objects.DashBoardButton.Size = UDim2.new(1, 0, 0, 60)
        else
            local tabinfolabel = Instance.new("TextLabel", tab.Objects.DashBoardButton)
            tabinfolabel.AnchorPoint = Vector2.new(0.5, 1)
            tabinfolabel.BackgroundTransparency = 1
            tabinfolabel.Position = UDim2.fromScale(0.5, 1)
            tabinfolabel.Size = UDim2.new(1, 0, 0, 22)
            tabinfolabel.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
            tabinfolabel.Text = tab.TabInfo
            tabinfolabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            tabinfolabel.TextTransparency = 0.5
            tabinfolabel.TextSize = 14
            tabinfolabel.TextXAlignment = Enum.TextXAlignment.Left
            tabinfolabel.TextWrapped = true
            Instance.new("UIPadding", tabinfolabel).PaddingLeft = UDim.new(0, 20)

            local tabinfoicon = Instance.new("ImageLabel", tabinfolabel)
            tabinfoicon.AnchorPoint = Vector2.new(0, 0.5)
            tabinfoicon.BackgroundTransparency = 1
            tabinfoicon.Position = UDim2.new(0, -20, 0.5, 0)
            tabinfoicon.Size = UDim2.fromOffset(15, 15)
            tabinfoicon.Image = "rbxassetid://11422155687"
            tabinfoicon.ImageColor3 = Color3.fromRGB(255, 255, 255)
            tabinfoicon.ImageTransparency = 0.5
            tabinfoicon.ScaleType = Enum.ScaleType.Fit
        end

        if tab.Name == "Premium" then
            tab.Tweens.PremiumGradient = TweenService:Create(strokegradient, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, math.huge, true), {Offset = Vector2.new(1,0)})
            tab.Tweens.PremiumGradient:Play()
        end

        if not AppleHub.Tabs.TabBackground then
            AppleHub.Tabs.TabBackground = Instance.new("ImageButton", AppleHub.Background.Objects.MainFrame)
            AppleHub.Tabs.TabBackground.AnchorPoint = Vector2.new(0.5, 0.5)
            AppleHub.Tabs.TabBackground.BackgroundTransparency = 1
            AppleHub.Tabs.TabBackground.Position = UDim2.fromScale(0.5, 0.5)
            AppleHub.Tabs.TabBackground.Size = UDim2.fromScale(1, 1)
            AppleHub.Tabs.TabBackground.Image = "rbxassetid://16286761786"
            AppleHub.Tabs.TabBackground.ImageTransparency = 0.5
            AppleHub.Tabs.TabBackground.ScaleType = Enum.ScaleType.Stretch
            AppleHub.Tabs.TabBackground.Visible = false
            AppleHub.Tabs.TabBackground.AutoButtonColor = false
            Instance.new("UICorner", AppleHub.Tabs.TabBackground).CornerRadius = UDim.new(0, 20)
        end

        tab.Objects.ActualTab = Instance.new("ImageButton", AppleHub.Tabs.TabBackground)
        tab.Objects.ActualTab.AnchorPoint = Vector2.new(0.5, 0.5)
        tab.Objects.ActualTab.BackgroundTransparency = 1
        tab.Objects.ActualTab.Position = UDim2.fromScale(0.5, 0.5)
        tab.Objects.ActualTab.Size = UDim2.fromScale(0.8, 0.8)
        tab.Objects.ActualTab.Image = "rbxassetid://16286719854"
        tab.Objects.ActualTab.ImageColor3 = Color3.fromRGB(AppleHub.Config.UI.TabColor.value1, AppleHub.Config.UI.TabColor.value2, AppleHub.Config.UI.TabColor.value3)
        tab.Objects.ActualTab.ImageTransparency = AppleHub.Config.UI.TabTransparency
        tab.Objects.ActualTab.ScaleType = Enum.ScaleType.Slice
        tab.Objects.ActualTab.SliceCenter = Rect.new(512, 512, 512, 512)
        tab.Objects.ActualTab.SliceScale = 0.1
        tab.Objects.ActualTab.AutoButtonColor = false
        tab.Objects.ActualTab.Visible = false
        if not AppleHub.Config.Game.Other.TabPos then 
            AppleHub.Config.Game.Other.TabPos = {}
        end
        if AppleHub.Config.Game.Other.TabPos[tab.Name] then
            local pos = AppleHub.Config.Game.Other.TabPos[tab.Name]
            if pos.X then
                tab.Objects.ActualTab.Position = UDim2.fromScale(pos.X, tab.Objects.ActualTab.Position.Y.Scale)
            end
            if pos.Y then
                tab.Objects.ActualTab.Position = UDim2.fromScale(tab.Objects.ActualTab.Position.X.Scale, pos.Y)
            end
        end

        local TabPrism = Instance.new("ImageLabel", tab.Objects.ActualTab)
        TabPrism.AnchorPoint = Vector2.new(0.5, 0.5)
        TabPrism.BackgroundTransparency = 1
        TabPrism.Position = UDim2.fromScale(0.5, 0.5)
        TabPrism.Size = UDim2.new(1, 20, 1, 20)
        TabPrism.ZIndex = 1000
        TabPrism.Image = "rbxassetid://16255699706"
        TabPrism.ImageColor3 = Color3.fromRGB(143, 143, 143)
        TabPrism.ImageTransparency = 0.8
        TabPrism.ScaleType = Enum.ScaleType.Crop
        Instance.new("UICorner", TabPrism).CornerRadius = UDim.new(0, 27)
        local PrismStroke = Instance.new("UIStroke", TabPrism)
        PrismStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        PrismStroke.Color = Color3.fromRGB(255, 255, 255)
        PrismStroke.Transparency = 0.85

        tab.Objects.TabDragCanvas = Instance.new("CanvasGroup", tab.Objects.ActualTab)
        tab.Objects.TabDragCanvas.AnchorPoint = Vector2.new(0.5, 0.5)
        tab.Objects.TabDragCanvas.BackgroundTransparency = 1
        tab.Objects.TabDragCanvas.Position = UDim2.fromScale(0.5, 0.5)
        tab.Objects.TabDragCanvas.Size = UDim2.fromScale(1, 1)
        tab.Objects.TabDragCanvas.ZIndex = 10000000

        tab.Objects.DragButton = Instance.new("ImageButton", tab.Objects.TabDragCanvas)
        tab.Objects.DragButton.AnchorPoint = Vector2.new(0.5, 0)
        tab.Objects.DragButton.AutoButtonColor = false
        tab.Objects.DragButton.BackgroundTransparency = 1
        tab.Objects.DragButton.BorderSizePixel = 0
        tab.Objects.DragButton.Position = UDim2.fromScale(0.5, 0)
        tab.Objects.DragButton.Size = UDim2.fromOffset(60, 40)
        tab.Objects.DragButton.ZIndex = 10
        
        local dragicon = Instance.new("ImageLabel", tab.Objects.DragButton)
        dragicon.AnchorPoint = Vector2.new(0.5, 0)
        dragicon.BackgroundTransparency = 1
        dragicon.BorderSizePixel = 0
        dragicon.Position = UDim2.fromScale(0.5, 0)
        dragicon.Size = UDim2.fromScale(1, 0.75)
        dragicon.ZIndex = 10
        dragicon.Image = "rbxassetid://12974354535"
        dragicon.ImageTransparency = 0.5
        dragicon.ScaleType = Enum.ScaleType.Fit

        tab.Functions.Drag = function(mouseStart: Vector2 | Vector3 | nil, frameStart: UDim2, input: InputObject?)
            pcall(function()
                if UserCamera then
                    local Viewport = UserCamera.ViewportSize
                    local Delta = Vector2.new(0, 0)
                    if mouseStart and input then
                        Delta = (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(mouseStart.X, mouseStart.Y :: Vector2 & Vector3))
                    end
        
                    local newX = frameStart.X.Scale + (Delta.X / (Viewport.X / (AppleHub.Background.Objects.MainFrame.Size.X.Scale + 2.13)))
                    local newY = frameStart.Y.Scale + (Delta.Y / (Viewport.Y / 2))
        
                    tab.Objects.ActualTab.Position = UDim2.fromScale(newX, newY)
                    local flagged = false
                    for i,v in AppleHub.Tabs.Tabs do
                        if v.Objects and v.Objects.ActualTab then
                            local Tab = v.Objects.ActualTab
                            local TabPos = Tab.Position
                            if TabPos.X.Scale > 0.9 or 0 > TabPos.X.Scale or TabPos.Y.Scale >= 0.95 or 0 > TabPos.Y.Scale then
                                if not flagged then
                                    local t = TweenService:Create(AppleHub.Tabs.TabBackground, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 1})
                                    t:Play()
                                    task.spawn(function()
                                        t.Completed:Wait()
                                        task.wait(0.1)
                                        if not flagged and AppleHub.Tabs.TabBackground.ZIndex ~= -100 then
                                            AppleHub.Tabs.TabBackground.ZIndex = -100
                                        end
                                    end)
                                end
                            else
                                if v.Objects.ActualTab.Visible then
                                    TweenService:Create(AppleHub.Tabs.TabBackground, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 0.5}):Play()
                                    AppleHub.Tabs.TabBackground.ZIndex = 1
                                    flagged = true
                                end
                            end
                        end
                    end
    
                    if not AppleHub.Config.Game.Other.TabPos then
                        AppleHub.Config.Game.Other.TabPos = {}
                    end
                    AppleHub.Config.Game.Other.TabPos[tab.Name] = {X = newX, Y = newY}
                end
            end)
        end

        local InputStarting, FrameStarting = nil, nil
        table.insert(AppleHub.Connections, tab.Objects.DragButton.InputBegan:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
                tab.Data.Dragging, InputStarting, FrameStarting = true, input.Position, tab.Objects.ActualTab.Position
                AppleHub.CurrntInputChangeCallback = function(input)
                    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then  
                        if tab.Data.Dragging then
                            tab.Functions.Drag(InputStarting, FrameStarting, input)
                        end
                    end
                end
                AppleHub.InputEndFunc = function(input)
                    if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
                        tab.Data.Dragging, InputStarting, FrameStarting = false, input.Position, tab.Objects.ActualTab.Position
                        AppleHub.CurrntInputChangeCallback = function() end

                        Assets.Config.Save(AppleHub.GameSave, AppleHub.Config.Game)
                        AppleHub.InputEndFunc = nil
                    end
                end
            end
        end))


        
        local TabPad = Instance.new("UIPadding", tab.Objects.ActualTab)
        TabPad.PaddingBottom = UDim.new(0, 10)
        TabPad.PaddingLeft = UDim.new(0, 10)
        TabPad.PaddingRight = UDim.new(0, 10)
        TabPad.PaddingTop = UDim.new(0, 10)

        local TabScale = Instance.new("UIScale", tab.Objects.ActualTab)
        TabScale.Scale = 0
        
        local TabConstraint = Instance.new("UISizeConstraint", tab.Objects.ActualTab)
        TabConstraint.MaxSize = Vector2.new(1000, 800)

        local TabHeader = Instance.new("TextLabel", tab.Objects.ActualTab)
        TabHeader.AnchorPoint = Vector2.new(0.5, 0)
        TabHeader.BackgroundTransparency = 1
        TabHeader.Position = UDim2.fromScale(0.5, 0.04)
        TabHeader.Size = UDim2.new(1, 0, 0, 40)
        TabHeader.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold)
        TabHeader.Text = tab.Name
        TabHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabHeader.TextSize = 22
        TabHeader.TextTransparency = 0.1
        TabHeader.ZIndex = 2

        local CloseButton = Instance.new("ImageButton", tab.Objects.ActualTab)
        CloseButton.AnchorPoint = Vector2.new(1, 0)
        CloseButton.BackgroundColor3 = Color3.fromRGB(AppleHub.Config.UI.TabColor.value1 + 20, AppleHub.Config.UI.TabColor.value2 + 20, AppleHub.Config.UI.TabColor.value3 + 20)
        CloseButton.Position = UDim2.new(1, -5, 0, 5)
        CloseButton.Size = UDim2.fromOffset(30, 30)
        CloseButton.AutoButtonColor = false
        CloseButton.ZIndex = 2
        Instance.new("UICorner", CloseButton).CornerRadius = UDim.new(1, 0)
        tab.Objects.CloseButton = CloseButton

        local CloseButtonIcon = Instance.new("ImageLabel", CloseButton)
        CloseButtonIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        CloseButtonIcon.BackgroundTransparency = 1
        CloseButtonIcon.Position = UDim2.fromScale(0.5, 0.5)
        CloseButtonIcon.Size = UDim2.fromOffset(16, 16)
        CloseButtonIcon.Image = "rbxassetid://11293981586"
        CloseButtonIcon.ImageTransparency = 0.2
        CloseButtonIcon.ZIndex = 2
        CloseButtonIcon.ScaleType = Enum.ScaleType.Fit

        tab.Objects.ScrollFrame = Instance.new("ScrollingFrame", tab.Objects.ActualTab)
        tab.Objects.ScrollFrame.AnchorPoint = Vector2.new(0.5, 0)
        tab.Objects.ScrollFrame.BackgroundTransparency = 1
        tab.Objects.ScrollFrame.Position = UDim2.new(0.5, 0, 0.04, 50)
        tab.Objects.ScrollFrame.Size = UDim2.new(1, -10, 1, -70)
        tab.Objects.ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        tab.Objects.ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        tab.Objects.ScrollFrame.ScrollBarThickness = 2
        tab.Objects.ScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
        tab.Objects.ScrollFrame.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
        tab.Objects.ScrollFrame.BorderSizePixel = 0

        local ScrollFrameList = Instance.new("UIListLayout", tab.Objects.ScrollFrame)
        ScrollFrameList.SortOrder = Enum.SortOrder.LayoutOrder
        ScrollFrameList.Padding = UDim.new(0, 10)
        ScrollFrameList.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local ScrollFramePad = Instance.new("UIPadding", tab.Objects.ScrollFrame)
        ScrollFramePad.PaddingBottom = UDim.new(0, 10)
        ScrollFramePad.PaddingLeft = UDim.new(0, 15)
        ScrollFramePad.PaddingRight = UDim.new(0, 15)

        local SearchBar = Instance.new("Frame", tab.Objects.ScrollFrame)
        SearchBar.AnchorPoint = Vector2.new(0.5, 0)
        SearchBar.BackgroundTransparency = 0.7
        SearchBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        SearchBar.Size = UDim2.new(1, 0, 0, 40)
        SearchBar.LayoutOrder = -1000
        Instance.new("UICorner", SearchBar).CornerRadius = UDim.new(1, 0)

        local SearchBarFocusGradient = Instance.new("UIGradient", SearchBar)
        SearchBarFocusGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(29, 59, 95)), ColorSequenceKeypoint.new(1, Color3.fromRGB(81, 32, 124))}
        SearchBarFocusGradient.Offset = Vector2.new(-0.5, 0)
        SearchBarFocusGradient.Enabled = false

        local SearchBarPadding = Instance.new("UIPadding", SearchBar)
        SearchBarPadding.PaddingLeft = UDim.new(0, 40)

        local SearchBarDepth = Instance.new("ImageLabel", SearchBar)
        SearchBarDepth.AnchorPoint = Vector2.new(0, 0.5)
        SearchBarDepth.BackgroundTransparency = 1
        SearchBarDepth.Position = UDim2.new(0, -40, 0.5, 0)
        SearchBarDepth.Size = UDim2.new(1, 40, 1, 0)
        SearchBarDepth.Image = "rbxassetid://16264857615"
        SearchBarDepth.ImageColor3 = Color3.fromRGB(255, 255, 255)
        SearchBarDepth.ScaleType = Enum.ScaleType.Slice
        SearchBarDepth.SliceCenter = Rect.new(206, 206, 206, 206)

        local MainSearchBarTextBox = Instance.new("TextBox", SearchBar)
        MainSearchBarTextBox.BackgroundTransparency = 1
        MainSearchBarTextBox.Position = UDim2.fromOffset(0, -1)
        MainSearchBarTextBox.Size = UDim2.new(1, -50, 1, 0)
        MainSearchBarTextBox.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
        MainSearchBarTextBox.PlaceholderColor3 = Color3.fromRGB(175, 175, 175)
        MainSearchBarTextBox.PlaceholderText = "Search..."
        MainSearchBarTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        MainSearchBarTextBox.TextSize = 16
        MainSearchBarTextBox.TextTransparency = 0.2
        MainSearchBarTextBox.TextXAlignment = Enum.TextXAlignment.Left
        MainSearchBarTextBox.Text = ""
        MainSearchBarTextBox.ClearTextOnFocus = false

        local SearchBarIcon = Instance.new("ImageLabel", SearchBar)
        SearchBarIcon.AnchorPoint = Vector2.new(0, 0.5)
        SearchBarIcon.BackgroundTransparency = 1
        SearchBarIcon.Position = UDim2.new(0, -25, 0.5, 0)
        SearchBarIcon.Size = UDim2.fromOffset(17, 17)
        SearchBarIcon.Image = "rbxassetid://11293977875"
        SearchBarIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        SearchBarIcon.ImageTransparency = 0.5
        SearchBarIcon.ScaleType = Enum.ScaleType.Fit

        local SearchBarClear = Instance.new("ImageButton", SearchBar)
        SearchBarClear.AnchorPoint = Vector2.new(1, 0.5)
        SearchBarClear.BackgroundTransparency = 1
        SearchBarClear.Position = UDim2.fromScale(1, 0.5)
        SearchBarClear.Size = UDim2.fromOffset(40, 40)
        SearchBarClear.AutoButtonColor = false

        local SearchBarClearIcon = Instance.new("ImageLabel", SearchBarClear)
        SearchBarClearIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        SearchBarClearIcon.BackgroundTransparency = 1
        SearchBarClearIcon.Position = UDim2.fromScale(0.5, 0.5)
        SearchBarClearIcon.Size = UDim2.fromOffset(14, 14)
        SearchBarClearIcon.Image = "rbxassetid://11293981586"
        SearchBarClearIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        SearchBarClearIcon.ImageTransparency = 0.5
        SearchBarClearIcon.ScaleType = Enum.ScaleType.Fit

        local SearchBarClearScale = Instance.new("UIScale", SearchBarClearIcon)
        SearchBarClearScale.Scale = 0


        local resotredback = {backbuttons = {}, keybinds = {}}
        tab.Functions.ToggleTab = function(visible, anim, reopen)
            task.spawn(function()
                tab.Opened = visible
                tab.Objects.ScrollFrame.Visible = visible
                if visible then
                    if not reopen then
                        if not AppleHub.CurrentOpenTab then
                            AppleHub.CurrentOpenTab = {tab}
                        else
                            table.insert(AppleHub.CurrentOpenTab, tab)
                        end
                    end

                    AppleHub.Tabs.TabBackground.Visible = true
                    if not tab.Data.SettingsOpen then
                        CloseButton.Visible = true
                    end
                    tab.Objects.TabDragCanvas.Visible = true
                    TabHeader.TextTransparency = 0.1
                    for i,v in resotredback.backbuttons do
                        v.Visible = true
                    end
                    for i,v in resotredback.keybinds do
                        v.Visible = true
                    end
                    table.clear(resotredback.backbuttons)
                    table.clear(resotredback.keybinds)
                    if anim and AppleHub.Config.UI.Anim then
                        tab.Objects.ActualTab.ImageTransparency = 1
                        TabScale.Scale = 1.2

                        local flagged = false
                        for i,v in AppleHub.Tabs.Tabs do
                            if v.Objects and v.Objects.ActualTab then
                                local Tab = v.Objects.ActualTab
                                local TabPos = Tab.Position
                                if TabPos.X.Scale > 0.9 or 0 > TabPos.X.Scale or TabPos.Y.Scale >= 0.95 or 0 > TabPos.Y.Scale then
                                    if not flagged then
                                        local t = TweenService:Create(AppleHub.Tabs.TabBackground, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 1})
                                        t:Play()
                                        task.spawn(function()
                                            t.Completed:Wait()
                                            task.wait(0.1)
                                            if not flagged and AppleHub.Tabs.TabBackground.ZIndex ~= -100 then
                                                AppleHub.Tabs.TabBackground.ZIndex = -100
                                            end
                                        end)
                                        AppleHub.IsAllowedToHoverTabButton = false
                                    end
                                else
                                    if v.Objects.ActualTab.Visible and v ~= tab or v == tab then
                                        AppleHub.Tabs.TabBackground.ZIndex = 1
                                        TweenService:Create(AppleHub.Tabs.TabBackground, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0.5}):Play()
                                        AppleHub.IsAllowedToHoverTabButton = true
                                        flagged = true
                                    end
                                end
                            end
                        end
                        TweenService:Create(tab.Objects.ActualTab, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = AppleHub.Config.UI.TabTransparency}):Play()
                        TweenService:Create(TabScale, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = 1}):Play()
                    else
                        local flagged = false
                        for i,v in AppleHub.Tabs.Tabs do
                            if v.Objects and v.Objects.ActualTab then
                                local Tab = v.Objects.ActualTab
                                local TabPos = Tab.Position
                                if TabPos.X.Scale > 0.9 or 0 > TabPos.X.Scale or TabPos.Y.Scale >= 0.95 or 0 > TabPos.Y.Scale then
                                    if not flagged then
                                        local t = TweenService:Create(AppleHub.Tabs.TabBackground, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 1})
                                        t:Play()
                                        task.spawn(function()
                                            t.Completed:Wait()
                                            task.wait(0.1)
                                            if not flagged and AppleHub.Tabs.TabBackground.ZIndex ~= -100 then
                                                AppleHub.Tabs.TabBackground.ZIndex = -100
                                            end
                                        end)
                                        AppleHub.IsAllowedToHoverTabButton = false
                                    end
                                else
                                    if v.Objects.ActualTab.Visible and v ~= tab or v == tab then
                                        AppleHub.Tabs.TabBackground.ZIndex = 1
                                        TweenService:Create(AppleHub.Tabs.TabBackground, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 0.5}):Play()
                                        AppleHub.IsAllowedToHoverTabButton = true
                                        flagged = true
                                    end
                                end
                            end
                        end
                        TabScale.Scale = 1
                        tab.Objects.ActualTab.ImageTransparency = AppleHub.Config.UI.TabTransparency
                    end
                else
                    if not reopen then
                        table.remove(AppleHub.CurrentOpenTab, table.find(AppleHub.CurrentOpenTab, tab))
                    end
                    AppleHub.IsAllowedToHoverTabButton = false
                    CloseButton.Visible = false
                    tab.Objects.TabDragCanvas.Visible = false
                    for i,v in tab.Modules do
                        if v.Objects and v.Objects.BackButton and v.Objects.BackButton.Visible then 
                            v.Objects.BackButton.Visible = false
                            table.insert(resotredback.backbuttons, v.Objects.BackButton)
                        end
                        if v.Objects and v.Objects.KeybindButton and v.Objects.KeybindButton.Visible then
                            v.Objects.KeybindButton.Visible = false
                            table.insert(resotredback.keybinds, v.Objects.KeybindButton)
                        end
                    end
                    TabHeader.TextTransparency = 1
                    if anim and AppleHub.Config.UI.Anim  then
                        TweenService:Create(tab.Objects.ActualTab, TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {ImageTransparency = 1}):Play()
                        TweenService:Create(TabScale, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Scale = 1.2}):Play()

                        local flagged = false
                        for i,v in AppleHub.Tabs.Tabs do
                            if v.Objects and v.Objects.ActualTab then
                                local Tab = v.Objects.ActualTab
                                local TabPos = Tab.Position
                                if TabPos.X.Scale > 0.9 or 0 > TabPos.X.Scale or TabPos.Y.Scale >= 0.95 or 0 > TabPos.Y.Scale then
                                    if not flagged then
                                        local t = TweenService:Create(AppleHub.Tabs.TabBackground, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 1})
                                        t:Play()
                                        task.spawn(function()
                                            t.Completed:Wait()
                                            task.wait(0.1)
                                            if not flagged and AppleHub.Tabs.TabBackground.ZIndex ~= -100 then
                                                AppleHub.Tabs.TabBackground.ZIndex = -100
                                            end
                                        end)
                                        AppleHub.IsAllowedToHoverTabButton = false
                                    end
                                else
                                    if v.Objects.ActualTab.Visible and v ~= tab then
                                        TweenService:Create(AppleHub.Tabs.TabBackground, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 0.5}):Play()
                                        AppleHub.Tabs.TabBackground.ZIndex = 1
                                        AppleHub.IsAllowedToHoverTabButton = true
                                        flagged = true
                                    end
                                end
                            end
                        end

                        task.wait(0.15)
                    else
                        TabScale.Scale = 1.2
                        tab.Objects.ActualTab.ImageTransparency = 1
                        local flagged = false
                        for i,v in AppleHub.Tabs.Tabs do
                            if v.Objects and v.Objects.ActualTab then
                                local Tab = v.Objects.ActualTab
                                local TabPos = Tab.Position
                                if TabPos.X.Scale > 0.9 or 0 > TabPos.X.Scale or TabPos.Y.Scale >= 0.95 or 0 > TabPos.Y.Scale then
                                    if not flagged then
                                        local t = TweenService:Create(AppleHub.Tabs.TabBackground, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 1})
                                        t:Play()
                                        task.spawn(function()
                                            t.Completed:Wait()
                                            task.wait(0.1)
                                            if not flagged and AppleHub.Tabs.TabBackground.ZIndex ~= -100 then
                                                AppleHub.Tabs.TabBackground.ZIndex = -100
                                            end
                                        end)
                                        AppleHub.IsAllowedToHoverTabButton = false
                                    end
                                else
                                    if v.Objects.ActualTab.Visible and v ~= tab then
                                        TweenService:Create(AppleHub.Tabs.TabBackground, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 0.5}):Play()
                                        AppleHub.Tabs.TabBackground.ZIndex = 1
                                        AppleHub.IsAllowedToHoverTabButton = true
                                        flagged = true
                                    end
                                end
                            end
                        end
                    end
                    local cnt = 0 
                    for i,v in AppleHub.CurrentOpenTab do
                        cnt += 1
                    end
                    if 0 >= cnt then
                        AppleHub.Tabs.TabBackground.Visible = false
                    end
                end
                tab.Objects.ActualTab.Visible = visible
            end)
        end

        tab.Functions.Search = function(result)
            for i,v in tab.Modules do
                if result == "" then
                    v.Objects.Module.Visible = true
                else
                    if v.Name:lower():find(result:lower()) then
                        v.Objects.Module.Visible = true
                    else
                        v.Objects.Module.Visible = false
                    end
                end
            end
        end

        local dashboardbuttonclickcon = tab.Objects.DashBoardButton.MouseButton1Click:Connect(function()
            TweenService:Create(tab.Objects.DashBoardButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(17,17,17)}):Play()
            tab.Functions.ToggleTab(not tab.Opened, true)
        end)
        table.insert(tab.Connections, dashboardbuttonclickcon)
        table.insert(AppleHub.Connections, dashboardbuttonclickcon)


        local dashboardbuttonhovercon =  tab.Objects.DashBoardButton.MouseEnter:Connect(function()
            if not AppleHub.IsAllowedToHoverTabButton then
                TweenService:Create(tab.Objects.DashBoardButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40,40,40)}):Play()
            end
        end)
        table.insert(tab.Connections, dashboardbuttonhovercon)
        table.insert(AppleHub.Connections, dashboardbuttonhovercon)

        local dashboardbuttonleavecon = tab.Objects.DashBoardButton.MouseLeave:Connect(function()
            TweenService:Create(tab.Objects.DashBoardButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(0,0,0)}):Play()
        end)
        table.insert(tab.Connections, dashboardbuttonleavecon)
        table.insert(AppleHub.Connections, dashboardbuttonleavecon)

        local tabclosebuttoncon = CloseButton.MouseButton1Click:Connect(function()
            tab.Functions.ToggleTab(false, true)
        end)
        table.insert(tab.Connections, tabclosebuttoncon)
        table.insert(AppleHub.Connections, tabclosebuttoncon)

        local searchclearcon =  SearchBarClear.MouseButton1Click:Connect(function()
            MainSearchBarTextBox.Text = ""
            tab.Functions.Search("")
            TweenService:Create(SearchBarClearScale, TweenInfo.new(0.1), {Scale = 0}):Play()
        end)
        table.insert(tab.Connections, searchclearcon)
        table.insert(AppleHub.Connections, searchclearcon)

        local searchfocuslostcon =  MainSearchBarTextBox.FocusLost:Connect(function()
            tab.Functions.Search(MainSearchBarTextBox.Text)
            if MainSearchBarTextBox.Text ~= "" then
                TweenService:Create(SearchBarClearScale, TweenInfo.new(0.1), {Scale = 1}):Play()
            else
                TweenService:Create(SearchBarClearScale, TweenInfo.new(0.3), {Scale = 0}):Play()
            end
            TweenService:Create(SearchBar, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 0.7}):Play()
            task.wait(0.3)
            SearchBarFocusGradient.Enabled = false
            if tab.Tweens.SearchBackGround then
                tab.Tweens.SearchBackGround:Cancel()
            end
        end)
        table.insert(tab.Connections, searchfocuslostcon)
        table.insert(AppleHub.Connections, searchfocuslostcon)

        local searchfocuscon =  MainSearchBarTextBox.Focused:Connect(function()
            SearchBarFocusGradient.Enabled = true
            tab.Tweens.SearchBackGround = TweenService:Create(SearchBarFocusGradient, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, math.huge, true), {Offset = Vector2.new(.5, 0)})
            tab.Tweens.SearchBackGround:Play()

            TweenService:Create(SearchBar, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 0}):Play()
        end)
        table.insert(tab.Connections, searchfocuscon)
        table.insert(AppleHub.Connections, searchfocuscon)

            Tab.Functions.NewModule(data: table)
            ► Tạo 1 module (toggle on/off) bên trong tab
            ► data.Name        : string   - tên module
            ► data.Description : string   - mô tả module
            ► data.Icon        : string   - rbxassetid icon (tùy chọn)
            ► data.Flag        : string   - ID unique để lưu config
            ► data.Default     : boolean  - bật mặc định không (true/false)
            ► data.Callback    : function(self, enabled) - chạy khi toggle
            ► Trả về Module object, dùng Module.Functions.Settings.xxx() để thêm settings
            Ví dụ:
                local Aimbot = CombatTab.Functions.NewModule({
                    Name = "Aimbot",
                    Description = "Tự động aim vào địch",
                    Flag = "Aimbot",
                    Default = false,
                    Callback = function(self, enabled)
                        if enabled then
                        else
                        end
                    end
                })
        tab.Functions.NewModule = function(data)
            local ModuleData = {
                Name = data and data.Name or "New Module",
                Description = data and data.Description or "New Module",
                Icon = data and data.Icon or "",
                Default = data and data.Default or false,
                Data = {Enabled = false, Keybind = nil, SettingKeybind = false, ExcludeSettingsVisiblity = {}, SettingsOpen = false, ArrayIndex = nil},
                Button = data and data.Button,
                Flag = data and data.Flag or "New Module",
                Callback = data and data.Callback or function() end,
                Settings = {},
                Objects = {},
                Connections = {},
                Functions = {Toggle = nil, Settings = {}},
            }

            if tab.Name == "Premium" then
                ModuleData.Callback = function(self, callback)
                    if callback then
                        task.wait(0.3)
                        Assets.Notifications.Send({
                            Description = "Contact the developer to purchase or get a trial",
                            Duration = 4
                        })


                        task.wait(0.1)
                        ModuleData.Functions.Toggle(false, false, false, true, true)
                    end
                end
            end

            ModuleData.Objects.Module = Instance.new("ImageButton", tab.Objects.ScrollFrame)
            ModuleData.Objects.Module.AutoButtonColor = false
            ModuleData.Objects.Module.BackgroundTransparency = 0.95
            ModuleData.Objects.Module.Size = UDim2.new(1, 0, 0, 65)
            ModuleData.Objects.Module.ZIndex = 2
            ModuleData.Objects.Module.ImageTransparency = 1
            ModuleData.Objects.Module.ClipsDescendants = true
            Instance.new("UICorner", ModuleData.Objects.Module).CornerRadius = UDim.new(0, 15)
            
            local ModulePadding = Instance.new("UIPadding", ModuleData.Objects.Module)
            ModulePadding.PaddingBottom = UDim.new(0, 10)
            ModulePadding.PaddingLeft = UDim.new(0, 20)
            ModulePadding.PaddingRight = UDim.new(0, 20)
            ModulePadding.PaddingTop = UDim.new(0, 10)
            

            local ModuleIcon = Instance.new("ImageLabel", ModuleData.Objects.Module)
            ModuleIcon.BackgroundTransparency = 1
            ModuleIcon.Position = UDim2.fromOffset(0, 10)
            ModuleIcon.Size = UDim2.fromOffset(25, 25)
            ModuleIcon.Image = ModuleData.Icon
            ModuleIcon.ImageColor3 = Color3.fromRGB(255,255,255)
            ModuleIcon.ScaleType = Enum.ScaleType.Fit

            local ModuleDetails = Instance.new("Frame", ModuleData.Objects.Module)
            ModuleDetails.BackgroundTransparency = 1
            ModuleDetails.Position = UDim2.fromOffset(40, 2)
            ModuleDetails.Size = UDim2.new(1, -40, 0, 40)

            local ModuleDetailsList = Instance.new("UIListLayout", ModuleDetails)
            ModuleDetailsList.SortOrder = Enum.SortOrder.LayoutOrder
            ModuleDetailsList.Padding = UDim.new(0, 2)
            ModuleDetailsList.VerticalAlignment = Enum.VerticalAlignment.Center

            local NameText = Instance.new("TextLabel", ModuleDetails)
            NameText.BackgroundTransparency = 1
            NameText.Size = UDim2.fromScale(1, 0.35)
            NameText.ZIndex = 2
            NameText.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
            NameText.Text = ModuleData.Name
            NameText.TextColor3 = Color3.fromRGB(255,255,255)
            NameText.TextSize = 16
            NameText.TextTruncate = Enum.TextTruncate.AtEnd
            NameText.TextXAlignment = Enum.TextXAlignment.Left
            NameText.TextYAlignment = Enum.TextYAlignment.Bottom

            local KeybindInfoText = Instance.new("TextLabel", ModuleDetails)
            KeybindInfoText.AnchorPoint = Vector2.new(0.5, 1)
            KeybindInfoText.BackgroundTransparency = 1
            KeybindInfoText.Size = UDim2.new(0.9, 0, 0, 15)
            KeybindInfoText.ZIndex = 2
            KeybindInfoText.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
            KeybindInfoText.Text = "No Keybind Set"
            KeybindInfoText.TextColor3 = Color3.fromRGB(255,255,255)
            KeybindInfoText.TextSize = 14
            KeybindInfoText.TextTransparency = 0.5
            KeybindInfoText.TextXAlignment = Enum.TextXAlignment.Left
            KeybindInfoText.TextWrapped = true

            local KeybindInfoPadding = Instance.new("UIPadding", KeybindInfoText)
            KeybindInfoPadding.PaddingLeft = UDim.new(0, 20)

            local KeybindInfoIcon = Instance.new("ImageLabel", KeybindInfoText)
            KeybindInfoIcon.AnchorPoint = Vector2.new(0, 0.5)
            KeybindInfoIcon.BackgroundTransparency = 1
            KeybindInfoIcon.Position = UDim2.new(0, -20, 0.5, 0)
            KeybindInfoIcon.Size = UDim2.fromOffset(15, 15)
            KeybindInfoIcon.Image = "rbxassetid://11422155687"
            KeybindInfoIcon.ImageColor3 = Color3.fromRGB(255,255,255)
            KeybindInfoIcon.ImageTransparency = 0.5
            KeybindInfoIcon.ScaleType = Enum.ScaleType.Fit

            local Requirements = Instance.new("Frame", ModuleData.Objects.Module)
            Requirements.AnchorPoint = Vector2.new(0.5, 0)
            Requirements.BackgroundTransparency = 1
            Requirements.BorderSizePixel = 0
            Requirements.Position = UDim2.new(0.5, 0, 0, 2)
            Requirements.Size = UDim2.new(1, 0, 0, 165)
            Requirements.Visible = false

            local RequirementsList = Instance.new("UIListLayout", Requirements)
            RequirementsList.SortOrder = Enum.SortOrder.LayoutOrder
            RequirementsList.Padding = UDim.new(0, 10)
            RequirementsList.HorizontalAlignment = Enum.HorizontalAlignment.Right


            local ToggleButton = Instance.new("ImageButton", Requirements)
            ToggleButton.AutoButtonColor = false
            ToggleButton.BackgroundColor3 = Color3.fromRGB(43, 43, 43)
            ToggleButton.Position = UDim2.fromOffset(0, 55)
            ToggleButton.Size = UDim2.fromOffset(40, 40)
            ToggleButton.ZIndex = 2
            Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(1, 0)

            local ToggleButtonPadding = Instance.new("UIPadding", ToggleButton)
            ToggleButtonPadding.PaddingLeft = UDim.new(0, 10)

            local ToggleButtonEnabledIcon = Instance.new("ImageLabel", ToggleButton)
            ToggleButtonEnabledIcon.BackgroundTransparency = 1
            ToggleButtonEnabledIcon.Position = UDim2.fromScale(0, 0.25)
            ToggleButtonEnabledIcon.Size = UDim2.fromOffset(20, 20)
            ToggleButtonEnabledIcon.ZIndex = 2
            ToggleButtonEnabledIcon.Image = "rbxassetid://3926305904"
            ToggleButtonEnabledIcon.ImageColor3 = Color3.fromRGB(255,255,255)
            ToggleButtonEnabledIcon.ImageRectOffset = Vector2.new(284, 4)
            ToggleButtonEnabledIcon.ImageRectSize = Vector2.new(24, 24)

            local DescriptionText = Instance.new("TextLabel", Requirements)
            DescriptionText.BackgroundTransparency = 1
            DescriptionText.LayoutOrder = 100
            DescriptionText.Size = UDim2.new(1, 0, 0, 20)
            DescriptionText.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
            DescriptionText.Text = ModuleData.Description
            DescriptionText.TextColor3 = Color3.fromRGB(255,255,255)
            DescriptionText.TextSize = 12
            DescriptionText.TextTransparency = 0.6
            DescriptionText.TextXAlignment = Enum.TextXAlignment.Left

            local SettingsButton = Instance.new("TextButton", Requirements)
            SettingsButton.AnchorPoint = Vector2.new(0.5, 0)
            SettingsButton.AutoButtonColor = false
            SettingsButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            SettingsButton.BackgroundTransparency = 0.7
            SettingsButton.LayoutOrder = 5
            SettingsButton.Size = UDim2.new(1, 0, 0, 50)
            SettingsButton.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
            SettingsButton.Text = ModuleData.Name .. " Settings"
            SettingsButton.TextColor3 = Color3.fromRGB(255,255,255)
            SettingsButton.TextSize = 16
            SettingsButton.TextTransparency = 0.2
            SettingsButton.TextXAlignment = Enum.TextXAlignment.Left
            SettingsButton.ZIndex = 2
            SettingsButton.Visible = false
            Instance.new("UICorner", SettingsButton).CornerRadius = UDim.new(0, 12)

            local SettingsButtonPadding = Instance.new("UIPadding", SettingsButton)
            SettingsButtonPadding.PaddingBottom = UDim.new(0, 1)
            SettingsButtonPadding.PaddingLeft = UDim.new(0, 20)
            SettingsButtonPadding.PaddingRight = UDim.new(0, 15)

            local SettingsButtonIcon = Instance.new("ImageLabel", SettingsButton)
            SettingsButtonIcon.AnchorPoint = Vector2.new(1, 0.5)
            SettingsButtonIcon.BackgroundTransparency = 1
            SettingsButtonIcon.Position = UDim2.fromScale(1, 0.5)
            SettingsButtonIcon.Size = UDim2.fromOffset(20, 20)
            SettingsButtonIcon.Image = "rbxassetid://11419703997"
            SettingsButtonIcon.ImageColor3 = Color3.fromRGB(255,255,255)
            SettingsButtonIcon.ImageTransparency = 0.5
            SettingsButtonIcon.ScaleType = Enum.ScaleType.Fit

            local Backbutton = Instance.new("ImageButton", tab.Objects.ActualTab)
            Backbutton.BackgroundColor3 = Color3.fromRGB(AppleHub.Config.UI.TabColor.value1 + 20, AppleHub.Config.UI.TabColor.value2 + 20, AppleHub.Config.UI.TabColor.value3 + 20)
            Backbutton.Position = UDim2.new(1.8, 0, 0, 5)
            Backbutton.Size = UDim2.fromOffset(30, 30)
            Backbutton.AutoButtonColor = false
            Backbutton.ZIndex = 2
            Backbutton.Visible = false
            Instance.new("UICorner", Backbutton).CornerRadius = UDim.new(1, 0)
            ModuleData.Objects.BackButton = Backbutton

            local BackButtonIcon = Instance.new("ImageLabel", Backbutton)
            BackButtonIcon.AnchorPoint = Vector2.new(0.5, 0.5)
            BackButtonIcon.BackgroundTransparency = 1
            BackButtonIcon.Position = UDim2.fromScale(0.5, 0.5)
            BackButtonIcon.Size = UDim2.fromOffset(16, 16)
            BackButtonIcon.Image = "rbxassetid://11293981980"
            BackButtonIcon.ImageTransparency = 0.2
            BackButtonIcon.ZIndex = 2
            BackButtonIcon.ScaleType = Enum.ScaleType.Fit

            local ModuleSettingsList = Instance.new("UIListLayout", nil)
            ModuleSettingsList.SortOrder = Enum.SortOrder.LayoutOrder
            ModuleSettingsList.Padding = UDim.new(0, 15)
            ModuleSettingsList.HorizontalAlignment = Enum.HorizontalAlignment.Center

            local ModuleSettings = Instance.new("Folder", ModuleData.Objects.Module)

            local KeyBindButton = Instance.new("TextButton", tab.Objects.ActualTab)
            KeyBindButton.AnchorPoint = Vector2.new(0.5, 1)
            KeyBindButton.AutoButtonColor = false
            KeyBindButton.BackgroundColor3 = Color3.fromRGB(AppleHub.Config.UI.KeybindColor.value1, AppleHub.Config.UI.KeybindColor.value2, AppleHub.Config.UI.KeybindColor.value3)
            KeyBindButton.BackgroundTransparency = AppleHub.Config.UI.KeybindTransparency
            KeyBindButton.Position = UDim2.new(0.5,0,1,-20)
            KeyBindButton.Size = UDim2.new(1, -40, 0, 45)
            KeyBindButton.ZIndex = 2
            KeyBindButton.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold)
            KeyBindButton.Text = "CLICK TO BIND"
            KeyBindButton.TextColor3 = Color3.fromRGB(255,255,255)
            KeyBindButton.TextSize = 17
            KeyBindButton.Visible = false
            Instance.new("UICorner", KeyBindButton).CornerRadius = UDim.new(1, 0)
            ModuleData.Objects.KeybindButton = KeyBindButton

            local DropOpen = false
            local db = false
            local moduleclickcon = ModuleData.Objects.Module.MouseButton1Click:Connect(function()
                if db then return end
                db = true
                DropOpen = not DropOpen
                if DropOpen then
                    DescriptionText.TextTransparency = 0.6
                    SettingsButton.TextTransparency = 0.2
                    SettingsButton.BackgroundTransparency = 0.7
                    SettingsButtonIcon.ImageTransparency = 0.5

                    DescriptionText.Visible = true
                    SettingsButton.Visible = true
                    Requirements.Visible = true
                    Requirements.AnchorPoint = Vector2.new(0.5, 1)
                    Requirements.Position = UDim2.new(0.5, 0, 1, 2)
                    TweenService:Create(Requirements, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2)}):Play()
                    TweenService:Create(ModuleData.Objects.Module, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, 150)}):Play()
                else
                    TweenService:Create(ModuleData.Objects.Module, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, 65)}):Play()
                    if not ModuleData.Data.Enabled then
                        Requirements.Visible = false
                        TweenService:Create(Requirements, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 2)}):Play()
                    else
                        TweenService:Create(DescriptionText, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
                        TweenService:Create(SettingsButton, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
                        TweenService:Create(SettingsButtonIcon, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
                        task.wait(0.5)
                        DescriptionText.Visible = false
                        SettingsButton.Visible = false
                    end
                end
                db = false
            end)
            table.insert(AppleHub.Connections, moduleclickcon)
            table.insert(ModuleData.Connections, moduleclickcon)

            ModuleData.onToggles = {}
            ModuleData.Functions.Toggle = function(enabled: boolean, override: boolean, notify: boolean, save: boolean, updateArray: boolean)
                if setthreadidentity then
                    setthreadidentity(8)
                end

                if notify == nil then notify = true end
                if enabled == nil or typeof(enabled) == "string" then
                    enabled = not ModuleData.Data.Enabled
                end
                if save == nil then save = true end
                if ModuleData.Button then
                    ModuleData.Callback(ModuleData, true); task.wait(0.1); ModuleData.Callback(ModuleData, false)
                end

                local Array
                if not AppleHub.ArrayList.Loaded then
                    Array = Assets.ArrayList.Init()
                else
                    Array = AppleHub.ArrayList
                end

                if enabled then
                    if not ModuleData.Data.Enabled or override then
                        ModuleData.Data.Enabled = enabled
                        task.spawn(function()
                            ModuleData.Callback(ModuleData, enabled)
                        end)

                        task.spawn(function()
                            for i,v in next, ModuleData.onToggles do
                                v(ModuleData, enabled)
                            end
                        end)

                        if updateArray then
                            ModuleData.Data.ArrayIndex = Array.Functions.PushModule({
                                Name = ModuleData.Name
                            })
                        end

                        if not DropOpen then
                            DescriptionText.Visible = false
                            SettingsButton.Visible = false
                            Requirements.Visible = true
                            Requirements.AnchorPoint = Vector2.new(0.5, 0)
                            Requirements.Position = UDim2.new(0.5, 0, 0, 2)
                        end
                        TweenService:Create(ToggleButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(32, 175, 77)}):Play()
                        TweenService:Create(ToggleButtonEnabledIcon, TweenInfo.new(0.1), {ImageTransparency = 1}):Play()
                        task.wait(0.05)
                        ToggleButtonEnabledIcon.ImageRectOffset = Vector2.new(644, 204)
                        ToggleButtonEnabledIcon.ImageRectSize = Vector2.new(36, 36)
                        TweenService:Create(ToggleButtonEnabledIcon, TweenInfo.new(0.1), {ImageTransparency = 0}):Play()
                        if notify and AppleHub.Config.UI.Notifications then
                            Assets.Notifications.Send({
                                Description = ModuleData.Name.." enabled!",
                                Duration = 2.5
                            })
                        end
                    end
                else
                    if ModuleData.Data.Enabled or override then
                        ModuleData.Data.Enabled = enabled
                        task.spawn(function()
                            ModuleData.Callback(ModuleData, enabled)
                            for i,v in next, ModuleData.onToggles do
                                v(ModuleData, enabled)
                            end
                        end)

                        if updateArray and ModuleData.Data.ArrayIndex then
                            local Index = ModuleData.Data.ArrayIndex
                            if Index.Deconstruct then
                                Index.Deconstruct()
                            end
                            ModuleData.Data.ArrayIndex = nil
                        end

                        TweenService:Create(ToggleButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(43, 43, 43)}):Play()
                        TweenService:Create(ToggleButtonEnabledIcon, TweenInfo.new(0.1), {ImageTransparency = 1}):Play()
                        task.wait(0.05)
                        ToggleButtonEnabledIcon.ImageRectOffset = Vector2.new(284, 4)
                        ToggleButtonEnabledIcon.ImageRectSize = Vector2.new(24, 24)
                        TweenService:Create(ToggleButtonEnabledIcon, TweenInfo.new(0.1), {ImageTransparency = 0}):Play()
                        if not DropOpen then
                            Requirements.Visible = false
                            DescriptionText.Visible = true
                            SettingsButton.Visible = true
                            Requirements.AnchorPoint = Vector2.new(0.5, 1)
                            Requirements.Position = UDim2.new(0.5, 0, 1, 2)
                        end
                        if notify and AppleHub.Config.UI.Notifications then
                            Assets.Notifications.Send({
                                Description = ModuleData.Name.." disabled!",
                                Duration = 2.5
                            })
                        end
                    end
                end
                if save then
                    AppleHub.Config.Game.Modules[ModuleData.Flag] = enabled
                    Assets.Config.Save(AppleHub.GameSave, AppleHub.Config.Game)
                end
            end

            if AppleHub.Mobile then
                KeyBindButton.Text = "TAP TO BIND"
            end

            ModuleData.Functions.BindKeybind = function(Bind: string, Save: boolean)
                if not ModuleData.Data.Keybind then
                    local suc = pcall(function()
                        if not AppleHub.Mobile then
                            ModuleData.Data.Keybind = Enum.KeyCode[Bind]
                            ModuleData.Data.SettingKeybind = false
                            KeybindInfoText.Text = "Set Keybind is: "..Bind
                            KeyBindButton.Text = "Bound to: "..Bind
                        else
                            AppleHub.Background.Functions.CreateMobileButton({
                                Name = ModuleData.Name,
                                Flag = ModuleData.Flag.."MobileButton",
                                Callbacks = {
                                    End = function(self, drag : boolean)
                                        if drag then return end
                                        ModuleData.Functions.Toggle(nil, false, true, true, true)
                                    end
                                }
                            })
                            KeyBindButton.Text = "TAP TO UNBIND"
                            KeybindInfoText.Text = "Set Keybind is a Button"
                            ModuleData.Data.Keybind = "button"
                        end
                    end)

                    if Save and suc then
                        AppleHub.Config.Game.Keybinds[ModuleData.Flag] = Bind
                        Assets.Config.Save(AppleHub.GameSave, AppleHub.Config.Game)
                    end
                end
            end

            ModuleData.Functions.UnbindKeybind = function(Save: boolean)
                if AppleHub.Mobile then
                    if AppleHub.Background.MobileButtons and AppleHub.Background.MobileButtons.Buttons[ModuleData.Flag.."MobileButton"] and AppleHub.Background.MobileButtons.Buttons[ModuleData.Flag.."MobileButton"].Functions then
                        AppleHub.Background.MobileButtons.Buttons[ModuleData.Flag.."MobileButton"].Functions.Destroy()
                    end
                    KeyBindButton.Text = "TAP TO BIND"
                else
                    ModuleData.Data.Keybind = nil 
                    KeyBindButton.Text = "CLICK TO BIND" 
                    ModuleData.Data.SettingKeybind = false
                end

                KeybindInfoText.Text = "No Keybind Set"
                AppleHub.Config.Game.Keybinds[ModuleData.Flag] = nil
                ModuleData.Data.Keybind = nil

                if Save then
                    Assets.Config.Save(AppleHub.GameSave, AppleHub.Config.Game)
                end
            end

            local keybindbuttonpresscon = KeyBindButton.MouseButton1Click:Connect(function()
                if not AppleHub.Mobile then
                    ModuleData.Data.SettingKeybind = true
                    KeyBindButton.Text = "Press Any Key"
                else
                    if ModuleData.Data.Keybind then
                        ModuleData.Functions.UnbindKeybind(true)
                    else
                        ModuleData.Functions.BindKeybind("Binded", true)
                    end
                end
            end)
            table.insert(AppleHub.Connections, keybindbuttonpresscon)
            table.insert(ModuleData.Connections, keybindbuttonpresscon)

            if AppleHub.Config.Game.Keybinds[ModuleData.Flag] then
                if AppleHub.Config.Game.Keybinds[ModuleData.Flag] == "Binded" and AppleHub.Mobile then
                    ModuleData.Functions.BindKeybind("Binded", false)
                else
                    ModuleData.Functions.BindKeybind(AppleHub.Config.Game.Keybinds[ModuleData.Flag], false)
                end
            end

            local keybindinputbegancon = UserInputService.InputBegan:Connect(function(input)
                if input.KeyCode then
                    if ModuleData.Data.SettingKeybind then
                        if ModuleData.Data.Keybind and ModuleData.Data.Keybind == input.KeyCode then
                            ModuleData.Functions.UnbindKeybind(true)
                            return
                        end
                        ModuleData.Functions.BindKeybind(input.KeyCode.Name, true)
                    else
                        if not UserInputService:GetFocusedTextBox() then
                            if ModuleData.Data.Keybind and ModuleData.Data.Keybind == input.KeyCode then
                                ModuleData.Functions.Toggle(not ModuleData.Data.Enabled, false, true, true, true)
                            end
                        end
                    end
                end
            end)
            table.insert(AppleHub.Connections, keybindinputbegancon)
            table.insert(ModuleData.Connections, keybindinputbegancon)


            local togglebuttoncon = ToggleButton.MouseButton1Click:Connect(function()
                ModuleData.Functions.Toggle(not ModuleData.Data.Enabled, false, true, true, true)
            end)
            table.insert(AppleHub.Connections, togglebuttoncon)
            table.insert(ModuleData.Connections, togglebuttoncon)

            local settingsbuttoncon = SettingsButton.MouseButton1Click:Connect(function()
                tab.Data.SettingsOpen = true
                ModuleData.Data.SettingsOpen = true
                tab.Objects.ActualTab.ClipsDescendants = true      
                tab.ClipNeeded = true          
                TweenService:Create(tab.Objects.ScrollFrame, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(-1.8, 0, 0.04, 50)}):Play()
                TweenService:Create(TabHeader, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(-1.8, 0.04)}):Play()
                TweenService:Create(CloseButton, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(-1.8, 0, 0, 5)}):Play()
                TweenService:Create(KeyBindButton, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(-1.8,0,1,-20)}):Play()
                task.wait(0.2)
                if not tab.Data.SettingsOpen then
                    return
                end
                
                for i,v in tab.Modules do
                    v.Objects.Module.Visible = false
                end
                CloseButton.Visible = false
                Backbutton.Visible = true
                ModuleSettings.Parent = tab.Objects.ScrollFrame
                tab.Objects.ScrollFrame.Size = UDim2.new(1, -10, 1, -160)
                ModuleData.Objects.Module.Size = UDim2.fromScale(1, 1)
                ModuleData.Objects.Module.ZIndex = -1000
                ModuleData.Objects.Module.BackgroundTransparency = 1
                ModuleSettingsList.Parent = ModuleSettings
                tab.Objects.ScrollFrame.Position = UDim2.new(1.8, 0, 0.04, 50)
                TabHeader.Position = UDim2.fromScale(1.8, 0.04)
                KeyBindButton.Position = UDim2.new(1.8,0,1,-20)
                TabHeader.Text = ModuleData.Name .. " Settings"

                SearchBar.Visible = false
                KeyBindButton.Visible = true
                for i,v in ModuleData.Objects.Module:GetChildren() do
                    if v:IsA("Frame") or v:IsA("ImageLabel") then
                        v.Visible = false
                    end
                end
                for i,v in tab.Modules do
                    if v ~= ModuleData then
                        v.Objects.Module.Visible = false
                    end
                end
                for i,v in ModuleData.Settings do
                    if not table.find(ModuleData.Data.ExcludeSettingsVisiblity, v) then
                        v.Objects.MainInstance.Visible = true
                    end
                end

                TweenService:Create(tab.Objects.ScrollFrame, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.5, 0, 0.04, 50)}):Play()
                TweenService:Create(TabHeader, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(0.5, 0.04)}):Play()
                TweenService:Create(Backbutton, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.fromOffset(5, 5)}):Play()
                TweenService:Create(KeyBindButton, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.5,0,1,-20)}):Play()
                tab.ClipNeeded = false
                task.wait(0.8)
                if not tab.ClipNeeded then
                    tab.Objects.ActualTab.ClipsDescendants = false
                end
            end)
            table.insert(AppleHub.Connections, settingsbuttoncon)
            table.insert(ModuleData.Connections, settingsbuttoncon)

            local currentbackbuttonfunc = function()
                tab.Data.SettingsOpen = false
                ModuleData.Data.SettingsOpen = false
                if ModuleData.Data.SettingKeybind then
                    ModuleData.Data.SettingKeybind = false
                    KeyBindButton.Text = "CLICK TO BIND"
                end
                tab.Objects.ActualTab.ClipsDescendants = true
                tab.ClipNeeded = true
                ModuleSettings.Parent = ModuleData.Objects.Module
                tab.Objects.ScrollFrame.Size = UDim2.new(1, -10, 1, -70)
                ModuleData.Objects.Module.Size = UDim2.new(1, 0, 0, 150)
                TweenService:Create(tab.Objects.ScrollFrame, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(1.8, 0, 0.04, 50)}):Play()
                TweenService:Create(TabHeader, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(1.8, 0.04)}):Play()
                TweenService:Create(Backbutton, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(1.8, 0, 0, 5)}):Play()
                TweenService:Create(KeyBindButton, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(1.8,0,1,-20)}):Play()
                task.wait(0.2)
                for i,v in tab.Modules do
                    v.Objects.Module.Visible = true
                end
                Backbutton.Visible = false
                CloseButton.Visible = true
                ModuleData.Objects.Module.ZIndex = 2
                tab.Objects.ScrollFrame.Position = UDim2.new(-1.8, 0, 0.04, 50)
                TabHeader.Position = UDim2.fromScale(-1.8, 0.04)
                ModuleSettingsList.Parent = nil
                ModuleData.Objects.Module.BackgroundTransparency = 0.95
                KeyBindButton.Position = UDim2.new(-1.8,0,1,-20)
                KeyBindButton.Visible = false

                TabHeader.Text = tab.Name
                SearchBar.Visible = true
                for i,v in ModuleData.Objects.Module:GetChildren() do
                    if v:IsA("Frame") or v:IsA("ImageLabel") then
                        v.Visible = true
                    end
                end
                for i,v in ModuleData.Settings do
                    v.Objects.MainInstance.Visible = false
                end
                for i,v in tab.Modules do
                    v.Objects.Module.Visible = true
                end


                TweenService:Create(tab.Objects.ScrollFrame, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0.5, 0, 0.04, 50)}):Play()
                TweenService:Create(TabHeader, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.fromScale(0.5, 0.04)}):Play()
                TweenService:Create(CloseButton, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(1, -5, 0, 5)}):Play()
                tab.ClipNeeded = false
                task.wait(0.8)
                if not tab.ClipNeeded then
                    tab.Objects.ActualTab.ClipsDescendants = false
                end
            end

            local settingsbackbuttoncon = Backbutton.MouseButton1Click:Connect(function() currentbackbuttonfunc() end)
            table.insert(AppleHub.Connections, settingsbackbuttoncon)
            table.insert(ModuleData.Connections, settingsbackbuttoncon)

            ModuleData.Functions.ConstructSetting = function(data: {Size: number, Description: string, Name: string, ToolTip: string, OnToolTipEdit: any, Layout: boolean})
                local ConstructionData = {
                    Name = data and data.Name or "Setting",
                    Description = data and data.Description or "Setting",
                    ToolTip = data and data.ToolTip or "Tooltip",
                    YSize = data and data.Size or 100,
                    NeedsLayout = data and data.Layout,
                    Objects = {},
                    Functions = {},
                    OnToolTipEdit = data and data.OnToolTipEdit or function() end
                }

                ConstructionData.Objects.MainInstance = Instance.new("ImageButton", ModuleSettings)
                ConstructionData.Objects.MainInstance.AutoButtonColor = false
                ConstructionData.Objects.MainInstance.BackgroundColor3 = Color3.fromRGB(0,0,0)
                ConstructionData.Objects.MainInstance.BackgroundTransparency = 0.8
                ConstructionData.Objects.MainInstance.Size = UDim2.new(1, 0, 0, ConstructionData.YSize)
                ConstructionData.Objects.MainInstance.ImageTransparency = 1
                ConstructionData.Objects.MainInstance.Visible = false
                Instance.new("UICorner", ConstructionData.Objects.MainInstance).CornerRadius = UDim.new(0, 10)
                
                if ConstructionData.NeedsLayout then
                    local layout = Instance.new("UIListLayout", ConstructionData.Objects.MainInstance)
                    layout.Padding = UDim.new(0, 10)
                    layout.SortOrder = Enum.SortOrder.LayoutOrder
                end

                local SettingPadding = Instance.new("UIPadding", ConstructionData.Objects.MainInstance)
                SettingPadding.PaddingBottom = UDim.new(0, 10)
                SettingPadding.PaddingLeft = UDim.new(0, 15)
                SettingPadding.PaddingRight = UDim.new(0, 15)
                SettingPadding.PaddingTop = UDim.new(0, 10)

                local stroke = Instance.new("UIStroke", ConstructionData.Objects.MainInstance)
                stroke.Color = Color3.fromRGB(255, 255, 255)
                stroke.Transparency = 0.95

                local SettingDescLabel = Instance.new("TextLabel", ConstructionData.Objects.MainInstance)
                SettingDescLabel.AnchorPoint = Vector2.new(0, 1)
                SettingDescLabel.BackgroundTransparency = 1
                SettingDescLabel.Position = UDim2.fromScale(0, 1)
                SettingDescLabel.Size = UDim2.new(0.997, 0, 0, 15)
                SettingDescLabel.ZIndex = 2
                SettingDescLabel.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
                SettingDescLabel.Text = ConstructionData.Description
                SettingDescLabel.TextColor3 = Color3.fromRGB(255,255,255)
                SettingDescLabel.TextSize = 13
                SettingDescLabel.TextTransparency = 0.6
                SettingDescLabel.TextXAlignment = Enum.TextXAlignment.Left
                SettingDescLabel.LayoutOrder = 3

                local SettingDetails = Instance.new("Frame", ConstructionData.Objects.MainInstance)
                SettingDetails.BackgroundTransparency = 1
                SettingDetails.Size = UDim2.new(0.63, 0, 0, 35)
                SettingDetails.LayoutOrder = 1

                local SettingNameText = Instance.new("TextLabel", SettingDetails)
                SettingNameText.BackgroundTransparency = 1
                SettingNameText.Size = UDim2.new(0.997, 0, 0, 15)
                SettingNameText.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
                SettingNameText.Text = ConstructionData.Name
                SettingNameText.TextColor3 = Color3.fromRGB(255, 255, 255)
                SettingNameText.TextSize = 15
                SettingNameText.TextTransparency = 0.1
                SettingNameText.TextTruncate = Enum.TextTruncate.AtEnd
                SettingNameText.TextXAlignment = Enum.TextXAlignment.Left
                SettingNameText.TextYAlignment = Enum.TextYAlignment.Bottom

                local ToolTip = Instance.new("TextLabel", SettingDetails)
                ToolTip.AnchorPoint = Vector2.new(0, 1)
                ToolTip.BackgroundTransparency = 1
                ToolTip.Position = UDim2.new(0, 20, 1, 0)
                ToolTip.Size = UDim2.new(0.944, 0, 0, 15)
                ToolTip.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
                ToolTip.Text = ConstructionData.ToolTip
                ToolTip.TextColor3 = Color3.fromRGB(255, 255, 255)
                ToolTip.TextSize = 13
                ToolTip.TextTransparency = 0.6
                ToolTip.TextXAlignment = Enum.TextXAlignment.Left

                local ToolTipIcon = Instance.new("ImageLabel", SettingDetails)
                ToolTipIcon.BackgroundTransparency = 1
                ToolTipIcon.Position = UDim2.fromScale(-0.004, 0.571)
                ToolTipIcon.Size = UDim2.fromOffset(15, 15)
                ToolTipIcon.Image = "rbxassetid://82132857700485"
                ToolTipIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
                ToolTipIcon.ImageTransparency = 0.6
                ToolTipIcon.ScaleType = Enum.ScaleType.Stretch

                ConstructionData.Functions.EditToolTip = function(newdata: {ToolTip: string})
                    if newdata.ToolTip then
                        ConstructionData.ToolTip = newdata.ToolTip
                        ToolTip.Text = newdata.ToolTip

                        ConstructionData.OnToolTipEdit({ToolTip = newdata.ToolTip})
                    end
                end

                return ConstructionData
            end
            
                Module.Functions.Settings.TextBox(data: table)
                ► Thêm ô nhập text vào settings của module
                ► data.Name            : string - tên setting
                ► data.Description     : string - mô tả
                ► data.PlaceHolderText : string - text gợi ý khi trống
                ► data.Default         : string - giá trị mặc định
                ► data.Flag            : string - ID unique để lưu config
                ► data.Callback        : function(self, value) - chạy khi mất focus
                Ví dụ:
                    Module.Functions.Settings.TextBox({
                        Name = "Target Name",
                        Description = "Tên player muốn target",
                        PlaceHolderText = "Nhập tên...",
                        Default = "",
                        Flag = "TargetName",
                        Callback = function(self, value)
                            print("Target:", value)
                        end
                    })
            ModuleData.Functions.Settings.TextBox = function(data)
                local TextBoxData = {
                    Name = data and data.Name or "Textbox",
                    PlaceHolderText = data and data.PlaceHolderText or data and data.Name or "",
                    Description = data and data.Description or "Textbox",
                    ToolTip = data and data.ToolTip or "Click to Enter A Value",
                    Flag = data and data.Flag or data and data.Name or "New TextBox",
                    Default = data and data.Default or "",
                    Hide = data and data.Hide or false,
                    Callback = data and data.Callback or function() end,
                    Type = "TextBoxes",
                    Objects = {},
                    Functions = {}
                }

                if AppleHub.Config.Game.TextBoxes[TextBoxData.Flag] then
                    TextBoxData.Default = AppleHub.Config.Game.TextBoxes[TextBoxData.Flag]                
                end
                
                TextBoxData.Construction = ModuleData.Functions.ConstructSetting({
                    Name = TextBoxData.Name,
                    Description = TextBoxData.Description,
                    Size = 125,
                    ToolTip = TextBoxData.ToolTip,
                    Layout = true,
                    OnToolTipEdit = function(new: {ToolTip: string})
                        TextBoxData.ToolTip = new.ToolTip
                    end
                })

                TextBoxData.Objects.MainInstance = TextBoxData.Construction.Objects.MainInstance
                if AppleHub.Mobile and TextBoxData.ToolTip == "Click to Enter A Value" then
                    TextBoxData.Construction.Functions.EditToolTip({ToolTip = "Tap to Enter A Value"})
                end

                TextBoxData.Functions.EditToolTip = TextBoxData.Construction.Functions.EditToolTip

                TextBoxData.Objects.MainInstance.AutomaticSize = Enum.AutomaticSize.Y

                local ActualTextBoxBox = Instance.new("Frame", TextBoxData.Objects.MainInstance)
                ActualTextBoxBox.AnchorPoint = Vector2.new(1,0.5)
                ActualTextBoxBox.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
                ActualTextBoxBox.BackgroundTransparency = 0.6
                ActualTextBoxBox.Size = UDim2.new(1, 0, 0, 35)
                ActualTextBoxBox.LayoutOrder = 2
                ActualTextBoxBox.AutomaticSize = Enum.AutomaticSize.Y
                Instance.new("UICorner", ActualTextBoxBox).CornerRadius = UDim.new(0, 6)

                local BoxStroke = Instance.new("UIStroke", ActualTextBoxBox)
                BoxStroke.Color = Color3.fromRGB(255,255,255)
                BoxStroke.Transparency = 0.9
                
                local BoxPadding = Instance.new("UIPadding", ActualTextBoxBox)
                BoxPadding.PaddingBottom = UDim.new(0, 12)
                BoxPadding.PaddingLeft = UDim.new(0, 15)
                BoxPadding.PaddingTop = UDim.new(0, 12)

                local ActualTextBox = Instance.new("TextBox", ActualTextBoxBox)
                ActualTextBox.BackgroundTransparency = 1
                ActualTextBox.BorderSizePixel = 0
                ActualTextBox.Position = UDim2.fromScale(0, 0)
                ActualTextBox.Size = UDim2.fromScale(0.98, 0.26)
                ActualTextBox.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
                ActualTextBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
                ActualTextBox.Text = TextBoxData.Default
                ActualTextBox.TextColor3 = Color3.fromRGB(255,255,255)
                ActualTextBox.TextSize = 13
                ActualTextBox.TextTransparency = 0.2
                ActualTextBox.TextWrapped = true
                ActualTextBox.TextXAlignment = Enum.TextXAlignment.Left
                ActualTextBox.AutomaticSize = Enum.AutomaticSize.Y

                if TextBoxData.PlaceHolderText and typeof(TextBoxData.PlaceHolderText) == "string" then
                    ActualTextBox.PlaceholderText = TextBoxData.PlaceHolderText
                end

                TextBoxData.Functions.SetVisiblity = function(enabled)
                    if enabled then
                        if table.find(ModuleData.Data.ExcludeSettingsVisiblity, TextBoxData) then
                            table.remove(ModuleData.Data.ExcludeSettingsVisiblity, table.find(ModuleData.Data.ExcludeSettingsVisiblity, TextBoxData))
                        end
                        if ModuleData.Data.SettingsOpen then
                            TextBoxData.Objects.MainInstance.Visible = enabled
                        end
                    else
                        if not table.find(ModuleData.Data.ExcludeSettingsVisiblity, TextBoxData) then
                            table.insert(ModuleData.Data.ExcludeSettingsVisiblity, TextBoxData)
                        end
                        TextBoxData.Objects.MainInstance.Visible = false
                    end
                end

                if TextBoxData.Hide then
                    TextBoxData.Functions.SetVisiblity(false)
                end

                TextBoxData.Functions.SetValue = function(text: string, save: boolean)
                    if text and tostring(text) then
                        text = tostring(text)

                        ActualTextBox.Text = text
                        TextBoxData.Callback(TextBoxData, text)
                        AppleHub.Config.Game.TextBoxes[TextBoxData.Flag] = text
                        if save then
                            Assets.Config.Save(AppleHub.GameSave, AppleHub.Config.Game)
                        end
                    end
                end

                local actualtextboxfocuslostcon = ActualTextBox.FocusLost:Connect(function() 
                    TextBoxData.Callback(TextBoxData, ActualTextBox.Text)
                    AppleHub.Config.Game.TextBoxes[TextBoxData.Flag] = ActualTextBox.Text
                    Assets.Config.Save(AppleHub.GameSave, AppleHub.Config.Game)
                end)
                table.insert(AppleHub.Connections, actualtextboxfocuslostcon)
                table.insert(ModuleData.Connections, actualtextboxfocuslostcon)

                ModuleData.Settings[TextBoxData.Flag] = TextBoxData
                return TextBoxData
            end

                Module.Functions.Settings.MiniToggle(data: table)
                ► Thêm toggle nhỏ on/off vào settings của module
                ► data.Name        : string   - tên setting
                ► data.Description : string   - mô tả
                ► data.Default     : boolean  - mặc định bật/tắt
                ► data.Flag        : string   - ID unique để lưu config
                ► data.Callback    : function(self, enabled) - chạy khi đổi
                Ví dụ:
                    Module.Functions.Settings.MiniToggle({
                        Name = "Team Check",
                        Description = "Bỏ qua đồng đội",
                        Default = true,
                        Flag = "AimbotTeamCheck",
                        Callback = function(self, enabled)
                            print("Team Check:", enabled)
                        end
                    })
            ModuleData.Functions.Settings.MiniToggle = function(data)
                local MiniToggleData = {
                    Name = data and data.Name or "New MiniToggle",
                    Description = data and data.Description or "MiniToggle",
                    ToolTip = data and data.Tooltip or "Click to toggle",
                    Default = data and data.Default or false,
                    Enabled = false,
                    Flag = data and data.Flag or data and data.Name or "New MiniToggle",
                    Hide = data and data.Hide or false,
                    Callback = data and data.Callback or function() end,
                    Type = "MiniToggles",
                    Objects = {},
                    Functions = {}
                }

                MiniToggleData.Construction = ModuleData.Functions.ConstructSetting({
                    Name = MiniToggleData.Name,
                    Description = MiniToggleData.Description,
                    Size = 80,
                    Layout = false,
                    ToolTip = MiniToggleData.ToolTip,
                    OnToolTipEdit = function(new: {ToolTip: string})
                        MiniToggleData.ToolTip = new.ToolTip
                    end
                })

                MiniToggleData.Objects.MainInstance = MiniToggleData.Construction.Objects.MainInstance
                if AppleHub.Mobile and MiniToggleData.ToolTip == "Click to toggle" then
                    MiniToggleData.Construction.Functions.EditToolTip({ToolTip = "Tap to toggle"})
                end
                
                MiniToggleData.Functions.EditToolTip = MiniToggleData.Construction.Functions.EditToolTip

                local ToggleBox = Instance.new("Frame", MiniToggleData.Objects.MainInstance)
                ToggleBox.AnchorPoint = Vector2.new(1, 0.5)
                ToggleBox.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
                ToggleBox.BackgroundTransparency = 0.4
                ToggleBox.Position = UDim2.fromScale(1, 0.5)
                ToggleBox.Size = UDim2.fromOffset(36, 21)
                Instance.new("UICorner", ToggleBox).CornerRadius = UDim.new(0, 15)
                
                local ToggleCircle = Instance.new("Frame", ToggleBox)
                ToggleCircle.AnchorPoint = Vector2.new(0, 0.5)
                ToggleCircle.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
                ToggleCircle.Position = UDim2.fromScale(0.05, 0.5)
                ToggleCircle.Size = UDim2.fromOffset(17, 17)
                Instance.new("UICorner", ToggleCircle).CornerRadius = UDim.new(0, 15)

                MiniToggleData.Functions.Toggle = function(enabled, save, override)
                    if enabled and not MiniToggleData.Enabled or override or not enabled and MiniToggleData.Enabled then
                        MiniToggleData.Callback(MiniToggleData, enabled)
                    end
                    if enabled then
                        TweenService:Create(ToggleBox, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(195, 195, 195)}):Play()
                        TweenService:Create(ToggleCircle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.95, 0.5)}):Play()
                    else
                        TweenService:Create(ToggleCircle, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.05, 0.5)}):Play()
                        TweenService:Create(ToggleBox, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.4, BackgroundColor3 = Color3.fromRGB(65, 65, 65)}):Play()

                    end
                    MiniToggleData.Enabled = enabled

                    if save then
                        AppleHub.Config.Game.MiniToggles[MiniToggleData.Flag] = enabled
                        Assets.Config.Save(AppleHub.GameSave, AppleHub.Config.Game)
                    end
                end
                MiniToggleData.Functions.SetValue = MiniToggleData.Functions.Toggle

                MiniToggleData.Functions.SetVisiblity = function(enabled)
                    if enabled then
                        if table.find(ModuleData.Data.ExcludeSettingsVisiblity, MiniToggleData) then
                            table.remove(ModuleData.Data.ExcludeSettingsVisiblity, table.find(ModuleData.Data.ExcludeSettingsVisiblity, MiniToggleData))
                        end
                        if ModuleData.Data.SettingsOpen then
                            MiniToggleData.Objects.MainInstance.Visible = enabled
                        end
                    else
                        if not table.find(ModuleData.Data.ExcludeSettingsVisiblity, MiniToggleData) then
                            table.insert(ModuleData.Data.ExcludeSettingsVisiblity, MiniToggleData)
                        end
                        MiniToggleData.Objects.MainInstance.Visible = false
                    end
                end

                
                if MiniToggleData.Hide then
                    MiniToggleData.Functions.SetVisiblity(false)
                end

                local minitoggleclickcon = MiniToggleData.Objects.MainInstance.MouseButton1Click:Connect(function()
                    MiniToggleData.Functions.Toggle(not MiniToggleData.Enabled, true)
                end)
                table.insert(AppleHub.Connections, minitoggleclickcon)
                table.insert(ModuleData.Connections, minitoggleclickcon)

                ModuleData.Settings[MiniToggleData.Flag] = MiniToggleData
                return MiniToggleData
            end

                Module.Functions.Settings.Slider(data: table)
                ► Thêm thanh kéo số vào settings của module
                ► data.Name        : string  - tên setting
                ► data.Description : string  - mô tả
                ► data.Min         : number  - giá trị nhỏ nhất
                ► data.Max         : number  - giá trị lớn nhất
                ► data.Default     : number | {Value1,Value2} - giá trị mặc định
                ► data.Decimals    : number  - số chữ số thập phân (mặc định 0)
                ► data.DoubleValue : boolean - 2 đầu kéo (range) thay vì 1
                ► data.Flag        : string  - ID unique để lưu config
                ► data.Callback    : function(self, value) - chạy khi đổi giá trị
                Ví dụ (slider đơn):
                    Module.Functions.Settings.Slider({
                        Name = "Walk Speed",
                        Min = 16, Max = 500, Default = 50,
                        Flag = "WalkSpeed",
                        Callback = function(self, value)
                            game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = value
                        end
                    })
                Ví dụ (slider đôi / range):
                    Module.Functions.Settings.Slider({
                        Name = "FOV Range",
                        Min = 0, Max = 500,
                        Default = {Value1 = 50, Value2 = 200},
                        DoubleValue = true,
                        Flag = "FOVRange",
                        Callback = function(self, value)
                            print(value.Value1, value.Value2)
                        end
                    })
            ModuleData.Functions.Settings.Slider = function(data)
                local SliderData = {
                    Name = data and data.Name or "New Slider",
                    Description = data and data.Description or "Slider",
                    ToolTip = data and data.Tooltip or "Slide the circle to edit value",
                    Min = data and tonumber(data.Min) or 0,
                    Max = data and tonumber(data.Max) or 100,
                    Default = data and data.Default or {Value1 = 50, Value2 = 100},
                    Decimals = data and tonumber(data.Decimals) or 0,
                    Multi = data and data.DoubleValue or false,
                    Flag = data and data.Flag or data and data.Name or "New Slider",
                    Hide = data and data.Hide or false,
                    Callback = data and data.Callback or function() end,
                    Type = "Sliders",
                    Data = {Dragging = false},
                    Tweens = {},
                    Objects = {},
                    Functions = {}
                }


                if AppleHub.Config.Game.Sliders[SliderData.Flag] then
                    if typeof(AppleHub.Config.Game.Sliders[SliderData.Flag]) == "table" then
                        SliderData.Default = AppleHub.Config.Game.Sliders[SliderData.Flag]
                    elseif typeof(AppleHub.Config.Game.Sliders[SliderData.Flag]) == "number" then
                        SliderData.Default = {Value2 = AppleHub.Config.Game.Sliders[SliderData.Flag]}
                    end
                else
                    if typeof(SliderData.Default) == "number" then
                        SliderData.Default = {Value2 = SliderData.Default}
                    end
                end

                if not SliderData.Default.Value1 then
                    SliderData.Default.Value1 = SliderData.Min
                end
                if not SliderData.Default.Value2 then
                    SliderData.Default.Value2 = SliderData.Max
                end

                SliderData.Construction = ModuleData.Functions.ConstructSetting({
                    Name = SliderData.Name,
                    Description = SliderData.Description,
                    Size = 100,
                    Layout = false,
                    ToolTip = SliderData.ToolTip,
                    OnToolTipEdit = function(new: {ToolTip: string})
                        SliderData.ToolTip = new.ToolTip
                    end
                })

                SliderData.Objects.MainInstance = SliderData.Construction.Objects.MainInstance
                if SliderData.Multi then
                    SliderData.Construction.Functions.EditToolTip({ToolTip = "Slide a circle to edit the value"})
                end
                
                SliderData.Functions.EditToolTip = SliderData.Construction.Functions.EditToolTip

                local Numbers = Instance.new("Frame", SliderData.Objects.MainInstance)
                Numbers.BackgroundTransparency = 1
                Numbers.Position = UDim2.fromScale(0.59, 0.237)
                Numbers.Size = UDim2.fromScale(0.409, 0.15)

                local NumbersLayout = Instance.new("UIListLayout", Numbers)
                NumbersLayout.Padding = UDim.new(0, 20)
                NumbersLayout.FillDirection = Enum.FillDirection.Horizontal
                NumbersLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
                NumbersLayout.SortOrder = Enum.SortOrder.LayoutOrder

                local SliderValue1
                local SliderValue2 = Instance.new("TextBox", Numbers)
                SliderValue2.AnchorPoint = Vector2.new(0, 0.5)
                SliderValue2.BackgroundTransparency = 1
                SliderValue2.Size = UDim2.new(0.043, 0, 0, 15)
                SliderValue2.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
                SliderValue2.Text = tonumber(SliderData.Default.Value2)
                SliderValue2.TextColor3 = Color3.fromRGB(255, 255, 255)
                SliderValue2.TextSize = 13
                SliderValue2.TextTransparency = 0.2
                SliderValue2.TextXAlignment = Enum.TextXAlignment.Right
                SliderValue2.AutomaticSize = Enum.AutomaticSize.X
                SliderValue2.LayoutOrder = 2

                local SliderBox = Instance.new("Frame", SliderData.Objects.MainInstance)
                SliderBox.AnchorPoint = Vector2.new(0, 0.5)
                SliderBox.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
                SliderBox.BackgroundTransparency = 0.6
                SliderBox.Position = UDim2.fromScale(0, 0.63)
                SliderBox.Size = UDim2.fromScale(1, 0.05)
                Instance.new("UICorner", SliderBox).CornerRadius = UDim.new(0, 15)

                local Fill = Instance.new("Frame", SliderBox)
                Fill.AnchorPoint = Vector2.new(0, 0.5)
                Fill.BackgroundColor3 = Color3.fromRGB(195, 195, 195)
                Fill.Position = UDim2.fromScale(0, 0.5)
                Fill.Size = UDim2.fromScale(math.clamp((tonumber(SliderValue2.Text)-SliderData.Min)/(SliderData.Max-SliderData.Min), 0, 1), 1)
                Instance.new("UICorner", Fill).CornerRadius = UDim.new(0, 15)

                local Circle2 = Instance.new("ImageButton", Fill)
                Circle2.AutoButtonColor = false
                Circle2.AnchorPoint = Vector2.new(0.5,0.5)
                Circle2.BackgroundColor3 = Color3.fromRGB(195, 195, 195)
                Circle2.Position = UDim2.fromScale(1, 0.5)
                Circle2.Size = UDim2.fromOffset(10, 10)
                Circle2.ImageTransparency = 1
                Instance.new("UICorner", Circle2).CornerRadius = UDim.new(0, 15)

                SliderData.Functions.SetValue = function(value: number, save: boolean, target: number)

                    if value then
                        local info = {Value1 = SliderData.Default.Value1, Value2 = value}
                        if target == 2 then
                            if AppleHub.Config.Game.Sliders[SliderData.Flag] and typeof(AppleHub.Config.Game.Sliders[SliderData.Flag]) == "table" and AppleHub.Config.Game.Sliders[SliderData.Flag].Value1 then
                                info = {Value1 = AppleHub.Config.Game.Sliders[SliderData.Flag].Value1, Value2 = value}
                            end

                        elseif target == 1 then
                            info = {Value1 = value, Value2 = SliderData.Default.Value2}
                            if AppleHub.Config.Game.Sliders[SliderData.Flag] and typeof(AppleHub.Config.Game.Sliders[SliderData.Flag]) == "table" and AppleHub.Config.Game.Sliders[SliderData.Flag].Value2 then
                                info = {Value1 = value, Value2 = AppleHub.Config.Game.Sliders[SliderData.Flag].Value2}
                            end
                        else
                            if typeof(value) == "table" then
                                info = value
                            end
                        end

                        if target == 1 and SliderData.Multi then
                            if tonumber(SliderValue2.Text) < value then return end
                            local val = math.clamp((tonumber(value)-SliderData.Min)/(SliderData.Max-SliderData.Min), 0, 1)
                            local val2 = math.clamp((tonumber(SliderValue2.Text)-SliderData.Min)/(SliderData.Max-SliderData.Min) - val, 0, 1)
                            TweenService:Create(Fill, TweenInfo.new(0.45), {Size = UDim2.fromScale(val2 , 1), Position = UDim2.fromScale(val, 0.5)}):Play()
                            SliderValue1.Text = tostring(value)
                        elseif target == 1 and not SliderData.Multi or target == 2 then
                            if SliderData.Multi and value > tonumber(SliderValue1.Text) or not SliderData.Multi then
                                TweenService:Create(Fill, TweenInfo.new(0.45), {Size = UDim2.fromScale(math.clamp((tonumber(value)-SliderData.Min)/(SliderData.Max-SliderData.Min) - Fill.Position.X.Scale, 0, 1), 1)}):Play()
                                SliderValue2.Text = tostring(value)
                            else
                                return
                            end
                        elseif not target then
                            if SliderData.Multi then
                                if SliderData.Multi and info.Value2 > tonumber(SliderValue1.Text) or not SliderData.Multi then
                                    TweenService:Create(Fill, TweenInfo.new(0.45), {Size = UDim2.fromScale(math.clamp((tonumber(info.Value2)-SliderData.Min)/(SliderData.Max-SliderData.Min) - Fill.Position.X.Scale, 0, 1), 1)}):Play()
                                    SliderValue2.Text = tostring(info.Value2)
                                end

                                if tonumber(SliderValue2.Text) >= info.Value1 then
                                    local val = math.clamp((tonumber(info.Value1)-SliderData.Min)/(SliderData.Max-SliderData.Min), 0, 1)
                                    local val2 = math.clamp((tonumber(SliderValue2.Text)-SliderData.Min)/(SliderData.Max-SliderData.Min) - val, 0, 1)
                                    TweenService:Create(Fill, TweenInfo.new(0.45), {Size = UDim2.fromScale(val2 , 1), Position = UDim2.fromScale(val, 0.5)}):Play()
                                    SliderValue1.Text = tostring(info.Value1)
                                end
                            else
                                TweenService:Create(Fill, TweenInfo.new(0.45), {Size = UDim2.fromScale(math.clamp((tonumber(info.Value2)-SliderData.Min)/(SliderData.Max-SliderData.Min) - Fill.Position.X.Scale, 0, 1), 1)}):Play()
                                SliderValue2.Text = tostring(info.Value2)
                            end
                        end

                        if SliderData.Multi then
                            SliderData.Callback(SliderData, info)
                        else
                            SliderData.Callback(SliderData, tonumber(info.Value2))
                        end

                        if save then
                            AppleHub.Config.Game.Sliders[SliderData.Flag] = info
                            Assets.Config.Save(AppleHub.GameSave, AppleHub.Config.Game)
                        end
                    end
                end

                local Circle1
                if SliderData.Multi then

                    SliderValue1 = Instance.new("TextBox", Numbers)
                    SliderValue1.AnchorPoint = Vector2.new(0, 0.5)
                    SliderValue1.BackgroundTransparency = 1
                    SliderValue1.Size = UDim2.new(0.044, 0, 0, 15)
                    SliderValue1.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
                    SliderValue1.Text = tonumber(SliderData.Default.Value1)
                    SliderValue1.TextColor3 = Color3.fromRGB(255, 255, 255)
                    SliderValue1.TextSize = 13
                    SliderValue1.TextTransparency = 0.2
                    SliderValue1.TextXAlignment = Enum.TextXAlignment.Left
                    SliderValue1.AutomaticSize = Enum.AutomaticSize.X
                    SliderValue1.LayoutOrder = 0
                    local ValueSplitIcon = Instance.new("ImageLabel", Numbers)
                    ValueSplitIcon.BackgroundTransparency = 1
                    ValueSplitIcon.Size = UDim2.fromOffset(15, 15)
                    ValueSplitIcon.Image = "rbxassetid://136254264936851"
                    ValueSplitIcon.ImageColor3 = Color3.fromRGB(255,255,255)
                    ValueSplitIcon.ImageTransparency = 0.6
                    ValueSplitIcon.ScaleType = Enum.ScaleType.Stretch
                    ValueSplitIcon.LayoutOrder = 1

                    Circle1 = Instance.new("ImageButton", Fill)
                    Circle1.AutoButtonColor = false
                    Circle1.AnchorPoint = Vector2.new(0.5,0.5)
                    Circle1.BackgroundColor3 = Color3.fromRGB(195, 195, 195)
                    Circle1.Position = UDim2.fromScale(0, 0.5)
                    Circle1.Size = UDim2.fromOffset(10, 10)
                    Circle1.ImageTransparency = 1
                    Instance.new("UICorner", Circle1).CornerRadius = UDim.new(0, 15)

                    local sliderdragbuttonclickcon2 =  Circle1.MouseButton1Down:Connect(function()
                        AppleHub.CurrntInputChangeCallback = function(input)
                            if SliderData.Data.Dragging then
                                local mouse = UserInputService:GetMouseLocation()
                                local relativePos = mouse-SliderBox.AbsolutePosition
                                local percent = math.clamp(relativePos.X/(SliderBox.AbsoluteSize.X - 20), 0, 1)
                                local value = math.floor(((((SliderData.Max - SliderData.Min) * percent) + SliderData.Min) * (10 ^ SliderData.Decimals)) + 0.5) / (10 ^ SliderData.Decimals) 

                                SliderData.Functions.SetValue(value, true, 1)

                            end
                        end
                        SliderData.Data.Dragging = true

                        AppleHub.InputEndFunc = function(input) 
                            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                AppleHub.CurrntInputChangeCallback = function() end
                                SliderData.Data.Dragging = false
                            end
                        end
                    end)
                    table.insert(AppleHub.Connections, sliderdragbuttonclickcon2)
                    table.insert(ModuleData.Connections, sliderdragbuttonclickcon2)                                
                end

                local sliderdragbuttonclickcon
                if AppleHub.Mobile and not SliderData.Multi then
                    sliderdragbuttonclickcon = SliderData.Objects.MainInstance.MouseButton1Down:Connect(function()
                        AppleHub.CurrntInputChangeCallback = function(input)
                            if SliderData.Data.Dragging then
                                local mouse = UserInputService:GetMouseLocation()
                                local relativePos = mouse-SliderBox.AbsolutePosition
                                local percent = math.clamp(relativePos.X/(SliderBox.AbsoluteSize.X - 20), 0, 1)
                                local value = math.floor(((((SliderData.Max - SliderData.Min) * percent) + SliderData.Min) * (10 ^ SliderData.Decimals)) + 0.5) / (10 ^ SliderData.Decimals) 

                                SliderData.Functions.SetValue(value, true, 2)

                            end
                        end
                        SliderData.Data.Dragging = true

                        AppleHub.InputEndFunc = function(input) 
                            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                AppleHub.CurrntInputChangeCallback = function() end
                                SliderData.Data.Dragging = false
                            end
                        end
                    end)
                else
                    sliderdragbuttonclickcon = Circle2.MouseButton1Down:Connect(function()
                        AppleHub.CurrntInputChangeCallback = function(input)
                            if SliderData.Data.Dragging then
                                local mouse = UserInputService:GetMouseLocation()
                                local relativePos = mouse-SliderBox.AbsolutePosition
                                local percent = math.clamp(relativePos.X/(SliderBox.AbsoluteSize.X - 20), 0, 1)
                                local value = math.floor(((((SliderData.Max - SliderData.Min) * percent) + SliderData.Min) * (10 ^ SliderData.Decimals)) + 0.5) / (10 ^ SliderData.Decimals) 

                                SliderData.Functions.SetValue(value, true, 2)

                            end
                        end
                        SliderData.Data.Dragging = true

                        AppleHub.InputEndFunc = function(input) 
                            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                AppleHub.CurrntInputChangeCallback = function() end
                                SliderData.Data.Dragging = false
                            end
                        end
                    end)
                end
                table.insert(AppleHub.Connections, sliderdragbuttonclickcon)
                table.insert(ModuleData.Connections, sliderdragbuttonclickcon)
            

                local slidervaluetextchangecon = SliderValue2.FocusLost:Connect(function()
                    if SliderValue2.Text and tonumber(SliderValue2.Text) then
                        SliderData.Functions.SetValue(tonumber(SliderValue2.Text), true, 2)
                    end
                end)
                table.insert(AppleHub.Connections, slidervaluetextchangecon)
                table.insert(ModuleData.Connections, slidervaluetextchangecon)

                if SliderData.Multi then
                    local slidervaluetextchangecon2 = SliderValue1.FocusLost:Connect(function()
                        if SliderValue1.Text and tonumber(SliderValue1.Text) then
                            SliderData.Functions.SetValue(tonumber(SliderValue1.Text), true, 1)
                        end
                    end)
                    table.insert(AppleHub.Connections, slidervaluetextchangecon2)
                    table.insert(ModuleData.Connections, slidervaluetextchangecon2)
                end

                SliderData.Functions.SetVisiblity = function(enabled)
                    if enabled then
                        if table.find(ModuleData.Data.ExcludeSettingsVisiblity, SliderData) then
                            table.remove(ModuleData.Data.ExcludeSettingsVisiblity, table.find(ModuleData.Data.ExcludeSettingsVisiblity, SliderData))
                        end
                        if ModuleData.Data.SettingsOpen then
                            SliderData.Objects.MainInstance.Visible = true
                        end
                    else
                        if not table.find(ModuleData.Data.ExcludeSettingsVisiblity, SliderData) then
                            table.insert(ModuleData.Data.ExcludeSettingsVisiblity, SliderData)
                        end
                        SliderData.Objects.MainInstance.Visible = false
                    end
                end

                if SliderData.Hide then
                    SliderData.Functions.SetVisiblity(false)
                end

                ModuleData.Settings[SliderData.Flag] = SliderData
                return SliderData
            end

                Module.Functions.Settings.Dropdown(data: table)
                ► Thêm menu chọn option vào settings của module
                ► data.Name        : string        - tên setting
                ► data.Description : string        - mô tả
                ► data.Options     : table          - danh sách lựa chọn
                ► data.Default     : string | table - lựa chọn mặc định
                ► data.SelectLimit : number         - số lượng có thể chọn (mặc định 1)
                ► data.Flag        : string         - ID unique để lưu config
                ► data.Callback    : function(self, value) - chạy khi chọn
                Ví dụ (chọn 1):
                    Module.Functions.Settings.Dropdown({
                        Name = "Hitpart",
                        Options = {"Head", "Torso", "LeftArm"},
                        Default = "Head",
                        Flag = "AimbotHitpart",
                        Callback = function(self, value)
                            print("Hitpart:", value)
                        end
                    })
                Ví dụ (chọn nhiều):
                    Module.Functions.Settings.Dropdown({
                        Name = "Ignored Parts",
                        Options = {"Head", "Torso", "Arms"},
                        Default = {"Head"},
                        SelectLimit = 3,
                        Flag = "IgnoredParts",
                        Callback = function(self, value)
                        end
                    })
            ModuleData.Functions.Settings.Dropdown = function(data)
                local DropdownData = {
                    Name = data and data.Name or "Dropdown",
                    Description = data and data.Description or "Dropdown",
                    ToolTip = data and data.ToolTip or "Select a option",
                    Default = data and data.Default or "",
                    SelectLimit = data and data.SelectLimit or 1,
                    Options = data and data.Options or {},
                    Flag = data and data.Flag or "Dropdown",
                    Hide = data and data.Hide or false,
                    Callback = data and data.Callback or function() end,
                    Type = "Dropdowns",
                    Objects = {},
                    Connections = {},
                    Functions = {},
                    Buttons = {Selected = {}, Buttons = {}},
                    Data = {ExtendSize = 0, Opened = false},
                }

                if not AppleHub.Config.Game.Dropdowns then
                    AppleHub.Config.Game.Dropdowns = {}
                else
                    if AppleHub.Config.Game.Dropdowns[DropdownData.Flag] then
                        DropdownData.Default = AppleHub.Config.Game.Dropdowns[DropdownData.Flag]
                    end
                end

                DropdownData.Construction = ModuleData.Functions.ConstructSetting({
                    Name = DropdownData.Name,
                    Description = DropdownData.Description,
                    Size = 125,
                    Layout = true,
                    ToolTip = DropdownData.ToolTip,
                    OnToolTipEdit = function(new: {ToolTip: string})
                        DropdownData.ToolTip = new.ToolTip
                    end
                })

                DropdownData.Objects.MainInstance = DropdownData.Construction.Objects.MainInstance
                DropdownData.Functions.EditToolTip = DropdownData.Construction.Functions.EditToolTip

                local DropBox = Instance.new("ImageButton", DropdownData.Objects.MainInstance)
                DropBox.AutoButtonColor = false
                DropBox.AnchorPoint = Vector2.new(1, 0.5)
                DropBox.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
                DropBox.BackgroundTransparency = 0.6
                DropBox.LayoutOrder = 2
                DropBox.Size = UDim2.new(1, 0, 0, 35)
                DropBox.ImageTransparency = 1
                DropBox.ClipsDescendants = true
                Instance.new("UICorner", DropBox).CornerRadius = UDim.new(0, 6)
                
                local BoxStroke = Instance.new("UIStroke", DropBox)
                BoxStroke.Color = Color3.fromRGB(255, 255, 255)
                BoxStroke.Transparency = 0.9

                local Details = Instance.new("Frame", DropBox)
                Details.AnchorPoint = Vector2.new(0.5, 0)
                Details.BackgroundTransparency = 1
                Details.Position = UDim2.fromScale(0.5, 0)
                Details.Size = UDim2.new(1, 0, 0, 35)

                local SelectedText = Instance.new("TextLabel", Details)
                SelectedText.AnchorPoint = Vector2.new(0, 0.5)
                SelectedText.BackgroundTransparency = 1
                SelectedText.Position = UDim2.fromScale(0.02, 0.5)
                SelectedText.Size = UDim2.new(0.892, 0, 0, 140)
                SelectedText.ZIndex = 2
                SelectedText.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
                SelectedText.TextSize = 13
                SelectedText.TextColor3 = Color3.fromRGB(255, 255, 255)
                SelectedText.TextTransparency = 0.2
                SelectedText.TextXAlignment = 0.2
                if typeof(DropdownData.Default) == "table" then
                    SelectedText.Text = table.concat(DropdownData.Default, ", ")
                else
                    SelectedText.Text = tostring(DropdownData.Default)
                end

                local DropIcon = Instance.new("ImageLabel", Details)
                DropIcon.AnchorPoint = Vector2.new(1, 0.5)
                DropIcon.BackgroundTransparency = 1
                DropIcon.Position = UDim2.fromScale(0.97, 0.5)      
                DropIcon.Size = UDim2.fromOffset(10, 10)    
                DropIcon.ZIndex = 2
                DropIcon.Image = "rbxassetid://133663094711296"
                DropIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
                DropIcon.ImageTransparency = 0.2
                DropIcon.ScaleType = Enum.ScaleType.Fit

                local OptionsList = Instance.new("ScrollingFrame", Details)
                OptionsList.AnchorPoint = Vector2.new(0.5, 0)
                OptionsList.BackgroundTransparency = 1
                OptionsList.Position = UDim2.fromScale(0.5, 1)
                OptionsList.Size = UDim2.fromScale(1, 0)
                OptionsList.ScrollBarThickness = 0
                OptionsList.ScrollBarImageTransparency = 1
                OptionsList.CanvasSize = UDim2.fromScale(0, 0)
                OptionsList.AutomaticCanvasSize = Enum.AutomaticSize.Y

                local OptionsLayout = Instance.new("UIListLayout", OptionsList)
                OptionsLayout.Padding = UDim.new(0, 2)
                OptionsLayout.VerticalAlignment = Enum.VerticalAlignment.Top

                local OptionsPadding = Instance.new("UIPadding", OptionsList)
                OptionsPadding.PaddingLeft = UDim.new(0, 13)
                OptionsPadding.PaddingTop = UDim.new(0, -5)

                DropdownData.Functions.SetValue = function(NewData: string | {}, Save: boolean)
                    if NewData then
                        local ReturnData = NewData
                        if typeof(NewData) == "string" then
                            if DropdownData.SelectLimit == 1  then
                                table.clear(DropdownData.Buttons.Selected)
                                table.insert(DropdownData.Buttons.Selected, NewData)
                            end

                            SelectedText.Text = NewData
                            if DropdownData.SelectLimit > 1 then
                                ReturnData = {NewData}
                            end
                        elseif typeof(NewData) == "table" then
                            if DropdownData.SelectLimit > 1  then
                                if DropdownData.SelectLimit >= #NewData then
                                    DropdownData.Buttons.Selected = NewData
                                else
                                    DropdownData.Buttons.Selected[#DropdownData.Buttons.Selected] = nil
                                end
                            else
                                table.clear(DropdownData.Buttons.Selected)
                                for i,v in NewData do
                                    table.insert(DropdownData.Buttons.Selected, v)                                        
                                end
                            end

                            if #NewData >= 1 then
                                SelectedText.Text = table.concat(NewData, ", ")
                            else
                                SelectedText.Text = "No Option Selected"
                            end
                        end

                        for i,v in DropdownData.Buttons.Buttons do
                            if table.find(DropdownData.Buttons.Selected, i) then
                                v.CheckMark.Visible = true
                                v.ButtonText.Position = UDim2.fromScale(0.037, 0.5)
                                v.ButtonText.Size = UDim2.fromScale(0.961, 1)
                            else
                                if v.CheckMark.Visible then
                                    v.CheckMark.Visible = false
                                    v.ButtonText.Position = UDim2.fromScale(0, 0.5)
                                    v.ButtonText.Size = UDim2.fromScale(1, 1)
                                end
                            end
                        end

                        DropdownData.Callback(DropdownData, ReturnData)

                        if Save then
                            AppleHub.Config.Game.Dropdowns[DropdownData.Flag] = ReturnData
                            Assets.Config.Save(AppleHub.GameSave, AppleHub.Config.Game)
                        end
                    end
                end

                for i,v in DropdownData.Options do
                    DropdownData.Data.ExtendSize += 22

                    local ButtonInfo = {
                        CheckMark = Instance.new("ImageLabel"),
                        ButtonText = Instance.new("TextLabel"),
                        Functions = {},
                        Connections = {}
                    }

                    local Button = Instance.new("TextButton", OptionsList)
                    Button.AutoButtonColor = false
                    Button.BackgroundTransparency = 1
                    Button.Size = UDim2.new(0.97, 0, 0, 20)
                    Button.Text = ""

                    ButtonInfo.ButtonText.Parent = Button
                    ButtonInfo.ButtonText.AnchorPoint = Vector2.new(0, 0.5)
                    ButtonInfo.ButtonText.BackgroundTransparency = 1
                    ButtonInfo.ButtonText.Position = UDim2.fromScale(0, 0.5)
                    ButtonInfo.ButtonText.Size = UDim2.fromScale(1, 1)
                    ButtonInfo.ButtonText.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
                    ButtonInfo.ButtonText.Text = tostring(v)
                    ButtonInfo.ButtonText.TextColor3 = Color3.fromRGB(255, 255, 255)
                    ButtonInfo.ButtonText.TextSize = 13
                    ButtonInfo.ButtonText.TextTransparency = 0.2
                    ButtonInfo.ButtonText.TextXAlignment = Enum.TextXAlignment.Left

                    ButtonInfo.CheckMark.Parent = Button
                    ButtonInfo.CheckMark.AnchorPoint = Vector2.new(0, 0.5)
                    ButtonInfo.CheckMark.BackgroundTransparency = 1
                    ButtonInfo.CheckMark.Position = UDim2.fromScale(0, 0.4)
                    ButtonInfo.CheckMark.Size = UDim2.fromOffset(13, 13)
                    ButtonInfo.CheckMark.Image = "rbxassetid://91799225292383"
                    ButtonInfo.CheckMark.ImageColor3 = Color3.fromRGB(255, 255, 255)
                    ButtonInfo.CheckMark.ImageTransparency = 0.2
                    ButtonInfo.CheckMark.ScaleType = Enum.ScaleType.Stretch
                    ButtonInfo.CheckMark.Visible = false

                    if typeof(DropdownData.Default) == "table" then
                        if table.find(DropdownData.Default, tostring(v)) then
                            ButtonInfo.CheckMark.Visible = true
                            ButtonInfo.ButtonText.Position = UDim2.fromScale(0.037, 0.5)
                            ButtonInfo.ButtonText.Size = UDim2.fromScale(0.961, 1)
                        end
                    elseif typeof(DropdownData.Default) == "string" then
                        if DropdownData.Default == tostring(v) then
                            ButtonInfo.CheckMark.Visible = true
                            ButtonInfo.ButtonText.Position = UDim2.fromScale(0.037, 0.5)
                            ButtonInfo.ButtonText.Size = UDim2.fromScale(0.961, 1)
                        end
                    end

                    local ClickCon = Button.MouseButton1Down:Connect(function()
                        if DropdownData.SelectLimit > 1 then
                            if not table.find(DropdownData.Buttons.Selected, v) then
                                table.insert(DropdownData.Buttons.Selected, v)                                        
                            else
                                table.remove(DropdownData.Buttons.Selected, table.find(DropdownData.Buttons.Selected, v))
                            end

                            DropdownData.Functions.SetValue(DropdownData.Buttons.Selected, true)
                        else
                            DropdownData.Functions.SetValue(v, true)
                        end
                    end)

                    table.insert(ButtonInfo.Connections, ClickCon)
                    table.insert(DropdownData.Connections, ClickCon)
                    table.insert(AppleHub.Connections, ClickCon)

                    ButtonInfo.Functions.Destroy = function()
                        for i,v in ButtonInfo.Connections do
                            local con1 = table.find(DropdownData.Connections, v)
                            local con2 = table.find(AppleHub.Connections, v)
                            v:Disconnect()
                            if con1 then
                                table.remove(DropdownData.Connections, con1)
                            end
                            if con2 then
                                table.remove(AppleHub.Connections, con2)
                            end
                        end
                    end

                    DropdownData.Buttons.Buttons[v] = ButtonInfo
                end

                local OpenCon = DropBox.MouseButton1Down:Connect(function()
                    DropdownData.Data.Opened = not DropdownData.Data.Opened
                    if DropdownData.Data.Opened then
                        local extend = DropdownData.Data.ExtendSize
                        if extend > 88 then
                            extend = 88
                        end

                        TweenService:Create(DropdownData.Objects.MainInstance, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, 125 + extend)}):Play()
                        TweenService:Create(DropBox, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, 35 + extend)}):Play()
                        TweenService:Create(OptionsList, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, extend)}):Play()
                    else
                        TweenService:Create(OptionsList, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {Size = UDim2.fromScale(1, 0)}):Play()
                        TweenService:Create(DropBox, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, 35)}):Play()
                        TweenService:Create(DropdownData.Objects.MainInstance, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0, 125)}):Play()
                    end
                end)
                table.insert(DropdownData.Connections, OpenCon)
                table.insert(AppleHub.Connections, OpenCon)


                DropdownData.Functions.SetVisiblity = function(enabled)
                    if enabled then
                        if table.find(ModuleData.Data.ExcludeSettingsVisiblity, DropdownData) then
                            table.remove(ModuleData.Data.ExcludeSettingsVisiblity, table.find(ModuleData.Data.ExcludeSettingsVisiblity, DropdownData))
                        end
                        if ModuleData.Data.SettingsOpen then
                            DropdownData.Objects.MainInstance.Visible = true
                        end
                    else
                        if not table.find(ModuleData.Data.ExcludeSettingsVisiblity, DropdownData) then
                            table.insert(ModuleData.Data.ExcludeSettingsVisiblity, DropdownData)
                        end
                        DropdownData.Objects.MainInstance.Visible = false
                    end
                end

                if DropdownData.Hide then
                    DropdownData.Functions.SetVisiblity(false)
                end

                ModuleData.Settings[DropdownData.Flag] = DropdownData
                return DropdownData
            end

                Module.Functions.Settings.Button(data: table)
                ► Thêm nút bấm vào settings của module
                ► data.Name        : string   - tên nút
                ► data.Description : string   - mô tả
                ► data.Flag        : string   - ID unique
                ► data.Callback    : function(self) - chạy khi click
                Ví dụ:
                    Module.Functions.Settings.Button({
                        Name = "Reset về mặc định",
                        Description = "Reset toàn bộ setting",
                        Flag = "ResetBtn",
                        Callback = function(self)
                            print("Đã reset!")
                        end
                    })
            ModuleData.Functions.Settings.Button = function(data: {Name: string, Flag: string, Description: string, ToolTip: string, Hide: boolean, Callback: any})
                local ButtonData = {
                    Name = data and data.Name or "Button",
                    Flag = data and data.Flag or "Button",
                    Description = data and data.Description or "Button",
                    ToolTip = data and data.ToolTip or "Click to Toggle",
                    Hide = data and data.Hide or false,
                    Callback = data and data.Callback or function() end,
                    Connections = {},
                    Functions = {},
                    Objects = {}
                }

                ButtonData.Construction = ModuleData.Functions.ConstructSetting({
                    Name = ButtonData.Name,
                    Description = ButtonData.Description,
                    Size = 80,
                    Layout = false,
                    ToolTip = ButtonData.ToolTip,
                    OnToolTipEdit = function(new: {ToolTip: string})
                        ButtonData.ToolTip = new.ToolTip
                    end
                })
                ButtonData.Objects.MainInstance = ButtonData.Construction.Objects.MainInstance
                ButtonData.Functions.EditToolTip = ButtonData.Construction.Functions.EditToolTip
                if AppleHub.Mobile and ButtonData.ToolTip == "Click to toggle" then
                    ButtonData.Construction.Functions.EditToolTip({ToolTip = "Tap to toggle"})
                end

                local ClickCon = ButtonData.Objects.MainInstance.MouseButton1Down:Connect(function()
                    ButtonData.Callback(ButtonData)
                end)
                table.insert(ButtonData.Connections, ClickCon)
                table.insert(AppleHub.Connections, ClickCon)

                ButtonData.Functions.SetVisiblity = function(enabled)
                    if enabled then
                        if table.find(ModuleData.Data.ExcludeSettingsVisiblity, ButtonData) then
                            table.remove(ModuleData.Data.ExcludeSettingsVisiblity, table.find(ModuleData.Data.ExcludeSettingsVisiblity, ButtonData))
                        end
                        if ModuleData.Data.SettingsOpen then
                            ButtonData.Objects.MainInstance.Visible = true
                        end
                    else
                        if not table.find(ModuleData.Data.ExcludeSettingsVisiblity, ButtonData) then
                            table.insert(ModuleData.Data.ExcludeSettingsVisiblity, ButtonData)
                        end
                        ButtonData.Objects.MainInstance.Visible = false
                    end
                end

                if ButtonData.Hide then
                    ButtonData.Functions.SetVisiblity(false)
                end

                ModuleData.Settings[ButtonData.Flag] = ButtonData
                return ButtonData
            end

                Module.Functions.Settings.NewSection(data: table)
                ► Thêm tiêu đề phân cách giữa các nhóm settings
                ► data.Name : string - tên section
                ► data.Flag : string - ID unique
                Ví dụ:
                    Module.Functions.Settings.NewSection({
                        Name = "Advanced Settings",
                        Flag = "AdvancedSection"
                    })
            ModuleData.Functions.Settings.NewSection = function(Data: {Name: string, Flag: string})
                local SectionData = {
                    Name = Data and Data.Name or "Section",
                    Flag = Data and Data.Flag or "Flag", 
                    Objects = {}
                }

                SectionData.Objects.MainInstance = Instance.new("TextLabel", ModuleSettings)
                SectionData.Objects.MainInstance.BackgroundTransparency = 1
                SectionData.Objects.MainInstance.Size = UDim2.new(0.976, 0, 0, 35)
                SectionData.Objects.MainInstance.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
                SectionData.Objects.MainInstance.Text = tostring(SectionData.Name)
                SectionData.Objects.MainInstance.TextColor3 = Color3.fromRGB(255, 255, 255)
                SectionData.Objects.MainInstance.TextSize = 17
                SectionData.Objects.MainInstance.TextTransparency = 0.1
                SectionData.Objects.MainInstance.TextXAlignment = Enum.TextXAlignment.Left
                SectionData.Objects.MainInstance.Visible = false

                ModuleData.Settings[SectionData.Flag] = SectionData
                return SectionData
            end

                Module.Functions.Settings.Keybind(data: table)
                ► Thêm keybind riêng vào settings của module (khác với keybind toggle module)
                ► data.Name            : string   - tên setting
                ► data.Description     : string   - mô tả
                ► data.Default         : string   - phím mặc định (vd: "Q", "F", "LeftShift")
                ► data.Flag            : string   - ID unique để lưu config
                ► data.Mobile.Text     : string   - tên nút hiện trên mobile
                ► data.Mobile.Default  : boolean  - tự tạo nút mobile mặc định không
                ► data.Callbacks.Began   : function - chạy khi BẮT ĐẦU giữ phím
                ► data.Callbacks.End     : function - chạy khi THẢ phím
                ► data.Callbacks.Changed : function(self, key) - chạy khi đổi phím
                Ví dụ:
                    Module.Functions.Settings.Keybind({
                        Name = "Hold Key",
                        Description = "Giữ để kích hoạt",
                        Default = "Q",
                        Flag = "SilentAimKey",
                        Mobile = {Text = "SA", Default = false, Visible = true},
                        Callbacks = {
                            Began = function(self)
                            end,
                            End = function(self)
                            end,
                            Changed = function(self, key)
                                print("Phím mới:", key)
                            end
                        }
                    })
            ModuleData.Functions.Settings.Keybind = function(Data: {Name: string, Description: string, Default: string, ToolTip: string, Hide: boolean, Flag: string, Callbacks: {Began: () -> (), End: () -> (), Changed: () -> ()}, Mobile: {Text: string, Default: boolean, Visible: boolean}})
                local KeybindData = {
                    Name = Data and Data.Name or "Keybind",
                    Description = Data and Data.Description or "Keybind",
                    Default = Data and Data.Default or "",
                    Flag = Data and Data.Flag or "FlagKeybind", 
                    Hide = data and data.Hide or false,
                    ToolTip = Data and Data.ToolTip or "Click The Box To Bind",
                    Callbacks = Data and Data.Callbacks or {Began = function() end, End = function() end, Changed = function() end},
                    Data = {Keybind = nil, Binding = false},
                    Mobile = Data and Data.Mobile or {Text = "Keybind", Default = false, Visible = true},
                    Type = "ModuleKeybinds",
                    Functions = {},
                    Objects = {},
                    Connections = {}
                }

                if not KeybindData.Callbacks.Began then
                    KeybindData.Callbacks.Began = function() end
                end
                if not KeybindData.Callbacks.End then
                    KeybindData.Callbacks.End = function() end
                end
                if not KeybindData.Callbacks.Changed then
                    KeybindData.Callbacks.Changed = function() end
                end

                if not AppleHub.Config.Game.ModuleKeybinds then
                    AppleHub.Config.Game.ModuleKeybinds = {}
                else
                    if AppleHub.Config.Game.ModuleKeybinds[KeybindData.Flag] then
                        if AppleHub.Config.Game.ModuleKeybinds[KeybindData.Flag] == "unbinded" then
                            KeybindData.Default = ""
                        else
                            KeybindData.Default = AppleHub.Config.Game.ModuleKeybinds[KeybindData.Flag]
                        end
                    else
                        if KeybindData.Mobile.Default then
                            KeybindData.Default = "button"
                        end
                    end
                end

                KeybindData.Construction = ModuleData.Functions.ConstructSetting({
                    Name = KeybindData.Name,
                    Description = KeybindData.Description,
                    Size = 80,
                    Layout = false,
                    ToolTip = KeybindData.Flag,
                    OnToolTipEdit = function(new: {ToolTip: string})
                        KeybindData.ToolTip = new.ToolTip
                    end
                })
                KeybindData.Objects.MainInstance = KeybindData.Construction.Objects.MainInstance

                local KeybindBox = Instance.new("ImageButton", KeybindData.Objects.MainInstance)
                KeybindBox.AnchorPoint = Vector2.new(1, 0.5)
                KeybindBox.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
                KeybindBox.BackgroundTransparency = 0.4
                KeybindBox.Position = UDim2.fromScale(1, 0.5)
                KeybindBox.Size = UDim2.fromOffset(25, 25)
                KeybindBox.AutoButtonColor = false
                Instance.new("UICorner", KeybindBox).CornerRadius = UDim.new(0, 5)
                
                local BoxStroke = Instance.new("UIStroke", KeybindBox)
                BoxStroke.Color = Color3.fromRGB(255, 255, 255)
                BoxStroke.Transparency = 0.9

                local BoxIcon = Instance.new("ImageLabel", KeybindBox)
                BoxIcon.AnchorPoint = Vector2.new(0.5, 0.5)
                BoxIcon.BackgroundTransparency = 1
                BoxIcon.Position = UDim2.fromScale(0.5, 0.5)
                BoxIcon.Size = UDim2.fromOffset(13, 13)
                BoxIcon.Image = "rbxassetid://101725457581159"
                BoxIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
                BoxIcon.ImageTransparency = 0.6
                BoxIcon.ScaleType = Enum.ScaleType.Stretch

                local KeybindText = Instance.new("TextLabel", KeybindBox)
                KeybindText.AnchorPoint = Vector2.new(0.5, 0.5)
                KeybindText.BackgroundTransparency = 1
                KeybindText.Position = UDim2.fromScale(0.5, 0.5)
                KeybindText.Size = UDim2.fromOffset(10, 15)
                KeybindText.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
                KeybindText.Text = KeybindData.Default
                KeybindText.TextColor3 = Color3.fromRGB(255, 255, 255)
                KeybindText.TextSize = 13
                KeybindText.TextTransparency = 0.6
                KeybindText.Visible = false

                if AppleHub.Mobile then
                    table.insert(ModuleData.onToggles, function(self, enabled)
                        if enabled then
                            if KeybindData.Data.Keybind and KeybindData.Data.Keybind ~= "unbinded" then
                                AppleHub.Background.Functions.CreateMobileButton({
                                    Name = KeybindData.Mobile.Text,
                                    Flag = KeybindData.Flag.."MobileKeybind",
                                    Callbacks = {
                                        Began = function(self)
                                            return KeybindData.Callbacks.Began(KeybindData)
                                        end,
                                        End = function(self, drag : boolean)
                                            return KeybindData.Callbacks.End(KeybindData)
                                        end
                                    }
                                })

                            end
                        else
                            if AppleHub.Background.MobileButtons.Buttons[KeybindData.Flag.."MobileKeybind"] then
                                AppleHub.Background.MobileButtons.Buttons[KeybindData.Flag.."MobileKeybind"].Functions.Destroy()
                            end
                        end
                    end)
                end

                if tostring(KeybindData.Default):gsub(" ", "") ~= "" then
                    KeybindData.Data.Keybind = KeybindData.Default
                    local Size = GetTextBounds(KeybindData.Default, Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), 13)
                    KeybindBox.Size = UDim2.fromOffset(Size.X + 18, 25)

                    BoxIcon.Visible = false
                    KeybindText.Visible = true 
                    BoxIcon.Image = "rbxassetid://135395971960120"

                    if AppleHub.Mobile and tostring(KeybindData.Default) == "button" then
                        KeybindData.Construction.Functions.EditToolTip({ToolTip = "Tap The Box To Unbind"})
                            KeybindData.Callbacks.Changed(KeybindData, KeybindData.Default)
                    elseif AppleHub.Mobile and tostring(KeybindData.Default) == "unbinded" then
                        KeybindData.Callbacks.Changed(KeybindData, nil)

                        KeybindData.Data.Keybind = nil
                        BoxIcon.Image = "rbxassetid://101725457581159"
                        BoxIcon.Visible = true
                        KeybindText.Visible = false
                        KeybindText.Text = "binded"
                    elseif not AppleHub.Mobile then
                        KeybindData.Callbacks.Changed(KeybindData, KeybindData.Default)
                        KeybindData.Construction.Functions.EditToolTip({ToolTip = "Click The Box To Unbind"})
                    end

                end

                local ClickCon = KeybindBox.MouseButton1Down:Connect(function()
                    if not KeybindData.Data.Keybind then
                        if AppleHub.Mobile then
                            KeybindData.Data.Keybind = "button"

                            local Size = GetTextBounds("button", Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), 13)
                            KeybindBox.Size = UDim2.fromOffset(Size.X + 18, 25)
                            KeybindText.Text = "binded"

                            BoxIcon.Visible = false
                            KeybindText.Visible = true 
                            BoxIcon.Image = "rbxassetid://135395971960120"
                            KeybindData.Construction.Functions.EditToolTip({ToolTip = "Tap The Box To Unbind"})

                            if not AppleHub.Config.Game.ModuleKeybinds then
                                AppleHub.Config.Game.ModuleKeybinds = {}
                            end

                            if not AppleHub.Background.MobileButtons.Buttons[KeybindData.Flag.."MobileKeybind"] and ModuleData.Data.Enabled then
                                AppleHub.Background.Functions.CreateMobileButton({
                                    Name = KeybindData.Mobile.Text,
                                    Flag = KeybindData.Flag.."MobileKeybind",
                                    Callbacks = {
                                        Began = function(self)
                                            return KeybindData.Callbacks.Began(KeybindData)
                                        end,
                                        End = function(self, drag : boolean)
                                            return KeybindData.Callbacks.End(KeybindData)
                                        end
                                    }
                                })
                            end
                            
                            KeybindData.Callbacks.Changed(KeybindData, "button")

                            AppleHub.Config.Game.ModuleKeybinds[KeybindData.Flag] = "button"
                            AppleHub.Assets.Config.Save(tostring(AppleHub.GameSave), AppleHub.Config.Game)
                        else
                            KeybindData.Construction.Functions.EditToolTip({ToolTip = "Please Click A Button"})
                            KeybindData.Data.Binding = true
                        end
                    else
                        KeybindData.Callbacks.Changed(KeybindData, nil)

                        KeybindData.Data.Keybind = nil
                        BoxIcon.Image = "rbxassetid://101725457581159"
                        BoxIcon.Visible = true
                        KeybindText.Visible = false 

                        KeybindBox.Size = UDim2.fromOffset(25, 25)
                        if AppleHub.Mobile then
                            if AppleHub.Background.MobileButtons.Buttons[KeybindData.Flag.."MobileKeybind"] then
                                AppleHub.Background.MobileButtons.Buttons[KeybindData.Flag.."MobileKeybind"].Functions.Destroy()
                            end
                            KeybindData.Construction.Functions.EditToolTip({ToolTip = "Tap The Box To Bind"})
                        else
                            KeybindData.Construction.Functions.EditToolTip({ToolTip = "Click The Box To Bind"})
                        end

                        AppleHub.Config.Game.ModuleKeybinds[KeybindData.Flag] = nil
                        if AppleHub.Mobile then
                            AppleHub.Config.Game.ModuleKeybinds[KeybindData.Flag] = "unbinded"
                        end
                        AppleHub.Assets.Config.Save(tostring(AppleHub.GameSave), AppleHub.Config.Game)
                    end
                end)

                local CallbackCon = UserInputService.InputBegan:Connect(function(input)
                    if UserInputService:GetFocusedTextBox() and not KeybindData.Data.Binding then return end
                    if KeybindData.Data.Binding then
                        if input.KeyCode and input.KeyCode.Name ~= "Unknown" then
                            KeybindData.Data.Keybind = input.KeyCode.Name

                            local Size = GetTextBounds(input.KeyCode.Name, Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), 13)
                            KeybindBox.Size = UDim2.fromOffset(Size.X + 18, 25)
                            KeybindText.Text = input.KeyCode.Name

                            BoxIcon.Visible = false
                            KeybindText.Visible = true 
                            BoxIcon.Image = "rbxassetid://135395971960120"
                            KeybindData.Construction.Functions.EditToolTip({ToolTip = "Click The Box To Unbind"})

                            if not AppleHub.Config.Game.ModuleKeybinds then
                                AppleHub.Config.Game.ModuleKeybinds = {}
                            end

                            KeybindData.Callbacks.Changed(KeybindData, input.KeyCode.Name)
                            AppleHub.Config.Game.ModuleKeybinds[KeybindData.Flag] = input.KeyCode.Name
                            AppleHub.Assets.Config.Save(tostring(AppleHub.GameSave), AppleHub.Config.Game)
                        end
                    else
                        if KeybindData.Data.Keybind and KeybindData.Data.Keybind == input.KeyCode.Name then
                            KeybindData.Callbacks.Began(KeybindData)
                        end
                    end
                end)

                local EndCon = UserInputService.InputEnded:Connect(function(input)
                    if UserInputService:GetFocusedTextBox() then return end
                    if KeybindData.Data.Keybind and KeybindData.Data.Keybind == input.KeyCode.Name then
                        if KeybindData.Data.Binding then
                            KeybindData.Data.Binding = false
                            return
                        end
                        KeybindData.Callbacks.End(KeybindData)
                    end
                end)

                local HoverCon = KeybindBox.MouseEnter:Connect(function()
                    if KeybindData.Data.Keybind then
                        KeybindText.Visible = false
                        BoxIcon.Visible = true
                    end
                end)

                local UnHoverCon = KeybindBox.MouseLeave:Connect(function()
                    if KeybindData.Data.Keybind then
                        KeybindText.Visible = true
                        BoxIcon.Visible = false
                    end
                end)
                
                table.insert(KeybindData.Connections, ClickCon)
                table.insert(AppleHub.Connections, ClickCon)

                table.insert(KeybindData.Connections, CallbackCon)
                table.insert(AppleHub.Connections, CallbackCon)

                table.insert(KeybindData.Connections, EndCon)
                table.insert(AppleHub.Connections, EndCon)

                table.insert(KeybindData.Connections, HoverCon)
                table.insert(AppleHub.Connections, HoverCon)
                
                table.insert(KeybindData.Connections, UnHoverCon)
                table.insert(AppleHub.Connections, UnHoverCon)


                KeybindData.Functions.SetValue = function(NewValue: string, save: boolean)
                    if not NewValue or NewValue == "" or NewValue == "unbinded" then
                        KeybindData.Data.Keybind = nil
                        BoxIcon.Image = "rbxassetid://101725457581159"
                        BoxIcon.Visible = true
                        KeybindText.Visible = false 

                        KeybindBox.Size = UDim2.fromOffset(25, 25)
                        KeybindData.Construction.Functions.EditToolTip({ToolTip = "Click The Box To Bind"})

                        if save then
                            AppleHub.Config.Game.ModuleKeybinds[KeybindData.Flag] = nil
                            AppleHub.Assets.Config.Save(tostring(AppleHub.GameSave), AppleHub.Config.Game)
                        end
                    else
                        KeybindData.Data.Keybind = NewValue

                        local Size = GetTextBounds(NewValue, Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium), 13)
                        KeybindBox.Size = UDim2.fromOffset(Size.X + 18, 25)

                        KeybindText.Text = NewValue

                        BoxIcon.Visible = false
                        KeybindText.Visible = true 
                        BoxIcon.Image = "rbxassetid://135395971960120"
                        KeybindData.Construction.Functions.EditToolTip({ToolTip = "Click The Box To Unbind"})

                        if not AppleHub.Config.Game.ModuleKeybinds then
                            AppleHub.Config.Game.ModuleKeybinds = {}
                        end
                        if save then
                            AppleHub.Config.Game.ModuleKeybinds[KeybindData.Flag] = NewValue
                            AppleHub.Assets.Config.Save(tostring(AppleHub.GameSave), AppleHub.Config.Game)
                        end
                    end
                end

                KeybindData.Functions.SetVisiblity = function(enabled)
                    if enabled then
                        if table.find(ModuleData.Data.ExcludeSettingsVisiblity, KeybindData) then
                            table.remove(ModuleData.Data.ExcludeSettingsVisiblity, table.find(ModuleData.Data.ExcludeSettingsVisiblity, KeybindData))
                        end
                        if ModuleData.Data.SettingsOpen then
                            KeybindData.Objects.MainInstance.Visible = true
                        end
                    else
                        if not table.find(ModuleData.Data.ExcludeSettingsVisiblity, KeybindData) then
                            table.insert(ModuleData.Data.ExcludeSettingsVisiblity, KeybindData)
                        end
                        KeybindData.Objects.MainInstance.Visible = false
                    end
                end
                
                if KeybindData.Hide then
                    KeybindData.Functions.SetVisiblity(false)
                end

                ModuleData.Settings[KeybindData.Flag] = KeybindData
                return KeybindData
            end

            ModuleData.Functions.Destroy = function()
                for i,v in ModuleData.Connections do
                    v:Disconnect()
                end
                ModuleData.Callback(ModuleData, false)
                table.clear(ModuleData.Connections)
                tab.Modules[ModuleData.Flag] = nil

                ModuleData.Objects.Module:Destroy()
                table.clear(ModuleData)
            end

            tab.Modules[ModuleData.Flag] = ModuleData
            return ModuleData
        end

        tab.Functions.Destroy = function()
            for i,v in tab.Modules do
                if v and v.Functions and v.Functions.Destroy then
                    v.Functions.Destroy()
                end
            end
            for i,v in tab.Connections do
                v:Disconnect()
            end
            tab.Objects.ActualTab:Destroy()
            tab.Objects.DashBoardButton:Destroy()
            table.clear(tab)
        end

        AppleHub.Tabs.Tabs[tab.Name] = tab
        return tab
    end

end

do
    Assets.SettingsPage.Init = function(Settings)
        if not Settings then return end
        local SettingsPageInfo = {
            Functions = {},
        }

        local pageselectorbuttonicon = Settings.Objects.PageselectorButton:FindFirstChildWhichIsA("ImageLabel")
        if pageselectorbuttonicon then
            pageselectorbuttonicon.ImageTransparency = 0.1
        end
        
        local SettingsScroll = Instance.new("ScrollingFrame", Settings.Objects.ActualPage)
        SettingsScroll.AnchorPoint = Vector2.new(0.5, 1)
        SettingsScroll.BackgroundTransparency = 1
        SettingsScroll.Position = UDim2.new(0.5, 0, 1, 20)
        SettingsScroll.Size = UDim2.new(1, 0, 1, -100)
        SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        SettingsScroll.CanvasSize = UDim2.fromScale(1, 0)
        SettingsScroll.ScrollBarImageTransparency = 0.8
        SettingsScroll.ScrollBarThickness = 2
        SettingsScroll.ScrollingDirection = Enum.ScrollingDirection.Y

        local SettingsScrollList = Instance.new("UIListLayout", SettingsScroll)
        SettingsScrollList.SortOrder = Enum.SortOrder.LayoutOrder
        SettingsScrollList.Padding = UDim.new(0, 10)
        SettingsScrollList.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local scrollPadding = Instance.new("UIPadding", SettingsScroll)
        scrollPadding.PaddingBottom = UDim.new(0, 20)
        scrollPadding.PaddingLeft = UDim.new(0, 20)
        scrollPadding.PaddingRight = UDim.new(0, 20)
        scrollPadding.PaddingTop = UDim.new(0, 5)

        SettingsPageInfo.Functions.NewSection = function(data)
            local SectionData = {
                Functions = {},
            }

            local Section = Instance.new("Frame", SettingsScroll)
            Section.AnchorPoint = Vector2.new(0.5, 0)
            Section.AutomaticSize = Enum.AutomaticSize.Y
            Section.BackgroundTransparency = 1
            Section.Size = UDim2.fromScale(1, 0)

            local SectionList = Instance.new("UIListLayout", Section)
            SectionList.SortOrder = Enum.SortOrder.LayoutOrder
            SectionList.HorizontalAlignment = Enum.HorizontalAlignment.Center

            local SectionText = Instance.new("TextLabel", Section)
            SectionText.BackgroundTransparency = 1
            SectionText.Size = UDim2.new(1, -40, 0, 20)
            SectionText.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
            SectionText.Text = data.Name:upper()
            SectionText.TextColor3 = Color3.fromRGB(255, 255, 255)
            SectionText.TextTransparency = 0.5
            SectionText.TextSize = 14
            SectionText.TextXAlignment = Enum.TextXAlignment.Left
            SectionText.TextYAlignment = Enum.TextYAlignment.Top

            local madebutton = false
            SectionData.Functions.NewButton = function(data)
                local ButtonData = {
                    Name = data.Name or "Button",
                    Input = data.Input,
                    Last = data.Last or false,
                    Toggle = data.Toggle or false,
                    Default = data.Default or false,
                    Textbox = data.Textbox or false,
                    Flag = data.Flag or nil,
                    Data = {Enabled = false},
                    Objects = {},
                    Callback = data.Callback or function() end,
                }

                ButtonData.Objects.MainButton = Instance.new("ImageButton", Section)
                ButtonData.Objects.MainButton.BackgroundTransparency = 1
                ButtonData.Objects.MainButton.Size = UDim2.new(1, 0, 0, 45)
                ButtonData.Objects.MainButton.AutoButtonColor = false
                ButtonData.Objects.MainButton.Image = "rbxassetid://16286719854"
                ButtonData.Objects.MainButton.ImageColor3 = Color3.fromRGB(0, 0, 0)
                ButtonData.Objects.MainButton.ImageTransparency = 0.6
                ButtonData.Objects.MainButton.ScaleType = Enum.ScaleType.Crop

                if not madebutton then
                    ButtonData.Objects.MainButton.ScaleType = Enum.ScaleType.Slice
                    ButtonData.Objects.MainButton.SliceCenter = Rect.new(512, 214, 512, 214)
                    ButtonData.Objects.MainButton.SliceScale = 0.12
                    ButtonData.Objects.MainButton.Image = "rbxassetid://16287196357"
                    madebutton = true
                end
                if ButtonData.Last then
                    ButtonData.Objects.MainButton.ScaleType = Enum.ScaleType.Slice
                    ButtonData.Objects.MainButton.SliceCenter = Rect.new(512, 0, 512, 0)
                    ButtonData.Objects.MainButton.SliceScale = 0.12
                    ButtonData.Objects.MainButton.Image = "rbxassetid://16287194510"
                end

                local ButtonPadding = Instance.new("UIPadding", ButtonData.Objects.MainButton)
                ButtonPadding.PaddingLeft = UDim.new(0, 20)
                ButtonPadding.PaddingRight = UDim.new(0, 20)

                ButtonData.Objects.MainButtonText = Instance.new("TextLabel", ButtonData.Objects.MainButton)
                ButtonData.Objects.MainButtonText.AnchorPoint = Vector2.new(0, 0.5)
                ButtonData.Objects.MainButtonText.BackgroundTransparency = 1
                ButtonData.Objects.MainButtonText.Position = UDim2.fromScale(0, 0.5)
                ButtonData.Objects.MainButtonText.Size = UDim2.new(1, -50, 1, 0)
                ButtonData.Objects.MainButtonText.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
                ButtonData.Objects.MainButtonText.Text = ButtonData.Name
                ButtonData.Objects.MainButtonText.TextColor3 = Color3.fromRGB(255, 255, 255)
                ButtonData.Objects.MainButtonText.TextTransparency = 0.3
                ButtonData.Objects.MainButtonText.TextSize = 16
                ButtonData.Objects.MainButtonText.TextXAlignment = Enum.TextXAlignment.Left
                ButtonData.Objects.MainButtonText.TextYAlignment = Enum.TextYAlignment.Center

                local EnabledCheckMark
                if ButtonData.Toggle then
                    EnabledCheckMark = Instance.new("ImageLabel", ButtonData.Objects.MainButton)
                    EnabledCheckMark.AnchorPoint = Vector2.new(1, 0.5)
                    EnabledCheckMark.BackgroundTransparency = 1
                    EnabledCheckMark.Position = UDim2.fromScale(1, 0.5)
                    EnabledCheckMark.Size = UDim2.fromOffset(18, 18)
                    EnabledCheckMark.Image = "rbxassetid://10709790644"
                    EnabledCheckMark.ImageColor3 = Color3.fromRGB(255,255,255)
                    EnabledCheckMark.ImageTransparency = 0.5
                    EnabledCheckMark.ScaleType = Enum.ScaleType.Stretch
                    EnabledCheckMark.Visible = false
                    if ButtonData.Flag then
                        if AppleHub.Config.UI[ButtonData.Flag] == nil and ButtonData.Default or AppleHub.Config.UI[ButtonData.Flag] then
                            ButtonData.Data.Enabled = true
                            EnabledCheckMark.Visible = true
                            ButtonData.Callback(ButtonData, true)
                        end
                    end
                end

                if ButtonData.Textbox then
                    local Textbox = Instance.new("TextBox", ButtonData.Objects.MainButton)
                    Textbox.AnchorPoint = Vector2.new(1, 0.5)
                    Textbox.BackgroundTransparency = 1
                    Textbox.Position = UDim2.fromScale(1, 0.5)
                    Textbox.Size = UDim2.new(1, -60, 0, 18)
                    Textbox.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)
                    Textbox.Text = ""
                    Textbox.TextSize = 16
                    Textbox.TextColor3 = Color3.fromRGB(255, 255, 255)
                    Textbox.PlaceholderColor3 = Color3.fromRGB(255, 255, 255)   
                    Textbox.TextTransparency = 0.3
                    Textbox.TextXAlignment = Enum.TextXAlignment.Right
                    Textbox.ZIndex = 1000
                    Textbox.TextWrapped = true
                    if ButtonData.Default and typeof(ButtonData.Default) == "string" and AppleHub.Config.UI[ButtonData.Flag] == nil then
                        Textbox.Text = ButtonData.Default
                    end
                    if AppleHub.Config.UI[ButtonData.Flag] then
                        if typeof(AppleHub.Config.UI[ButtonData.Flag]) == "table" then
                            for i,v in AppleHub.Config.UI[ButtonData.Flag] do
                                Textbox.Text = Textbox.Text .. tostring(v) .. ", "
                            end
                            Textbox.Text = string.sub(Textbox.Text, 0, #Textbox.Text-2)
                        else
                            Textbox.Text = tostring(AppleHub.Config.UI[ButtonData.Flag])
                        end
                    end

                    table.insert(AppleHub.Connections, Textbox.FocusLost:Connect(function()
                        ButtonData.Callback(ButtonData, Textbox.Text)
                    end))

                    return ButtonData.Callback(ButtonData, Textbox.Text)
                end

                table.insert(AppleHub.Connections, ButtonData.Objects.MainButton.MouseButton1Click:Connect(function() 
                    if ButtonData.Toggle then
                        ButtonData.Data.Enabled = not ButtonData.Data.Enabled
                        EnabledCheckMark.Visible = ButtonData.Data.Enabled
                        return ButtonData.Callback(ButtonData, ButtonData.Data.Enabled)
                    end
                    return ButtonData.Callback(ButtonData) 
                end))

                return ButtonData
            end
            return SectionData
        end
        return SettingsPageInfo
    end

end 

do    
    Assets.Main.OnUninject = Instance.new("BindableEvent")
        AppleHub.Main.Uninject()
        ► Xóa toàn bộ UI, dọn sạch connections và memory
        ► Gọi khi muốn tắt hoàn toàn script
        Ví dụ:
            AppleHub.Main.Uninject()
    Assets.Main.Uninject = function()
        Assets.Main.OnUninject:Fire(true)

        AppleHub.Background.Objects.MainScreenGui:Destroy()
        AppleHub.Notifications.Objects.NotificationGui:Destroy()
        AppleHub.ArrayList.Objects.ArrayGui:Destroy()

        if AppleHub.Mobile then
            for i,v in AppleHub.Background.MobileButtons.Buttons do
                if v and v.Functions and v.Functions.Destroy then
                    v.Functions.Destroy()
                end
            end
        end

        for i,v in AppleHub.Tabs.Tabs do
            if v.Modules then
                for i2,v2 in v.Modules do
                    if v2 and v2.Callback then
                        v2.Callback(v2, false)
                        if v2.Data and v2.Data.Enabled then
                            v2.Data.Enabled = false
                        end
                    end
                end
            end
        end
        for i,v in AppleHub.Connections do
            v:Disconnect()
        end
        
        Assets.Main.OnUninject:Destroy()
        table.clear(getgenv().AppleHub)
        getgenv().AppleHub = nil
    end

    local cantogglewithkeybind = true
        AppleHub.Main.Load(gameSave: string)
        ► Khởi tạo toàn bộ UI, tạo Dashboard + Settings page mặc định
        ► gameSave: tên file lưu config (vd: "Bloxfruits", "Arsenal")
        ► Trả về: { Background, Dashboard, Settings }
        ► Phải gọi hàm này TRƯỚC khi tạo Tab/Module
        Ví dụ:
            local UI = AppleHub.Main.Load("MyGame")
    Assets.Main.Load = function(file)
        if not AppleHub.Background then
            AppleHub.Background = Assets.MainBackground.Init()
        end

        if not AppleHub.Dashboard then
            AppleHub.Dashboard = Assets.Pages.NewPage({
                Name = "Dashboard",
                Icon = "rbxassetid://11295288868",
                Default = true
            })
            Assets.Dashboard.NewTab({
                Name = "Premium",
                Icon = "rbxassetid://102351199755031",
                TabInfo = "Powerful modules kept premium",
                Dashboard = AppleHub.Dashboard
            })

            local Settings = Assets.Pages.NewPage({
                Name = "Settings",
                Icon = "rbxassetid://11293977610",
                Default = false
            })

            local SettingsPage = Assets.SettingsPage.Init(Settings)
            local MainSettings = SettingsPage.Functions.NewSection({Name = "main"})
            MainSettings.Functions.NewButton({Name = "Uninject", Callback = function()
                Assets.Main.Uninject()
            end})
            MainSettings.Functions.NewButton({Name = "Notifications", Default = true, Toggle = true, Flag = "Notifications", Callback = function(self, enabled)
                AppleHub.Config.UI.Notifications = enabled
                Assets.Config.Save("UI", AppleHub.Config.UI)
            end})
            MainSettings.Functions.NewButton({Name = "Animations", Default = true, Toggle = true, Flag = "Anim", Callback = function(self, enabled)
                AppleHub.Config.UI.Anim = enabled
                Assets.Config.Save("UI", AppleHub.Config.UI)
            end})
            MainSettings.Functions.NewButton({Name = "ArrayList", Default = false, Toggle = true, Flag = "ArrayList", Callback = function(self, enabled)
                AppleHub.Config.UI.ArrayList = enabled
                local Array
                if not AppleHub.ArrayList.Loaded then
                    Array = Assets.ArrayList.Init()
                else
                    Array = AppleHub.ArrayList
                end
                Array.Functions.Toggle(enabled)

                Assets.Config.Save("UI", AppleHub.Config.UI)
            end})
            MainSettings.Functions.NewButton({Name = "Change Keybind", Callback = function(self)
                self.Objects.MainButtonText.Text = "Press the key you want to bind"
                local changecon = nil
                changecon = UserInputService.InputBegan:Connect(function(input)
                    if input and input.KeyCode.Name ~= "Unknown" then
                        cantogglewithkeybind = false
                        self.Objects.MainButtonText.Text = "Changed Keybind to " .. input.KeyCode.Name
                        AppleHub.Config.UI.ToggleKeyCode = input.KeyCode.Name
                        Assets.Config.Save("UI", AppleHub.Config.UI)
                        task.wait(1)
                        cantogglewithkeybind = true
                        self.Objects.MainButtonText.Text = "Change Keybind"
                    else
                        self.Objects.MainButtonText.Text = "Error Setting Bind"
                        task.wait(1)
                        self.Objects.MainButtonText.Text = "Change Keybind"
                    end
                    changecon:Disconnect()
                end)
                table.insert(AppleHub.Connections, changecon)
            end})
            MainSettings.Functions.NewButton({Name = "Reset Game Config", Callback = function()
                AppleHub.Config.Game = {
                    Modules = {},
                    Keybinds = {},
                    Sliders = {},
                    TextBoxes = {},
                    MiniToggles = {},
                    Dropdowns = {},
                    ToggleLists = {},
                    ModuleKeybinds = {},
                    Other = {}
                }
                Assets.Config.Save(AppleHub.GameSave, AppleHub.Config.Game)
            end})
            MainSettings.Functions.NewButton({Name = "Reset UI Config", Last = true, Callback = function()
                AppleHub.Config.UI = {
                    Position = {X = 0.5, Y = 0.5},
                    Size = {X = 0.24, Y = 0.52},
                    FullScreen = false,
                    ToggleKeyCode = "LeftAlt",
                    Scale = 1,
                    Notifications = true,
                    Anim = true,
                    ArrayList = false,
                    TabColor = {value1 = 40, value2 = 40, value3 = 40},
                    TabTransparency = 0.07,
                    KeybindTransparency = 0.7,
                    KeybindColor = {value1 = 0, value2 = 0, value3 = 0},
                }
                Assets.Config.Save("UI", AppleHub.Config.UI)
            end})

            local ThemeSettings = SettingsPage.Functions.NewSection({Name = "Theme"})
            ThemeSettings.Functions.NewButton({Name = "TabColor", Textbox = true, Flag = "TabColor", Default = "70, 70, 70", Callback = function(self, value)
                local split = string.split(value, ",")
                if #split == 3 then
                    local v1, v2, v3 = split[1]:gsub(" ", ""), split[2]:gsub(" ", ""), split[3]:gsub(" ", "")
                    if tonumber(v1) and tonumber(v2) and tonumber(v3) then
                        AppleHub.Config.UI.TabColor = {value1 = tonumber(v1), value2 = tonumber(v2), value3 = tonumber(v3)}
                        Assets.Config.Save("UI", AppleHub.Config.UI)
                        for i,v in AppleHub.Tabs.Tabs do
                            v.Objects.ActualTab.ImageColor3 = Color3.fromRGB(tonumber(v1), tonumber(v2), tonumber(v3))
                            v.Objects.CloseButton.BackgroundColor3 = Color3.fromRGB(tonumber(v1 + 20), tonumber(v2 + 20), tonumber(v3 + 20))
                            for i2, b in v.Modules do
                                if b.Objects and b.Objects.BackButton then 
                                    b.Objects.BackButton.BackgroundColor3 = Color3.fromRGB(tonumber(v1 + 20), tonumber(v2 + 20), tonumber(v3 + 20))
                                end
                            end
                        end
                    end
                end
            end})
            ThemeSettings.Functions.NewButton({Name = "TabTransparency", Textbox = true, Flag = "TabTransparency", Default = "0.1", Callback = function(self, value)
                if tonumber(value) then
                    AppleHub.Config.UI.TabTransparency = tonumber(value)
                    for i,v in AppleHub.Tabs.Tabs do
                        v.Objects.ActualTab.ImageTransparency = AppleHub.Config.UI.TabTransparency
                    end
                    Assets.Config.Save("UI", AppleHub.Config.UI)
                end
            end})
            ThemeSettings.Functions.NewButton({Name = "KeybindColor", Textbox = true, Flag = "KeybindColor", Default = "85, 89, 91", Callback = function(self, value)
                local split = string.split(value, ",")
                if #split == 3 then
                    local v1, v2, v3 = split[1]:gsub(" ", ""), split[2]:gsub(" ", ""), split[3]:gsub(" ", "")
                    if tonumber(v1) and tonumber(v2) and tonumber(v3) then
                        AppleHub.Config.UI.KeybindColor = {value1 = tonumber(v1), value2 = tonumber(v2), value3 = tonumber(v3)}
                        Assets.Config.Save("UI", AppleHub.Config.UI)
                        for i,v in AppleHub.Tabs.Tabs do
                            if v.Objects.ActualTab:FindFirstChildWhichIsA("TextButton") then
                                v.Objects.ActualTab:FindFirstChildWhichIsA("TextButton").BackgroundColor3 = Color3.fromRGB(tonumber(v1), tonumber(v2), tonumber(v3))
                            end
                        end
                    end
                end
            end})
            ThemeSettings.Functions.NewButton({Name = "KeybindTransparency", Textbox = true, Flag = "KeybindTransparency", Last = true, Default = "0.015", Callback = function(self, value)
                if tonumber(value) then
                    AppleHub.Config.UI.KeybindTransparency = tonumber(value)
                    Assets.Config.Save("UI", AppleHub.Config.UI)
                    for i,v in AppleHub.Tabs.Tabs do
                        if v.Objects.ActualTab:FindFirstChildWhichIsA("TextButton") then
                            v.Objects.ActualTab:FindFirstChildWhichIsA("TextButton").BackgroundTransparency = tonumber(value)
                        end
                    end
                end
            end})


            Assets.Config.Load(file, "Game")
            return {Background = AppleHub.Background, Dashboard = AppleHub.Dashboard, Settings = Settings}
        else
            Assets.Config.Load(AppleHub.GameSave, "Game")
            return {Background = AppleHub.Background, Dashboard = AppleHub.Dashboard}
        end
    end




    local ToggleTweens = {}
    local Restore = {}
    local IsToggleAnimating = false
        AppleHub.Main.ToggleVisibility(visible: boolean)
        ► Hiện hoặc ẩn toàn bộ cửa sổ UI
        ► visible = true  → mở UI
        ► visible = false → thu nhỏ UI
        Ví dụ:
            AppleHub.Main.ToggleVisibility(true)   -- mở
            AppleHub.Main.ToggleVisibility(false)  -- ẩn
    Assets.Main.ToggleVisibility = function(visible)
        do
            if not AppleHub.Config.UI.Anim then
                AppleHub.Background.Objects.MainFrame.Visible = visible
                if visible then
                    AppleHub.Background.Objects.MainFrame.BackgroundTransparency = 0.1
                    AppleHub.Background.Objects.MainFrame.ImageTransparency = 0.8
                    AppleHub.Background.Objects.MainFrameScale.Scale = 1
                    AppleHub.Background.Objects.WindowControls.GroupTransparency = 0.4
                end
                return
            end

            if IsToggleAnimating then repeat task.wait() until not IsToggleAnimating end
            IsToggleAnimating = true

            local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
            if visible then
                if not AppleHub.Background.Objects.MainFrame.Visible then  
                    AppleHub.Background.Objects.ToggleButton.Visible = false
                    AppleHub.Background.Objects.MainFrame.Visible = true
                    AppleHub.Background.Objects.DropShadow.Visible = true
                    
                    AppleHub.Background.Objects.MainFrame.BackgroundTransparency = 1
                    AppleHub.Background.Objects.MainFrame.ImageTransparency = 1
                    AppleHub.Background.Objects.MainFrameScale.Scale = 1.2
                    AppleHub.Background.Objects.WindowControls.GroupTransparency = 1


                    table.insert(ToggleTweens, TweenService:Create(AppleHub.Background.Objects.MainFrame, tweenInfo, {BackgroundTransparency = 0.1, ImageTransparency = 0.8}))
                    table.insert(ToggleTweens, TweenService:Create(AppleHub.Background.Objects.WindowControls, tweenInfo, {GroupTransparency = 0.4}))
                    table.insert(ToggleTweens, TweenService:Create(AppleHub.Background.Objects.MainFrameScale, tweenInfo, {Scale = 1}))

                    for i,v in Restore do
                        v.Visible = true
                    end
                    for i,v in AppleHub.Pages do
                        if v.Objects and v.Objects.ActualPage and v.Selected then
                            v.Objects.ActualPage.Visible = true
                        end
                    end
                    table.clear(Restore)

                    local completedTweens = 0
                    for i,v in ToggleTweens do
                        v:Play()
                        v.Completed:Connect(function()
                            completedTweens += 1
                            if completedTweens == #ToggleTweens then
                                IsToggleAnimating = false
                            end
                        end)
                    end
                    if AppleHub.CurrentOpenTab then
                        for i,v in AppleHub.CurrentOpenTab do
                            if v.Functions then
                                task.wait(0.015)
                                v.Functions.ToggleTab(true, true, true)
                            end
                        end
                    end

                else
                    IsToggleAnimating = false
                end

            else
                if AppleHub.Notifications.Active.discordnoti then
                    AppleHub.Notifications.Active.discordnoti.Functions.Remove(true)
                end
                AppleHub.Background.Objects.ToggleButton.Visible = true

                if AppleHub.CurrentOpenTab then
                    for i,v in AppleHub.CurrentOpenTab do
                        if v.Functions then
                            v.Functions.ToggleTab(false, true, true)
                        end
                    end
                end

                table.insert(ToggleTweens, TweenService:Create(AppleHub.Background.Objects.MainFrame, tweenInfo, {BackgroundTransparency = 1, ImageTransparency = 1}))
                table.insert(ToggleTweens, TweenService:Create(AppleHub.Background.Objects.WindowControls, tweenInfo, {GroupTransparency = 1}))
                table.insert(ToggleTweens, TweenService:Create(AppleHub.Background.Objects.MainFrameScale, tweenInfo, {Scale = 1.2}))

                if AppleHub.Pageselector.Objects.Pageselector.Visible then
                    AppleHub.Pageselector.Objects.Pageselector.Visible = false
                    table.insert(Restore, AppleHub.Pageselector.Objects.Pageselector)
                end
                AppleHub.Background.Objects.NavigationButtons.Visible = false
                table.insert(Restore, AppleHub.Background.Objects.NavigationButtons)
                AppleHub.Background.Objects.WindowControls.Visible = false
                table.insert(Restore, AppleHub.Background.Objects.WindowControls)

                for i,v in AppleHub.Pages do
                    if v.Objects and v.Objects.ActualPage then
                        v.Objects.ActualPage.Visible = false
                    end
                end
                AppleHub.Background.Objects.DropShadow.Visible = false

                local completedTweens = 0
                for i,v in ToggleTweens do
                    v:Play()
                    v.Completed:Connect(function()
                        completedTweens += 1
                        if completedTweens == #ToggleTweens then
                            IsToggleAnimating = false
                        end
                    end)
                end

                task.wait(0.5)
                AppleHub.Background.Objects.MainFrame.Visible = false
            end
        end
    end
    table.insert(AppleHub.Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed and UserInputService:GetFocusedTextBox() or not cantogglewithkeybind then return end
        if input.KeyCode.Name == AppleHub.Config.UI.ToggleKeyCode then
            Assets.Main.ToggleVisibility(not AppleHub.Background.Objects.MainFrame.Visible)
        end
    end))

end

AppleHub.Assets = Assets

return Assets

    end)()
end

local AH = getgenv().AppleHub

local uiResult = AppleHubLib.Main.Load("Rivals")
AppleHubLib.Main.ToggleVisibility(GetConfig("settings.showGuiOnLoad", true))

local dashboard = uiResult and uiResult.Dashboard or AH.Dashboard

local root = {
    Parent = true, -- always "exists"
    Visible = GetConfig("settings.showGuiOnLoad", true),
}
do
    local mt = getmetatable(root) or {}
    setmetatable(root, {
        __newindex = function(t, k, v)
            if k == "Visible" then
                rawset(t, k, v)
                pcall(function() AppleHubLib.Main.ToggleVisibility(v) end)
            else
                rawset(t, k, v)
            end
        end,
    })
end

local function makeHandle()
    return {} -- plain table used as key
end

local function bridgeToggle(module, flag, configKey, defaultVal)
    local handle = makeHandle()
    local currentState = GetConfig(configKey, defaultVal or false)

    ToggleAPI[handle] = {
        Get = function() return currentState end,
        Set = function(v)
            currentState = not not v
            pcall(function() module.Functions.Toggle(currentState) end)
        end,
        OnToggle = nil,
    }

    module.Callback = function(self, state)
        currentState = not not state
        SetConfig(configKey, currentState)
        SaveConfig()
        local api = ToggleAPI[handle]
        if api and type(api.OnToggle) == "function" then
            pcall(api.OnToggle, currentState)
        end
    end

    if currentState then
        task.defer(function()
            pcall(function()
                local api = ToggleAPI[handle]
                if api and type(api.OnToggle) == "function" then
                    pcall(api.OnToggle, true)
                end
            end)
        end)
    end

    return handle
end

local function bridgeSlider(module, sliderData, configKey, defaultVal)
    local handle = makeHandle()
    local currentVal = GetConfig(configKey, defaultVal)

    local setting = module.Functions.Settings.Slider({
        Name = sliderData.Name,
        Flag = sliderData.Flag or configKey,
        Min = sliderData.Min,
        Max = sliderData.Max,
        Default = currentVal,
        Callback = function(self, val)
            currentVal = val
            SetConfig(configKey, val)
            SaveConfig()
            local api = SliderAPI[handle]
            if api and type(api.OnChange) == "function" then
                pcall(api.OnChange, val)
            end
        end,
    })

    SliderAPI[handle] = {
        Get = function() return currentVal end,
        Set = function(v) currentVal = v end,
        OnChange = nil,
        Min = sliderData.Min,
        Max = sliderData.Max,
    }

    return handle
end

local function bridgeKeybind(module, kbData, configKey, defaultKey)
    local handle = makeHandle()
    local savedName = GetConfig(configKey, defaultKey and defaultKey.Name or "None")
    local currentKey = Enum.KeyCode[savedName] or defaultKey

    local setting = module.Functions.Settings.Keybind({
        Name = kbData.Name,
        Flag = kbData.Flag or configKey,
        Default = currentKey,
        Callback = function(self, key)
            currentKey = key
            if key and typeof(key) == "EnumItem" then
                SetConfig(configKey, key.Name)
                SaveConfig()
            end
            local api = KeybindAPI[handle]
            if api and type(api.OnBind) == "function" then
                pcall(api.OnBind, key)
            end
        end,
    })

    KeybindAPI[handle] = {
        Get = function() return currentKey end,
        Set = function(k)
            if typeof(k) == "EnumItem" then currentKey = k end
        end,
        OnBind = nil,
    }

    return handle
end

local function bridgeDropdown(module, ddData, configKey, defaultIdx)
    local handle = makeHandle()
    local currentIdx = GetConfig(configKey, defaultIdx) or defaultIdx

    local setting = module.Functions.Settings.Dropdown({
        Name = ddData.Name,
        Flag = ddData.Flag or configKey,
        Options = ddData.Options,
        Default = currentIdx,
        Callback = function(self, idx, val)
            currentIdx = idx
            SetConfig(configKey, val or idx)
            SaveConfig()
            local api = DropdownAPI[handle]
            if api and type(api.OnSelect) == "function" then
                pcall(api.OnSelect, idx, val)
            end
        end,
    })

    DropdownAPI[handle] = {
        Get = function() return currentIdx end,
        Set = function(idx) currentIdx = idx end,
        OnSelect = nil,
    }

    return handle
end

local function bridgeColorPicker(module, cpData, configKey)
    local handle = makeHandle()
    local initTbl = GetConfig(configKey, nil)
    local currentColor = (type(initTbl) == "table" and initTbl.r and initTbl.g and initTbl.b)
        and Color3.new(initTbl.r, initTbl.g, initTbl.b)
        or COLORS.accent

    module.Functions.Settings.Button({
        Name = (cpData.Name or "Color Picker") .. " (set via script)",
        Flag = cpData.Flag or configKey,
        Callback = function() end,
    })

    ColorPickerAPI[handle] = {
        Get = function() return currentColor end,
        Set = function(c)
            currentColor = c
            if c then SetConfig(configKey, { r = c.R, g = c.G, b = c.B }) end
        end,
        OnChange = nil,
    }

    task.defer(function()
        local api = ColorPickerAPI[handle]
        if api and type(api.OnChange) == "function" then
            pcall(api.OnChange, currentColor)
        end
    end)

    return handle
end



local AH_dashboard = getgenv().AppleHub.Dashboard

local function makeToggleHandle(configKey, defaultVal, onEnable, onDisable)
    local handle = {}
    local currentState = GetConfig(configKey, defaultVal or false)

    ToggleAPI[handle] = {
        Get = function() return currentState end,
        Set = function(v)
            currentState = not not v
            if currentState then pcall(onEnable or function() end)
            else pcall(onDisable or function() end) end
        end,
        OnToggle = nil,
    }
    return handle, currentState
end

local function makeSliderHandle(configKey, defaultVal)
    local handle = {}
    local cur = GetConfig(configKey, defaultVal) or defaultVal
    SliderAPI[handle] = {
        Get = function() return cur end,
        Set = function(v) cur = v end,
        OnChange = nil,
        Min = 0, Max = 100,
    }
    return handle, cur
end

local function makeKeybindHandle(configKey, defaultKey)
    local handle = {}
    local savedName = GetConfig(configKey, defaultKey and defaultKey.Name or "None")
    local cur = Enum.KeyCode[savedName] or defaultKey
    KeybindAPI[handle] = {
        Get = function() return cur end,
        Set = function(k) if typeof(k) == "EnumItem" then cur = k end end,
        OnBind = nil,
    }
    return handle, cur
end

local function makeColorHandle(configKey)
    local handle = {}
    local tbl = GetConfig(configKey, nil)
    local cur = (type(tbl)=="table" and tbl.r and tbl.g and tbl.b) and Color3.new(tbl.r,tbl.g,tbl.b) or COLORS.accent
    ColorPickerAPI[handle] = {
        Get = function() return cur end,
        Set = function(c)
            cur = c
            if c then SetConfig(configKey, {r=c.R, g=c.G, b=c.B}); SaveConfig() end
            local api = ColorPickerAPI[handle]
            if api and type(api.OnChange)=="function" then pcall(api.OnChange, c) end
        end,
        OnChange = nil,
    }
    task.defer(function()
        local api = ColorPickerAPI[handle]
        if api and type(api.OnChange)=="function" then pcall(api.OnChange, cur) end
    end)
    return handle
end

local function makeDropHandle(configKey, defaultIdx)
    local handle = {}
    local cur = GetConfig(configKey, defaultIdx) or defaultIdx
    DropdownAPI[handle] = {
        Get = function() return cur end,
        Set = function(idx) cur = idx end,
        OnSelect = nil,
    }
    return handle, cur
end

local visualsTab = pcall(function() end) and (function()
    return AppleHubLib.Dashboard.NewTab({
        Name = "Visuals",
        Icon = "rbxassetid://11295288868",
        TabInfo = "Visual cheats và ESP",
        Dashboard = AH_dashboard,
    })
end)()

local playerChamsToggle, playerChamsColorPicker, glowChamsToggle,
      glowIntensitySlider, playerHealthToggle, showHealthKeybind,
      espBoxesToggle, espBoxesColorPicker, showEnemyWeaponsToggle

pcall(function()
    local _chamsState = GetConfig("visuals.playerChams", true)
    playerChamsToggle = {}
    ToggleAPI[playerChamsToggle] = { Get=function() return _chamsState end, Set=function(v) _chamsState=not not v end, OnToggle=nil }
    visualsTab.Functions.NewModule({
        Name = "Player Chams",
        Description = "Highlight toàn bộ người chơi",
        Icon = "rbxassetid://11293977610",
        Flag = "visuals.playerChams",
        Default = _chamsState,
        Callback = function(self, state)
            _chamsState = not not state
            SetConfig("visuals.playerChams", _chamsState); SaveConfig()
            local api = ToggleAPI[playerChamsToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _chamsState) end
        end,
    })

    playerChamsColorPicker = makeColorHandle("visuals.playerChamsColor")
end)

pcall(function()
    local _glowState = GetConfig("visuals.glowChams", false)
    glowChamsToggle = {}
    ToggleAPI[glowChamsToggle] = { Get=function() return _glowState end, Set=function(v) _glowState=not not v end, OnToggle=nil }
    local glowMod = visualsTab.Functions.NewModule({
        Name = "Glow Chams",
        Description = "Highlight với hiệu ứng phát sáng",
        Icon = "rbxassetid://11293977610",
        Flag = "visuals.glowChams",
        Default = _glowState,
        Callback = function(self, state)
            _glowState = not not state
            SetConfig("visuals.glowChams", _glowState); SaveConfig()
            local api = ToggleAPI[glowChamsToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _glowState) end
        end,
    })

    local _glowInt = GetConfig("visuals.glowChamsIntensity", 50) or 50
    glowIntensitySlider = {}
    SliderAPI[glowIntensitySlider] = { Get=function() return _glowInt end, Set=function(v) _glowInt=v end, OnChange=nil, Min=0, Max=100 }
    pcall(function()
        glowMod.Functions.Settings.Slider({
            Name = "Glow Intensity",
            Flag = "visuals.glowChamsIntensity",
            Min = 0, Max = 100,
            Default = _glowInt,
            Callback = function(self, val)
                _glowInt = val
                SetConfig("visuals.glowChamsIntensity", val); SaveConfig()
                local api = SliderAPI[glowIntensitySlider]
                if api and type(api.OnChange)=="function" then pcall(api.OnChange, val) end
            end,
        })
    end)
end)

pcall(function()
    local _healthState = GetConfig("visuals.playerHealth", false)
    playerHealthToggle = {}
    ToggleAPI[playerHealthToggle] = { Get=function() return _healthState end, Set=function(v) _healthState=not not v end, OnToggle=nil }
    local healthMod = visualsTab.Functions.NewModule({
        Name = "Player Health",
        Description = "Hiển thị thanh máu người chơi",
        Icon = "rbxassetid://11293977610",
        Flag = "visuals.playerHealth",
        Default = _healthState,
        Callback = function(self, state)
            _healthState = not not state
            SetConfig("visuals.playerHealth", _healthState); SaveConfig()
            local api = ToggleAPI[playerHealthToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _healthState) end
        end,
    })

    local _hkSaved = GetConfig("visuals.showHealthKey", "P")
    local _hkEnum = Enum.KeyCode[_hkSaved] or Enum.KeyCode.P
    showHealthKeybind = {}
    KeybindAPI[showHealthKeybind] = { Get=function() return _hkEnum end, Set=function(k) if typeof(k)=="EnumItem" then _hkEnum=k end end, OnBind=nil }
    pcall(function()
        healthMod.Functions.Settings.Keybind({
            Name = "Show Health Keybind",
            Flag = "visuals.showHealthKey",
            Default = _hkSaved,
            Callbacks = {
                Began = function() end,
                End = function() end,
                Changed = function(key)
                    if key and typeof(key)=="EnumItem" then
                        _hkEnum = key
                        SetConfig("visuals.showHealthKey", key.Name); SaveConfig()
                        local api = KeybindAPI[showHealthKeybind]
                        if api and type(api.OnBind)=="function" then pcall(api.OnBind, key) end
                    end
                end,
            },
        })
    end)
end)

pcall(function()
    local _espState = GetConfig("visuals.espBoxes", false)
    espBoxesToggle = {}
    ToggleAPI[espBoxesToggle] = { Get=function() return _espState end, Set=function(v) _espState=not not v end, OnToggle=nil }
    visualsTab.Functions.NewModule({
        Name = "ESP Boxes",
        Description = "Vẽ box quanh người chơi",
        Icon = "rbxassetid://11293977610",
        Flag = "visuals.espBoxes",
        Default = _espState,
        Callback = function(self, state)
            _espState = not not state
            SetConfig("visuals.espBoxes", _espState); SaveConfig()
            local api = ToggleAPI[espBoxesToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _espState) end
        end,
    })
    espBoxesColorPicker = makeColorHandle("visuals.espBoxesColor")
end)

pcall(function()
    local _weapState = GetConfig("visuals.showEnemyWeapons", false)
    showEnemyWeaponsToggle = {}
    ToggleAPI[showEnemyWeaponsToggle] = { Get=function() return _weapState end, Set=function(v) _weapState=not not v end, OnToggle=nil }
    visualsTab.Functions.NewModule({
        Name = "Show Enemy Weapons",
        Description = "Hiện vũ khí của địch trên màn hình",
        Icon = "rbxassetid://11293977610",
        Flag = "visuals.showEnemyWeapons",
        Default = _weapState,
        Callback = function(self, state)
            _weapState = not not state
            SetConfig("visuals.showEnemyWeapons", _weapState); SaveConfig()
            local api = ToggleAPI[showEnemyWeaponsToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _weapState) end
        end,
    })
end)

local combatTab = nil
pcall(function()
    combatTab = AppleHubLib.Dashboard.NewTab({
        Name = "Combat",
        Icon = "rbxassetid://11293977610",
        TabInfo = "Aimbot và combat cheats",
        Dashboard = AH_dashboard,
    })
end)

local aimbotToggle, enableAimbotKeybind, aimLockKeybind, persistentAimbotToggle,
      useAimbotSmoothingToggle, smoothingSlider, aimPredictionToggle,
      aimbotFOVSlider, drawFovCircleToggle, aimnbotTargetZoneToggle,
      aimbotTargetZoneSlider, targetBehindWallsToggle, teamCheckToggle,
      sixthSenseToggle, autoShootToggle, enableAutoShootKeybind

if combatTab then
pcall(function()
    local _aimState = GetConfig("combat.aimbot", false)
    aimbotToggle = {}
    ToggleAPI[aimbotToggle] = { Get=function() return _aimState end, Set=function(v) _aimState=not not v end, OnToggle=nil }
    local aimMod = combatTab.Functions.NewModule({
        Name = "Aimbot",
        Description = "Tự động aim vào địch",
        Icon = "rbxassetid://11293977610",
        Flag = "combat.aimbot",
        Default = _aimState,
        Callback = function(self, state)
            _aimState = not not state
            SetConfig("combat.aimbot", _aimState); SaveConfig()
            local api = ToggleAPI[aimbotToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _aimState) end
        end,
    })

    local _aimKSaved = GetConfig("combat.aimbotKey", "V")
    local _aimKEnum = Enum.KeyCode[_aimKSaved] or Enum.KeyCode.V
    enableAimbotKeybind = {}
    KeybindAPI[enableAimbotKeybind] = { Get=function() return _aimKEnum end, Set=function(k) if typeof(k)=="EnumItem" then _aimKEnum=k end end, OnBind=nil }
    pcall(function()
        aimMod.Functions.Settings.Keybind({
            Name = "Bật Aimbot", Flag = "combat.aimbotKey", Default = _aimKSaved,
            Callbacks = { Began=function() end, End=function() end,
                Changed=function(key) if key and typeof(key)=="EnumItem" then _aimKEnum=key; SetConfig("combat.aimbotKey",key.Name); SaveConfig()
                    local api=KeybindAPI[enableAimbotKeybind]; if api and type(api.OnBind)=="function" then pcall(api.OnBind,key) end end end },
        })
    end)

    local _lockKSaved = GetConfig("combat.aimLockKey", "Q")
    local _lockKEnum = Enum.KeyCode[_lockKSaved] or Enum.KeyCode.Q
    aimLockKeybind = {}
    KeybindAPI[aimLockKeybind] = { Get=function() return _lockKEnum end, Set=function(k) if typeof(k)=="EnumItem" then _lockKEnum=k end end, OnBind=nil }
    pcall(function()
        aimMod.Functions.Settings.Keybind({
            Name = "Aim Lock", Flag = "combat.aimLockKey", Default = _lockKSaved,
            Callbacks = { Began=function() end, End=function() end,
                Changed=function(key) if key and typeof(key)=="EnumItem" then _lockKEnum=key; SetConfig("combat.aimLockKey",key.Name); SaveConfig()
                    local api=KeybindAPI[aimLockKeybind]; if api and type(api.OnBind)=="function" then pcall(api.OnBind,key) end end end },
        })
    end)
end)

pcall(function()
    local _pState = GetConfig("combat.persistentAimbot", false)
    persistentAimbotToggle = {}
    ToggleAPI[persistentAimbotToggle] = { Get=function() return _pState end, Set=function(v) _pState=not not v end, OnToggle=nil }
    combatTab.Functions.NewModule({
        Name = "Persistent Aimbot",
        Description = "Khóa mục tiêu kể cả khi ra khỏi FOV",
        Icon = "rbxassetid://11293977610",
        Flag = "combat.persistentAimbot",
        Default = _pState,
        Callback = function(self, state)
            _pState = not not state
            SetConfig("combat.persistentAimbot", _pState); SaveConfig()
            local api = ToggleAPI[persistentAimbotToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _pState) end
        end,
    })
end)

pcall(function()
    local _sState = GetConfig("combat.useAimbotSmoothing", false)
    useAimbotSmoothingToggle = {}
    ToggleAPI[useAimbotSmoothingToggle] = { Get=function() return _sState end, Set=function(v) _sState=not not v end, OnToggle=nil }
    local smoothMod = combatTab.Functions.NewModule({
        Name = "Aimbot Smoothing",
        Description = "Di chuyển aim mượt mà hơn",
        Icon = "rbxassetid://11293977610",
        Flag = "combat.useAimbotSmoothing",
        Default = _sState,
        Callback = function(self, state)
            _sState = not not state
            SetConfig("combat.useAimbotSmoothing", _sState); SaveConfig()
            local api = ToggleAPI[useAimbotSmoothingToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _sState) end
        end,
    })
    local _sv = GetConfig("combat.aimbotSmoothing", 1) or 1
    smoothingSlider = {}
    SliderAPI[smoothingSlider] = { Get=function() return _sv end, Set=function(v) _sv=v end, OnChange=nil, Min=1, Max=100 }
    pcall(function()
        smoothMod.Functions.Settings.Slider({
            Name="Smooth Amount", Flag="combat.aimbotSmoothing", Min=1, Max=100, Default=_sv,
            Callback=function(self,v) _sv=v; SetConfig("combat.aimbotSmoothing",v); SaveConfig()
                local api=SliderAPI[smoothingSlider]; if api and type(api.OnChange)=="function" then pcall(api.OnChange,v) end end,
        })
    end)
end)

pcall(function()
    local _apState = GetConfig("combat.aimPrediction", false)
    aimPredictionToggle = {}
    ToggleAPI[aimPredictionToggle] = { Get=function() return _apState end, Set=function(v) _apState=not not v end, OnToggle=nil }
    combatTab.Functions.NewModule({
        Name = "Aimbot Prediction",
        Description = "Dự đoán chuyển động địch",
        Icon = "rbxassetid://11293977610",
        Flag = "combat.aimPrediction",
        Default = _apState,
        Callback = function(self, state)
            _apState = not not state
            SetConfig("combat.aimPrediction", _apState); SaveConfig()
            local api = ToggleAPI[aimPredictionToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _apState) end
        end,
    })
end)

pcall(function()
    local _fovMod = combatTab.Functions.NewModule({
        Name = "FOV Settings",
        Description = "Chỉnh FOV aimbot",
        Icon = "rbxassetid://11293977610",
        Flag = "combat.fovSettings",
        Default = false, Button = true,
        Callback = function() end,
    })

    local _fovV = GetConfig("combat.aimbotFOV", 700) or 700
    aimbotFOVSlider = {}
    SliderAPI[aimbotFOVSlider] = { Get=function() return _fovV end, Set=function(v) _fovV=v end, OnChange=nil, Min=1, Max=1000 }
    pcall(function()
        _fovMod.Functions.Settings.Slider({
            Name="Aimbot FOV", Flag="combat.aimbotFOV", Min=1, Max=1000, Default=_fovV,
            Callback=function(self,v) _fovV=v; SetConfig("combat.aimbotFOV",v); SaveConfig()
                local api=SliderAPI[aimbotFOVSlider]; if api and type(api.OnChange)=="function" then pcall(api.OnChange,v) end end,
        })
    end)

    local _tzV = GetConfig("combat.aimbotTargetZone", 500) or 500
    aimbotTargetZoneSlider = {}
    SliderAPI[aimbotTargetZoneSlider] = { Get=function() return _tzV end, Set=function(v) _tzV=v end, OnChange=nil, Min=1, Max=900 }
    pcall(function()
        _fovMod.Functions.Settings.Slider({
            Name="Target Zone", Flag="combat.aimbotTargetZone", Min=1, Max=900, Default=math.min(_tzV,900),
            Callback=function(self,v) _tzV=v; SetConfig("combat.aimbotTargetZone",v); SaveConfig()
                local api=SliderAPI[aimbotTargetZoneSlider]; if api and type(api.OnChange)=="function" then pcall(api.OnChange,v) end end,
        })
    end)
end)

pcall(function()
    local _dfc = GetConfig("combat.drawFovCircle", false)
    drawFovCircleToggle = {}
    ToggleAPI[drawFovCircleToggle] = { Get=function() return _dfc end, Set=function(v) _dfc=not not v end, OnToggle=nil }
    combatTab.Functions.NewModule({
        Name = "Draw FOV Circle",
        Description = "Vẽ vòng tròn FOV aimbot",
        Icon = "rbxassetid://11293977610",
        Flag = "combat.drawFovCircle",
        Default = _dfc,
        Callback = function(self, state)
            _dfc = not not state
            SetConfig("combat.drawFovCircle", _dfc); SaveConfig()
            local api = ToggleAPI[drawFovCircleToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _dfc) end
        end,
    })
end)

pcall(function()
    local _tzState = GetConfig("combat.aimbotTargetZoneEnabled", false)
    aimnbotTargetZoneToggle = {}
    ToggleAPI[aimnbotTargetZoneToggle] = { Get=function() return _tzState end, Set=function(v) _tzState=not not v end, OnToggle=nil }
    combatTab.Functions.NewModule({
        Name = "Use Target Zone",
        Description = "Chỉ aim địch trong phạm vi",
        Icon = "rbxassetid://11293977610",
        Flag = "combat.aimbotTargetZoneEnabled",
        Default = _tzState,
        Callback = function(self, state)
            _tzState = not not state
            SetConfig("combat.aimbotTargetZoneEnabled", _tzState); SaveConfig()
            local api = ToggleAPI[aimnbotTargetZoneToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _tzState) end
        end,
    })
end)

pcall(function()
    local _tbw = GetConfig("combat.targetBehindWalls", false)
    targetBehindWallsToggle = {}
    ToggleAPI[targetBehindWallsToggle] = { Get=function() return _tbw end, Set=function(v) _tbw=not not v end, OnToggle=nil }
    combatTab.Functions.NewModule({
        Name = "Target Behind Walls",
        Description = "Aim xuyên tường",
        Icon = "rbxassetid://11293977610",
        Flag = "combat.targetBehindWalls",
        Default = _tbw,
        Callback = function(self, state)
            _tbw = not not state
            SetConfig("combat.targetBehindWalls", _tbw); SaveConfig()
            local api = ToggleAPI[targetBehindWallsToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _tbw) end
        end,
    })
end)

pcall(function()
    local _tc = GetConfig("combat.teamCheck", true)
    teamCheckToggle = {}
    ToggleAPI[teamCheckToggle] = { Get=function() return _tc end, Set=function(v) _tc=not not v end, OnToggle=nil }
    combatTab.Functions.NewModule({
        Name = "Team Check",
        Description = "Không nhắm vào đồng đội",
        Icon = "rbxassetid://11293977610",
        Flag = "combat.teamCheck",
        Default = _tc,
        Callback = function(self, state)
            _tc = not not state
            SetConfig("combat.teamCheck", _tc); SaveConfig()
            local api = ToggleAPI[teamCheckToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _tc) end
        end,
    })
end)

pcall(function()
    local _ss = GetConfig("combat.sixthSense", false)
    sixthSenseToggle = {}
    ToggleAPI[sixthSenseToggle] = { Get=function() return _ss end, Set=function(v) _ss=not not v end, OnToggle=nil }
    combatTab.Functions.NewModule({
        Name = "Sixth Sense",
        Description = "Phát hiện bẫy và katana",
        Icon = "rbxassetid://11293977610",
        Flag = "combat.sixthSense",
        Default = _ss,
        Callback = function(self, state)
            _ss = not not state
            SetConfig("combat.sixthSense", _ss); SaveConfig()
            local api = ToggleAPI[sixthSenseToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _ss) end
        end,
    })
end)

pcall(function()
    local _as = GetConfig("combat.autoShoot", false)
    autoShootToggle = {}
    ToggleAPI[autoShootToggle] = { Get=function() return _as end, Set=function(v) _as=not not v end, OnToggle=nil }
    local asMod = combatTab.Functions.NewModule({
        Name = "Auto-Shoot",
        Description = "Tự động bắn khi địch vào crosshair",
        Icon = "rbxassetid://11293977610",
        Flag = "combat.autoShoot",
        Default = _as,
        Callback = function(self, state)
            _as = not not state
            SetConfig("combat.autoShoot", _as); SaveConfig()
            local api = ToggleAPI[autoShootToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _as) end
        end,
    })
    local _asKSaved = GetConfig("combat.autoShootKey", "Y")
    local _asKEnum = Enum.KeyCode[_asKSaved] or Enum.KeyCode.Y
    enableAutoShootKeybind = {}
    KeybindAPI[enableAutoShootKeybind] = { Get=function() return _asKEnum end, Set=function(k) if typeof(k)=="EnumItem" then _asKEnum=k end end, OnBind=nil }
    pcall(function()
        asMod.Functions.Settings.Keybind({
            Name="Auto-Shoot Keybind", Flag="combat.autoShootKey", Default=_asKSaved,
            Callbacks={ Began=function() end, End=function() end,
                Changed=function(key) if key and typeof(key)=="EnumItem" then _asKEnum=key; SetConfig("combat.autoShootKey",key.Name); SaveConfig()
                    local api=KeybindAPI[enableAutoShootKeybind]; if api and type(api.OnBind)=="function" then pcall(api.OnBind,key) end end end },
        })
    end)
end)

end -- if combatTab

local rageTab = nil
pcall(function()
    rageTab = AppleHubLib.Dashboard.NewTab({
        Name = "Rage",
        Icon = "rbxassetid://11293977610",
        TabInfo = "High-risk features",
        Dashboard = AH_dashboard,
    })
end)

local noclipToggle, noclipKeybind, stickToToggle, stickToKeybind,
      useStickSmoothingToggle, smoothStickingSlider, flyToggle,
      flyKeybind, flySpeedSlider

if rageTab then
pcall(function()
    local _nc = GetConfig("rage.noclip", false)
    noclipToggle = {}
    ToggleAPI[noclipToggle] = { Get=function() return _nc end, Set=function(v) _nc=not not v end, OnToggle=nil }
    local ncMod = rageTab.Functions.NewModule({
        Name = "Noclip",
        Description = "Đi xuyên tường",
        Icon = "rbxassetid://11293977610",
        Flag = "rage.noclip",
        Default = _nc,
        Callback = function(self, state)
            _nc = not not state
            SetConfig("rage.noclip", _nc); SaveConfig()
            local api = ToggleAPI[noclipToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _nc) end
        end,
    })
    local _ncKSaved = GetConfig("rage.noclipKeybind", "N")
    local _ncKEnum = Enum.KeyCode[_ncKSaved] or Enum.KeyCode.N
    noclipKeybind = {}
    KeybindAPI[noclipKeybind] = { Get=function() return _ncKEnum end, Set=function(k) if typeof(k)=="EnumItem" then _ncKEnum=k end end, OnBind=nil }
    pcall(function()
        ncMod.Functions.Settings.Keybind({
            Name="Noclip Keybind", Flag="rage.noclipKeybind", Default=_ncKSaved,
            Callbacks={ Began=function() end, End=function() end,
                Changed=function(key) if key and typeof(key)=="EnumItem" then _ncKEnum=key; SetConfig("rage.noclipKeybind",key.Name); SaveConfig()
                    local api=KeybindAPI[noclipKeybind]; if api and type(api.OnBind)=="function" then pcall(api.OnBind,key) end end end },
        })
    end)
end)

pcall(function()
    local _st = GetConfig("rage.stickToTarget", false)
    stickToToggle = {}
    ToggleAPI[stickToToggle] = { Get=function() return _st end, Set=function(v) _st=not not v end, OnToggle=nil }
    local stickMod = rageTab.Functions.NewModule({
        Name = "Stick to Target",
        Description = "Bám theo người chơi gần nhất",
        Icon = "rbxassetid://11293977610",
        Flag = "rage.stickToTarget",
        Default = _st,
        Callback = function(self, state)
            _st = not not state
            SetConfig("rage.stickToTarget", _st); SaveConfig()
            local api = ToggleAPI[stickToToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _st) end
        end,
    })
    local _stKSaved = GetConfig("rage.stickToTargetKeybind", "I")
    local _stKEnum = Enum.KeyCode[_stKSaved] or Enum.KeyCode.I
    stickToKeybind = {}
    KeybindAPI[stickToKeybind] = { Get=function() return _stKEnum end, Set=function(k) if typeof(k)=="EnumItem" then _stKEnum=k end end, OnBind=nil }
    pcall(function()
        stickMod.Functions.Settings.Keybind({
            Name="Stick Keybind", Flag="rage.stickToTargetKeybind", Default=_stKSaved,
            Callbacks={ Began=function() end, End=function() end,
                Changed=function(key) if key and typeof(key)=="EnumItem" then _stKEnum=key; SetConfig("rage.stickToTargetKeybind",key.Name); SaveConfig()
                    local api=KeybindAPI[stickToKeybind]; if api and type(api.OnBind)=="function" then pcall(api.OnBind,key) end end end },
        })
    end)
end)

pcall(function()
    local _uss = GetConfig("rage.useStickSmoothing", false)
    useStickSmoothingToggle = {}
    ToggleAPI[useStickSmoothingToggle] = { Get=function() return _uss end, Set=function(v) _uss=not not v end, OnToggle=nil }
    local sssMod = rageTab.Functions.NewModule({
        Name = "Smooth Sticking",
        Description = "Di chuyển mượt về phía mục tiêu",
        Icon = "rbxassetid://11293977610",
        Flag = "rage.useStickSmoothing",
        Default = _uss,
        Callback = function(self, state)
            _uss = not not state
            SetConfig("rage.useStickSmoothing", _uss); SaveConfig()
            local api = ToggleAPI[useStickSmoothingToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _uss) end
        end,
    })
    local _ssV = GetConfig("rage.smoothStickingIntensity", 20) or 20
    smoothStickingSlider = {}
    SliderAPI[smoothStickingSlider] = { Get=function() return _ssV end, Set=function(v) _ssV=v end, OnChange=nil, Min=0, Max=100 }
    pcall(function()
        sssMod.Functions.Settings.Slider({
            Name="Smooth Intensity", Flag="rage.smoothStickingIntensity", Min=0, Max=100, Default=_ssV,
            Callback=function(self,v) _ssV=v; SetConfig("rage.smoothStickingIntensity",v); SaveConfig()
                local api=SliderAPI[smoothStickingSlider]; if api and type(api.OnChange)=="function" then pcall(api.OnChange,v) end end,
        })
    end)
end)

pcall(function()
    local _fly = GetConfig("rage.fly", false)
    flyToggle = {}
    ToggleAPI[flyToggle] = { Get=function() return _fly end, Set=function(v) _fly=not not v end, OnToggle=nil }
    local flyMod = rageTab.Functions.NewModule({
        Name = "Fly",
        Description = "Bay - SPACE lên, SHIFT xuống",
        Icon = "rbxassetid://11293977610",
        Flag = "rage.fly",
        Default = _fly,
        Callback = function(self, state)
            _fly = not not state
            SetConfig("rage.fly", _fly); SaveConfig()
            local api = ToggleAPI[flyToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _fly) end
        end,
    })
    local _flyKSaved = GetConfig("rage.flyKeybind", "N")
    local _flyKEnum = Enum.KeyCode[_flyKSaved] or Enum.KeyCode.N
    flyKeybind = {}
    KeybindAPI[flyKeybind] = { Get=function() return _flyKEnum end, Set=function(k) if typeof(k)=="EnumItem" then _flyKEnum=k end end, OnBind=nil }
    pcall(function()
        flyMod.Functions.Settings.Keybind({
            Name="Fly Keybind", Flag="rage.flyKeybind", Default=_flyKSaved,
            Callbacks={ Began=function() end, End=function() end,
                Changed=function(key) if key and typeof(key)=="EnumItem" then _flyKEnum=key; SetConfig("rage.flyKeybind",key.Name); SaveConfig()
                    local api=KeybindAPI[flyKeybind]; if api and type(api.OnBind)=="function" then pcall(api.OnBind,key) end end end },
        })
    end)
    local _flySpd = GetConfig("rage.flySpeed", 20) or 20
    flySpeedSlider = {}
    SliderAPI[flySpeedSlider] = { Get=function() return _flySpd end, Set=function(v) _flySpd=v end, OnChange=nil, Min=0, Max=400 }
    pcall(function()
        flyMod.Functions.Settings.Slider({
            Name="Fly Speed", Flag="rage.flySpeed", Min=0, Max=400, Default=math.min(_flySpd,400),
            Callback=function(self,v) _flySpd=v; SetConfig("rage.flySpeed",v); SaveConfig()
                local api=SliderAPI[flySpeedSlider]; if api and type(api.OnChange)=="function" then pcall(api.OnChange,v) end end,
        })
    end)
end)

end -- if rageTab

local settingsTab = nil
pcall(function()
    settingsTab = AppleHubLib.Dashboard.NewTab({
        Name = "Settings",
        Icon = "rbxassetid://11293977610",
        TabInfo = "Cài đặt script",
        Dashboard = AH_dashboard,
    })
end)

local showGuiOnLoadToggle, closeOpenGuiKeybind, showNotificationsToggle,
      warnIfUnsupportedGameToggle, debugModeToggle, debugConfigToggle, autoScaleUIToggle

if settingsTab then
pcall(function()
    local _sgl = GetConfig("settings.showGuiOnLoad", true)
    showGuiOnLoadToggle = {}
    ToggleAPI[showGuiOnLoadToggle] = { Get=function() return _sgl end, Set=function(v) _sgl=not not v end, OnToggle=nil }
    local sglMod = settingsTab.Functions.NewModule({
        Name = "Show GUI On Load",
        Description = "Hiện GUI khi chạy script",
        Icon = "rbxassetid://11293977610",
        Flag = "settings.showGuiOnLoad",
        Default = _sgl,
        Callback = function(self, state)
            _sgl = not not state
            SetConfig("settings.showGuiOnLoad", _sgl); SaveConfig()
            local api = ToggleAPI[showGuiOnLoadToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _sgl) end
        end,
    })
    local _cogKSaved = GetConfig("settings.closeOpenGuiKey", "Insert")
    local _cogKEnum = Enum.KeyCode[_cogKSaved] or Enum.KeyCode.Insert
    closeOpenGuiKeybind = {}
    KeybindAPI[closeOpenGuiKeybind] = { Get=function() return _cogKEnum end, Set=function(k) if typeof(k)=="EnumItem" then _cogKEnum=k end end, OnBind=nil }
    pcall(function()
        sglMod.Functions.Settings.Keybind({
            Name="Toggle GUI Keybind", Flag="settings.closeOpenGuiKey", Default=_cogKSaved,
            Callbacks={ Began=function() end, End=function() end,
                Changed=function(key) if key and typeof(key)=="EnumItem" then _cogKEnum=key; SetConfig("settings.closeOpenGuiKey",key.Name); SaveConfig()
                    local api=KeybindAPI[closeOpenGuiKeybind]; if api and type(api.OnBind)=="function" then pcall(api.OnBind,key) end end end },
        })
    end)
end)

pcall(function()
    local _en = GetConfig("settings.enableNotifications", true)
    showNotificationsToggle = {}
    ToggleAPI[showNotificationsToggle] = { Get=function() return _en end, Set=function(v) _en=not not v end, OnToggle=nil }
    settingsTab.Functions.NewModule({
        Name = "Enable Notifications",
        Description = "Hiện thông báo trên màn hình",
        Icon = "rbxassetid://11293977610",
        Flag = "settings.enableNotifications",
        Default = _en,
        Callback = function(self, state)
            _en = not not state
            SetConfig("settings.enableNotifications", _en); SaveConfig()
            local api = ToggleAPI[showNotificationsToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _en) end
        end,
    })
end)

pcall(function()
    local _wu = GetConfig("settings.warnIfUnsupportedGame", true)
    warnIfUnsupportedGameToggle = {}
    ToggleAPI[warnIfUnsupportedGameToggle] = { Get=function() return _wu end, Set=function(v) _wu=not not v end, OnToggle=nil }
    settingsTab.Functions.NewModule({
        Name = "Warn Unsupported Game",
        Description = "Cảnh báo nếu game không được hỗ trợ",
        Icon = "rbxassetid://11293977610",
        Flag = "settings.warnIfUnsupportedGame",
        Default = _wu,
        Callback = function(self, state)
            _wu = not not state
            SetConfig("settings.warnIfUnsupportedGame", _wu); SaveConfig()
            local api = ToggleAPI[warnIfUnsupportedGameToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _wu) end
        end,
    })
end)

pcall(function()
    local _dm = GetConfig("settings.debugMode", false)
    debugModeToggle = {}
    ToggleAPI[debugModeToggle] = { Get=function() return _dm end, Set=function(v) _dm=not not v end, OnToggle=nil }
    settingsTab.Functions.NewModule({
        Name = "Debug Mode",
        Description = "Bật debug output",
        Icon = "rbxassetid://11293977610",
        Flag = "settings.debugMode",
        Default = _dm,
        Callback = function(self, state)
            _dm = not not state
            SetConfig("settings.debugMode", _dm); SaveConfig()
            local api = ToggleAPI[debugModeToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _dm) end
        end,
    })
end)

pcall(function()
    local _dc = GetConfig("settings.debugConfig", false)
    debugConfigToggle = {}
    ToggleAPI[debugConfigToggle] = { Get=function() return _dc end, Set=function(v) _dc=not not v end, OnToggle=nil }
    settingsTab.Functions.NewModule({
        Name = "Debug Config",
        Description = "Debug hệ thống config",
        Icon = "rbxassetid://11293977610",
        Flag = "settings.debugConfig",
        Default = _dc,
        Callback = function(self, state)
            _dc = not not state
            SetConfig("settings.debugConfig", _dc); SaveConfig()
            local api = ToggleAPI[debugConfigToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _dc) end
        end,
    })
end)

pcall(function()
    local _au = GetConfig("settings.autoScaleUI", false)
    autoScaleUIToggle = {}
    ToggleAPI[autoScaleUIToggle] = { Get=function() return _au end, Set=function(v) _au=not not v end, OnToggle=nil }
    settingsTab.Functions.NewModule({
        Name = "Auto-Scale UI",
        Description = "Tự động scale UI theo màn hình",
        Icon = "rbxassetid://11293977610",
        Flag = "settings.autoScaleUI",
        Default = _au,
        Callback = function(self, state)
            _au = not not state
            SetConfig("settings.autoScaleUI", _au); SaveConfig()
            local api = ToggleAPI[autoScaleUIToggle]
            if api and type(api.OnToggle)=="function" then pcall(api.OnToggle, _au) end
        end,
    })
end)

end -- if settingsTab

local customizationTab = nil
pcall(function()
    customizationTab = AppleHubLib.Dashboard.NewTab({
        Name = "Customize",
        Icon = "rbxassetid://11293977610",
        TabInfo = "Themes và tuỳ chỉnh",
        Dashboard = AH_dashboard,
    })
end)

local themeDropDownList, deviceSpoodDropDownList

if customizationTab then
pcall(function()
    local THEMES = {"Your Desire","Gilded Crown","Blue Hour","Verdant Pulse","Crimson Dusk","Slate Steel"}
    local _savedTheme = GetConfig("settings.theme", "Your Desire")
    local _themeIdx = 1
    for i, n in ipairs(THEMES) do if n == _savedTheme then _themeIdx = i; break end end

    themeDropDownList = {}
    DropdownAPI[themeDropDownList] = { Get=function() return _themeIdx end, Set=function(idx) _themeIdx=idx end, OnSelect=nil }

    local themeMod = customizationTab.Functions.NewModule({
        Name = "Theme",
        Description = "Chọn màu theme UI",
        Icon = "rbxassetid://11293977610",
        Flag = "customize.theme",
        Default = false, Button = true,
        Callback = function() end,
    })
    pcall(function()
        themeMod.Functions.Settings.Dropdown({
            Name = "Theme",
            Flag = "settings.theme",
            Options = THEMES,
            Default = _themeIdx,
            Callback = function(self, idx, val)
                _themeIdx = idx
                local themeName = THEMES[idx] or "Your Desire"
                SetConfig("settings.theme", themeName); SaveConfig()
                pcall(ApplyTheme, themeName)
                local api = DropdownAPI[themeDropDownList]
                if api and type(api.OnSelect)=="function" then pcall(api.OnSelect, idx, themeName) end
            end,
        })
    end)
    pcall(ApplyTheme, _savedTheme)
end)

pcall(function()
    local DEVICES = {"PC","Phone","Controller","VR"}
    local _savedDev = GetConfig("customization.deviceSpoof", 1)
    local _devIdx = type(_savedDev)=="number" and _savedDev or 1

    deviceSpoodDropDownList = {}
    DropdownAPI[deviceSpoodDropDownList] = { Get=function() return _devIdx end, Set=function(idx) _devIdx=idx end, OnSelect=nil }

    local devMod = customizationTab.Functions.NewModule({
        Name = "Device Spoof",
        Description = "Giả mạo thiết bị",
        Icon = "rbxassetid://11293977610",
        Flag = "customize.deviceSpoof",
        Default = false, Button = true,
        Callback = function() end,
    })
    pcall(function()
        devMod.Functions.Settings.Dropdown({
            Name = "Device",
            Flag = "customization.deviceSpoof",
            Options = DEVICES,
            Default = _devIdx,
            Callback = function(self, idx, val)
                _devIdx = idx
                SetConfig("customization.deviceSpoof", idx); SaveConfig()
                local api = DropdownAPI[deviceSpoodDropDownList]
                if api and type(api.OnSelect)=="function" then pcall(api.OnSelect, idx, val) end
            end,
        })
    end)
end)

end -- if customizationTab

_G.RivalsCHTUI = {
    root = root,
    Config = { Get=GetConfig, Set=SetConfig, Save=SaveConfig },
    Notification = nil,
    RegisterUnload = nil,
    RunUnload = nil,
}


NotificationAPI = {
    _permissions = {},
    Filter = function(inv) return GetConfig("settings.enableNotifications", true) end,
}

function NotificationAPI.CanCreate(invoker)
    if invoker == nil then
        if type(NotificationAPI.Filter) == "function" then
            local res = NotificationAPI.Filter(invoker)
            if res ~= nil then return not not res end
        end
        return true
    end
    local key = tostring(invoker)
    if NotificationAPI._permissions[key] ~= nil then
        return not not NotificationAPI._permissions[key]
    end
    if type(NotificationAPI.Filter) == "function" then
        local res = NotificationAPI.Filter(invoker)
        if res ~= nil then return not not res end
    end
    return true
end

function NotificationAPI.SetPermission(invokerKey, allowed)
    NotificationAPI._permissions[tostring(invokerKey)] = not not allowed
end

function NotificationAPI.RegisterFilter(fn)
    if type(fn) == "function" then NotificationAPI.Filter = fn end
end

pcall(function() _G.RivalsCHTUI.Notification = NotificationAPI end)
pcall(function() _G.RivalsCHT_Notification = NotificationAPI end)

local UnloadHandlers = {}

local function RegisterUnload(fn)
    if type(fn) == "function" then
        table.insert(UnloadHandlers, fn)
    end
end

local function RunUnload()
    for _, fn in ipairs(UnloadHandlers) do
        pcall(fn)
    end
    pcall(SaveConfig)
    pcall(function()
        if gui and gui.Parent then gui:Destroy() end
    end)
    pcall(function()
        local Players = game:GetService("Players")
        local CoreGui = game:GetService("CoreGui")
        pcall(function()
            if gui and gui.Parent then gui:Destroy() end
        end)
        pcall(function()
            local notifRoot = CoreGui:FindFirstChild("Rivals_Notifications")
            if notifRoot then notifRoot:Destroy() end
            local lp = Players.LocalPlayer
            if lp then
                local pg = lp:FindFirstChild("PlayerGui")
                if pg then
                    local pgNotif = pg:FindFirstChild("Rivals_Notifications")
                    if pgNotif then pgNotif:Destroy() end
                end
            end
        end)
    end)
end

_G.RivalsCHTUI.RegisterUnload = RegisterUnload
_G.RivalsCHTUI.RunUnload = RunUnload

do
    local CoreGui = game:GetService("CoreGui")
    local markersRoot = CoreGui:FindFirstChild("CommonUtils")
    if not markersRoot then
        markersRoot = Instance.new("Folder")
        markersRoot.Name = "CommonUtils"
        markersRoot.Archivable = false
        markersRoot.Parent = CoreGui
    end

    local myId = tostring(tick()) .. "-" .. tostring(math.random(1,999999))
    local myMarker = Instance.new("StringValue")
    myMarker.Name = "Instance_" .. myId
    myMarker.Value = myId
    myMarker.Parent = markersRoot
    myMarker:SetAttribute("OwnerId", myId)
    myMarker:SetAttribute("StartedAt", tick())

    local attrConn = nil
    if myMarker.GetAttributeChangedSignal then
        attrConn = myMarker:GetAttributeChangedSignal("Unload"):Connect(function()
            local v = myMarker:GetAttribute("Unload")
            if v then
                pcall(RunUnload)
            end
        end)
    end

    for _, child in ipairs(markersRoot:GetChildren()) do
        if child ~= myMarker then
            pcall(function()
                if child.SetAttribute then child:SetAttribute("Unload", true) end
            end)
            pcall(function() if child and child.Parent then child:Destroy() end end)
        end
    end

    RegisterUnload(function()
        pcall(function() if attrConn and attrConn.Disconnect then attrConn:Disconnect() end end)
        pcall(function() if myMarker and myMarker.Parent then myMarker:Destroy() end end)
    end)

    pcall(function() _G.RivalsCHTUI.Unload = RunUnload end)
end



local WeaponDefs = {

    Assault_Rifle = {
        "AKEY-47",
        "AUG",
        "Gingerbread AUG",
        "Tommy Gun",
        "AK-47",
        "Boneclaw Rifle",
        "Glorious Assault Rifle",
        "Phoenix Rifle",
        "10B Visits"
    },

    Shotgun = {
        "Balloon Shotgun",
        "Hyper Shotgun",
        "Cactus Shotgun",
        "Shotkey",
        "Broomstick",
        "Wrapped Shotgun",
        "Glorious Shotgun"
    },

    Minigun = {
        "Lasergun 3000",
        "Pixel Minigun",
        "Fighter Jet",
        "Pumpkin Minigun",
        "Wrapped Minigun"
    },

    RPG = {
        "Nuke Launcher",
        "Spaceship Launcher",
        "Squid Launcher",
        "Pencil Launcher"
    },

    Paintball_Gun = {
        "Slime Gun",
        "Boba Gun",
        "Ketchup Gun"
    },

    Grenade_Launcher = {
        "Swashbuckler",
        "Uranium Launcher",
        "Gearnade Launcher"
    },

    Flamethrower = {
        "Pixel Flamethrower",
        "Lamethrower",
        "Glitterthrower"
    },

    Bow = {
        "Compound Bow",
        "Raven Bow",
        "Dream Bow",
        "Key"
    },

    Crossbow = {
        "Pixel Crossbow",
        "Harpoon Crossbow",
        "Violin Crossbow",
        "Crossbone",
        "Frostbite Crossbow"
    },

    Gunblade = {
        "Hyper Gunblade",
        "Crude Gunblade",
        "Gunsaw",
        "Elf's Gunblade",
        "Boneblade",
        "Glorious Gunblade"
    },

    Burst_Rifle = {
        "Electro Burst",
        "Aqua Burst",
        "FAMAS",
        "Spectral Burst",
        "Pine Burst",
        "Key Rifle"
    },

    Energy_Rifle = {
        "Hacker Rifle",
        "Hydro Rifle",
        "Void Rifle",
        "2025 Energy Rifle"
    },

    Distortion = {
        "Plasma Distortion",
        "Magma Distortion",
        "Cyber Distortion"
    },

    Permafrost = {
        "Ice Permafrost"
    },


    Subspace_Tripmine = {
        "Don't Press",
        "Dev-In-The-Box",
        "Spring",
        "Trick Or Treat",
        "DIY Tripmine",
        "Glorious Subspace Tripmine"
    },


    Riot_Shield = {
    "Door",
    "Sled",
    "Tombstone Shield",
    "Energy Shield",
    "Masterpiece",
    "Glorious Riot Shield"
    },
    
    Knife = {
    "Keyrambit",
    "Keylisong",
    "Karambit",
    "Balisong",
    "Candy Cane",
    "Machete",
    "Chancla",
    "Glorious Knife",
    "Armature Knife"
},


Spray = {
        "Bottle Spray",
        "Boneclaw Spray",
        "Nail Gun",
        "Lovely Spray",
        "Pine Spray",
        "Glorious Spray"
    },

}





do
    local chams = {} 
    local charConns = {}
    local playerAddedConn, playerRemovingConn

    local function createHighlightForCharacter(char)
        if not char or not char:IsA("Model") then return nil end
        local ok, h = pcall(function()
            local inst = Instance.new("Highlight")
            inst.Name = "Rivals_PlayerChams"
            inst.Adornee = char
            local fillColor = COLORS.accent
            do
                local coltbl = GetConfig("visuals.playerChamsColor", nil)
                if type(coltbl) == "table" and coltbl.r and coltbl.g and coltbl.b then
                    fillColor = Color3.new(coltbl.r, coltbl.g, coltbl.b)
                end
            end
            inst.FillColor = fillColor
            inst.OutlineColor = COLORS.panelDark
            inst.Parent = gui
            return inst
        end)
        if ok then return h end
        return nil
    end

    local function removeChamsFromPlayer(p)
        if charConns[p] then
            pcall(function() charConns[p]:Disconnect() end)
            charConns[p] = nil
        end
        if chams[p] then
            pcall(function() chams[p]:Destroy() end)
            chams[p] = nil
        end
    end

    local function addChamsToPlayer(p)
        if not p or p == Players.LocalPlayer then return end
        removeChamsFromPlayer(p)
        local char = p.Character
        if char then
            chams[p] = createHighlightForCharacter(char)
        end
        charConns[p] = p.CharacterAdded:Connect(function(c)
            pcall(function()
                if chams[p] then chams[p]:Destroy() end
                chams[p] = createHighlightForCharacter(c)
            end)
        end)
    end

    local function enableChams()
        for _, p in ipairs(Players:GetPlayers()) do
            pcall(function() addChamsToPlayer(p) end)
        end
        playerAddedConn = Players.PlayerAdded:Connect(function(p) pcall(function() addChamsToPlayer(p) end) end)
        playerRemovingConn = Players.PlayerRemoving:Connect(function(p) pcall(function() removeChamsFromPlayer(p) end) end)
    end

    local function disableChams()
        if playerAddedConn then playerAddedConn:Disconnect() playerAddedConn = nil end
        if playerRemovingConn then playerRemovingConn:Disconnect() playerRemovingConn = nil end
        for p, conn in pairs(charConns) do
            pcall(function() conn:Disconnect() end)
            charConns[p] = nil
        end
        for p, h in pairs(chams) do
            pcall(function() if h and h.Destroy then h:Destroy() end end)
            chams[p] = nil
        end
    end

    local api = ToggleAPI[playerChamsToggle]
    if api then
        local prev = api.OnToggle
        api.OnToggle = function(state)
            if prev then pcall(prev, state) end
            if state then
                pcall(enableChams)
            else
                pcall(disableChams)
            end
        end
        pcall(function() if api.Get and api.Get() then enableChams() end end)
    end

    RegisterUnload(function()
        pcall(disableChams)
    end)
end




do
    local initTbl = GetConfig("visuals.playerChamsColor", nil)
    local initColor = (type(initTbl) == "table" and initTbl.r and initTbl.g and initTbl.b) and Color3.new(initTbl.r, initTbl.g, initTbl.b) or COLORS.accent
    local api = ColorPickerAPI[playerChamsColorPicker]
    if api then
        api.OnChange = function(c)
            SetConfig("visuals.playerChamsColor", { r = c.R, g = c.G, b = c.B })
            pcall(function()
                for _, inst in ipairs(gui:GetChildren()) do
                    if inst:IsA("Highlight") then
                        if inst.Name == "Rivals_PlayerChams" then
                            inst.FillColor = c
                        elseif inst.Name == "Rivals_GlowChams" then
                            inst.FillColor = c
                            inst.OutlineColor = c
                        end
                    end
                end
                for _, p in ipairs(Players:GetPlayers()) do
                    local ch = p.Character
                    if ch then
                        for _, d in ipairs(ch:GetDescendants()) do
                            if d:IsA("PointLight") and d.Name == "Rivals_GlowLight" then
                                d.Color = c
                            end
                        end
                    end
                end
            end)
        end
        pcall(function() api.Set(initColor) end)
    end
end




do
    if typeof(Drawing) == "table" and Drawing.new then
        local boxes = {}
        local renderConn, playerAddedConn, playerRemovingConn
        local charConns = {}
        local colorApi = nil
        local colorApiPrev = nil

        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local localPlayer = Players.LocalPlayer

        local MAX_CREATE_DISTANCE = 300 
        local PAD = 8

        local function getBoxColor()
            local okE, eApi = pcall(function() return ColorPickerAPI[espBoxesColorPicker] end)
            if okE and eApi and eApi.Get then
                local c = eApi.Get()
                if typeof(c) == "Color3" then return c end
            end
            local tbl = GetConfig("visuals.espBoxesColor", nil)
            if type(tbl) == "table" and tbl.r and tbl.g and tbl.b then
                return Color3.new(tbl.r, tbl.g, tbl.b)
            end
            local ok, api = pcall(function() return ColorPickerAPI[playerChamsColorPicker] end)
            if ok and api and api.Get then
                local c = api.Get()
                if typeof(c) == "Color3" then return c end
            end
            return COLORS.accent
        end

        local function makeBoxForPlayer(p)
            if boxes[p] then return boxes[p] end
            local ok, box = pcall(function() return Drawing.new("Square") end)
            if not ok or not box then return nil end
            box.Visible = false
            box.Filled = false
            box.Thickness = 2
            box.Color = getBoxColor()
            boxes[p] = box
            return box
        end

        local function removeBoxForPlayer(p)
            if boxes[p] then
                pcall(function() boxes[p]:Remove() end)
                boxes[p] = nil
            end
        end

        local function projectWorldPointsToScreen(cam, points)
            local minX, minY = math.huge, math.huge
            local maxX, maxY = -math.huge, -math.huge
            local anyOnScreen = false
            for _, worldPos in ipairs(points) do
                local ok, sx, sy, sz
                ok, sx, sy, sz = pcall(function() 
                    local xv = cam:WorldToViewportPoint(worldPos)
                    return xv.X, xv.Y, xv.Z
                end)
                if ok and sz and sz > 0 then
                    anyOnScreen = true
                    minX = math.min(minX, sx)
                    maxX = math.max(maxX, sx)
                    minY = math.min(minY, sy)
                    maxY = math.max(maxY, sy)
                end
            end
            return anyOnScreen and minX or nil, anyOnScreen and minY or nil, anyOnScreen and maxX or nil, anyOnScreen and maxY or nil
        end

        local function getImportantParts(ch)
            local parts = {}
            local function tryGet(name)
                local p = ch:FindFirstChild(name)
                if p and p:IsA("BasePart") then table.insert(parts, p) end
            end
            tryGet("HumanoidRootPart")
            tryGet("Head")
            tryGet("UpperTorso")
            tryGet("LowerTorso")
            return parts
        end

        local function updateBoxes()
            local cam = workspace.CurrentCamera
            if not cam then return end
            local color = getBoxColor()
            local camPos = cam.CFrame.Position

            for _, p in ipairs(Players:GetPlayers()) do
                if p == localPlayer then continue end
                local ch = p and p.Character
                if not ch or not ch.Parent then
                    removeBoxForPlayer(p)
                else
                    local root = ch.PrimaryPart or ch:FindFirstChild("HumanoidRootPart")
                    if not root then
                        removeBoxForPlayer(p)
                    else
                        local dist = (root.Position - camPos).Magnitude
                        if dist > MAX_CREATE_DISTANCE then
                            removeBoxForPlayer(p)
                        else
                            local box = boxes[p] or makeBoxForPlayer(p)
                            if not box then
                            else
                                local minX, minY, maxX, maxY
                                local ok, bboxCFrame, bboxSize = pcall(function() return ch:GetBoundingBox() end)
                                if ok and bboxCFrame and bboxSize then
                                    local hx, hy, hz = bboxSize.X / 2, bboxSize.Y / 2, bboxSize.Z / 2
                                    local corners = {
                                        bboxCFrame * CFrame.new(-hx, -hy, -hz),
                                        bboxCFrame * CFrame.new(-hx, -hy,  hz),
                                        bboxCFrame * CFrame.new(-hx,  hy, -hz),
                                        bboxCFrame * CFrame.new(-hx,  hy,  hz),
                                        bboxCFrame * CFrame.new( hx, -hy, -hz),
                                        bboxCFrame * CFrame.new( hx, -hy,  hz),
                                        bboxCFrame * CFrame.new( hx,  hy, -hz),
                                        bboxCFrame * CFrame.new( hx,  hy,  hz),
                                    }
                                    local points = {}
                                    for _, cf in ipairs(corners) do table.insert(points, cf.Position) end
                                    minX, minY, maxX, maxY = projectWorldPointsToScreen(cam, points)
                                else
                                    local parts = getImportantParts(ch)
                                    local points = {}
                                    for _, part in ipairs(parts) do table.insert(points, part.Position) end
                                    minX, minY, maxX, maxY = projectWorldPointsToScreen(cam, points)
                                end

                                if not minX then
                                    box.Visible = false
                                else
                                    local x = minX - PAD
                                    local y = minY - PAD
                                    local w = math.max(4, maxX - minX + PAD * 2)
                                    local h = math.max(4, maxY - minY + PAD * 2)
                                    box.Position = Vector2.new(x, y)
                                    box.Size = Vector2.new(w, h)
                                    box.Color = color
                                    box.Visible = true
                                end
                            end
                        end
                    end
                end
            end
        end

        local function enableBoxes()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= localPlayer then
                    if charConns[p] then pcall(function() charConns[p]:Disconnect() end) end
                    charConns[p] = p.CharacterAdded:Connect(function()
                        pcall(function() end) 
                    end)
                end
            end
            playerAddedConn = Players.PlayerAdded:Connect(function(p)
                if p ~= localPlayer then
                    if charConns[p] then pcall(function() charConns[p]:Disconnect() end) end
                    charConns[p] = p.CharacterAdded:Connect(function()
                        pcall(function() end)
                    end)
                end
            end)
            playerRemovingConn = Players.PlayerRemoving:Connect(function(p)
                if charConns[p] then pcall(function() charConns[p]:Disconnect() end) charConns[p] = nil end
                removeBoxForPlayer(p)
            end)
            pcall(function()
                colorApi = ColorPickerAPI[espBoxesColorPicker] or ColorPickerAPI[playerChamsColorPicker]
                if colorApi then
                    colorApiPrev = colorApi.OnChange
                    colorApi.OnChange = function(c)
                        if colorApiPrev then pcall(colorApiPrev, c) end
                        for _, b in pairs(boxes) do pcall(function() b.Color = c end) end
                    end
                end
            end)
            if not renderConn then renderConn = RunService.RenderStepped:Connect(updateBoxes) end
        end

        local function disableBoxes()
            if renderConn then pcall(function() renderConn:Disconnect() end) renderConn = nil end
            if playerAddedConn then pcall(function() playerAddedConn:Disconnect() end) playerAddedConn = nil end
            if playerRemovingConn then pcall(function() playerRemovingConn:Disconnect() end) playerRemovingConn = nil end
            for p,_ in pairs(charConns) do pcall(function() charConns[p]:Disconnect() end) charConns[p] = nil end
            for p,_ in pairs(boxes) do removeBoxForPlayer(p) end
            pcall(function()
                if colorApi and colorApi.OnChange then
                    colorApi.OnChange = colorApiPrev
                end
                colorApi = nil
                colorApiPrev = nil
            end)
        end

        local api = ToggleAPI[espBoxesToggle]
        if api then
            local prev = api.OnToggle
            api.OnToggle = function(state)
                if prev then pcall(prev, state) end
                if state then pcall(enableBoxes) else pcall(disableBoxes) end
            end
            pcall(function() if api.Get and api.Get() then enableBoxes() end end)
        end

        RegisterUnload(function()
            pcall(disableBoxes)
        end)
    end
end





do
    local glow = {}
    local glowConns = {}
    local playerAddedConn, playerRemovingConn

    local function getSavedColor()
        local coltbl = GetConfig("visuals.playerChamsColor", nil)
        if type(coltbl) == "table" and coltbl.r and coltbl.g and coltbl.b then
            return Color3.new(coltbl.r, coltbl.g, coltbl.b)
        end
        return COLORS.accent
    end

    local function applyGlowToCharacter(char, intensity)
        if not char or not char:IsA("Model") then return nil end
        local ok, h = pcall(function()
            local inst = Instance.new("Highlight")
            inst.Name = "Rivals_GlowChams"
            inst.Adornee = char
            inst.FillColor = getSavedColor()
            inst.OutlineColor = getSavedColor()
            inst.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            inst.Parent = gui
            local t = math.clamp(1 - (intensity or 50) / 100, 0, 1)
            inst.FillTransparency = t * 0.6 
            inst.OutlineTransparency = t * 0.35 
            local lights = {}
            local function makeLight(part, scale)
                if not part or not part:IsA("BasePart") then return nil end
                local pl = Instance.new("PointLight")
                pl.Name = "Rivals_GlowLight"
                pl.Color = inst.FillColor
                local rng = 6 + (intensity or 50) / 100 * (24 * (scale or 1)) 
                local bri = 1 + (intensity or 50) / 100 * (4 * (scale or 1))   
                pl.Range = rng
                pl.Brightness = bri
                pl.Shadows = false
                pl.Parent = part
                return pl
            end
            local head = char:FindFirstChild("Head")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if head and head:IsA("BasePart") then table.insert(lights, makeLight(head, 1.0)) end
            if hrp and hrp:IsA("BasePart") then table.insert(lights, makeLight(hrp, 0.7)) end
            if #lights == 0 then
                for _,part in ipairs(char:GetChildren()) do
                    if part:IsA("BasePart") then table.insert(lights, makeLight(part, 0.5)); break end
                end
            end
            return {hl = inst, lights = lights}
        end)
        if ok then return h end
        return nil
    end

    local function removeGlowFromPlayer(p)
        if glowConns[p] then
            pcall(function() glowConns[p]:Disconnect() end)
            glowConns[p] = nil
        end
        if glow[p] then
            pcall(function()
                local data = glow[p]
                if data.hl and data.hl.Destroy then data.hl:Destroy() end
                if data.lights and type(data.lights) == "table" then
                    for _,l in ipairs(data.lights) do
                        if l and l.Destroy then pcall(function() l:Destroy() end) end
                    end
                end
            end)
            glow[p] = nil
        end
    end

    local function addGlowToPlayer(p, intensity)
        if not p or p == player then return end
        removeGlowFromPlayer(p)
        if p.Character then
            glow[p] = applyGlowToCharacter(p.Character, intensity)
        end
        glowConns[p] = p.CharacterAdded:Connect(function(c)
            pcall(function() removeGlowFromPlayer(p) end)
            pcall(function() glow[p] = applyGlowToCharacter(c, intensity) end)
        end)
    end

    local function enableGlow()
        disableGlow = disableGlow 
        local intensity = GetConfig("visuals.glowChamsIntensity", 50)
        playerAddedConn = Players.PlayerAdded:Connect(function(p) addGlowToPlayer(p, intensity) end)
        playerRemovingConn = Players.PlayerRemoving:Connect(function(p) removeGlowFromPlayer(p) end)
        for _,p in ipairs(Players:GetPlayers()) do
            addGlowToPlayer(p, intensity)
        end
    end

    local function disableGlow()
        if playerAddedConn then pcall(function() playerAddedConn:Disconnect() end) playerAddedConn = nil end
        if playerRemovingConn then pcall(function() playerRemovingConn:Disconnect() end) playerRemovingConn = nil end
        for p,_ in pairs(glowConns) do
            pcall(function() glowConns[p]:Disconnect() end)
            glowConns[p] = nil
        end
        for p,data in pairs(glow) do
            pcall(function()
                if data and type(data) == "table" then
                    if data.hl and data.hl.Destroy then pcall(function() data.hl:Destroy() end) end
                    if data.lights and type(data.lights) == "table" then
                        for _,l in ipairs(data.lights) do if l and l.Destroy then pcall(function() l:Destroy() end) end end
                    end
                end
            end)
            glow[p] = nil
        end
    end

    local initialIntensity = GetConfig("visuals.glowChamsIntensity", 50)
    local sliderApi = SliderAPI[glowIntensitySlider]
    if sliderApi then
        sliderApi.OnChange = function(v)
            SetConfig("visuals.glowChamsIntensity", v)
            pcall(function()
                for _,data in pairs(glow) do
                            if data and type(data) == "table" then
                                local t = math.clamp(1 - v / 100, 0, 1)
                                if data.hl and data.hl.IsA and data.hl:IsA("Highlight") then
                                    data.hl.FillTransparency = t * 0.6
                                    data.hl.OutlineTransparency = t * 0.35
                                end
                                if data.lights and type(data.lights) == "table" then
                                    for _,l in ipairs(data.lights) do
                                        if l and l.IsA and l:IsA("PointLight") then
                                            l.Range = 6 + v / 100 * 24
                                            l.Brightness = 1 + v / 100 * 4
                                        end
                                    end
                                end
                            end
                        end
            end)
        end
        pcall(function() sliderApi.Set(initialIntensity) end)
    end

    BindToggleToConfig(glowChamsToggle, "visuals.glowChams", false)
    do
        local api = ToggleAPI[glowChamsToggle]
        if api then
            local prev = api.OnToggle
            api.OnToggle = function(state)
                if prev then pcall(prev, state) end
                if state then pcall(enableGlow) else pcall(disableGlow) end
            end
            pcall(function() if api.Get and api.Get() then enableGlow() end end)
        end
    end

    RegisterUnload(function()
        pcall(disableGlow)
    end)
end



            do
                local KEY_CONFIG = "settings.closeOpenGuiKey"
                local keyApi = KeybindAPI[closeOpenGuiKeybind]

                pcall(function()
                    local saved = GetConfig(KEY_CONFIG, "Insert")
                    if keyApi and type(saved) == "string" and Enum.KeyCode[saved] then
                        pcall(function() keyApi.Set(Enum.KeyCode[saved]) end)
                    end
                end)

                if keyApi then
                    keyApi.OnBind = function(k)
                        local name = nil
                        if typeof(k) == "EnumItem" then
                            name = k.Name
                        elseif type(k) == "string" then
                            name = tostring(k)
                        end
                        if name then SetConfig(KEY_CONFIG, name) end
                    end
                end

                local keyConn
                keyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if gameProcessed then return end
                    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                    local bound = GetConfig(KEY_CONFIG, "Insert")
                    if not bound then return end
                    local target = Enum.KeyCode[bound]
                    if not target then return end
                    if input.KeyCode == target then
                        pcall(function()
                            if root and root.Parent then
                                root.Visible = not root.Visible
                            end
                        end)
                    end
                end)

                RegisterUnload(function()
                    if keyConn and keyConn.Disconnect then
                        pcall(function() keyConn:Disconnect() end)
                        keyConn = nil
                    end
                end)
            end






do
    local KEY = "settings.showGuiOnLoad"
    local api = ToggleAPI[showGuiOnLoadToggle]

    pcall(function()
        local show = GetConfig(KEY, true)
        if root and root.Parent then root.Visible = not not show end
    end)

    if api then
        local prev = api.OnToggle
        api.OnToggle = function(state)
            if prev then pcall(prev, state) end
            pcall(function() if root and root.Parent then root.Visible = not not state end end)
        end
        pcall(function() if api.Get and api.Get() then root.Visible = true else root.Visible = false end end)
    end
end




do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local healthOverlays = {}
    local charConns = {}
    local humConns = {}

    local HEALTH_BASE_W, HEALTH_BASE_H = 140, 12  
    local MAX_CREATE_DISTANCE = 350
    local HEALTH_BAR_MIN_WIDTH = 60
    local HEALTH_BAR_MAX_WIDTH = 140

    local KEY_CONFIG = "settings.showHealthKey"

    local function safeDisconnect(c)
        if c and c.Disconnect then
            pcall(function() c:Disconnect() end)
        end
    end

    local function createHealthBar(p)
        if healthOverlays[p] then return healthOverlays[p] end
        
        local bg = Drawing.new("Square")
        local fill = Drawing.new("Square")
        local text = Drawing.new("Text")
        
        bg.Filled = true
        bg.Thickness = 1
        bg.Color = Color3.fromRGB(30, 30, 30)
        bg.ZIndex = 1
        bg.Visible = false
        
        fill.Filled = true
        fill.Thickness = 0
        fill.Color = Color3.fromRGB(0, 200, 80)
        fill.ZIndex = 2
        fill.Visible = false
        
        text.Center = true
        text.Outline = true
        text.Font = 2
        text.Size = 14  
        text.Color = Color3.new(1, 1, 1)
        text.ZIndex = 3
        text.Visible = false
        
        healthOverlays[p] = {
            bg = bg,
            fill = fill,
            text = text
        }
        
        return healthOverlays[p]
    end

    local function removeHealthBar(p)
        local data = healthOverlays[p]
        if not data then return end
        
        if data.bg then data.bg:Remove() end
        if data.fill then data.fill:Remove() end
        if data.text then data.text:Remove() end
        
        healthOverlays[p] = nil
    end

    local function updateHealthBar(p, data, cam, refPos)
        if not p.Character then 
            data.bg.Visible = false
            data.fill.Visible = false
            data.text.Visible = false
            return 
        end
        
        local root = p.Character.PrimaryPart or p.Character:FindFirstChild("HumanoidRootPart")
        if not root then 
            data.bg.Visible = false
            data.fill.Visible = false
            data.text.Visible = false
            return 
        end
        
        local dist = (root.Position - refPos).Magnitude
        if dist > MAX_CREATE_DISTANCE then
            data.bg.Visible = false
            data.fill.Visible = false
            data.text.Visible = false
            return
        end
        
        local ok, bboxCFrame, bboxSize = pcall(function() 
            return p.Character:GetBoundingBox() 
        end)
        
        if not ok then 
            data.bg.Visible = false
            data.fill.Visible = false
            data.text.Visible = false
            return 
        end
        
        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge
        
        local hx, hy, hz = bboxSize.X / 2, bboxSize.Y / 2, bboxSize.Z / 2
        local corners = {
            bboxCFrame * CFrame.new(-hx, -hy, -hz),
            bboxCFrame * CFrame.new(-hx, -hy,  hz),
            bboxCFrame * CFrame.new(-hx,  hy, -hz),
            bboxCFrame * CFrame.new(-hx,  hy,  hz),
            bboxCFrame * CFrame.new( hx, -hy, -hz),
            bboxCFrame * CFrame.new( hx, -hy,  hz),
            bboxCFrame * CFrame.new( hx,  hy, -hz),
            bboxCFrame * CFrame.new( hx,  hy,  hz),
        }
        
        local anyVisible = false
        for _, cf in ipairs(corners) do
            local screen = cam:WorldToViewportPoint(cf.Position)
            if screen.Z > 0 then
                anyVisible = true
                minX = math.min(minX, screen.X)
                maxX = math.max(maxX, screen.X)
                minY = math.min(minY, screen.Y)
                maxY = math.max(maxY, screen.Y)
            end
        end
        
        if not anyVisible then
            data.bg.Visible = false
            data.fill.Visible = false
            data.text.Visible = false
            return
        end
        
        local espWidth = maxX - minX
        
        local scaleFactor = math.clamp(1 - (dist / MAX_CREATE_DISTANCE) * 0.5, 0.3, 1.0)
        local healthBarWidth = math.clamp(espWidth * 0.8 * scaleFactor, HEALTH_BAR_MIN_WIDTH, HEALTH_BAR_MAX_WIDTH)
        local healthBarHeight = 10  
        
        local centerX = (minX + maxX) / 2
        local yPos = minY - healthBarHeight - 8
        
        local hum = p.Character:FindFirstChildOfClass("Humanoid")
        local pct = hum and math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1) or 0
        
        data.bg.Size = Vector2.new(healthBarWidth, healthBarHeight)
        data.bg.Position = Vector2.new(centerX - healthBarWidth/2, yPos)
        data.bg.Visible = true
        
        local fillWidth = math.max(2, healthBarWidth * pct)
        data.fill.Size = Vector2.new(fillWidth, healthBarHeight)
        data.fill.Position = Vector2.new(centerX - healthBarWidth/2, yPos)
        data.fill.Visible = true
        
        local hp = math.floor((hum and hum.Health) or 0)
        local max = math.floor((hum and hum.MaxHealth) or 0)
        data.text.Text = string.format("%d/%d", hp, max)
        data.text.Position = Vector2.new(centerX, yPos + healthBarHeight/2 - 1)

        local textSize = math.clamp(math.floor(healthBarWidth / 6), 12, 16)  
        data.text.Size = textSize
        data.text.Visible = true
    end

    local renderConn
    local function onRender()
        local cam = workspace.CurrentCamera
        if not cam then return end
        
        local refPos = cam.CFrame.Position
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player == Players.LocalPlayer then continue end
            
            local data = healthOverlays[player]
            
            if not data then
                data = createHealthBar(player)
            end
            
            if data then
                updateHealthBar(player, data, cam, refPos)
            end
        end
    end

    local function addPlayer(p)
        if p == Players.LocalPlayer then return end
        
        charConns[p] = p.CharacterAdded:Connect(function()
            createHealthBar(p)
        end)
        
        humConns[p] = nil
        
        if p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                humConns[p] = hum.HealthChanged:Connect(function()
                end)
            end
        end
        
        local charAddedConn
        charAddedConn = p.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                humConns[p] = hum.HealthChanged:Connect(function()
                end)
            end
        end)
        
        if charConns[p] ~= charAddedConn then
            table.insert(charConns, charAddedConn)
        end
    end

    local function removePlayer(p)
        safeDisconnect(charConns[p])
        charConns[p] = nil
        
        safeDisconnect(humConns[p])
        humConns[p] = nil
        
        removeHealthBar(p)
    end

    local playerAddedConn, playerRemovingConn
    local function enableHealth()
        for _, p in ipairs(Players:GetPlayers()) do
            addPlayer(p)
        end
        
        playerAddedConn = Players.PlayerAdded:Connect(addPlayer)
        playerRemovingConn = Players.PlayerRemoving:Connect(removePlayer)
        
        if not renderConn then
            renderConn = RunService.RenderStepped:Connect(onRender)
        end
    end

    local function disableHealth()
        if renderConn then
            renderConn:Disconnect()
            renderConn = nil
        end
        
        if playerAddedConn then
            playerAddedConn:Disconnect()
            playerAddedConn = nil
        end
        
        if playerRemovingConn then
            playerRemovingConn:Disconnect()
            playerRemovingConn = nil
        end
        
        for p, _ in pairs(charConns) do
            safeDisconnect(charConns[p])
        end
        charConns = {}
        
        for p, _ in pairs(humConns) do
            safeDisconnect(humConns[p])
        end
        humConns = {}
        
        for p, _ in pairs(healthOverlays) do
            removeHealthBar(p)
        end
        healthOverlays = {}
    end

    local api = ToggleAPI[playerHealthToggle]
    if api then
        local prev = api.OnToggle
        api.OnToggle = function(state)
            if prev then pcall(prev, state) end
            if state then enableHealth() else disableHealth() end
        end
        if api.Get and api.Get() then
            enableHealth()
        end
    end

    local keyApi = KeybindAPI[showHealthKeybind]
    if keyApi then
        local saved = GetConfig(KEY_CONFIG, "P")
        if type(saved) == "string" and Enum.KeyCode[saved] then
            keyApi.Set(Enum.KeyCode[saved])
        end
        
        keyApi.OnBind = function(k)
            local name = k.Name or tostring(k)
            SetConfig(KEY_CONFIG, name)
        end
    end

    local keyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        
        local bound = GetConfig(KEY_CONFIG, "P")
        local target = bound and Enum.KeyCode[bound]
        if target and input.KeyCode == target then
            local tapi = ToggleAPI[playerHealthToggle]
            if tapi and tapi.Get and tapi.Set then
                tapi.Set(not tapi.Get())
            end
        end
    end)

    RegisterUnload(function()
        if keyConn then keyConn:Disconnect() end
        disableHealth()
    end)
end




do
    local KEY_CONFIG = "combat.enableAimbotKey"
    local fovMax = GetConfig("combat.aimbotFOV", 700) or 700
    local leftDown, rightDown = false, false
    local loopConn, inputConnBegin, inputConnEnd, fovDrawConn

    local smoothingEnabled = false
    local smoothingValue = GetConfig("combat.aimbotSmoothing", 1) or 1
    local aimAccumX, aimAccumY = 0, 0
    local teamCheckEnabled = GetConfig("combat.teamCheck", true) or true
    local targetZone = GetConfig("combat.aimbotTargetZone", nil) or (initialZone or 1500)
    local useTargetZone = GetConfig("combat.aimbotTargetZoneEnabled", false) or false
    local teammateCache = {}
    local aimHistory = {} 
    local projSpeedLocal = (type(projSpeed) == "number" and projSpeed) or 900
    local leadScaleLocal = (type(leadScale) == "number" and leadScale) or 1
    local aimPredictionEnabled = GetConfig("combat.aimPrediction", false) or false

    local t = ToggleAPI[aimbotToggle]
    if t then
        local p = t.OnToggle
        t.OnToggle = function(s)
            if type(p) == "function" then p(s) end
            makeNotification(s and "Aimbot is ON" or "Aimbot is OFF", 3, nil, "AimbotToggle")
        end
    end

    _G.RivalsCHT_TeamCheck = _G.RivalsCHT_TeamCheck or {}
    do
        local teamApi = _G.RivalsCHT_TeamCheck
        teamApi.GetCache = function() return teammateCache end

        local function resolvePlayer(playerOrName)
            if not playerOrName then return nil end
            local Players = game:GetService("Players")
            if type(playerOrName) == "string" then
                return Players:FindFirstChild(playerOrName)
            end
            return playerOrName
        end

        teamApi.IsTeammate = function(playerOrName)
            local pl = resolvePlayer(playerOrName)
            if not pl then return false end
            local entry = teammateCache[pl]
            if entry and entry.isTeam ~= nil then return entry.isTeam end

            local ok, isTeam = pcall(function()
                local Players = game:GetService("Players")
                local localTeam = Players.LocalPlayer and Players.LocalPlayer:GetAttribute("TeamID")
                local teamId = pl:GetAttribute("TeamID")
                if localTeam ~= nil and teamId ~= nil then
                    local res = (tostring(localTeam) == tostring(teamId))
                    teammateCache[pl] = { teamId = teamId, isTeam = res }
                    return res
                end
                if Players.LocalPlayer and Players.LocalPlayer.Team and pl.Team then
                    local res = (Players.LocalPlayer.Team == pl.Team)
                    teammateCache[pl] = { teamId = teamId, isTeam = res }
                    return res
                end
                teammateCache[pl] = { teamId = teamId, isTeam = false }
                return false
            end)
            return ok and isTeam or false
        end

        teamApi.IsEnemy = function(playerOrName)
            local pl = resolvePlayer(playerOrName)
            if not pl then return false end
            local ok, isTeam = pcall(teamApi.IsTeammate, pl)
            if ok and type(isTeam) == "boolean" then return not isTeam end
            local Players = game:GetService("Players")
            local lp = Players.LocalPlayer
            if lp and lp.Team and pl.Team then
                return lp.Team ~= pl.Team
            end
            return false
        end

        teamApi.GetTeammates = function()
            local Players = game:GetService("Players")
            local t = {}
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= Players.LocalPlayer and teamApi.IsTeammate(pl) then table.insert(t, pl) end
            end
            return t
        end

        teamApi.Invalidate = function(playerOrName)
            if not playerOrName then
                for k in pairs(teammateCache) do teammateCache[k] = nil end
                return
            end
            local pl = resolvePlayer(playerOrName)
            if pl then teammateCache[pl] = nil end
        end
    end

    do
        local Players = game:GetService("Players")
        local attrConns = {}
        local function onPlayerAttrChanged(pl)
            teammateCache[pl] = nil
        end
        Players.PlayerAdded:Connect(function(pl)
            if pl ~= Players.LocalPlayer then
                local ok, conn = pcall(function() return pl:GetAttributeChangedSignal("TeamID"):Connect(function() onPlayerAttrChanged(pl) end) end)
                if ok and conn then attrConns[pl] = conn end
            end
        end)
        Players.PlayerRemoving:Connect(function(pl)
            teammateCache[pl] = nil
            local c = attrConns[pl]
            if c and c.Disconnect then pcall(function() c:Disconnect() end) end
            attrConns[pl] = nil
        end)
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= Players.LocalPlayer then
                local ok, conn = pcall(function() return pl:GetAttributeChangedSignal("TeamID"):Connect(function() onPlayerAttrChanged(pl) end) end)
                if ok and conn then attrConns[pl] = conn end
            end
        end
    end

    if GetConfig("combat.aimbotSmoothing", nil) == nil then SetConfig("combat.aimbotSmoothing", smoothingValue) end
    if GetConfig("combat.aimbotFOV", nil) == nil then SetConfig("combat.aimbotFOV", fovMax) end
    if GetConfig("combat.useAimbotSmoothing", nil) == nil then SetConfig("combat.useAimbotSmoothing", smoothingEnabled) end

    local function safeDisconnect(c)
        if c and c.Disconnect then pcall(function() c:Disconnect() end) end
    end

    local keyApi = KeybindAPI[enableAimbotKeybind]
    pcall(function()
        local saved = GetConfig(KEY_CONFIG, "V")
        if keyApi and type(saved) == "string" and Enum.KeyCode[saved] then pcall(function() keyApi.Set(Enum.KeyCode[saved]) end) end
    end)
    if keyApi then
        keyApi.OnBind = function(k)
            local name = nil
            if typeof(k) == "EnumItem" then name = k.Name elseif type(k) == "string" then name = tostring(k) end
            if name then SetConfig(KEY_CONFIG, name) end
        end
    end

    do
        local tApi = ToggleAPI[useAimbotSmoothingToggle]
        local sApi = SliderAPI[smoothingSlider]
        if tApi then
            smoothingEnabled = tApi.Get and tApi.Get() or false
            local prev = tApi.OnToggle
            tApi.OnToggle = function(state)
                if prev then pcall(prev, state) end
                smoothingEnabled = not not state
                SetConfig("combat.useAimbotSmoothing", smoothingEnabled)
                pcall(function() if debugDelayLabel then debugDelayLabel.Show(debugModeEnabled and not smoothingEnabled) end end)
            end
        end
        if sApi then
            smoothingValue = sApi.Get and sApi.Get() or smoothingValue
            sApi.OnChange = function(v)
                smoothingValue = tonumber(v) or smoothingValue
                SetConfig("combat.aimbotSmoothing", smoothingValue)
            end
            pcall(function() sApi.Set(smoothingValue) end)
            pcall(function() if debugDelayLabel then debugDelayLabel.Show(debugModeEnabled and not smoothingEnabled) end end)
        end
    end

    do
        local tApi = ToggleAPI[teamCheckToggle]
        if tApi then
            teamCheckEnabled = tApi.Get and tApi.Get() or teamCheckEnabled
            local prev = tApi.OnToggle
            tApi.OnToggle = function(state)
                if prev then pcall(prev, state) end
                teamCheckEnabled = not not state
                SetConfig("combat.teamCheck", teamCheckEnabled)
                pcall(function()
                    for k in pairs(teammateCache) do teammateCache[k] = nil end
                end)
            end
        end
    end

    do
        local tApi = ToggleAPI[aimPredictionToggle]
        if tApi then
            aimPredictionEnabled = tApi.Get and tApi.Get() or aimPredictionEnabled
            local prev = tApi.OnToggle
            tApi.OnToggle = function(state)
                if prev then pcall(prev, state) end
                aimPredictionEnabled = not not state
                SetConfig("combat.aimPrediction", aimPredictionEnabled)
            end
        end
    end

    do
        local fApi = SliderAPI[aimbotFOVSlider]
        if fApi then
            fovMax = fApi.Get and fApi.Get() or fovMax
            fApi.OnChange = function(v)
                fovMax = tonumber(v) or fovMax
                SetConfig("combat.aimbotFOV", fovMax)
            end
            pcall(function() fApi.Set(fovMax) end)
        end
    end

    do
        local tzApi = SliderAPI[aimbotTargetZoneSlider]
        if tzApi then
            targetZone = tzApi.Get and tonumber(tzApi.Get()) or targetZone
            tzApi.OnChange = function(v)
                targetZone = tonumber(v) or targetZone
                SetConfig("combat.aimbotTargetZone", targetZone)
            end
            pcall(function() tzApi.Set(targetZone) end)
        end
    end

    do
        local tApi = ToggleAPI[aimnbotTargetZoneToggle]
        if tApi then
            useTargetZone = tApi.Get and tApi.Get() or useTargetZone
            local prev = tApi.OnToggle
            tApi.OnToggle = function(s)
                if prev then pcall(prev, s) end
                useTargetZone = not not s
                SetConfig("combat.aimbotTargetZoneEnabled", useTargetZone)
            end
        end
    end

    local drawCircle = nil
    local drawEnabled = false
    do
        local dApi = ToggleAPI[drawFovCircleToggle]
        if dApi then
            drawEnabled = dApi.Get and dApi.Get() or false
            local prev = dApi.OnToggle
            dApi.OnToggle = function(s)
                if prev then pcall(prev, s) end
                drawEnabled = not not s
                pcall(function()
                    if drawEnabled then
                        if not drawCircle and typeof(Drawing) == "table" and Drawing.new then
                            drawCircle = Drawing.new("Circle")
                            drawCircle.Color = Color3.fromRGB(255,255,255)
                            drawCircle.Thickness = 1
                            drawCircle.Filled = false
                            drawCircle.Visible = true
                        end
                        if not fovDrawConn then
                            fovDrawConn = RunService.RenderStepped:Connect(function()
                                if not drawCircle then return end
                                if not drawEnabled then
                                    pcall(function() drawCircle.Visible = false end)
                                    return
                                end
                                local cam = workspace.CurrentCamera
                                if not cam then pcall(function() drawCircle.Visible = false end); return end
                                local vs = cam.ViewportSize
                                pcall(function()
                                    drawCircle.Position = Vector2.new(vs.X * 0.5, vs.Y * 0.5)
                                    drawCircle.Radius = fovMax
                                    drawCircle.Visible = true
                                end)
                            end)
                        end
                    else
                        if fovDrawConn then pcall(function() fovDrawConn:Disconnect() end) fovDrawConn = nil end
                        if drawCircle and drawCircle.Remove then pcall(function() drawCircle:Remove() end) end
                        drawCircle = nil
                    end
                end)
            end
        end
        pcall(function()
            if drawEnabled and not drawCircle and typeof(Drawing) == "table" and Drawing.new then
                drawCircle = Drawing.new("Circle")
                drawCircle.Color = Color3.fromRGB(255,255,255)
                drawCircle.Thickness = 1
                drawCircle.Filled = false
                drawCircle.Visible = true
                if not fovDrawConn then
                    fovDrawConn = RunService.RenderStepped:Connect(function()
                        if not drawCircle then return end
                        if not drawEnabled then pcall(function() drawCircle.Visible = false end); return end
                        local cam = workspace.CurrentCamera
                        if not cam then pcall(function() drawCircle.Visible = false end); return end
                        local vs = cam.ViewportSize
                        pcall(function()
                            drawCircle.Position = Vector2.new(vs.X * 0.5, vs.Y * 0.5)
                            drawCircle.Radius = fovMax
                            drawCircle.Visible = true
                        end)
                    end)
                end
            end
        end)
    end

    local function findClosestHead()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local vs = cam.ViewportSize
        local cx, cy = vs.X * 0.5, vs.Y * 0.5
        local best, bestDist = nil, math.huge
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl ~= Players.LocalPlayer then
                local ch = pl.Character
                if ch then
                        local okAlive, aliveRes = pcall(function() return _G.RivalsCHT_Aimbot.IsAlive(ch) end)
                        if not okAlive or not aliveRes then continue end
                        local head = ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
                        if head and head.Position then
                        local isTeammate = false
                        if teamCheckEnabled then
                            local hrp = head
                            if hrp and hrp.Name ~= "HumanoidRootPart" then
                                hrp = head.Parent and head.Parent:FindFirstChild("HumanoidRootPart")
                            end
                            if hrp then
                                local cache = teammateCache[pl]
                                if cache and cache.hrp == hrp then
                                    isTeammate = cache.isTeam
                                else
                                    local function findLabelNow()
                                        local ok, found = pcall(function()
                                            local f = hrp:FindFirstChild("TeammateLabel", true)
                                            if f then return f end
                                            if ch then
                                                f = ch:FindFirstChild("TeammateLabel", true)
                                                if f then return f end
                                            end
                                            local wp = workspace:FindFirstChild(pl.Name)
                                            if wp then
                                                f = wp:FindFirstChild("TeammateLabel", true)
                                                if f then return f end
                                            end
                                            return nil
                                        end)
                                        if ok and found then return found end
                                        return nil
                                    end

                                    local lbl = findLabelNow()
                                    if not lbl then
                                        pcall(function()
                                            if task and task.delay then
                                                task.delay(1, function()
                                                    local late = findLabelNow()
                                                    if late then teammateCache[pl] = { hrp = hrp, isTeam = true } end
                                                end)
                                            else
                                                spawn(function() wait(1) local late = findLabelNow() if late then teammateCache[pl] = { hrp = hrp, isTeam = true } end end)
                                            end
                                        end)
                                        isTeammate = false
                                    else
                                        isTeammate = true
                                        teammateCache[pl] = { hrp = hrp, isTeam = true }
                                    end
                                end
                            end
                        end
                        if not isTeammate then
                            local p = cam:WorldToViewportPoint(head.Position)
                            if p.Z > 0 then
                            local occluded = false
                            if not targetBehindWallsEnabled then
                                pcall(function()
                                    local rp = RaycastParams.new()
                                    rp.FilterType = Enum.RaycastFilterType.Blacklist
                                    rp.FilterDescendantsInstances = { ch }
                                    local origin = cam.CFrame.Position
                                    local direction = head.Position - origin
                                    local ray = workspace:Raycast(origin, direction, rp)
                                    if ray and ray.Instance and not ray.Instance:IsDescendantOf(ch) then
                                        occluded = true
                                    end
                                end)
                            end
                            if not occluded then
                                local dx = p.X - cx
                                local dy = p.Y - cy
                                local dist = math.sqrt(dx*dx + dy*dy)
                                local worldDist = nil
                                pcall(function() worldDist = (head.Position - cam.CFrame.Position).Magnitude end)
                                local tz = tonumber(targetZone) or (initialZone or 900)
                                local passesZone = (not useTargetZone) or (worldDist and worldDist <= tz)
                                if dist < bestDist and dist <= fovMax and passesZone then
                                    bestDist = dist
                                    best = head
                                end
                            end
                            end
                        end
                    end
                end
            end
        end
        return best, bestDist
    end

    local debugModeEnabled = GetConfig("settings.debugMode", false) or false
    local debugTrackerLabel, debugDelayLabel = nil, nil
    local aimbotInfoLabel = nil
    do
        debugTrackerLabel = makeDebugLabel("")
        debugDelayLabel = makeDebugLabel("")
        aimbotInfoLabel = makeDebugLabel("")
        local tApi = ToggleAPI[debugModeToggle]
        if tApi then
            debugModeEnabled = tApi.Get and tApi.Get() or debugModeEnabled
            local prev = tApi.OnToggle
            tApi.OnToggle = function(s)
                if prev then pcall(prev, s) end
                debugModeEnabled = not not s
                if debugTrackerLabel then debugTrackerLabel.Show(debugModeEnabled) end
                if debugDelayLabel then debugDelayLabel.Show(debugModeEnabled and not smoothingEnabled) end
                if aimbotInfoLabel then aimbotInfoLabel.Show(debugModeEnabled) end
            end
        end
        if debugTrackerLabel then debugTrackerLabel.Show(debugModeEnabled) end
        if debugDelayLabel then debugDelayLabel.Show(debugModeEnabled and not smoothingEnabled) end
        if aimbotInfoLabel then aimbotInfoLabel.Show(debugModeEnabled) end
        RegisterUnload(function()
            if debugTrackerLabel then debugTrackerLabel.Destroy() end
            if debugDelayLabel then debugDelayLabel.Destroy() end
            if aimbotInfoLabel then aimbotInfoLabel.Destroy() end
        end)
    end

    local persistentTarget = nil


    local aimbotInfo_lastTime = 0
    local _aim_lastTime = nil
    local function startLoop()
        if loopConn then return end
        loopConn = RunService.RenderStepped:Connect(function()
            local nowDebug = tick()
            local forceActive = (_G.RivalsCHT_Aimbot and _G.RivalsCHT_Aimbot.ForceActive) or false
            if not leftDown and not forceActive then return end
            local api = ToggleAPI[aimbotToggle]
            local enabled = api and api.Get and api.Get()
            if not enabled and not forceActive then return end
            local cam = workspace.CurrentCamera
            if not cam then return end

            local head = findClosestHead()
            local pApi = ToggleAPI[persistentAimbotToggle]
            local persistentEnabled = pApi and pApi.Get and pApi.Get()
            local now = tick()
            if head and head.Position then
                if persistentEnabled then
                    persistentTarget = { model = head.Parent, player = Players:GetPlayerFromCharacter(head.Parent), lastPos = head.Position, t = now }
                    if type(_G) == "table" and _G.RivalsCHT_Aimbot then _G.RivalsCHT_Aimbot.PersistentTarget = persistentTarget end
                end
            else
                if persistentEnabled and persistentTarget and persistentTarget.model and persistentTarget.model.Parent then
                    local model = persistentTarget.model
                    local reacquire = model:FindFirstChild("Head") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
                    if reacquire and reacquire.Position then
                        head = reacquire
                        persistentTarget.lastPos = reacquire.Position
                        persistentTarget.t = now
                    else
                        local timeout = 3 
                        if persistentTarget.lastPos and (now - (persistentTarget.t or 0) <= timeout) then
                            head = { Position = persistentTarget.lastPos }
                        else
                            persistentTarget = nil
                            if type(_G) == "table" and _G.RivalsCHT_Aimbot then _G.RivalsCHT_Aimbot.PersistentTarget = nil end
                        end
                    end
                end
            end
            if head and head.Position then
                local predicted = head.Position
                local root = head.Parent and (head.Parent:FindFirstChild("HumanoidRootPart") or head.Parent:FindFirstChild("Torso"))
                local now = tick()
                local frameDt = 0
                if _aim_lastTime then frameDt = now - _aim_lastTime end
                _aim_lastTime = now
                local estVel = nil
                if root and root:IsA("BasePart") then
                    estVel = root.Velocity
                end
                local histId = (head.Parent and head.Parent.Name) or tostring(head)
                local prev = aimHistory[histId]
                if (not estVel or (estVel and estVel.Magnitude < 0.001)) and prev and prev.pos and prev.t then
                    local dt = now - prev.t
                    if dt > 0 and dt <= 0.05 then
                        estVel = (head.Position - prev.pos) / dt
                    end
                end
                aimHistory[histId] = { pos = head.Position, t = now }

                if root and root:IsA("BasePart") then
                    local okDist, dist = pcall(function() return (head.Position - cam.CFrame.Position).Magnitude end)
                    local travel = (type(projSpeedLocal) == "number" and projSpeedLocal) or 900
                    if okDist and dist and travel and travel > 0 then
                        local tt = dist / travel
                        if estVel and aimPredictionEnabled then
                            local dir = (head.Position - cam.CFrame.Position)
                            local dirUnit = (dir.Magnitude > 0) and (dir / dir.Magnitude) or Vector3.new(0,0,0)
                            local forwardComp = estVel:Dot(dirUnit)
                            local lateral = estVel - dirUnit * forwardComp
                            local lateralMag = lateral.Magnitude
                            local leadFactor = 1
                            if tt < 0.04 then
                                leadFactor = 0
                            elseif tt < 0.12 then
                                leadFactor = (tt - 0.04) / (0.12 - 0.04)
                            else
                                leadFactor = 1
                            end
                            predicted = predicted + lateral * tt * leadScaleLocal * leadFactor
                        end
                    end
                end

                local okP, p = pcall(function() return cam:WorldToViewportPoint(predicted) end)
                if not okP or not p then p = nil end
                if (leftDown or forceActive) and persistentEnabled and p and p.Z and p.Z <= 0 then
                    local mousePos = UserInputService:GetMouseLocation()
                    local moveX = p.X - mousePos.X
                    local moveY = p.Y - mousePos.Y
                    mousemoverel(moveX, moveY)
                end
                if (leftDown or forceActive) and p and p.Z and p.Z > 0 then
                    local mousePos = UserInputService:GetMouseLocation()
                    local dx = p.X - mousePos.X
                    local dy = p.Y - mousePos.Y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if dist > 0.5 then
                        local fpsScale = 1
                        if frameDt and frameDt > 0 then
                            local raw = 60 * frameDt
                            local scale = math.sqrt(raw)
                            if scale < 0.9 then scale = 0.9 end
                            if scale > 2 then scale = 2 end
                            fpsScale = scale
                        end
                        if smoothingEnabled then
                            local sv = tonumber(smoothingValue) or 1
                            if sv <= 0 then sv = 1 end
                            aimAccumX = aimAccumX + (dx / sv)
                            aimAccumY = aimAccumY + (dy / sv)
                            local toMoveX = 0
                            local toMoveY = 0
                            if aimAccumX >= 1 then
                                toMoveX = math.floor(aimAccumX)
                                aimAccumX = aimAccumX - toMoveX
                            elseif aimAccumX <= -1 then
                                toMoveX = math.ceil(aimAccumX)
                                aimAccumX = aimAccumX - toMoveX
                            end
                            if aimAccumY >= 1 then
                                toMoveY = math.floor(aimAccumY)
                                aimAccumY = aimAccumY - toMoveY
                            elseif aimAccumY <= -1 then
                                toMoveY = math.ceil(aimAccumY)
                                aimAccumY = aimAccumY - toMoveY
                            end
                            if toMoveX ~= 0 or toMoveY ~= 0 then
                                toMoveX = math.clamp(toMoveX * fpsScale, -150, 150)
                                toMoveY = math.clamp(toMoveY * fpsScale, -150, 150)
                                mousemoverel(toMoveX, toMoveY)
                            end
                        else
                            mousemoverel(dx * fpsScale, dy * fpsScale)
                        end
                    end
                    if debugModeEnabled and aimbotInfoLabel and (now - (aimbotInfo_lastTime or 0) >= 0.2) then
                        aimbotInfo_lastTime = now
                        local okInfo, info = pcall(function()
                            local info = "Aimbot: "
                            if head and head.Position then
                                local okWorld, worldDist = pcall(function() return (head.Position - cam.CFrame.Position).Magnitude end)
                                local okP2, vp = pcall(function() return cam:WorldToViewportPoint(head.Position) end)
                                local screenDist = 0
                                if okP2 and vp then
                                    local vs = cam.ViewportSize
                                    local cx, cy = vs.X * 0.5, vs.Y * 0.5
                                    local dx2 = vp.X - cx
                                    local dy2 = vp.Y - cy
                                    screenDist = math.sqrt(dx2*dx2 + dy2*dy2)
                                end
                                local occluded = false
                                pcall(function()
                                    local rp = RaycastParams.new()
                                    rp.FilterType = Enum.RaycastFilterType.Blacklist
                                    rp.FilterDescendantsInstances = { head.Parent }
                                    local origin = cam.CFrame.Position
                                    local direction = head.Position - origin
                                    local ray = workspace:Raycast(origin, direction, rp)
                                    if ray and ray.Instance and not ray.Instance:IsDescendantOf(head.Parent) then occluded = true end
                                end)
                                local isTeam = false
                                pcall(function()
                                    if type(_G) == "table" and _G.RivalsCHT_TeamCheck and type(_G.RivalsCHT_TeamCheck.IsTeammate) == "function" then
                                        local pl = Players:GetPlayerFromCharacter(head.Parent)
                                        isTeam = pl and _G.RivalsCHT_TeamCheck.IsTeammate(pl) or false
                                    end
                                end)
                                local name = (head.Parent and head.Parent.Name) or "model"
                                info = info .. string.format("Target=%s | screen=%.1f | world=%.1f | tz=%.1f | fov=%.1f | useTZ=%s | occluded=%s | team=%s", name, screenDist or 0, (worldDist or 0), (targetZone or 0), (fovMax or 0), (useTargetZone and "Y" or "N"), (occluded and "Y" or "N"), (isTeam and "Y" or "N"))
                            else
                                info = info .. string.format("no target | tz=%.1f | fov=%.1f | useTZ=%s", (targetZone or 0), (fovMax or 0), (useTargetZone and "Y" or "N"))
                            end
                            return info
                        end)
                        if okInfo and info and aimbotInfoLabel then pcall(function() aimbotInfoLabel.Set(info) end) end
                    end
                end
            end
            if drawCircle and drawEnabled then
                pcall(function()
                    local vs = cam.ViewportSize
                    drawCircle.Position = Vector2.new(vs.X * 0.5, vs.Y * 0.5)
                    drawCircle.Radius = fovMax
                    drawCircle.Visible = true
                end)
            elseif drawCircle then
                pcall(function() drawCircle.Visible = false end)
            end
        end)
    end

    local function stopLoop()
        safeDisconnect(loopConn)
        loopConn = nil
    end

    inputConnBegin = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            leftDown = true
            startLoop()
        end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local bound = GetConfig(KEY_CONFIG, "V")
            if bound and Enum.KeyCode[bound] and input.KeyCode == Enum.KeyCode[bound] then
                pcall(function()
                    local t = ToggleAPI[aimbotToggle]
                    if t and t.Get and t.Set then t.Set(not t.Get()) end
                end)
            end
        end
    end)

    inputConnEnd = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            leftDown = false
            persistentTarget = nil
            if not leftDown then stopLoop() end
        end
    end)

    RegisterUnload(function()
        safeDisconnect(inputConnBegin)
        safeDisconnect(inputConnEnd)
        safeDisconnect(loopConn)
        if drawCircle and drawCircle.Remove then pcall(function() drawCircle:Remove() end) end
        if playerRemoveConn and playerRemoveConn.Disconnect then pcall(function() playerRemoveConn:Disconnect() end) end
        for p,_ in pairs(teammateCache) do teammateCache[p] = nil end
        if playerCharConns then
            for p, conn in pairs(playerCharConns) do
                pcall(function() if conn and conn.Disconnect then conn:Disconnect() end end)
                playerCharConns[p] = nil
            end
        end
    end)
    _G.RivalsCHT_Aimbot = _G.RivalsCHT_Aimbot or {}
    _G.RivalsCHT_Aimbot.Start = startLoop
    _G.RivalsCHT_Aimbot.Stop = stopLoop
    _G.RivalsCHT_Aimbot.ForceActive = false
    _G.RivalsCHT_Aimbot.IsEnabled = function()
        local api = ToggleAPI[aimbotToggle]
        return api and api.Get and api.Get()
    end
    _G.RivalsCHT_Aimbot.Trigger = function()
        if persistentTarget and persistentTarget.model then
            if not _G.RivalsCHT_Aimbot.IsAlive(persistentTarget.model) then
                pcall(function() _G.RivalsCHT_Aimbot.ClearPersistentTarget() end)
                return
            end
        end
        _G.RivalsCHT_Aimbot.ForceActive = true
        pcall(function() _G.RivalsCHT_Aimbot.Start() end)
    end
    _G.RivalsCHT_Aimbot.Release = function()
        _G.RivalsCHT_Aimbot.ForceActive = false
        pcall(function() _G.RivalsCHT_Aimbot.Stop() end)
    end
    _G.RivalsCHT_Aimbot.GetPersistentTarget = function()
        return persistentTarget
    end
    _G.RivalsCHT_Aimbot.HasPersistentTarget = function()
        return persistentTarget ~= nil
    end
    _G.RivalsCHT_Aimbot.SetPersistentTarget = function(model)
        if not model then return end
        if not _G.RivalsCHT_Aimbot.IsAlive(model) then return end
        persistentTarget = { model = model, player = Players:GetPlayerFromCharacter(model), lastPos = (model:FindFirstChild("Head") and model:FindFirstChild("Head").Position) or (model.PrimaryPart and model.PrimaryPart.Position), t = tick() }
        if type(_G) == "table" and _G.RivalsCHT_Aimbot then _G.RivalsCHT_Aimbot.PersistentTarget = persistentTarget end
    end

    _G.RivalsCHT_Aimbot.IsAlive = function(target)
        local Players = game:GetService("Players")
        local ok, hum
        if type(target) == "string" then
            local pl = Players:FindFirstChild(target)
            if not pl or not pl.Character then return false end
            ok, hum = pcall(function() return pl.Character:FindFirstChildOfClass("Humanoid") end)
        elseif typeof(target) == "Instance" then
            if target:IsA("Player") or target:IsA("PlayerInstance") then
                local pl = target
                if pl.Character then ok, hum = pcall(function() return pl.Character:FindFirstChildOfClass("Humanoid") end) end
            elseif target:IsA("Model") then
                ok, hum = pcall(function() return target:FindFirstChildOfClass("Humanoid") end)
            else
                return false
            end
        elseif type(target) == "table" and target.model then
            ok, hum = pcall(function() return target.model:FindFirstChildOfClass("Humanoid") end)
        else
            return false
        end
        if not ok then return false end
        if not hum then return false end
        if hum.Health == nil then return true end
        return (hum.Health > 0)
    end
    _G.RivalsCHT_Aimbot.ClearPersistentTarget = function()
        persistentTarget = nil
        if type(_G) == "table" and _G.RivalsCHT_Aimbot then _G.RivalsCHT_Aimbot.PersistentTarget = nil end
    end
    _G.RivalsCHT_AimAssist = _G.RivalsCHT_AimAssist or {}
    _G.RivalsCHT_AimAssist.IsHeadInFOV = function(target)
        local headPos = nil
        local headInst = nil
        local Players = game:GetService("Players")
        if type(target) == "string" then
            local pl = Players:FindFirstChild(target)
            if pl and pl.Character then
                headInst = pl.Character:FindFirstChild("Head") or pl.Character:FindFirstChild("UpperTorso") or pl.Character:FindFirstChild("HumanoidRootPart")
                if headInst and headInst.Position then headPos = headInst.Position end
            end
        elseif typeof(target) == "Instance" then
            if target:IsA("Model") then
                headInst = target:FindFirstChild("Head") or target:FindFirstChild("UpperTorso") or target:FindFirstChild("HumanoidRootPart")
                if headInst and headInst.Position then headPos = headInst.Position end
            elseif target:IsA("BasePart") then
                headInst = target
                headPos = target.Position
            end
        elseif typeof(target) == "Vector3" then
            headPos = target
        end

        local cam = workspace.CurrentCamera
        if not cam or not headPos then return false, nil, nil, headInst end

        local p = cam:WorldToViewportPoint(headPos)
        if not p or p.Z <= 0 then return false, nil, nil, headInst end
        local vs = cam.ViewportSize
        local cx, cy = vs.X * 0.5, vs.Y * 0.5
        local dx = p.X - cx
        local dy = p.Y - cy
        local dist = math.sqrt(dx*dx + dy*dy)
        local inFov = (dist <= (fovMax or 0))
        return inFov, dist, Vector2.new(p.X, p.Y), headInst
    end
end





targetBehindWallsEnabled = false
do
    local ok, tApi = pcall(function() return ToggleAPI[targetBehindWallsToggle] end)
    if ok and tApi then
        pcall(function() targetBehindWallsEnabled = tApi.Get and tApi.Get() or false end)
        local prev = tApi.OnToggle
        tApi.OnToggle = function(state)
            if prev then pcall(prev, state) end
            targetBehindWallsEnabled = not not state
        end
    end
end





do
    local KEY_CONFIG = "combat.aimLockKey"
    local targetKey = Enum.KeyCode.Q

    local function updateTargetKey()
        local saved = GetConfig(KEY_CONFIG, "Q")
        targetKey = (type(saved) == "string" and Enum.KeyCode[saved]) or Enum.KeyCode.Q
    end

    updateTargetKey()

    pcall(function()
        local api = KeybindAPI[aimLockKeybind]
        if api then
            local prevOnBind = api.OnBind
            api.OnBind = function(k)
                if prevOnBind then prevOnBind(k) end
                updateTargetKey()
            end
        end
    end)

    local aimLockDown = false
    local kbBegan, kbEnded

    kbBegan = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode == targetKey then
            aimLockDown = true
            if _G.RivalsCHT_Aimbot then _G.RivalsCHT_Aimbot.ForceActive = true; _G.RivalsCHT_Aimbot.Start() end
        end
    end)

    kbEnded = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode == targetKey then
            aimLockDown = false
            if _G.RivalsCHT_Aimbot then _G.RivalsCHT_Aimbot.ForceActive = false end
            local leftHeld = false
            pcall(function() leftHeld = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end)
            if not leftHeld then if _G.RivalsCHT_Aimbot then _G.RivalsCHT_Aimbot.Stop() end end
        end
    end)

    RegisterUnload(function()
        if kbBegan and kbBegan.Disconnect then pcall(function() kbBegan:Disconnect() end) end
        if kbEnded and kbEnded.Disconnect then pcall(function() kbEnded:Disconnect() end) end
    end)

end







do
    local LocalPlayer = Players.LocalPlayer
    local ViewModels = workspace:FindFirstChild("ViewModels")
    
    if not ViewModels then
        return
    end
    
    local isEnabled = false
    local labels = {}
    local lastUpdate = 0
    local updateInterval = 0.2
    local FirstPersonCache = nil
    local firstPersonCacheTime = 0

    local labelContainer = Instance.new("Frame")
    labelContainer.Name = "EnemyWeaponLabels"
    labelContainer.Size = UDim2.new(0, 200, 0, 140)
    labelContainer.Position = UDim2.new(1, -220, 0, 24)
    labelContainer.AnchorPoint = Vector2.new(0, 0)
    labelContainer.BackgroundColor3 = COLORS.panel
    labelContainer.BackgroundTransparency = 0.04
    labelContainer.Visible = false
    labelContainer.Parent = gui

    local containerCorner = Instance.new("UICorner") containerCorner.CornerRadius = UDim.new(0,6) containerCorner.Parent = labelContainer
    local containerStroke = Instance.new("UIStroke") containerStroke.Color = COLORS.divider containerStroke.Transparency = 0.8 containerStroke.Thickness = 1 containerStroke.Parent = labelContainer

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = labelContainer
    
    local function extractWeaponName(modelName)
        local parts = string.split(modelName, " - ")
        if #parts >= 3 then
            return parts[3]
        elseif #parts >= 2 then
            return parts[2]
        end
        return modelName
    end

    local function normalizeWeaponName(rawName)
        if not rawName or type(rawName) ~= "string" then return rawName end
        local lname = string.lower(rawName)
        for norm, list in pairs(WeaponDefs or {}) do
            if type(list) == "table" then
                for _, alias in ipairs(list) do
                    if type(alias) == "string" and string.lower(alias) == lname then
                        return string.gsub(norm, "_", " ")
                    end
                end
            end
        end
        local key = string.gsub(rawName, " ", "_")
        if WeaponDefs and WeaponDefs[key] then
            return string.gsub(key, "_", " ")
        end
        return rawName
    end
    
    local function extractPlayerName(modelName)
        local parts = string.split(modelName, " - ")
        if #parts >= 1 then
            return parts[1]
        end
        return "Unknown"
    end
    
    local function createWeaponLabel(playerName)
        local label = Instance.new("TextLabel")
        label.Name = "WeaponLabel_" .. playerName
        label.Size = UDim2.new(1, 0, 0, 26)
        label.BackgroundColor3 = COLORS.panelAlt or Color3.fromRGB(18,18,18)
        label.BackgroundTransparency = 0
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 13
        label.TextColor3 = COLORS.text
        label.Text = ""
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.LayoutOrder = #labelContainer:GetChildren()
        label.Visible = false
        label.Parent = labelContainer

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = label

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.Parent = label

        local stroke = Instance.new("UIStroke")
        stroke.Color = COLORS.divider
        stroke.Thickness = 1
        stroke.Transparency = 0.85
        stroke.Parent = label

        return label
    end
    
    local function updateWeaponDisplay()
        if not isEnabled then return end
        
        local currentTime = tick()
        if currentTime - lastUpdate < updateInterval then return end
        lastUpdate = currentTime
        
        local activePlayers = {}
        
        for _, weapon in pairs(ViewModels:GetChildren()) do
            if weapon:IsA("Model") then
                local playerName = extractPlayerName(weapon.Name)
                local weaponName = extractWeaponName(weapon.Name)
                
                if playerName == LocalPlayer.Name then
                    continue
                end
                
                local player = Players:FindFirstChild(playerName)
                if not player then
                    continue
                end

                local isTeammate = false
                if _G and _G.RivalsCHT_TeamCheck and type(_G.RivalsCHT_TeamCheck.IsTeammate) == "function" then
                    pcall(function() isTeammate = _G.RivalsCHT_TeamCheck.IsTeammate(player) end)
                end
                if isTeammate then
                    continue
                end
                
                local displayName = normalizeWeaponName(weaponName)
                activePlayers[playerName] = displayName
                
                if not labels[playerName] then
                    labels[playerName] = createWeaponLabel(playerName)
                end
                
                local label = labels[playerName]
                label.Text = playerName .. " | " .. displayName
                label.Visible = true
            end
        end
        
        for playerName, label in pairs(labels) do
            if not activePlayers[playerName] then
                label.Visible = false
            end
        end
    end
    
    local function enableWeaponDisplay()
        if isEnabled then return end
        
        isEnabled = true
        labelContainer.Visible = true
        
        local updateConnection = RunService.Heartbeat:Connect(updateWeaponDisplay)
        
        _G.RivalsCHTUI.RegisterUnload(function()
            isEnabled = false
            labelContainer.Visible = false
            updateConnection:Disconnect()
            for _, label in pairs(labels) do
                label:Destroy()
            end
            labels = {}
            if labelContainer and labelContainer.Parent then
                labelContainer:Destroy()
            end
        end)
    end
    
    local function disableWeaponDisplay()
        if not isEnabled then return end
        
        isEnabled = false
        labelContainer.Visible = false
        for _, label in pairs(labels) do
            label.Visible = false
        end
    end
    
    local function onToggleChanged(state)
        if state then
            enableWeaponDisplay()
        else
            disableWeaponDisplay()
        end
    end
    
    local initialEnabled = GetConfig("visuals.showEnemyWeapons", false)
    onToggleChanged(initialEnabled)
    
    local toggleAPI = ToggleAPI[showEnemyWeaponsToggle]
    if toggleAPI then
        local prev = toggleAPI.OnToggle
        toggleAPI.OnToggle = function(state)
            if prev then pcall(prev, state) end
            onToggleChanged(state)
        end
    end

    local function GetEnemyHeldWeapon(playerOrName)
        local target = playerOrName
        if type(target) == "string" then target = Players:FindFirstChild(target) end
        if not target or target == LocalPlayer then return nil end
        for _, vm in ipairs(ViewModels:GetChildren()) do
            if vm:IsA("Model") then
                local pn = extractPlayerName(vm.Name)
                if pn == target.Name then
                    local raw = extractWeaponName(vm.Name)
                    local norm = normalizeWeaponName(raw)
                    return norm, raw, vm
                end
            end
        end
        return nil
    end

    local function GetAllEnemyHeldWeapons()
        local out = {}
        for _, vm in ipairs(ViewModels:GetChildren()) do
            if vm:IsA("Model") then
                local pn = extractPlayerName(vm.Name)
                local raw = extractWeaponName(vm.Name)
                out[pn] = { Normalized = normalizeWeaponName(raw), Raw = raw }
            end
        end
        return out
    end

    local function GetLocalPlayerHeldWeapon()
        if not LocalPlayer then return nil end
        local now = tick()
        if not FirstPersonCache or (now - firstPersonCacheTime) > 0.2 then
            FirstPersonCache = ViewModels:FindFirstChild("FirstPerson")
            firstPersonCacheTime = now
        end
        if not FirstPersonCache then return nil end
        for _, child in ipairs(FirstPersonCache:GetChildren()) do
            if child:IsA("Model") then
                local raw = extractWeaponName(child.Name)
                local norm = normalizeWeaponName(raw)
                return norm, raw, child
            end
        end
        return nil
    end

    pcall(function()
        if type(_G) == "table" and _G.RivalsCHTUI then
            _G.RivalsCHTUI.ShowEnemyWeapons = _G.RivalsCHTUI.ShowEnemyWeapons or {}
            _G.RivalsCHTUI.ShowEnemyWeapons.GetEnemyHeldWeapon = GetEnemyHeldWeapon
            _G.RivalsCHTUI.ShowEnemyWeapons.GetAllEnemyHeldWeapons = GetAllEnemyHeldWeapons
            _G.RivalsCHTUI.ShowEnemyWeapons.GetLocalPlayerHeldWeapon = GetLocalPlayerHeldWeapon
        end
    end)
end





do
    local labels = {}
    local labelCount = 0
    local childAddedConn, childRemovedConn, renderConn
    local displayName = ("Subspace_Tripmine"):gsub("_"," ")
    local MAX_LABELS = 50
    local MAX_DIST = 300

    local function isTripminePart(part)
        if not part or not part:IsA("BasePart") then return false end
        local vm = Workspace:FindFirstChild("ViewModels")
        if vm and part:IsDescendantOf(vm) then return false end
        local cam = Workspace.CurrentCamera
        if cam and part:IsDescendantOf(cam) then return false end
        local name = string.lower(part.Name or "")
        if string.find(name, "tripmine") then return true end
        local anc = part:FindFirstAncestorOfClass("Model")
        if anc and string.find(string.lower(anc.Name or ""), "tripmine") then return true end
        return false
    end

    local function makeLabel(part)
        if labels[part] then return end
        if labelCount >= MAX_LABELS then return end
        if localPlayer and localPlayer.Character and part:IsDescendantOf(localPlayer.Character) then return end
        local cam = Workspace.CurrentCamera
        if cam and (part.Position - cam.CFrame.Position).Magnitude > MAX_DIST then return end

        local txt = Drawing.new("Text")
        part:SetAttribute("Rivals_Trap", true)
        part:SetAttribute("Rivals_TrapName", displayName)
        txt.Text = displayName
        txt.Size = 18
        txt.Color = (COLORS and COLORS.accent) or Color3.fromRGB(255,120,120)
        txt.Center = true
        txt.Outline = true
        txt.Visible = false
        labels[part] = txt
        labelCount = labelCount + 1
    end

    local function removeLabel(part)
        local d = labels[part]
        if not d then return end
        if d.Remove then d:Remove() end
        labels[part] = nil
        labelCount = labelCount - 1
        if part.SetAttribute then
            part:SetAttribute("Rivals_Trap", nil)
            part:SetAttribute("Rivals_TrapName", nil)
        end
    end

    local function scanAndCreate()
        local cam = Workspace.CurrentCamera
        local camPos = cam and cam.CFrame.Position or nil
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if labelCount >= MAX_LABELS then break end
            if obj:IsA("BasePart") and isTripminePart(obj) then
                if not (camPos and (obj.Position - camPos).Magnitude > MAX_DIST) then
                    makeLabel(obj)
                end
            end
        end
    end

    local function onDescendantAdded(desc)
        local cam = Workspace.CurrentCamera
        local camPos = cam and cam.CFrame.Position or nil
        if desc:IsA("BasePart") then
            if isTripminePart(desc) and not (camPos and (desc.Position - camPos).Magnitude > MAX_DIST) then makeLabel(desc) end
        else
            for _, d in ipairs(desc:GetDescendants()) do
                if labelCount >= MAX_LABELS then break end
                if d:IsA("BasePart") and isTripminePart(d) and not (camPos and (d.Position - camPos).Magnitude > MAX_DIST) then
                    makeLabel(d)
                end
            end
        end
    end

    local function onDescendantRemoving(desc)
        if desc:IsA("BasePart") then
            removeLabel(desc)
        else
            for _, d in ipairs(desc:GetDescendants()) do
                if d:IsA("BasePart") then removeLabel(d) end
            end
        end
    end

    local function enable()
        if renderConn then return end
        scanAndCreate()
        childAddedConn = Workspace.DescendantAdded:Connect(onDescendantAdded)
        if Workspace.DescendantRemoving then childRemovedConn = Workspace.DescendantRemoving:Connect(onDescendantRemoving) end
        renderConn = RunService.RenderStepped:Connect(function()
            local cam = Workspace.CurrentCamera
            if not cam then
                for _, d in pairs(labels) do d.Visible = false end
                return
            end
            local camPos = cam.CFrame.Position
            for part, draw in pairs(labels) do
                if not part or not part.Parent then
                    removeLabel(part)
                else
                    local p, onScreen = cam:WorldToViewportPoint(part.Position)
                    if not onScreen or p.Z <= 0 or (part.Position - camPos).Magnitude > MAX_DIST then
                        draw.Visible = false
                    else
                        local dist = (part.Position - camPos).Magnitude
                        local ratio = math.clamp(50 / math.max(dist, 1), 0.125, 1)
                        draw.Size = math.floor(math.clamp(math.floor(32 * ratio), 12, 32))
                        draw.Position = Vector2.new(p.X, p.Y)
                        draw.Visible = true
                    end
                end
            end
        end)
    end

    local function disable()
        if renderConn then renderConn:Disconnect() renderConn = nil end
        if childAddedConn then childAddedConn:Disconnect() childAddedConn = nil end
        if childRemovedConn then childRemovedConn:Disconnect() childRemovedConn = nil end
        for p, _ in pairs(labels) do removeLabel(p) end
        labels = {}
        labelCount = 0
    end

    if GetConfig("combat.sixthSense", false) then enable() end

    local api = ToggleAPI and ToggleAPI[sixthSenseToggle]
    if api then
        local prev = api.OnToggle
        api.OnToggle = function(state)
            if prev then prev(state) end
            if state then enable() else disable() end
        end
        api.Set(GetConfig("combat.sixthSense", false))
    end

    if type(_G) == "table" and _G.RivalsCHTUI and type(_G.RivalsCHTUI.RegisterUnload) == "function" then
        _G.RivalsCHTUI.RegisterUnload(disable)
    else
        RegisterUnload(disable)
    end
end


do
    local api = (_G and _G.RivalsCHTUI and _G.RivalsCHTUI.ShowEnemyWeapons) or nil
    local katanaDraw = nil
    local katanaConn = nil
    local katanaExpiry = 0
    local KATANA_DIST = 150
    local KATANA_TIME = 1.4

    local function removeKatanaDraw()
        if katanaDraw and katanaDraw.Remove then
            pcall(function() katanaDraw:Remove() end)
        end
        katanaDraw = nil
    end

    local function showKatanaMessage()
        if typeof(Drawing) ~= "table" or not Drawing.new then return end
        if not katanaDraw then
            katanaDraw = Drawing.new("Text")
            katanaDraw.Text = "Enemy is holding Katana!"
            katanaDraw.Color = (COLORS and COLORS.accent) or Color3.fromRGB(255,80,80)
            katanaDraw.Size = 25
            katanaDraw.Center = true
            katanaDraw.Outline = true
            local cam = Workspace.CurrentCamera
            if cam then
                local vs = cam.ViewportSize
                katanaDraw.Position = Vector2.new(vs.X * 0.5, 48)
            else
                katanaDraw.Position = Vector2.new(400, 48)
            end
        end
        katanaDraw.Visible = true
        katanaExpiry = tick() + KATANA_TIME
    end

    local function checkAndHideKatana()
        if katanaDraw and tick() > katanaExpiry then
            pcall(function() katanaDraw.Visible = false end)
        end
    end

    local function detectKatana()
        if not GetConfig("combat.sixthSense", false) then
            if katanaDraw then pcall(function() katanaDraw.Visible = false end) end
            return
        end

        local lp = Players.LocalPlayer
        local lpchar = lp and lp.Character
        local lpRoot = lpchar and (lpchar.PrimaryPart or lpchar:FindFirstChild("HumanoidRootPart"))
        if not lpRoot then
            checkAndHideKatana()
            return
        end

        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= lp then
                local isTeam = false
                if _G and _G.RivalsCHT_TeamCheck and type(_G.RivalsCHT_TeamCheck.IsTeammate) == "function" then
                    pcall(function() isTeam = _G.RivalsCHT_TeamCheck.IsTeammate(pl) end)
                end
                if isTeam then continue end

                local norm, raw, vm
                if api and type(api.GetEnemyHeldWeapon) == "function" then
                    norm, raw, vm = api.GetEnemyHeldWeapon(pl)
                else
                    for _, m in ipairs((workspace:FindFirstChild("ViewModels") or {}):GetChildren()) do
                        if m:IsA("Model") then
                            local pn = string.split(m.Name, " - ")[1]
                            if pn == pl.Name then
                                raw = (function()
                                    local parts = string.split(m.Name, " - ")
                                    if #parts >= 3 then return parts[3] elseif #parts >= 2 then return parts[2] end
                                    return m.Name
                                end)()
                                norm = raw
                                vm = m
                                break
                            end
                        end
                    end
                end

                if raw and (string.find(string.lower(raw), "katana") or (norm and string.find(string.lower(tostring(norm)), "katana"))) then
                    local ch = pl.Character
                    if ch and ch.Parent then
                        local hrp = ch.PrimaryPart or ch:FindFirstChild("HumanoidRootPart")
                        if hrp and (lpRoot.Position - hrp.Position).Magnitude <= KATANA_DIST then
                            local dir = (lpRoot.Position - hrp.Position)
                            if dir.Magnitude > 0 then
                                local dirUnit = dir.Unit
                                local forward = hrp.CFrame.LookVector
                                local dot = forward:Dot(dirUnit)
                                if dot >= 0.3 then
                                    showKatanaMessage()
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end

        checkAndHideKatana()
    end

    katanaConn = RunService.Heartbeat:Connect(detectKatana)

    local function cleanupKatana()
        if katanaConn and katanaConn.Disconnect then pcall(function() katanaConn:Disconnect() end) end
        removeKatanaDraw()
    end

    if type(_G) == "table" and _G.RivalsCHTUI and type(_G.RivalsCHTUI.RegisterUnload) == "function" then
        _G.RivalsCHTUI.RegisterUnload(cleanupKatana)
    else
        RegisterUnload(cleanupKatana)
    end
end




do
    local MAX_LINES = 8
    local REFRESH_RATE = 1.5 -- seconds
    local collapse = {}
    local buffer = {}
    local lastUpdate = 0
    local visible = false
    local drawBg = nil
    local drawText = nil
    local posConn = nil
    local SHIFT_LEFT = 400
    
    local hbConn

    local function fmt(v)
        if v == nil then return "nil" end
        if type(v) == "boolean" then return (v and "on" or "off") end
        if type(v) == "string" then return v end
        if type(v) == "number" then return tostring(v) end
        if typeof and typeof(v) == "EnumItem" then return v.Name end
        return tostring(v)
    end

    local keys = {}
    local function isPrimitive(val)
        local t = type(val)
        if t == "boolean" or t == "number" or t == "string" then return true end
        if typeof and typeof(val) == "EnumItem" then return true end
        return false
    end

    local function humanize(key)
        local lbl = tostring(key):gsub("[_%./]", " ")
        lbl = lbl:gsub("%s+", " ")
        lbl = lbl:gsub("^%l", string.upper)
        return lbl
    end

    local function flatten(tbl, prefix)
        prefix = prefix or ""
        if type(tbl) ~= "table" then return end
        for k,v in pairs(tbl) do
            local full = (prefix == "") and tostring(k) or (prefix .. "." .. tostring(k))
            if isPrimitive(v) then
                table.insert(keys, { key = full, label = humanize(full), cfg = v })
            elseif type(v) == "table" then
                flatten(v, full)
            end
        end
    end

    flatten(Config)
    MAX_LINES = math.min(32, math.max(8, #keys))

    local function getRuntime(entry)
        local function tryTable(t)
            if type(t) ~= "table" then return nil end
            for _, api in pairs(t) do
                if type(api) == "table" and api.Get and type(api.Get) == "function" then
                    local v = api.Get()
                    if entry.cfg == nil then
                        if v ~= nil then return v end
                    else
                        if type(v) == type(entry.cfg) then return v end
                    end
                end
            end
            return nil
        end

        local v = tryTable(ToggleAPI)
        if v == nil then v = tryTable(SliderAPI) end
        if v == nil then v = tryTable(KeybindAPI) end
        return v
    end

    local function scanConfig()
        local out = {}
        for _, e in ipairs(keys) do
            local cfgv = e.cfg
            if GetConfig then cfgv = GetConfig(e.key, nil) end
            local runtime = getRuntime(e)
            table.insert(out, {label = e.label, key = e.key, cfg = cfgv, runtime = runtime})
        end
        return out
    end

    local function makeUI()
        drawBg = Drawing.new("Square")
        drawBg.Filled = true
        drawBg.Color = COLORS.panel
        drawBg.Transparency = 0.04
        drawBg.Size = Vector2.new(320, 24 + MAX_LINES * 18)
        drawBg.Visible = false
        drawBg.ZIndex = 9998

        drawText = Drawing.new("Text")
        drawText.Size = 14
        drawText.Color = COLORS.text
        drawText.Outline = true
        drawText.Center = false
        drawText.Text = ""
        drawText.Visible = false
        drawText.ZIndex = 9999

        posConn = RunService.RenderStepped:Connect(function()
            local cam = workspace.CurrentCamera
            if cam then
                local vs = cam.ViewportSize
                local margin = 8
                local desiredW = 320
                local availW = math.max(64, vs.X - margin*2)
                local w = math.min(desiredW, availW)
                drawBg.Size = Vector2.new(w, drawBg.Size.Y)
                local x = vs.X - margin - w - SHIFT_LEFT
                local y = margin
                if x < 0 then x = margin end
                drawBg.Position = Vector2.new(x, y)
                drawText.Position = Vector2.new(x + 8, y + 2)
            else
                drawBg.Position = Vector2.new(400, 8)
                drawText.Position = Vector2.new(408, 10)
            end
        end)
    end

    local function push(msg)
        if not msg then return end
        if buffer[#buffer] == msg then
            collapse[msg] = (collapse[msg] or 1) + 1
        else
            table.insert(buffer, msg)
        end
        while #buffer > MAX_LINES do table.remove(buffer, 1) end
    end

    local function buildMessages(list)
        for _, v in ipairs(list) do
            local cfgv = v.cfg
            local runv = v.runtime

            if cfgv == nil and runv == nil then

            elseif cfgv == nil and runv ~= nil then
                push(string.format("%s not present in config; runtime is %s", v.label, fmt(runv)))

            else
                if runv == nil then
                    push(string.format("%s is %s in config, but not present at runtime", v.label, fmt(cfgv)))
                else
                    local same = false
                    if type(cfgv) == type(runv) and cfgv == runv then
                        same = true
                    else
                        if tostring(cfgv) == tostring(runv) then same = true end
                    end

                    if same then
                        push(string.format("%s is %s in config and runtime (ok)", v.label, fmt(cfgv)))
                    else
                        push(string.format("%s is %s in config, but runtime is %s ; config didn't apply", v.label, fmt(cfgv), fmt(runv)))
                    end
                end
            end
        end
    end

    local function render()
        if not drawText then return end
        local lines = {}
        for i, s in ipairs(buffer) do
            local cnt = collapse[s]
            if cnt and cnt > 1 then
                s = string.format("%s  (x%d)", s, cnt)
            end
            table.insert(lines, s)
        end
        local text = (#lines > 0) and table.concat(lines, "\n") or ""
        drawText.Text = text
        drawText.Visible = text ~= ""
        drawBg.Visible = drawText.Visible
    end

    local function refresh()
        local now = tick()
        if now - lastUpdate < REFRESH_RATE then return end
        lastUpdate = now
        collapse = {}
        buffer = {}
        local list = scanConfig()
        buildMessages(list)
        render()
    end

    local function show(b)
        if b and not drawText then makeUI() end
        if drawText then drawText.Visible = b end
        if drawBg then drawBg.Visible = b end
        visible = b
        if b and not hbConn then
            hbConn = RunService.Heartbeat:Connect(function()
                refresh()
            end)
        elseif not b and hbConn then
            hbConn:Disconnect()
            hbConn = nil
        end
    end

    do
        local foundApi = nil
        if ToggleAPI then
            for frame, api in pairs(ToggleAPI) do
                if frame and type(frame) == "userdata" and frame:IsA("Frame") then
                    for _, child in ipairs(frame:GetChildren()) do
                        if child:IsA("TextLabel") and child.Text == "Debug Config" then
                            foundApi = api
                            break
                        end
                    end
                end
                if foundApi then break end
            end
        end

        if foundApi then
            local prev = foundApi.OnToggle
            foundApi.OnToggle = function(state)
                if prev then prev(state) end
                show(not not state)
            end
            if foundApi.Get and foundApi.Get() then show(true) else show(false) end
        else
            if GetConfig and GetConfig("settings.debugConfig", false) then show(true) end
        end
    end

    RegisterUnload(function()
        if hbConn and hbConn.Disconnect then hbConn:Disconnect() end
        if posConn and posConn.Disconnect then posConn:Disconnect() end
        if drawText and drawText.Remove then drawText:Remove() end
        if drawBg and drawBg.Remove then drawBg:Remove() end
    end)
end




do
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")

    local autoConn = nil
    local firing = false
    local lastInFov = 0
    local FOV_MISS_TIMEOUT = 1.5

    local KEY_CONFIG = "combat.enableAutoShootKey"
    local keyConn = nil
    
    local debugLabel = makeDebugLabel("AutoShoot: OFF")
    local lastDebugMsg = nil
    local persistentEngaged = false
    local katanaBlocked = false

    do
        local api = KeybindAPI[aimLockKeybind]
        local saved = GetConfig("combat.aimLockKey", "Q")
        if api and type(saved) == "string" and Enum.KeyCode[saved] then
            api.Set(Enum.KeyCode[saved])
        end
        if api then
            api.OnBind = function(k)
                local name = nil
                if typeof(k) == "EnumItem" then name = k.Name elseif type(k) == "string" then name = tostring(k) end
                if name then SetConfig("combat.aimLockKey", name) end
            end
        end
    end

    do
        local keyApi = KeybindAPI[enableAutoShootKeybind]
        local saved = GetConfig(KEY_CONFIG, "Y")
        pcall(function()
            if keyApi and type(saved) == "string" and Enum.KeyCode[saved] then keyApi.Set(Enum.KeyCode[saved]) end
        end)
        if keyApi then
            keyApi.OnBind = function(k)
                local name = nil
                if typeof(k) == "EnumItem" then name = k.Name elseif type(k) == "string" then name = tostring(k) end
                if name then SetConfig(KEY_CONFIG, name) end
            end
        end
    end

    local function isHeadInFOV(headInst)
        if not headInst or not headInst.Position then return false, nil end
        local cam = workspace.CurrentCamera
        if not cam then return false, nil end
        local p = cam:WorldToViewportPoint(headInst.Position)
        if not p or p.Z <= 0 then return false, nil end
        local vs = cam.ViewportSize
        local cx, cy = vs.X * 0.5, vs.Y * 0.5
        local dx = p.X - cx
        local dy = p.Y - cy
        local dist = math.sqrt(dx*dx + dy*dy)
        local fovRadius = GetConfig("combat.aimbotFOV", 700) or 700
        return (dist <= fovRadius), dist
    end

    local function isHoldingKatana(playerOrNil)
        if not playerOrNil then return false end
        if type(_G) == "table" and _G.RivalsCHTUI and _G.RivalsCHTUI.ShowEnemyWeapons and type(_G.RivalsCHTUI.ShowEnemyWeapons.GetEnemyHeldWeapon) == "function" then
            local ok, norm, raw = pcall(function() return _G.RivalsCHTUI.ShowEnemyWeapons.GetEnemyHeldWeapon(playerOrNil) end)
            if ok and (type(norm) == "string" or type(raw) == "string") then
                local sraw = (type(raw) == "string") and string.lower(raw) or ""
                local snorm = (type(norm) == "string") and string.lower(norm) or ""
                if string.find(sraw, "katana") or string.find(snorm, "katana") then
                    return true
                end
            end
        end

        return false
    end

    local function isHoldingRiotShield(playerOrNil)
        if not playerOrNil or playerOrNil == Players.LocalPlayer then
            if type(_G) == "table" and _G.RivalsCHTUI and _G.RivalsCHTUI.ShowEnemyWeapons and type(_G.RivalsCHTUI.ShowEnemyWeapons.GetLocalPlayerHeldWeapon) == "function" then
                local ok, norm, raw = pcall(function() return _G.RivalsCHTUI.ShowEnemyWeapons.GetLocalPlayerHeldWeapon() end)
                if ok then
                    local sraw = (type(raw) == "string") and string.lower(raw) or ""
                    local snorm = (type(norm) == "string") and string.lower(norm) or ""
                    if string.find(sraw, "riot shield") or string.find(snorm, "riot shield") or string.find(sraw, "shield") or string.find(snorm, "shield") then
                        return true
                    end
                end
            end
        else
            if type(_G) == "table" and _G.RivalsCHTUI and _G.RivalsCHTUI.ShowEnemyWeapons and type(_G.RivalsCHTUI.ShowEnemyWeapons.GetEnemyHeldWeapon) == "function" then
                local ok, norm, raw = pcall(function() return _G.RivalsCHTUI.ShowEnemyWeapons.GetEnemyHeldWeapon(playerOrNil) end)
                if ok then
                    local sraw = (type(raw) == "string") and string.lower(raw) or ""
                    local snorm = (type(norm) == "string") and string.lower(norm) or ""
                    if string.find(sraw, "riot shield") or string.find(snorm, "riot shield") or string.find(sraw, "shield") or string.find(snorm, "shield") then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function isVisibleToCamera(headInst)
        if not headInst or not headInst.Parent then return false end
        local cam = workspace.CurrentCamera
        if not cam then return false end
        
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Blacklist
        rp.FilterDescendantsInstances = {headInst.Parent}
        
        local origin = cam.CFrame.Position
        local direction = headInst.Position - origin
        local ray = workspace:Raycast(origin, direction, rp)
        
        if ray and ray.Instance and not ray.Instance:IsDescendantOf(headInst.Parent) then
            return false
        end
        
        return true
    end

    local function isHoldingSniper()
        if type(_G) == "table" and _G.RivalsCHTUI and _G.RivalsCHTUI.ShowEnemyWeapons and type(_G.RivalsCHTUI.ShowEnemyWeapons.GetLocalPlayerHeldWeapon) == "function" then
            local ok, norm, raw = pcall(function() return _G.RivalsCHTUI.ShowEnemyWeapons.GetLocalPlayerHeldWeapon() end)
            if ok and norm and string.find(string.lower(norm), "sniper") then
                return true
            end
        end
        return false
    end

    local rightClickPressTime = nil
    local rightClickConn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            rightClickPressTime = tick()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            rightClickPressTime = nil
        end
    end)

    local function checkAndFire()
        local autoShootEnabled = GetConfig("combat.autoShoot", false)
        if not autoShootEnabled then 
            if firing then
                mouse1release()
                firing = false
                if _G and _G.RivalsCHT_Aimbot then
                    _G.RivalsCHT_Aimbot.ForceActive = false
                    _G.RivalsCHT_Aimbot.Stop()
                end
            end
            if debugLabel then debugLabel.Set("AutoShoot: OFF (disabled)") end
            return 
        end
        
        local debugMsg = "AutoShoot: Scanning..."
        local found = nil
        local persistentEnabled = GetConfig("combat.persistentAimbot", false)

        if not found then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= Players.LocalPlayer then
                    local isTeam = false
                    if _G and _G.RivalsCHT_TeamCheck and type(_G.RivalsCHT_TeamCheck.IsTeammate) == "function" then
                        isTeam = _G.RivalsCHT_TeamCheck.IsTeammate(pl)
                    end
                    if isTeam then continue end

                    local char = pl.Character
                    if not char then continue end
                    local okAlive, aliveRes = pcall(function() return _G.RivalsCHT_Aimbot.IsAlive(char) end)
                    if not okAlive or not aliveRes then continue end

                    local headInst = char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
                    if not headInst then continue end

                    local inFov, screenDist = isHeadInFOV(headInst)

                    if inFov then
                        debugMsg = "AutoShoot: " .. pl.Name .. " in FOV (dist=" .. tostring(math.floor(screenDist or 0)) .. ")"
                        local isVis = isVisibleToCamera(headInst)
                        if isVis then
                            found = {player = pl, head = headInst}
                            debugMsg = "AutoShoot: TARGET LOCKED - " .. pl.Name
                            break
                        else
                            debugMsg = "AutoShoot: " .. pl.Name .. " blocked by geometry"
                        end
                    end
                end
            end
        end

        if not found then
            local persistentEnabled = GetConfig("combat.persistentAimbot", false)
            if persistentEnabled and _G and _G.RivalsCHT_Aimbot and type(_G.RivalsCHT_Aimbot.GetPersistentTarget) == "function" then
                local pt = _G.RivalsCHT_Aimbot.GetPersistentTarget()
                if pt and pt.model and pt.model.Parent then
                    local headInst = pt.model:FindFirstChild("Head") or pt.model:FindFirstChild("UpperTorso") or pt.model:FindFirstChild("HumanoidRootPart")
                    if headInst and headInst.Position then
                        local pl = pt.player or Players:GetPlayerFromCharacter(pt.model)
                        local isTeam = false
                        if pl and _G and _G.RivalsCHT_TeamCheck and type(_G.RivalsCHT_TeamCheck.IsTeammate) == "function" then
                            isTeam = _G.RivalsCHT_TeamCheck.IsTeammate(pl)
                        end
                        if not isTeam then
                            local isVis = isVisibleToCamera(headInst)
                            if isVis then
                                found = {player = pl, head = headInst}
                                debugMsg = "AutoShoot: PERSISTENT TARGET LOCKED (out of FOV)"
                                if persistentEnabled and _G and _G.RivalsCHT_Aimbot and not persistentEngaged then
                                    persistentEngaged = true
                                    if type(_G.RivalsCHT_Aimbot.SetPersistentTarget) == "function" then
                                        _G.RivalsCHT_Aimbot.SetPersistentTarget(headInst.Parent)
                                    end
                                    if type(_G.RivalsCHT_Aimbot.Trigger) == "function" then
                                        _G.RivalsCHT_Aimbot.Trigger()
                                    end
                                end
                            else
                                if firing then
                                    mouse1release()
                                    firing = false
                                    if _G and _G.RivalsCHT_Aimbot then
                                        _G.RivalsCHT_Aimbot.ForceActive = false
                                        _G.RivalsCHT_Aimbot.Stop()
                                    end
                                end
                                debugMsg = "AutoShoot: Persistent target blocked by geometry"
                            end
                        else
                            debugMsg = "AutoShoot: Persistent target is teammate"
                        end
                    end
                end
            end
        end

        if found then
            lastInFov = tick()
            local localPlayerHasShield = false
            pcall(function() localPlayerHasShield = isHoldingRiotShield(Players.LocalPlayer) end)

            local holdingKat = false
            local holdingShield = false
            pcall(function() holdingKat = isHoldingKatana(found.player) end)
            pcall(function() holdingShield = isHoldingRiotShield(found.player) end)

            local holdingSpray = false
            pcall(function()
                if type(_G) == "table" and _G.RivalsCHTUI and _G.RivalsCHTUI.ShowEnemyWeapons and type(_G.RivalsCHTUI.ShowEnemyWeapons.GetLocalPlayerHeldWeapon) == "function" then
                    local ok, norm, raw = pcall(function() return _G.RivalsCHTUI.ShowEnemyWeapons.GetLocalPlayerHeldWeapon() end)
                    if ok and norm and string.find(string.lower(norm), "spray") then
                        holdingSpray = true
                    end
                end
            end)

            local shouldBlock = (holdingKat or holdingShield or localPlayerHasShield) and not holdingSpray

            if shouldBlock then
                katanaBlocked = true
                local reason = ""
                if localPlayerHasShield then
                    reason = "Local player has Riot Shield"
                elseif holdingShield then
                    reason = "Target has Riot Shield"
                else
                    reason = "Target has Katana"
                end
                debugMsg = "AutoShoot: " .. reason .. " — Aim lock only: " .. (found.player and found.player.Name or "unknown")
                if _G and _G.RivalsCHT_Aimbot then
                    if type(_G.RivalsCHT_Aimbot.SetPersistentTarget) == "function" then
                        pcall(function() _G.RivalsCHT_Aimbot.SetPersistentTarget(found.head.Parent) end)
                        persistentEngaged = true
                    end
                    if type(_G.RivalsCHT_Aimbot.Trigger) == "function" then
                        pcall(_G.RivalsCHT_Aimbot.Trigger)
                    else
                        _G.RivalsCHT_Aimbot.ForceActive = true
                        pcall(function() _G.RivalsCHT_Aimbot.Start() end)
                    end
                end
                if firing then mouse1release(); firing = false end
            else
                katanaBlocked = false
                
                local holdingSniper = false
                pcall(function() holdingSniper = isHoldingSniper() end)
                
                if holdingSniper then
                    if _G and _G.RivalsCHT_Aimbot then
                        if type(_G.RivalsCHT_Aimbot.SetPersistentTarget) == "function" then
                            pcall(function() _G.RivalsCHT_Aimbot.SetPersistentTarget(found.head.Parent) end)
                            persistentEngaged = true
                        end
                        if type(_G.RivalsCHT_Aimbot.Trigger) == "function" then
                            pcall(_G.RivalsCHT_Aimbot.Trigger)
                        else
                            _G.RivalsCHT_Aimbot.ForceActive = true
                            _G.RivalsCHT_Aimbot.Start()
                        end
                    end
                    
                    if rightClickPressTime == nil then
                        debugMsg = "AutoShoot: Sniper - Aimlock active, waiting for right-click on " .. found.player.Name
                        if firing then mouse1release(); firing = false end
                    else
                        local timeSinceClick = tick() - rightClickPressTime
                        if timeSinceClick < 0.2 then
                            debugMsg = "AutoShoot: Sniper - Right-click delay (" .. string.format("%.2f", timeSinceClick) .. "s)"
                            if firing then mouse1release(); firing = false end
                        else
                            if not firing then
                                firing = true
                                debugMsg = "AutoShoot: FIRING (Sniper) at " .. found.player.Name
                                mouse1press()
                            else
                                debugMsg = "AutoShoot: Holding fire (Sniper) on " .. found.player.Name
                            end
                        end
                    end
                else
                    if not firing then
                        firing = true
                        debugMsg = "AutoShoot: FIRING at " .. found.player.Name
                        if _G and _G.RivalsCHT_Aimbot then
                            if type(_G.RivalsCHT_Aimbot.SetPersistentTarget) == "function" then
                                pcall(function() _G.RivalsCHT_Aimbot.SetPersistentTarget(found.head.Parent) end)
                                persistentEngaged = true
                            end
                            if type(_G.RivalsCHT_Aimbot.Trigger) == "function" then
                                pcall(_G.RivalsCHT_Aimbot.Trigger)
                            else
                                _G.RivalsCHT_Aimbot.ForceActive = true
                                _G.RivalsCHT_Aimbot.Start()
                            end
                        end
                        mouse1press()
                    else
                        debugMsg = "AutoShoot: Holding fire on " .. found.player.Name
                        if _G and _G.RivalsCHT_Aimbot then
                            if type(_G.RivalsCHT_Aimbot.SetPersistentTarget) == "function" then
                                pcall(function() _G.RivalsCHT_Aimbot.SetPersistentTarget(found.head.Parent) end)
                                persistentEngaged = true
                            end
                            if type(_G.RivalsCHT_Aimbot.Trigger) == "function" then
                                pcall(_G.RivalsCHT_Aimbot.Trigger)
                            else
                                _G.RivalsCHT_Aimbot.ForceActive = true
                                _G.RivalsCHT_Aimbot.Start()
                            end
                        end
                    end
                end
            end
        else
            if firing then
                mouse1release()
                firing = false
                debugMsg = "AutoShoot: Released fire"
                if _G and _G.RivalsCHT_Aimbot then
                    _G.RivalsCHT_Aimbot.ForceActive = false
                    _G.RivalsCHT_Aimbot.Stop()
                    if type(_G.RivalsCHT_Aimbot.ClearPersistentTarget) == "function" then
                        pcall(_G.RivalsCHT_Aimbot.ClearPersistentTarget)
                    end
                end
                if persistentEngaged then
                    persistentEngaged = false
                end
            else
                debugMsg = "AutoShoot: Waiting for target"
                if _G and _G.RivalsCHT_Aimbot then
                    _G.RivalsCHT_Aimbot.ForceActive = false
                    _G.RivalsCHT_Aimbot.Stop()
                    if type(_G.RivalsCHT_Aimbot.ClearPersistentTarget) == "function" then
                        pcall(_G.RivalsCHT_Aimbot.ClearPersistentTarget)
                    end
                end
                if persistentEngaged then
                    persistentEngaged = false
                end
            end
        
        end
        if debugLabel and debugMsg ~= lastDebugMsg then debugLabel.Set(debugMsg) lastDebugMsg = debugMsg end
    end

    pcall(function()
        keyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local bound = GetConfig(KEY_CONFIG, "Y")
            local target = bound and Enum.KeyCode[bound]
            if target and input.KeyCode == target then
                local currentState = GetConfig("combat.autoShoot", false)
                local newState = not currentState
                SetConfig("combat.autoShoot", newState)
                local api = ToggleAPI[autoShootToggle]
                if api and api.Set then api.Set(newState) end
            end
        end)
    end)

    local api = ToggleAPI[autoShootToggle]
    if api then
        pcall(function()
            if api.Get and api.Get() and not autoConn then autoConn = RunService.Heartbeat:Connect(checkAndFire) end
        end)
        local p = api.OnToggle
        api.OnToggle = function(state)
            if type(p) == "function" then p(state) end
            makeNotification(state and "Auto-Shoot is ON" or "Auto-Shoot is OFF", 3, nil, "AutoShootToggle")
            if state then
                if not autoConn then autoConn = RunService.Heartbeat:Connect(checkAndFire) end
                if debugLabel then debugLabel.Set("AutoShoot: ON") end
            else
                if autoConn then autoConn:Disconnect() autoConn = nil end
                if firing then mouse1release() firing = false end
                if _G and _G.RivalsCHT_Aimbot then
                    _G.RivalsCHT_Aimbot.ForceActive = false
                    pcall(function() _G.RivalsCHT_Aimbot.Stop() end)
                    if type(_G.RivalsCHT_Aimbot.ClearPersistentTarget) == "function" then
                        pcall(_G.RivalsCHT_Aimbot.ClearPersistentTarget)
                    end
                end
                persistentEngaged = false
                if debugLabel then debugLabel.Set("AutoShoot: OFF") end
            end
        end
    end

    RegisterUnload(function()
        if autoConn and autoConn.Disconnect then autoConn:Disconnect() end
        if keyConn and keyConn.Disconnect then keyConn:Disconnect() end
        if firing then mouse1release() end
        if debugLabel and debugLabel.Destroy then debugLabel.Destroy() end
    end)
end




do
    local noclipEnabled = false
    local player = Players.LocalPlayer
    local currentKeybind = Enum.KeyCode.N
    local keybindConn = nil
    local toggleApi = ToggleAPI[noclipToggle]
    local originalCollisionStates = {}
    local charAddedConn = nil
    local noclipLoopConn = nil
    
    local function getBodyParts()
        if not player or not player.Character then return {} end
        local char = player.Character
        local parts = {}
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(parts, part)
            end
        end
        return parts
    end

    local function setNoclip(enabled)
        noclipEnabled = enabled
        
        if enabled then
            originalCollisionStates = {}
            local parts = getBodyParts()
            for _, part in ipairs(parts) do
                if part then
                    originalCollisionStates[part] = part.CanCollide
                    part.CanCollide = false
                end
            end
            
            if not noclipLoopConn then
                noclipLoopConn = RunService.Heartbeat:Connect(function()
                    if not noclipEnabled or not player or not player.Character then return end
                    
                    local parts = getBodyParts()
                    for _, part in ipairs(parts) do
                        if part then
                            if not originalCollisionStates[part] then
                                originalCollisionStates[part] = part.CanCollide
                            end
                            if part.CanCollide then
                                part.CanCollide = false
                            end
                        end
                    end
                end)
            end
        else
            if noclipLoopConn then
                noclipLoopConn:Disconnect()
                noclipLoopConn = nil
            end
            
            for part, originalState in pairs(originalCollisionStates) do
                if part and part.Parent then
                    part.CanCollide = originalState
                end
            end
            originalCollisionStates = {}
        end
        
        makeNotification(enabled and "Noclip is ON" or "Noclip is OFF", 3)
        SetConfig("rage.noclip", enabled)
    end

    if toggleApi then
        toggleApi.OnToggle = function(state) setNoclip(state) end
    end

    local function setupKeybindListener()
        if keybindConn then keybindConn:Disconnect() end
        keybindConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

            local api = KeybindAPI[noclipKeybind]
            local bound = nil
            if api and api.Get and api.Get() then
                bound = api.Get()
            else
                local saved = GetConfig("rage.noclipKeybind", nil)
                if type(saved) == "string" and Enum.KeyCode[saved] then bound = Enum.KeyCode[saved] end
            end

            if bound and input.KeyCode == bound then
                local currentState = GetConfig("rage.noclip", false)
                local newState = not currentState
                SetConfig("rage.noclip", newState)
                if toggleApi and toggleApi.Set then toggleApi.Set(newState) end
            end
        end)
    end

    BindKeybindToConfig(noclipKeybind, "rage.noclipKeybind", Enum.KeyCode.N)

    setupKeybindListener()

    local function onCharacterAdded(char)
        originalCollisionStates = {}
        
        if noclipEnabled then
            for _, part in ipairs(char:GetDescendants()) do
                if part and part:IsA("BasePart") then
                    originalCollisionStates[part] = part.CanCollide
                    part.CanCollide = false
                end
            end
        end
    end
    if player then
        pcall(function()
            charAddedConn = player.CharacterAdded:Connect(onCharacterAdded)
        end)
    end

    do
        local savedState = GetConfig("rage.noclip", false)
        if toggleApi and toggleApi.Set then
            local prev = toggleApi.OnToggle
            toggleApi.OnToggle = nil
            pcall(toggleApi.Set, savedState)
            toggleApi.OnToggle = prev
        end
    end

    RegisterUnload(function()
        setNoclip(false)
        if keybindConn then keybindConn:Disconnect() end
        if charAddedConn then charAddedConn:Disconnect() end
        if noclipLoopConn then noclipLoopConn:Disconnect() end
    end)
end





do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local LocalPlayer = Players.LocalPlayer
    local stickEnabled = false
    local stickConn = nil
    local keybindConn = nil
    local stickTarget = nil
    local respawnConns = {}
    local respawnWatcherActive = false
    local MAX_DISTANCE = 300 -- lower this if u tp to lobby
    local BEHIND_DISTANCE = 6 -- studs behind target

    local function isValidTarget(pl)
        if not pl or pl == LocalPlayer then return false end
        if not pl.Character then return false end
        local pp = pl.Character.PrimaryPart or pl.Character:FindFirstChild("HumanoidRootPart")
        if not pp or not pp.Parent then return false end
        local humanoid = pl.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid or type(humanoid.Health) ~= "number" then return false end
        if humanoid.Health <= 0 then return false end
        return true
    end

    local function isEnemyByTeamCheck(pl)
        if not pl or pl == LocalPlayer then return false end
        
        local isEnemy = true
        if _G and _G.RivalsCHT_TeamCheck then
            if type(_G.RivalsCHT_TeamCheck.IsEnemy) == "function" then
                local ok, res = pcall(_G.RivalsCHT_TeamCheck.IsEnemy, pl)
                isEnemy = ok and not not res
            elseif type(_G.RivalsCHT_TeamCheck.IsTeammate) == "function" then
                local ok, isTeam = pcall(_G.RivalsCHT_TeamCheck.IsTeammate, pl)
                isEnemy = not (ok and isTeam)
            end
        end
        return isEnemy
    end

    local function findStickTarget()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local look = cam.CFrame.LookVector
        local origin = cam.CFrame.Position
        local best, bestDist = nil, math.huge

        for _, pl in ipairs(Players:GetPlayers()) do
            if isValidTarget(pl) and isEnemyByTeamCheck(pl) then
                local pp = pl.Character.PrimaryPart or pl.Character:FindFirstChild("HumanoidRootPart")
                local toTarget = pp.Position - origin
                local dot = look:Dot(toTarget.Unit)
                if dot > 0.65 then
                    local dist = toTarget.Magnitude
                    if dist < MAX_DISTANCE and dist < bestDist then
                        best = pl
                        bestDist = dist
                    end
                end
            end
        end
        return best
    end

    local function stopRespawnWatcher()
        if not respawnWatcherActive then return end
        respawnWatcherActive = false
        for _,c in ipairs(respawnConns) do
            pcall(function() if c and c.Disconnect then c:Disconnect() end end)
        end
        respawnConns = {}
    end

    local function startRespawnWatcher()
        if respawnWatcherActive then return end
        respawnWatcherActive = true
        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local function onChar(char)
                    if not p or p == LocalPlayer then return end
                    if isEnemyByTeamCheck(p) and isValidTarget(p) then
                        stickTarget = p
                        stopRespawnWatcher()
                    end
                end
                if p.Character then onChar(p.Character) end
                if p.CharacterAdded then table.insert(respawnConns, p.CharacterAdded:Connect(onChar)) end
            end
        end
        table.insert(respawnConns, Players.PlayerAdded:Connect(function(p)
            if p == LocalPlayer then return end
            local function onChar(char)
                if isEnemyByTeamCheck(p) and isValidTarget(p) then
                    stickTarget = p
                    stopRespawnWatcher()
                end
            end
            if p.Character then onChar(p.Character) end
            if p.CharacterAdded then table.insert(respawnConns, p.CharacterAdded:Connect(onChar)) end
        end))
    end

    local function isTargetHoldingKnife()
        if not stickTarget then return false end
        
        if type(_G) == "table" and _G.RivalsCHTUI and _G.RivalsCHTUI.ShowEnemyWeapons and type(_G.RivalsCHTUI.ShowEnemyWeapons.GetEnemyHeldWeapon) == "function" then
            local ok, norm, raw = pcall(function() return _G.RivalsCHTUI.ShowEnemyWeapons.GetEnemyHeldWeapon(stickTarget) end)
            if ok and (type(norm) == "string" or type(raw) == "string") then
                local sraw = (type(raw) == "string") and string.lower(raw) or ""
                local snorm = (type(norm) == "string") and string.lower(norm) or ""
                if string.find(sraw, "knife") or string.find(snorm, "knife") then
                    return true
                end
            end
        end
        return false
    end

    local function startStick()
        if stickConn then return end
        local lastSelect = 0
        local lastMove = 0
        local SELECT_INTERVAL = 0.25 -- seconds
        local MOVE_INTERVAL = 0 -- seconds 
        local prevHeartbeat = tick()
        local spinRotation = 0
        local isInKnifeDodgeMode = false
        local SPIN_SPEED = 12 -- radians per heartbeat
        local DODGE_DISTANCE = 15 -- studs away from target
        
        stickConn = RunService.Heartbeat:Connect(function()
            if not stickEnabled then return end
            if not LocalPlayer or not LocalPlayer.Character then return end
            local lpRoot = LocalPlayer.Character.PrimaryPart or LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not lpRoot then return end

            local now = tick()
            local dt = now - prevHeartbeat
            prevHeartbeat = now
            
            if not stickTarget and now - lastSelect >= SELECT_INTERVAL then
                stickTarget = findStickTarget()
                lastSelect = now
            end
            
            if stickTarget and (not isValidTarget(stickTarget) or not isEnemyByTeamCheck(stickTarget)) then
                stickTarget = nil
                isInKnifeDodgeMode = false
                spinRotation = 0
                return 
            end

            if not stickTarget then
                return 
            end

            if now - lastMove >= MOVE_INTERVAL then
                lastMove = now
                local tp = stickTarget.Character.PrimaryPart or stickTarget.Character:FindFirstChild("HumanoidRootPart")
                if tp and tp.Position then
                    local isHoldingKnife = isTargetHoldingKnife()

                    local backPos
                    if isHoldingKnife then
                        isInKnifeDodgeMode = true
                        spinRotation = spinRotation + SPIN_SPEED
                        
                        local pushDir = (lpRoot.Position - tp.Position).Unit
                        if pushDir.Magnitude == 0 then
                            pushDir = Vector3.new(1, 0, 0)
                        end
                        
                        backPos = tp.Position + (pushDir * DODGE_DISTANCE) + Vector3.new(0, 6.4, 0)
                    else
                        isInKnifeDodgeMode = false
                        spinRotation = 0
                        local targetPos = tp.Position + Vector3.new(0, 6.4, 0) 
                        backPos = targetPos - (tp.CFrame.LookVector.Unit * BEHIND_DISTANCE)
                    end
                    
                    local dest = CFrame.new(backPos, tp.Position)
                    
                    if isInKnifeDodgeMode then
                        dest = dest * CFrame.Angles(0, spinRotation, 0)
                    end
                    
                    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
                        local useSmoothing = false
                        local sToggleApi = ToggleAPI and ToggleAPI[useStickSmoothingToggle]
                        if sToggleApi and sToggleApi.Get then
                            useSmoothing = not not sToggleApi.Get()
                        else
                            useSmoothing = GetConfig("rage.useStickSmoothing", false)
                        end
                        if useSmoothing then
                            local intensity = nil
                            local sApi = SliderAPI and SliderAPI[smoothStickingSlider]
                            if sApi and sApi.Get then
                                intensity = sApi.Get()
                            else
                                intensity = GetConfig("rage.smoothStickingIntensity", 20)
                            end
                            if type(intensity) ~= "number" then intensity = 20 end
                            local alpha = math.clamp(intensity / 100, 0, 1)
                            local lerpAlpha = math.clamp(alpha * (dt * 8), 0, 1)
                            LocalPlayer.Character:SetPrimaryPartCFrame(LocalPlayer.Character.PrimaryPart.CFrame:Lerp(dest, lerpAlpha))
                        else
                            LocalPlayer.Character:SetPrimaryPartCFrame(dest)
                        end
                    end
                end
            end
        end)
    end

    local function stopStick()
        if stickConn then
            if stickConn.Disconnect then stickConn:Disconnect() end
            stickConn = nil
        end
        stickTarget = nil
        stopRespawnWatcher()
    end

    do
        local api = ToggleAPI and ToggleAPI[stickToToggle]
        if api then
            local prev = api.OnToggle
            api.OnToggle = function(state)
                if prev then prev(state) end
                stickEnabled = not not state
                if stickEnabled then
                    startStick()
                    makeNotification("Stick to Target is ON", 3)
                else
                    stopStick()
                    makeNotification("Stick to Target is OFF", 3)
                end
            end
            if api.Set then
                local prevOn = api.OnToggle
                api.OnToggle = nil
                pcall(api.Set, GetConfig("rage.stickToTarget", false))
                api.OnToggle = prevOn
            end
        end
    end

    do
        if keybindConn and keybindConn.Disconnect then keybindConn:Disconnect() end
        keybindConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

            local api = KeybindAPI and KeybindAPI[stickToKeybind]
            local bound = nil
            if api and api.Get and api.Get() then
                bound = api.Get()
            else
                local saved = GetConfig("rage.stickToTargetKeybind", nil)
                if type(saved) == "string" and Enum.KeyCode[saved] then bound = Enum.KeyCode[saved] end
            end

            if bound and input.KeyCode == bound then
                local current = GetConfig("rage.stickToTarget", false)
                local newState = not current
                SetConfig("rage.stickToTarget", newState)
                local api = ToggleAPI and ToggleAPI[stickToToggle]
                if api and api.Set then api.Set(newState) end
            end
        end)
    end

    RegisterUnload(function()
        stopStick()
        if keybindConn and keybindConn.Disconnect then keybindConn:Disconnect() end
    end)
end



do
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")

    local LOCAL_PLAYER = Players.LocalPlayer
    local interval = 1 
    local acc = 0
    local conn
    local lastSent = nil
    local remoteCache = nil

    local OPTIONS = {"PC","Phone","Controller","VR"}
    local MAP = {
        PC = "MouseKeyboard",
        Phone = "Touch",
        Controller = "Gamepad",
        VR = "VR",
    }

    local function findRemote()
        local ok, obj = pcall(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if not remotes then return nil end
            local replication = remotes:FindFirstChild("Replication")
            if not replication then return nil end
            local fighter = replication:FindFirstChild("Fighter")
            if not fighter then return nil end
            return fighter:FindFirstChild("SetControls")
        end)
        if ok then return obj end
        return nil
    end

    local function resolveSelection()
        local sel = nil
        if type(deviceSpoodDropDownList) == "table" and type(deviceSpoodDropDownList.Get) == "function" then
            local ok, v = pcall(deviceSpoodDropDownList.Get)
            if ok and v ~= nil then
                if type(v) == "string" then sel = v
                elseif type(v) == "number" then sel = OPTIONS[v]
                elseif type(v) == "table" then
                    if #v >= 1 then sel = v[1] end
                end
            end
        end
        if sel == nil and type(GetConfig) == "function" then
            local cfg = GetConfig("customization.deviceSpoof", nil)
            if type(cfg) == "string" then
                sel = cfg
            elseif type(cfg) == "number" then
                sel = OPTIONS[cfg]
            end
        end
        return sel
    end

    local function sendIfNeeded(mapped)
        if not mapped or mapped == "" then return end
        if remoteCache == nil then remoteCache = findRemote() end
        if remoteCache == nil then return end
        if lastSent == mapped then return end
        pcall(function()
            remoteCache:FireServer(mapped)
        end)
        lastSent = mapped
    end

    conn = RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc < interval then return end
        acc = acc - interval

        local sel = resolveSelection()
        if not sel then return end
        local mapped = MAP[sel] or sel
        sendIfNeeded(mapped)
    end)

    pcall(function()
        local sel = resolveSelection()
        if sel then
            local mapped = MAP[sel] or sel
            remoteCache = findRemote() or remoteCache
            if remoteCache then
                pcall(function() remoteCache:FireServer(mapped) end)
                lastSent = mapped
            end
        end
    end)

    RegisterUnload(function()
        if conn and conn.Disconnect then pcall(function() conn:Disconnect() end) end
    end)
end



do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local player = Players.LocalPlayer
    local flyEnabled = false
    local flyConn = nil
    local inputBeganConn = nil
    local inputEndedConn = nil
    local charAddedConn = nil
    local prevPlatformStand = nil
    local moveState = { W=false, A=false, S=false, D=false, Up=false, Down=false }
    local flyHeight = nil
    local flySpeed = GetConfig and GetConfig("rage.flySpeed", 20) or 20
    local flyDebugLabel = nil

    local function getSpeedFromSlider()
        if SliderAPI and SliderAPI[flySpeedSlider] and SliderAPI[flySpeedSlider].Get then
            local v = SliderAPI[flySpeedSlider].Get()
            if type(v) == "number" then
                flySpeed = v
                return
            end
        end
        flySpeed = GetConfig and GetConfig("rage.flySpeed", flySpeed) or flySpeed
    end

    local function setMovementFlag(key, down)
        if moveState[key] ~= nil then moveState[key] = not not down end
    end

    local function onInputBegan(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local k = input.KeyCode
        if k == Enum.KeyCode.W then setMovementFlag("W", true) end
        if k == Enum.KeyCode.S then setMovementFlag("S", true) end
        if k == Enum.KeyCode.A then setMovementFlag("A", true) end
        if k == Enum.KeyCode.D then setMovementFlag("D", true) end
        if k == Enum.KeyCode.Space then setMovementFlag("Up", true) end
        if k == Enum.KeyCode.LeftShift or k == Enum.KeyCode.RightShift then setMovementFlag("Down", true) end
    end

    local function onInputEnded(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local k = input.KeyCode
        if k == Enum.KeyCode.W then setMovementFlag("W", false) end
        if k == Enum.KeyCode.S then setMovementFlag("S", false) end
        if k == Enum.KeyCode.A then setMovementFlag("A", false) end
        if k == Enum.KeyCode.D then setMovementFlag("D", false) end
        if k == Enum.KeyCode.Space then setMovementFlag("Up", false) end
        if k == Enum.KeyCode.LeftShift or k == Enum.KeyCode.RightShift then setMovementFlag("Down", false) end
    end

    local function applyFly(dt)
        if not player or not player.Character then return end
        local root = player.Character.PrimaryPart or player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local cam = workspace.CurrentCamera
        if not cam then return end

        local forward = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector

        local hor = Vector3.new(0,0,0)
        if moveState.W then hor = hor + Vector3.new(forward.X, 0, forward.Z) end
        if moveState.S then hor = hor - Vector3.new(forward.X, 0, forward.Z) end
        if moveState.D then hor = hor + Vector3.new(right.X, 0, right.Z) end
        if moveState.A then hor = hor - Vector3.new(right.X, 0, right.Z) end

        if flyHeight == nil then flyHeight = root.Position.Y end
        if moveState.Up then flyHeight = flyHeight + (flySpeed or 20) * dt end
        if moveState.Down then flyHeight = flyHeight - (flySpeed or 20) * dt end

        pcall(function()
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = true end
            if root and root:IsA("BasePart") then
                root.AssemblyLinearVelocity = Vector3.new(0,0,0)
                root.Velocity = Vector3.new(0,0,0)
            end
        end)

        local horizontalMovement = Vector3.new(0,0,0)
        if hor.Magnitude > 0 then
            horizontalMovement = hor.Unit * (flySpeed or 20) * dt
        end

        local newPos = root.Position + horizontalMovement
        newPos = Vector3.new(newPos.X, flyHeight, newPos.Z)
        pcall(function()
            player.Character:SetPrimaryPartCFrame(CFrame.new(newPos, newPos + Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)))
        end)
    end

    local function onCharacterAdded(char)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then prevPlatformStand = hum.PlatformStand end
        if flyEnabled and hum then hum.PlatformStand = true end
    end

    local function startFly()
        if flyConn then return end
        getSpeedFromSlider()
        flyConn = RunService.Heartbeat:Connect(function(dt)
            applyFly(dt)
        end)
        if player and player.Character then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                prevPlatformStand = hum.PlatformStand
                hum.PlatformStand = true
            end
            local root = player.Character.PrimaryPart or player.Character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                flyHeight = root.Position.Y
            end
        end
        if player then
            charAddedConn = player.CharacterAdded:Connect(onCharacterAdded)
        end
    end

    local function stopFly()
        if flyConn then flyConn:Disconnect(); flyConn = nil end
        if charAddedConn then charAddedConn:Disconnect(); charAddedConn = nil end
        if player and player.Character then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hum and prevPlatformStand ~= nil then hum.PlatformStand = prevPlatformStand end
        end
        pcall(function() if flyDebugLabel and flyDebugLabel.Set then flyDebugLabel.Set("Fly: OFF (stop)") end end)
    end

    do
        local api = ToggleAPI and ToggleAPI[flyToggle]
        if api then
            local prev = api.OnToggle
            api.OnToggle = function(state)
                if prev then prev(state) end
                flyEnabled = not not state
                if flyEnabled then startFly() else stopFly() end
                pcall(function() if flyDebugLabel and flyDebugLabel.Set then flyDebugLabel.Set("Fly: " .. (flyEnabled and "ON (ui)" or "OFF (ui)")) end end)
                pcall(function() makeNotification("Fly is " .. (flyEnabled and "ON" or "OFF"), 2) end)
            end
            if api.Set then
                local prevOn = api.OnToggle
                api.OnToggle = nil
                pcall(api.Set, GetConfig("rage.fly", false))
                api.OnToggle = prevOn
            end
        end
    end

    do
        local sApi = SliderAPI and SliderAPI[flySpeedSlider]
        if sApi and sApi.Get and sApi.OnChange then
            pcall(function() sApi.Set(GetConfig("rage.flySpeed", flySpeed)) end)
            sApi.OnChange = function(v)
                flySpeed = tonumber(v) or flySpeed
                pcall(function() SetConfig("rage.flySpeed", flySpeed) end)
            end
        else
            flySpeed = GetConfig and GetConfig("rage.flySpeed", flySpeed) or flySpeed
        end
    end

    pcall(function() flyDebugLabel = makeDebugLabel("Fly: OFF") end)

    local flyKeyConn = nil
    flyKeyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local bound = GetConfig and GetConfig("rage.flyKeybind", "N")
        local target = nil
        if type(bound) == "string" and Enum.KeyCode[bound] then
            target = Enum.KeyCode[bound]
        elseif typeof and typeof(bound) == "EnumItem" then
            target = bound
        end
        if target and input.KeyCode == target then
            local currentState = GetConfig and GetConfig("rage.fly", false)
            local newState = not currentState
            if SetConfig then SetConfig("rage.fly", newState) end
            local api = ToggleAPI and ToggleAPI[flyToggle]
            if api and api.Set then api.Set(newState) end
            if flyDebugLabel and flyDebugLabel.Set then flyDebugLabel.Set("Fly: " .. (newState and "ON (keybind)" or "OFF (keybind)")) end
        end
    end)

    if not inputBeganConn then
        inputBeganConn = UserInputService.InputBegan:Connect(onInputBegan)
    end
    if not inputEndedConn then
        inputEndedConn = UserInputService.InputEnded:Connect(onInputEnded)
    end

    if GetConfig and GetConfig("rage.fly", false) then
        flyEnabled = true
        startFly()
    end

    RegisterUnload(function()
        stopFly()
        if inputBeganConn then inputBeganConn:Disconnect(); inputBeganConn = nil end
        if inputEndedConn then inputEndedConn:Disconnect(); inputEndedConn = nil end
        if flyKeyConn then flyKeyConn:Disconnect(); flyKeyConn = nil end
        if flyDebugLabel then pcall(function()
            if flyDebugLabel.Destroy then flyDebugLabel.Destroy() elseif flyDebugLabel.Set then flyDebugLabel.Set("") end
        end) end
    end)
end




do
    local url = "https://your-desire.vercel.app/api/changeLogs.js"
    local function get_request()
        if type(http_request) == "function" then return http_request end
        if type(request) == "function" then return request end
        if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
        if type(fluxus) == "table" and type(fluxus.request) == "function" then return fluxus.request end
        if type(http) == "table" and type(http.request) == "function" then return http.request end
        return nil
    end

    local reqfn = get_request()
    local body = nil
    if reqfn then
        local ok, res = pcall(function()
            return reqfn({ Url = url, Method = "GET" })
        end)
        if ok and res then
            if type(res) == "table" then
                body = res.Body or res.body or res.response or nil
            elseif type(res) == "string" then
                body = res
            end
        end
    end

    local function parse_js_object(js)
        if not js or type(js) ~= "string" then return nil end
        local s = js
        s = s:gsub("^%s*const%s+%w+%s*=", "")
        s = s:gsub(";%s*$", "")
        s = s:gsub("%[", "{")
        s = s:gsub("%]", "}")
        s = s:gsub('(%b"")%s*:', function(k) return "[" .. k .. "] =" end)
        s = s:gsub("%: null", "= nil")
        local prev = nil
        repeat
            prev = s
            s = s:gsub(",%s*([}%]])", "%1")
        until s == prev
        local chunk = "return " .. s
        local fn, err = loadstring(chunk)
        if not fn then return nil, err end
        local ok, tbl = pcall(fn)
        if not ok then return nil, tbl end
        return tbl
    end

    local updateLog = nil
    if body then
        local parsed, perr = parse_js_object(body)
        if parsed then updateLog = parsed end
    end

    if not updateLog then
        updateLog = {
            title = "Update",
            info = { "Could not fetch update log." },
            metadata = { id = "update_unknown", version = "0" }
        }
    end

    local seenKey = "updates.seen." .. (updateLog.metadata and updateLog.metadata.id or "unknown")
    local alreadySeen = false
    if GetConfig then
        local ok, val = pcall(function() return GetConfig(seenKey, false) end)
        if ok and val then alreadySeen = true end
    end

    if not alreadySeen then
        local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui and Players.LocalPlayer then
            playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
        end
        if not playerGui then
            pcall(function() playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") end)
        end

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "UpdateLogScreenGui"
        screenGui.ResetOnSpawn = false
        screenGui.DisplayOrder = 9999
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screenGui.Parent = playerGui

        local overlay = Instance.new("Frame")
        overlay.Name = "UpdateLogOverlay"
        overlay.Size = UDim2.new(1,0,1,0)
        overlay.Position = UDim2.new(0,0,0,0)
        overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
        overlay.BackgroundTransparency = 0.45
        overlay.ZIndex = 1
        overlay.Active = true
        overlay.Parent = screenGui

        local shadow = Instance.new("Frame")
        shadow.Name = "UpdateShadow"
        shadow.Size = UDim2.new(0, 780, 0, 440)
        shadow.Position = UDim2.new(0.5, -390, 0.5, -220)
        shadow.AnchorPoint = Vector2.new(0,0)
        shadow.BackgroundColor3 = Color3.fromRGB(0,0,0)
        shadow.BackgroundTransparency = 0.7
        shadow.ZIndex = 1
        shadow.Parent = overlay

        local dialog = Instance.new("Frame")
        dialog.Name = "UpdateDialog"
        dialog.Size = UDim2.new(0, 760, 0, 420)
        dialog.Position = UDim2.new(0.5, -380, 0.5, -210)
        dialog.AnchorPoint = Vector2.new(0,0)
        dialog.BackgroundColor3 = COLORS and COLORS.panel or Color3.fromRGB(18,18,18)
        dialog.BackgroundTransparency = 0
        dialog.BorderSizePixel = 0
        dialog.ZIndex = 2
        dialog.Parent = overlay

        local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0,14) corner.Parent = dialog
        local stroke = Instance.new("UIStroke") stroke.Color = COLORS and COLORS.divider or Color3.fromRGB(60,60,60) stroke.Thickness = 1 stroke.Parent = dialog
        RegisterThemed(dialog)

        local header = Instance.new("Frame")
        header.Name = "Header"
        header.Size = UDim2.new(1, 0, 0, 72)
        header.Position = UDim2.new(0, 0, 0, 0)
        header.BackgroundColor3 = COLORS and COLORS.accent or Color3.fromRGB(200,80,180)
        header.BorderSizePixel = 0
        header.ZIndex = 3
        header.Parent = dialog
        local headerCorner = Instance.new("UICorner") headerCorner.CornerRadius = UDim.new(0,12) headerCorner.Parent = header
        RegisterThemed(header)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -48, 0, 72)
        title.Position = UDim2.new(0, 24, 0, 0)
        title.BackgroundTransparency = 1
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Font = Enum.Font.GothamBold
        title.TextSize = 22
        title.TextColor3 = COLORS and COLORS.white or Color3.fromRGB(250,250,250)
        title.Text = updateLog.title or "Update"
        title.ZIndex = 4
        title.Parent = header
        RegisterThemed(title)

        local closeFrame = Instance.new("Frame")
        closeFrame.Name = "CloseButtonHolder"
        closeFrame.Size = UDim2.new(0,36,0,36)
        closeFrame.Position = UDim2.new(1, -44, 0, 12)
        closeFrame.AnchorPoint = Vector2.new(0,0)
        closeFrame.BackgroundTransparency = 1
        closeFrame.ZIndex = 4
        closeFrame.Parent = dialog
        RegisterThemed(closeFrame)

        local closeBtn = Instance.new("TextButton")
        closeBtn.Name = "CloseBtn"
        closeBtn.Size = UDim2.new(0,32,0,32)
        closeBtn.Position = UDim2.new(1, -4, 0.5, 0)
        closeBtn.AnchorPoint = Vector2.new(1,0.5)
        closeBtn.Text = "X"
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 18
        closeBtn.BackgroundColor3 = COLORS and COLORS.panelDark or Color3.fromRGB(40,40,40)
        closeBtn.TextColor3 = COLORS and COLORS.text or Color3.fromRGB(220,220,220)
        closeBtn.BorderSizePixel = 0
        closeBtn.Parent = closeFrame
        local closeCorner = Instance.new("UICorner") closeCorner.CornerRadius = UDim.new(0,6) closeCorner.Parent = closeBtn
        RegisterThemed(closeBtn)
        closeBtn.MouseButton1Click:Connect(function()
            if SetConfig then pcall(function() SetConfig(seenKey, true) end) end
            if screenGui and screenGui.Destroy then screenGui:Destroy() end
        end)

        local content = Instance.new("ScrollingFrame")
        content.Name = "UpdateContent"
        content.Size = UDim2.new(1, -48, 0, 220)
        content.Position = UDim2.new(0,24,0,72)
        content.BackgroundTransparency = 1
        content.ScrollBarThickness = 8
        content.CanvasSize = UDim2.new(0,0,0,0)
        content.ZIndex = 2
        content.Parent = dialog

        local contentPadding = Instance.new("UIPadding")
        contentPadding.PaddingLeft = UDim.new(0,6)
        contentPadding.PaddingRight = UDim.new(0,6)
        contentPadding.PaddingTop = UDim.new(0,6)
        contentPadding.PaddingBottom = UDim.new(0,6)
        contentPadding.Parent = content

        local uiList = Instance.new("UIListLayout")
        uiList.Name = "UpdateList"
        uiList.Padding = UDim.new(0,8)
        uiList.SortOrder = Enum.SortOrder.LayoutOrder
        uiList.Parent = content
        uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            content.CanvasSize = UDim2.new(0, 0, 0, uiList.AbsoluteContentSize.Y + 12)
        end)

        for i, line in ipairs(updateLog.info or {}) do
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 0)
            holder.AutomaticSize = Enum.AutomaticSize.Y
            holder.BackgroundTransparency = 1
            holder.Parent = content

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -12, 0, 0)
            lbl.AutomaticSize = Enum.AutomaticSize.Y
            lbl.BackgroundTransparency = 1
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextWrapped = true
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 16
            lbl.TextColor3 = COLORS and COLORS.text or Color3.fromRGB(230,230,230)
            lbl.Text = "• " .. tostring(line)
            lbl.LayoutOrder = i
            lbl.Parent = holder
        end

        local footer = Instance.new("TextLabel")
        footer.Size = UDim2.new(1, -48, 0, 48)
        footer.Position = UDim2.new(0,24,1,-88)
        footer.BackgroundTransparency = 1
        footer.Font = Enum.Font.Gotham
        footer.TextSize = 14
        footer.TextColor3 = Color3.fromRGB(180,180,180)
        footer.TextWrapped = true
        footer.Text = updateLog.footer or ""
        footer.TextXAlignment = Enum.TextXAlignment.Left
        footer.ZIndex = 3
        footer.Parent = dialog

        local okHolder = Instance.new("Frame")
        okHolder.Name = "OkButtonHolder"
        okHolder.Size = UDim2.new(0,140,0,40)
        okHolder.Position = UDim2.new(0.5, 0, 1, -48)
        okHolder.AnchorPoint = Vector2.new(0.5,0)
        okHolder.BackgroundTransparency = 1
        okHolder.Parent = dialog
        RegisterThemed(okHolder)

        local okBtn = Instance.new("TextButton")
        okBtn.Name = "OkBtn"
        okBtn.Size = UDim2.new(1, 0, 1, 0)
        okBtn.Position = UDim2.new(0, 0, 0, 0)
        okBtn.AnchorPoint = Vector2.new(0,0)
        okBtn.Text = "Ok"
        okBtn.Font = Enum.Font.GothamBold
        okBtn.TextSize = 16
        okBtn.TextColor3 = COLORS and COLORS.text or Color3.fromRGB(240,240,240)
        okBtn.BackgroundColor3 = COLORS and COLORS.accent or Color3.fromRGB(48,120,220)
        okBtn.BorderSizePixel = 0
        okBtn.Parent = okHolder
        local okCorner = Instance.new("UICorner") okCorner.CornerRadius = UDim.new(0,8) okCorner.Parent = okBtn
        RegisterThemed(okBtn)
        okBtn.MouseButton1Click:Connect(function()
            if SetConfig then pcall(function() SetConfig(seenKey, true) end) end
            if screenGui and screenGui.Destroy then screenGui:Destroy() end
        end)
    end
end




    
