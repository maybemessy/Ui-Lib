--// GameHub — v1.0
--// Companion launcher for MessyHub-style scripts
--// Left sidebar: category tabs + game list
--// Right panel: game info, console log, Load button
--// Usage:
--[[
    local Hub = loadstring(game:HttpGet("YOUR_GAMEHUB_URL"))()
    local Launcher = Hub:CreateLauncher({
        Name = "My Hub",
        Games = {
            {
                Name        = "Blox Fruits",
                Icon        = "🍎",            -- emoji OR rbxassetid://...
                Category    = "Adventure",
                Description = "Auto farm, boss esp, devil fruit notifier and more.",
                ScriptUrl   = "https://raw.githubusercontent.com/.../bloxfruits.lua",
                Tags        = {"Farm", "ESP", "TP"},
            },
            ...
        }
    })
--]]

local GameHub = {}

-- ── Services ──────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local LP               = Players.LocalPlayer

-- ── Palette (matches MessyHub dark theme) ────────────────────────────────────
local C = {
    Accent      = Color3.fromRGB(170,  0, 255),
    AccentDark  = Color3.fromRGB( 55,  0, 100),
    AccentMid   = Color3.fromRGB(100,  0, 180),
    BgWin       = Color3.fromRGB( 14, 14,  17),
    BgSide      = Color3.fromRGB( 10, 10,  13),
    BgPanel     = Color3.fromRGB( 10, 10,  13),
    BgCard      = Color3.fromRGB( 22, 22,  27),
    BgCard2     = Color3.fromRGB( 30, 30,  37),
    BgConsole   = Color3.fromRGB(  8,  8,  10),
    TxtPrimary  = Color3.fromRGB(238,238, 238),
    TxtSecond   = Color3.fromRGB(155,155, 172),
    TxtAccent   = Color3.fromRGB(195,110, 255),
    TxtMuted    = Color3.fromRGB( 80, 80, 100),
    Success     = Color3.fromRGB( 60,200, 100),
    Warning     = Color3.fromRGB(230,170,  30),
    Danger      = Color3.fromRGB(200, 45,  45),
    ConsoleTxt  = Color3.fromRGB(180,255, 180),
    ConsoleErr  = Color3.fromRGB(255,100, 100),
    ConsoleInfo = Color3.fromRGB(100,180, 255),
}

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function Tween(obj, props, t, style, dir)
    if not obj or not obj.Parent then return end
    TweenService:Create(obj,
        TweenInfo.new(t or 0.16, style or Enum.EasingStyle.Quad,
            dir or Enum.EasingDirection.Out), props):Play()
end

local function rng(n) return string.char(math.random(65,90)) .. math.random(10000,99999) .. n end

local function mk(cls, parent, props)
    local o = Instance.new(cls, parent)
    -- FIX: only set BorderSizePixel on GuiObject subclasses (Frame, TextButton etc.)
    -- ScreenGui, ScrollingFrame internals, etc. do NOT have this property.
    if o:IsA("GuiObject") then
        o.BorderSizePixel = 0
    end
    for k,v in pairs(props or {}) do
        if k ~= "BorderSizePixel" then
            pcall(function() o[k] = v end)
        end
    end
    return o
end

local function Frame(p,pr)  local f=mk("Frame",p,pr); return f end
local function Label(p,pr)
    local l=mk("TextLabel",p,pr)
    l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamSemibold
    l.TextSize=12
    l.TextColor3=C.TxtPrimary
    for k,v in pairs(pr or {}) do pcall(function() l[k]=v end) end
    return l
end
local function Btn(p,pr)
    local b=mk("TextButton",p,pr)
    b.AutoButtonColor=false
    b.Font=Enum.Font.GothamBold
    b.TextSize=12
    b.TextColor3=C.TxtPrimary
    for k,v in pairs(pr or {}) do pcall(function() b[k]=v end) end
    return b
end
local function Corner(p,r)
    local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 6); return c
end
local function Stroke(p,col,th,tr)
    local s=Instance.new("UIStroke",p)
    s.Color=col or C.Accent; s.Thickness=th or 1; s.Transparency=tr or 0.55; return s
end
local function Grad(p,c0,c1,rot)
    local g=Instance.new("UIGradient",p)
    g.Color=ColorSequence.new(c0,c1); g.Rotation=rot or 0; return g
end
local function Pad(p,l,r,t,b)
    local pd=Instance.new("UIPadding",p)
    pd.PaddingLeft=UDim.new(0,l or 0); pd.PaddingRight=UDim.new(0,r or 0)
    pd.PaddingTop=UDim.new(0,t or 0);  pd.PaddingBottom=UDim.new(0,b or 0)
    return pd
end
local function List(p,dir,pad,halign,valign)
    local l=Instance.new("UIListLayout",p)
    l.FillDirection=dir or Enum.FillDirection.Vertical
    l.Padding=UDim.new(0,pad or 4)
    l.SortOrder=Enum.SortOrder.LayoutOrder
    if halign then l.HorizontalAlignment=halign end
    if valign  then l.VerticalAlignment=valign   end
    return l
end

-- Random name for ScreenGui (anti-DEX)
local function randName()
    local s="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local t={}; for i=1,math.random(8,13) do
        local idx=math.random(1,#s); t[i]=s:sub(idx,idx)
    end
    return table.concat(t)
end

-- ─────────────────────────────────────────────────────────────────────────────
function GameHub:CreateLauncher(Config)
    local hubName   = Config.Name    or "GameHub"
    local allGames  = Config.Games   or {}
    local accentCol = Config.Accent  or C.Accent

    C.Accent     = accentCol
    C.AccentDark = Color3.new(accentCol.R*.3, accentCol.G*.3, accentCol.B*.3)
    C.AccentMid  = Color3.new(accentCol.R*.6, accentCol.G*.6, accentCol.B*.6)
    C.TxtAccent  = Color3.new(
        math.min(accentCol.R+.18,1),
        math.min(accentCol.G+.04,1),
        math.min(accentCol.B+.12,1))

    -- collect categories
    local cats = {}; local catSet = {}
    table.insert(cats, "All")
    for _, g in ipairs(allGames) do
        local c = g.Category or "Other"
        if not catSet[c] then catSet[c]=true; table.insert(cats,c) end
    end

    -- ── ScreenGui — created directly, NOT via mk(), to avoid BorderSizePixel error ──
    local sg = Instance.new("ScreenGui")
    sg.Name            = randName()
    sg.ResetOnSpawn    = false
    sg.IgnoreGuiInset  = true
    sg.DisplayOrder    = 99999998
    if gethui then sg.Parent=gethui()
    elseif typeof(syn)=="table" and syn.protect_gui then syn.protect_gui(sg); sg.Parent=CoreGui
    elseif typeof(protect_gui)=="function" then protect_gui(sg); sg.Parent=CoreGui
    else
        local ok=pcall(function() sg.Parent=CoreGui end)
        if not ok then sg.Parent=LP:WaitForChild("PlayerGui") end
    end
    task.defer(function() if sg and sg.Parent then sg.Name=randName() end end)

    local conns={}
    local function conn(c) table.insert(conns,c) end

    -- ── Window  480 × 300 ─────────────────────────────────────────────────────
    local W,H = 480, 300
    local win = Frame(sg, {
        Size=UDim2.new(0,W,0,0),
        Position=UDim2.new(0.5,-W/2,0.5,-H/2),
        BackgroundColor3=C.BgWin,
        ClipsDescendants=true,
        Active=true,
    })
    Corner(win,10)
    local winStroke=Stroke(win,C.Accent,1,0.4)

    -- open animation
    task.defer(function()
        Tween(win,{Size=UDim2.new(0,W,0,H)},0.35,Enum.EasingStyle.Back)
    end)

    -- ── BG glow blob ──────────────────────────────────────────────────────────
    local blob=Frame(win,{
        Size=UDim2.new(0,220,0,180),
        Position=UDim2.new(1,-60,0,-40),
        BackgroundColor3=C.AccentDark,
        BackgroundTransparency=0.55,
        ZIndex=0,
    })
    Corner(blob,90)

    -- ── Title bar ─────────────────────────────────────────────────────────────
    local TITLE_H = 32
    local titleBar = Frame(win,{
        Size=UDim2.new(1,0,0,TITLE_H),
        BackgroundColor3=Color3.fromRGB(10,10,13),
        ZIndex=5,
    })

    -- diamond icon
    local dia=Frame(titleBar,{
        Size=UDim2.new(0,10,0,10),
        Position=UDim2.new(0,10,0.5,-5),
        BackgroundColor3=C.Accent,
        Rotation=45, ZIndex=6,
    }); Corner(dia,2)
    local diaIn=Frame(dia,{
        Size=UDim2.new(0,4,0,4),
        Position=UDim2.new(0.5,-2,0.5,-2),
        BackgroundColor3=Color3.fromRGB(10,10,13),
        ZIndex=7,
    }); Corner(diaIn,1)

    Label(titleBar,{
        Size=UDim2.new(1,-80,1,0),
        Position=UDim2.new(0,26,0,0),
        Text=hubName,
        Font=Enum.Font.GothamBold,
        TextSize=13,
        TextColor3=C.TxtPrimary,
        TextXAlignment=Enum.TextXAlignment.Left,
        ZIndex=6,
    })

    -- title bar gradient separator
    local sep=Frame(titleBar,{
        Size=UDim2.new(1,0,0,1),
        Position=UDim2.new(0,0,1,-1),
        BackgroundColor3=C.Accent,
        ZIndex=6,
    })
    Grad(sep,Color3.new(0,0,0),C.Accent,0)

    -- fps label
    local fpsLbl=Label(titleBar,{
        Size=UDim2.new(0,60,1,0),
        Position=UDim2.new(1,-90,0,0),
        Text="60 fps",
        TextSize=10,
        TextColor3=C.TxtMuted,
        TextXAlignment=Enum.TextXAlignment.Right,
        ZIndex=6,
    })
    local fpsC,fpsT=0,os.clock()
    conn(RunService.Heartbeat:Connect(function()
        fpsC+=1
        if os.clock()-fpsT>=1 then
            fpsLbl.Text=fpsC.." fps"; fpsC=0; fpsT=os.clock()
        end
    end))

    -- close button
    local closeBtn=Btn(titleBar,{
        Size=UDim2.new(0,20,0,20),
        Position=UDim2.new(1,-26,0.5,-10),
        BackgroundColor3=Color3.fromRGB(55,20,20),
        Text="✕", TextSize=10,
        TextColor3=Color3.fromRGB(255,100,100),
        ZIndex=6,
    }); Corner(closeBtn,5)
    closeBtn.MouseEnter:Connect(function() Tween(closeBtn,{BackgroundColor3=C.Danger},0.1) end)
    closeBtn.MouseLeave:Connect(function() Tween(closeBtn,{BackgroundColor3=Color3.fromRGB(55,20,20)},0.1) end)
    closeBtn.MouseButton1Click:Connect(function()
        Tween(win,{Size=UDim2.new(0,W,0,0)},0.2,Enum.EasingStyle.Back,Enum.EasingDirection.In)
        task.wait(0.25); sg:Destroy()
    end)

    -- ── Drag ─────────────────────────────────────────────────────────────────
    local isLocked=false
    do
        local dragging,ds,sp=false,nil,nil
        titleBar.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 and not isLocked then
                dragging=true; ds=Vector2.new(i.Position.X,i.Position.Y); sp=win.Position
            end
        end)
        conn(UserInputService.InputChanged:Connect(function(i)
            if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
                local d=Vector2.new(i.Position.X,i.Position.Y)-ds
                win.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
            end
        end))
        conn(UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
        end))
    end

    -- ── Body ─────────────────────────────────────────────────────────────────
    local SIDE_W = 148
    local BODY_Y = TITLE_H

    -- LEFT: sidebar
    local sidebar=Frame(win,{
        Size=UDim2.new(0,SIDE_W,1,-BODY_Y),
        Position=UDim2.new(0,0,0,BODY_Y),
        BackgroundColor3=C.BgSide,
        ZIndex=3,
    })
    -- sidebar right divider
    local sDiv=Frame(sidebar,{
        Size=UDim2.new(0,1,1,0),
        Position=UDim2.new(1,-1,0,0),
        BackgroundColor3=C.Accent,
        BackgroundTransparency=0.6,
        ZIndex=4,
    })
    Grad(sDiv,Color3.new(0,0,0),C.Accent,90)

    -- category tabs row
    local CAT_H = 26
    local catRow=Frame(sidebar,{
        Size=UDim2.new(1,0,0,CAT_H),
        BackgroundColor3=Color3.fromRGB(8,8,10),
        ZIndex=4,
    })
    List(catRow,Enum.FillDirection.Horizontal,0,
        Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    Pad(catRow,4,4,0,0)

    -- game list scroll
    local gameScroll=Instance.new("ScrollingFrame",sidebar)
    gameScroll.Size=UDim2.new(1,0,1,-CAT_H)
    gameScroll.Position=UDim2.new(0,0,0,CAT_H)
    gameScroll.BackgroundTransparency=1
    gameScroll.BorderSizePixel=0
    gameScroll.ScrollBarThickness=3
    gameScroll.ScrollBarImageColor3=C.Accent
    gameScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    gameScroll.ZIndex=4
    List(gameScroll,Enum.FillDirection.Vertical,2)
    Pad(gameScroll,4,4,4,4)

    -- RIGHT: detail panel
    local panel=Frame(win,{
        Size=UDim2.new(1,-SIDE_W,1,-BODY_Y),
        Position=UDim2.new(0,SIDE_W,0,BODY_Y),
        BackgroundColor3=C.BgPanel,
        ClipsDescendants=true,
        ZIndex=3,
    })

    -- ── RIGHT PANEL CONTENTS ─────────────────────────────────────────────────
    -- empty state
    local emptyLbl=Label(panel,{
        Size=UDim2.new(1,0,1,0),
        Text="← Select a game",
        TextSize=13,
        TextColor3=C.TxtMuted,
        Font=Enum.Font.GothamSemibold,
        ZIndex=4,
    })

    -- header area (game name + tags)
    local header=Frame(panel,{
        Size=UDim2.new(1,0,0,52),
        BackgroundColor3=Color3.fromRGB(12,12,16),
        Visible=false,
        ZIndex=4,
    })
    Pad(header,10,10,8,0)
    local headerList=List(header,Enum.FillDirection.Vertical,2)

    local gameIcon=Label(header,{
        Size=UDim2.new(0,0,1,0),  -- will be set dynamically
        Text="🎮",
        TextSize=20,
        Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left,
        ZIndex=5,
    })
    local gameTitle=Label(header,{
        Size=UDim2.new(1,-30,0,20),
        Position=UDim2.new(0,30,0,8),
        Text="",
        Font=Enum.Font.GothamBold,
        TextSize=14,
        TextColor3=C.TxtPrimary,
        TextXAlignment=Enum.TextXAlignment.Left,
        ZIndex=5,
    })
    local tagRow=Frame(header,{
        Size=UDim2.new(1,-30,0,16),
        Position=UDim2.new(0,30,0,30),
        BackgroundTransparency=1,
        ZIndex=5,
    })
    List(tagRow,Enum.FillDirection.Horizontal,4)

    local headerSep=Frame(panel,{
        Size=UDim2.new(1,0,0,1),
        Position=UDim2.new(0,0,0,52),
        BackgroundColor3=C.Accent,
        BackgroundTransparency=0.7,
        Visible=false,
        ZIndex=4,
    })

    -- description
    local descLbl=Label(panel,{
        Size=UDim2.new(1,-16,0,28),
        Position=UDim2.new(0,8,0,60),
        Text="",
        TextSize=11,
        TextColor3=C.TxtSecond,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top,
        TextWrapped=true,
        Visible=false,
        ZIndex=4,
    })

    -- console label
    local consoleLbl=Label(panel,{
        Size=UDim2.new(1,-16,0,12),
        Position=UDim2.new(0,8,0,90),
        Text="CONSOLE",
        TextSize=9,
        Font=Enum.Font.GothamBold,
        TextColor3=C.TxtMuted,
        TextXAlignment=Enum.TextXAlignment.Left,

        Visible=false,
        ZIndex=4,
    })

    -- console scroll frame
    local consoleScroll=Instance.new("ScrollingFrame",panel)
    consoleScroll.Size=UDim2.new(1,-16,0,96)
    consoleScroll.Position=UDim2.new(0,8,0,104)
    consoleScroll.BackgroundColor3=C.BgConsole
    consoleScroll.BorderSizePixel=0
    consoleScroll.ScrollBarThickness=3
    consoleScroll.ScrollBarImageColor3=C.AccentMid
    consoleScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    consoleScroll.Visible=false
    consoleScroll.ZIndex=4
    Corner(consoleScroll,6)
    Stroke(consoleScroll,C.Accent,1,0.75)
    local consoleLayout=List(consoleScroll,Enum.FillDirection.Vertical,1)
    Pad(consoleScroll,6,6,4,4)

    -- load button
    local LOAD_BTN_H=28
    local loadBtn=Btn(panel,{
        Size=UDim2.new(1,-16,0,LOAD_BTN_H),
        Position=UDim2.new(0,8,1,-LOAD_BTN_H-8),
        BackgroundColor3=C.AccentDark,
        Text="",
        Visible=false,
        ZIndex=5,
    })
    Corner(loadBtn,7)
    Stroke(loadBtn,C.Accent,1,0.3)
    -- load btn gradient
    Grad(loadBtn,C.AccentMid,C.AccentDark,90)

    -- load btn label + icon
    local loadIcon=Label(loadBtn,{
        Size=UDim2.new(0,20,1,0),
        Position=UDim2.new(0,10,0,0),
        Text="▶",
        TextSize=11,
        TextColor3=C.TxtAccent,
        ZIndex=6,
    })
    local loadLbl=Label(loadBtn,{
        Size=UDim2.new(1,-36,1,0),
        Position=UDim2.new(0,28,0,0),
        Text="Load Script",
        Font=Enum.Font.GothamBold,
        TextSize=12,
        TextColor3=C.TxtPrimary,
        TextXAlignment=Enum.TextXAlignment.Left,
        ZIndex=6,
    })
    local loadSpinner=Label(loadBtn,{
        Size=UDim2.new(0,20,1,0),
        Position=UDim2.new(1,-28,0,0),
        Text="",
        TextSize=10,
        TextColor3=C.TxtMuted,
        ZIndex=6,
    })

    loadBtn.MouseEnter:Connect(function()
        Tween(loadBtn,{BackgroundColor3=C.AccentMid},0.12)
    end)
    loadBtn.MouseLeave:Connect(function()
        Tween(loadBtn,{BackgroundColor3=C.AccentDark},0.12)
    end)
    loadBtn.MouseButton1Down:Connect(function()
        Tween(loadBtn,{BackgroundColor3=C.Accent},0.07)
    end)
    loadBtn.MouseButton1Up:Connect(function()
        Tween(loadBtn,{BackgroundColor3=C.AccentMid},0.1)
    end)

    -- ── Console helpers ───────────────────────────────────────────────────────
    local function clearConsole()
        for _,c in ipairs(consoleScroll:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
    end

    local function log(msg, kind)
        -- kind: "info" | "ok" | "err" | "sys"
        local col = kind=="ok"  and C.ConsoleTxt
                 or kind=="err" and C.ConsoleErr
                 or kind=="sys" and C.TxtMuted
                 or C.ConsoleInfo

        local prefix = kind=="ok"  and "[✓] "
                    or kind=="err" and "[✗] "
                    or kind=="sys" and "[·] "
                    or "[>] "

        local lbl=Label(consoleScroll,{
            Size=UDim2.new(1,0,0,0),
            AutomaticSize=Enum.AutomaticSize.Y,
            Text=prefix..msg,
            TextSize=10,
            Font=Enum.Font.Code,
            TextColor3=col,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextYAlignment=Enum.TextYAlignment.Top,
            TextWrapped=true,
            BackgroundTransparency=1,
            ZIndex=5,
        })
        -- scroll to bottom
        task.defer(function()
            if consoleScroll and consoleScroll.Parent then
                consoleScroll.CanvasPosition=Vector2.new(0,
                    math.max(0, consoleScroll.AbsoluteCanvasSize.Y
                               - consoleScroll.AbsoluteSize.Y))
            end
        end)
        return lbl
    end

    -- ── Game card builder ─────────────────────────────────────────────────────
    local activeCard=nil
    local currentGame=nil
    local loadConn=nil

    local function makeTagChip(parent, txt)
        local chip=Frame(parent,{
            Size=UDim2.new(0,0,0,14),
            BackgroundColor3=C.AccentDark,
            ZIndex=5,
        }); Corner(chip,7)
        local lbl=Label(chip,{
            Size=UDim2.new(1,-8,1,0),
            Position=UDim2.new(0,4,0,0),
            Text=txt,
            TextSize=9,
            TextColor3=C.TxtAccent,
            Font=Enum.Font.GothamBold,
            ZIndex=6,
        })
        task.defer(function()
            if lbl and lbl.Parent then
                chip.Size=UDim2.new(0,lbl.TextBounds.X+10,0,14)
            end
        end)
    end

    local function showGame(game)
        if currentGame==game then return end
        currentGame=game

        -- clear tags
        for _,c in ipairs(tagRow:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end

        emptyLbl.Visible=false
        header.Visible=true
        headerSep.Visible=true
        descLbl.Visible=true
        consoleLbl.Visible=true
        consoleScroll.Visible=true
        loadBtn.Visible=true

        gameIcon.Text = game.Icon or "🎮"
        gameTitle.Text = game.Name or "Unknown"
        descLbl.Text = game.Description or "No description provided."

        for _,tag in ipairs(game.Tags or {}) do
            makeTagChip(tagRow, tag)
        end

        clearConsole()
        log("Selected: "..game.Name, "sys")
        log("Script: "..(game.ScriptUrl or "none"), "sys")
        log("Ready to load.", "info")

        loadLbl.Text = "Load  "..game.Name
        loadSpinner.Text = ""

        -- reconnect load button
        if loadConn then loadConn:Disconnect() end
        loadConn=loadBtn.MouseButton1Click:Connect(function()
            if not game.ScriptUrl or game.ScriptUrl=="" then
                log("No script URL configured.", "err")
                return
            end
            loadLbl.Text = "Loading..."
            loadSpinner.Text = "⟳"
            loadBtn.Active = false

            -- animate spinner
            local spinConn
            local rot=0
            spinConn=RunService.Heartbeat:Connect(function(dt)
                rot=(rot+200*dt)%360
                if loadSpinner and loadSpinner.Parent then
                    loadSpinner.Rotation=rot
                else
                    spinConn:Disconnect()
                end
            end)

            log("Fetching script from GitHub...", "info")
            task.spawn(function()
                local ok, result = pcall(function()
                    return game:HttpGet(game.ScriptUrl)
                end)
                spinConn:Disconnect()
                if ok and result and result~="" then
                    log("Fetched "..#result.." bytes.", "ok")
                    log("Executing script...", "info")
                    local run_ok, run_err = pcall(loadstring(result))
                    if run_ok then
                        log("Script loaded successfully!", "ok")
                        loadLbl.Text="Loaded ✓"
                        loadSpinner.Text=""
                        Tween(loadBtn,{BackgroundColor3=Color3.fromRGB(20,80,40)},0.2)
                    else
                        log("Runtime error: "..(run_err or "unknown"), "err")
                        loadLbl.Text="Error — retry?"
                        loadSpinner.Text=""
                    end
                else
                    log("Failed to fetch: "..(result or "network error"), "err")
                    loadLbl.Text="Failed — retry"
                    loadSpinner.Text=""
                end
                loadBtn.Active=true
            end)
        end)
    end

    local function makeGameCard(g)
        local card=Btn(gameScroll,{
            Size=UDim2.new(1,0,0,38),
            BackgroundColor3=C.BgCard,
            BackgroundTransparency=0.3,
            Text="",
            ZIndex=5,
        }); Corner(card,6)

        -- icon
        local ico=Label(card,{
            Size=UDim2.new(0,24,0,24),
            Position=UDim2.new(0,5,0.5,-12),
            Text=g.Icon or "🎮",
            TextSize=16,
            ZIndex=6,
        })
        -- name
        local nm=Label(card,{
            Size=UDim2.new(1,-34,0,16),
            Position=UDim2.new(0,32,0,6),
            Text=g.Name or "Game",
            TextSize=11,
            Font=Enum.Font.GothamBold,
            TextColor3=C.TxtPrimary,
            TextXAlignment=Enum.TextXAlignment.Left,
            ZIndex=6,
            TextTruncate=Enum.TextTruncate.AtEnd,
        })
        -- category
        local cat=Label(card,{
            Size=UDim2.new(1,-34,0,12),
            Position=UDim2.new(0,32,0,22),
            Text=g.Category or "",
            TextSize=9,
            TextColor3=C.TxtMuted,
            TextXAlignment=Enum.TextXAlignment.Left,
            ZIndex=6,
        })
        -- accent strip (shown when active)
        local strip=Frame(card,{
            Size=UDim2.new(0,3,0.6,0),
            Position=UDim2.new(0,0,0.2,0),
            BackgroundColor3=C.Accent,
            BackgroundTransparency=1,
            ZIndex=7,
        }); Corner(strip,2)

        card.MouseEnter:Connect(function()
            if activeCard~=card then
                Tween(card,{BackgroundColor3=C.BgCard2,BackgroundTransparency=0},0.1)
            end
        end)
        card.MouseLeave:Connect(function()
            if activeCard~=card then
                Tween(card,{BackgroundColor3=C.BgCard,BackgroundTransparency=0.3},0.1)
            end
        end)

        card.MouseButton1Click:Connect(function()
            -- deactivate previous
            if activeCard and activeCard~=card then
                Tween(activeCard,{BackgroundColor3=C.BgCard,BackgroundTransparency=0.3},0.15)
            end
            activeCard=card
            Tween(card,{BackgroundColor3=Color3.fromRGB(32,8,50),BackgroundTransparency=0},0.15)
            Tween(strip,{BackgroundTransparency=0},0.15)
            showGame(g)
        end)

        return card
    end

    -- ── Category tab builder ──────────────────────────────────────────────────
    local catBtns={}
    local activecat="All"
    local allCards={}

    local function filterGames(cat)
        activecat=cat
        for _,entry in ipairs(allCards) do
            local show = cat=="All" or entry.game.Category==cat
            entry.card.Visible=show
        end
        for _,b in pairs(catBtns) do
            local active=(b.Name==cat)
            Tween(b,{
                BackgroundColor3 = active and C.AccentDark or Color3.fromRGB(18,18,22),
                BackgroundTransparency = active and 0 or 0,
            },0.12)
            b.TextColor3 = active and C.TxtAccent or C.TxtSecond
        end
    end

    for _, cat in ipairs(cats) do
        local short = #cat>7 and cat:sub(1,6).."…" or cat
        local b=Btn(catRow,{
            Name=cat,
            Size=UDim2.new(0,0,1,-4),
            AutomaticSize=Enum.AutomaticSize.X,
            BackgroundColor3=cat=="All" and C.AccentDark or Color3.fromRGB(18,18,22),
            Text=short,
            TextSize=9,
            Font=Enum.Font.GothamBold,
            TextColor3=cat=="All" and C.TxtAccent or C.TxtSecond,
            ZIndex=5,
        }); Corner(b,4)
        Pad(b,5,5,0,0)
        catBtns[cat]=b
        b.MouseButton1Click:Connect(function() filterGames(cat) end)
    end

    -- build all game cards
    for _, g in ipairs(allGames) do
        local card=makeGameCard(g)
        table.insert(allCards,{game=g, card=card})
    end

    -- ── Cleanup ───────────────────────────────────────────────────────────────
    sg.Destroying:Connect(function()
        for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    end)

    local API={}
    function API:AddGame(g)
        table.insert(allGames,g)
        local card=makeGameCard(g)
        table.insert(allCards,{game=g,card=card})
        local c=g.Category or "Other"
        if not catSet[c] then
            catSet[c]=true; table.insert(cats,c)
            -- rebuild cat buttons would need re-layout; for simplicity just
            -- add it without rebuilding (full rebuild left as extension)
        end
        filterGames(activecat)
    end
    function API:Close()
        Tween(win,{Size=UDim2.new(0,W,0,0)},0.2,Enum.EasingStyle.Back,Enum.EasingDirection.In)
        task.wait(0.25); sg:Destroy()
    end
    function API:SetAccent(col) C.Accent=col; winStroke.Color=col end

    return API
end

return GameHub
