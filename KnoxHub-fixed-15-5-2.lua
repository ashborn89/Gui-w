-- KNOX HUB by Knox Team 
-- ================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")
local LocalPlayer      = Players.LocalPlayer

-- ================================================
-- STATE (UI only)
-- ================================================
local cfg = setmetatable({
    billboardEnabled = false,
    lockUI           = false,
    hideKey          = Enum.KeyCode.LeftControl,
}, {
    __index = function(t, k)
        return rawget(t, k)
    end,
    __newindex = function(t, k, v)
        rawset(t, k, v)
    end
})

-- ================================================
-- HELPERS
-- ================================================
local function getChar() return LocalPlayer.Character end
local function getHRP()  local c=getChar() return c and c:FindFirstChild("HumanoidRootPart") end

-- ================================================
-- DESTROY OLD
-- ================================================
-- Disconnect old connections if re-executed
if _G.KnoxHub_Cleanup then
    pcall(function() _G.KnoxHub_Cleanup() end)
end

pcall(function()
    for _,n in ipairs({"KnoxHubGUI","KnoxHubGUI_Old"}) do
        if CoreGui:FindFirstChild(n) then CoreGui[n]:Destroy() end
    end
end)

-- ================================================
-- PALETTE
-- ================================================
local C = {
    bg         = Color3.fromRGB(10,  11,  15),
    sidebar    = Color3.fromRGB(13,  14,  19),
    content    = Color3.fromRGB(10,  11,  15),
    topbar     = Color3.fromRGB(13,  14,  19),
    footer     = Color3.fromRGB(11,  12,  17),
    row        = Color3.fromRGB(18,  20,  28),
    rowHover   = Color3.fromRGB(24,  27,  38),
    tabActive  = Color3.fromRGB(22,  28, 88),   -- rich dark purple-blue (was flat blue)
    tabInact   = Color3.fromRGB(13,  14,  19),
    tabHover   = Color3.fromRGB(18,  22,  34),
    white      = Color3.fromRGB(245, 247, 255),
    sky        = Color3.fromRGB(70,  170, 255),
    skyDim     = Color3.fromRGB(50,  120, 200),
    dim        = Color3.fromRGB(120, 130, 155),
    divider    = Color3.fromRGB(45,  52,  75),
    togOff     = Color3.fromRGB(22,  24,  36),
    togOn      = Color3.fromRGB(50,  140, 255),
    dotOff     = Color3.fromRGB(65,  70,  95),
    dotOn      = Color3.fromRGB(245, 247, 255),
    inputBg    = Color3.fromRGB(14,  16,  24),
    kbBg       = Color3.fromRGB(16,  18,  28),
    premium    = Color3.fromRGB(50,  140, 255),
}

-- ================================================
-- BORDER ANIMATION — Ice Hub style (exact match)
-- UIGradient color on UIStroke, offset animated with math.sin(tick())
-- Only the GUI border gets this. Profile card / avatar use simple color cycle.
-- ================================================

-- Blue gradient: dark navy → dim blue → white peak → dim blue → dark navy
-- 5-stop pattern identical to humble hub, colours shifted to blue
local KNOX_STROKE_COLORS = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(0,  15,  60)),
    ColorSequenceKeypoint.new(0.25, Color3.fromRGB(0,  80, 200)),
    ColorSequenceKeypoint.new(0.5,  Color3.new(1,  1,  1  )),
    ColorSequenceKeypoint.new(0.75, Color3.fromRGB(0,  80, 200)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(0,  15,  60)),
})

-- Tab gradient: deep navy → teal → white peak → teal → deep navy
-- Distinct premium look, different from the main border blue
local TAB_STROKE_COLORS = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(0,  10,  40)),
    ColorSequenceKeypoint.new(0.25, Color3.fromRGB(0, 160, 180)),
    ColorSequenceKeypoint.new(0.5,  Color3.new(1,   1,   1  )),
    ColorSequenceKeypoint.new(0.75, Color3.fromRGB(0, 160, 180)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(0,  10,  40)),
})

-- Only one gradient — on the main GUI border stroke
local MainBorderGrad = nil  -- set after Main is created

-- Per-tab gradient instances — keyed by UIStroke object
-- Only exist (and spin) while the tab is active
local tabGradients = {}

-- ── COLOR CYCLE (profile card, avatar only) ──────────────────
local bSeq = {
    Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(180, 220, 255),
    Color3.fromRGB(70,  170, 255),
    Color3.fromRGB(180, 220, 255),
}
local bIdx=1; local bTick=0
local cycleStrokes = {}
local function addAnimStroke(s) table.insert(cycleStrokes, s) end
local function removeAnimStroke(s)
    for i,v in ipairs(cycleStrokes) do if v==s then table.remove(cycleStrokes,i); break end end
end

-- Toggle ON/OFF stroke helpers (simple color, no march)
local elemMarchStrokes = {}
local function addElemMarchStroke(s)
    table.insert(elemMarchStrokes, s)
    TweenService:Create(s,TweenInfo.new(0.18),{Color=Color3.fromRGB(0,120,255),Thickness=1.5}):Play()
end
local function removeElemMarchStroke(s)
    for i,v in ipairs(elemMarchStrokes) do if v==s then table.remove(elemMarchStrokes,i); break end end
    TweenService:Create(s,TweenInfo.new(0.18),{Color=Color3.fromRGB(28,32,48),Thickness=1}):Play()
end

-- Tab stroke helpers — attach/detach animated UIGradient on the stroke
local function addTabAnimStroke(s)
    -- White base required so UIGradient colours show through
    s.Color     = Color3.new(1, 1, 1)
    s.Thickness = 1.8
    -- Create and attach gradient if not already present
    if not tabGradients[s] then
        local g = Instance.new("UIGradient")
        g.Color    = TAB_STROKE_COLORS
        g.Rotation = 0
        g.Parent   = s
        tabGradients[s] = g
    end
end
local function removeTabAnimStroke(s)
    -- Destroy the gradient so the stroke goes back to a plain colour
    if tabGradients[s] then
        tabGradients[s]:Destroy()
        tabGradients[s] = nil
    end
    TweenService:Create(s, TweenInfo.new(0.15), {Color=Color3.fromRGB(28,32,48), Thickness=0}):Play()
end

-- RenderStepped: animate main border gradient — exact humble hub technique:
--   rotation spins full 360° continuously, offset does a slow sin/cos drift
--   this produces the sweeping light-on-border effect
RunService.RenderStepped:Connect(function()
    local t = tick()
    if MainBorderGrad then
        local rot = (t * 55) % 360
        local off = Vector2.new(math.sin(t * 1.6) * 0.45, math.cos(t * 1.0) * 0.45)
        MainBorderGrad.Rotation = rot
        MainBorderGrad.Offset   = off
    end
    -- Spin active tab gradients (same speed as main border — unified feel)
    for _, grad in pairs(tabGradients) do
        grad.Rotation = (t * 55) % 360
        grad.Offset   = Vector2.new(math.sin(t * 1.6) * 0.3, math.cos(t * 1.0) * 0.3)
    end
    -- Color cycle for profile card / avatar strokes
    bTick = bTick + (1/60)
    if bTick >= 0.45 then
        bTick = 0
        local ni = (bIdx % #bSeq) + 1; bIdx = ni
        for _,s in ipairs(cycleStrokes) do
            TweenService:Create(s,TweenInfo.new(0.4,Enum.EasingStyle.Sine),{Color=bSeq[ni]}):Play()
        end
    end
end)

-- ================================================
-- LAYOUT CONSTANTS
-- ================================================
local W        = 640
local H        = 420
local SB_W     = 200
local TOP_H    = 54
local FOOT_H   = 30
local CORNER   = 26   -- more curved

-- ================================================
-- SCREEN GUI
-- ================================================
local SG=Instance.new("ScreenGui")
SG.Name="KnoxHubGUI"; SG.ResetOnSpawn=false
SG.DisplayOrder=10; SG.IgnoreGuiInset=true; SG.Parent=CoreGui

-- ================================================
-- GLOBAL API stub — filled in after all vars are defined
-- ================================================
_G.KnoxHub = {}

-- ================================================
-- BLUR EFFECT (for intro)
-- ================================================
local BlurEffect=Instance.new("BlurEffect")
BlurEffect.Size=0; BlurEffect.Parent=Lighting

-- ================================================
-- INTRO SCREEN
-- ================================================
local IntroGui=Instance.new("Frame")
IntroGui.Name="KnoxIntro"
IntroGui.Size=UDim2.new(1,0,1,0)
IntroGui.Position=UDim2.new(0,0,0,0)
IntroGui.BackgroundColor3=Color3.fromRGB(0,0,0)
IntroGui.BackgroundTransparency=0
IntroGui.BorderSizePixel=0
IntroGui.ZIndex=100
IntroGui.Parent=SG

local IntroKnox=Instance.new("TextLabel")
IntroKnox.Size=UDim2.new(0,400,0,80)
IntroKnox.Position=UDim2.new(0.5,-200,0.5,-60)
IntroKnox.BackgroundTransparency=1
IntroKnox.Text=""
IntroKnox.TextColor3=Color3.fromRGB(255,255,255)
IntroKnox.Font=Enum.Font.GothamBlack
IntroKnox.TextSize=64
IntroKnox.TextXAlignment=Enum.TextXAlignment.Center
IntroKnox.ZIndex=101
IntroKnox.Parent=IntroGui

local IntroLine=Instance.new("Frame")
IntroLine.Size=UDim2.new(0,0,0,2)
IntroLine.Position=UDim2.new(0.5,0,0.5,30)
IntroLine.AnchorPoint=Vector2.new(0.5,0)
IntroLine.BackgroundColor3=Color3.fromRGB(70,170,255)
IntroLine.BorderSizePixel=0
IntroLine.ZIndex=101
IntroLine.Parent=IntroGui

task.spawn(function()
    TweenService:Create(BlurEffect,TweenInfo.new(0.4),{Size=24}):Play()
    local full="KNOX HUB"
    task.wait(0.3)
    for i=1,#full do
        IntroKnox.Text=string.sub(full,1,i)
        task.wait(0.13)
    end
    task.wait(0.1)
    TweenService:Create(IntroLine,TweenInfo.new(0.35,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=UDim2.new(0,340,0,2)}):Play()
    task.wait(0.4)
    TweenService:Create(IntroKnox,TweenInfo.new(0.5,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{
        Position=UDim2.new(0.5,-200,0.5,60),
        TextTransparency=1
    }):Play()
    TweenService:Create(IntroLine,TweenInfo.new(0.5,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{
        Position=UDim2.new(0.5,0,0.5,110),
        BackgroundTransparency=1
    }):Play()
    task.wait(0.5)
    TweenService:Create(IntroGui,TweenInfo.new(0.35),{BackgroundTransparency=1}):Play()
    TweenService:Create(BlurEffect,TweenInfo.new(0.5),{Size=0}):Play()
    task.wait(0.38)
    IntroGui:Destroy()
end)

-- ================================================
-- MAIN FRAME
-- ================================================
local Main=Instance.new("Frame")
Main.Name="Main"; Main.Size=UDim2.new(0,W,0,H)
Main.Position=UDim2.new(0,40,0,40)
Main.BackgroundColor3=C.bg
Main.BorderSizePixel=0; Main.Active=true
Main.ClipsDescendants=false; Main.Visible=false; Main.Parent=SG
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,CORNER); c.Parent=Main end

-- Subtle dark noise overlay for main background texture
local NoiseOverlay=Instance.new("ImageLabel")
NoiseOverlay.Size=UDim2.new(1,0,1,0)
NoiseOverlay.Position=UDim2.new(0,0,0,0)
NoiseOverlay.BackgroundTransparency=1
NoiseOverlay.Image="rbxassetid://6372755229"   -- tileable noise texture
NoiseOverlay.ScaleType=Enum.ScaleType.Tile
NoiseOverlay.TileSize=UDim2.new(0,64,0,64)
NoiseOverlay.ImageTransparency=0.93
NoiseOverlay.ImageColor3=Color3.fromRGB(255,255,255)
NoiseOverlay.ZIndex=1; NoiseOverlay.BorderSizePixel=0
NoiseOverlay.Parent=Main
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,CORNER); c.Parent=NoiseOverlay end

task.delay(1.85, function()
    Main.Visible=true
    Main.BackgroundTransparency=1
    TweenService:Create(Main,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()
end)

local UIScaleInst=Instance.new("UIScale"); UIScaleInst.Scale=1; UIScaleInst.Parent=Main

-- Border overlay: a fully transparent frame the exact same size as Main,
-- parented to Main at a very high ZIndex so it paints ABOVE all the
-- square-patch frames that would otherwise occlude the UIStroke.
-- UICorner + UIStroke on this overlay = animated curved border that is
-- never clipped by the sidebar / footer patch rectangles.
local BorderOverlay=Instance.new("Frame")
BorderOverlay.Name="BorderOverlay"
BorderOverlay.Size=UDim2.new(1,0,1,0)
BorderOverlay.Position=UDim2.new(0,0,0,0)
BorderOverlay.BackgroundTransparency=1
BorderOverlay.BorderSizePixel=0
BorderOverlay.ZIndex=100   -- above every patch frame (all are <=10)
BorderOverlay.ClipsDescendants=false
BorderOverlay.Parent=Main
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,CORNER); c.Parent=BorderOverlay end

local MainStroke=Instance.new("UIStroke")
MainStroke.Thickness=2
MainStroke.Color=Color3.new(1,1,1)   -- REQUIRED: white base so UIGradient colours are visible
MainStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
MainStroke.Parent=BorderOverlay
MainBorderGrad=Instance.new("UIGradient")
MainBorderGrad.Color=KNOX_STROKE_COLORS
MainBorderGrad.Rotation=0  -- starts at 0; RenderStepped drives it to spin 360° continuously
MainBorderGrad.Parent=MainStroke

-- ================================================
-- SIDEBAR
-- ================================================
-- Sidebar: UICorner gives all 4 corners curved.
-- We patch top-right, bottom-right, AND bottom-left back to square so the sidebar
-- only curves at the top-left corner (matching the Main GUI outer curve).
-- The sidebar then touches the full GUI height on the left side.
local Sidebar=Instance.new("Frame")
Sidebar.Size=UDim2.new(0,SB_W,1,0)
Sidebar.Position=UDim2.new(0,0,0,0)
Sidebar.BackgroundColor3=C.sidebar
Sidebar.BorderSizePixel=0; Sidebar.ZIndex=3
Sidebar.ClipsDescendants=false; Sidebar.Parent=Main
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,CORNER); c.Parent=Sidebar end

-- Patch top-right of Sidebar back to square
do local f=Instance.new("Frame")
   f.Size=UDim2.new(0,CORNER+2,0,CORNER+2)
   f.Position=UDim2.new(1,-(CORNER+2),0,0)
   f.BackgroundColor3=C.sidebar; f.BorderSizePixel=0; f.ZIndex=6; f.Parent=Sidebar end

-- Patch bottom-right of Sidebar back to square
do local f=Instance.new("Frame")
   f.Size=UDim2.new(0,CORNER+2,0,CORNER+2)
   f.Position=UDim2.new(1,-(CORNER+2),1,-(CORNER+2))
   f.BackgroundColor3=C.sidebar; f.BorderSizePixel=0; f.ZIndex=6; f.Parent=Sidebar end

-- Patch bottom-left of Sidebar back to square so it touches full GUI height at bottom.
-- We intentionally stop the patch CORNER px short of the left edge so it never reaches
-- the outer curve of Main. Main's own UICorner already masks the true bottom-left corner,
-- so no separate "restore" frame is needed and none should be added (it would create
-- the flat rectangular artifact above the curve).
do local f=Instance.new("Frame")
   f.Size=UDim2.new(0,CORNER+2,0,CORNER+2)
   f.Position=UDim2.new(0,0,1,-(CORNER+2))
   f.BackgroundColor3=C.sidebar; f.BorderSizePixel=0; f.ZIndex=6; f.Parent=Sidebar end
-- NOTE: no C.bg "restore" frame here — Main's UICorner already clips the outer corner
-- cleanly. Adding a bg-coloured frame on top of BorderOverlay would show as a
-- rectangular flat segment above the animated border curve.

-- Vertical divider line — runs full sidebar height with no gaps, straight edge
local SBLine=Instance.new("Frame")
SBLine.Size=UDim2.new(0,1,1,0)
SBLine.Position=UDim2.new(1,-1,0,0)
SBLine.BackgroundColor3=Color3.fromRGB(45,52,75)
SBLine.BorderSizePixel=0; SBLine.ZIndex=10; SBLine.Parent=Sidebar

-- ---- KNOX LOGO — image only, no wrapper frame, no extra text ----
local KnoxLogo=Instance.new("ImageLabel")
KnoxLogo.Size=UDim2.new(1,-20,0,104)
KnoxLogo.Position=UDim2.new(0,10,0,6)
KnoxLogo.BackgroundTransparency=1
KnoxLogo.Image="rbxassetid://120025299102610"
KnoxLogo.ScaleType=Enum.ScaleType.Fit
KnoxLogo.ZIndex=3; KnoxLogo.Parent=Sidebar

-- ---- PLAYER CARD ----
local PlayerCard=Instance.new("Frame")
PlayerCard.Size=UDim2.new(1,-16,0,70)
PlayerCard.Position=UDim2.new(0,8,0,114)
PlayerCard.BackgroundColor3=Color3.fromRGB(9,10,16)
PlayerCard.BorderSizePixel=0; PlayerCard.ZIndex=3; PlayerCard.Parent=Sidebar
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,14); c.Parent=PlayerCard end

local PlayerCardStroke=Instance.new("UIStroke")
PlayerCardStroke.Color=Color3.fromRGB(40,80,160); PlayerCardStroke.Thickness=0.8; PlayerCardStroke.Parent=PlayerCard
addAnimStroke(PlayerCardStroke)

-- Avatar circle
local AvatarFrame=Instance.new("Frame")
AvatarFrame.Size=UDim2.new(0,46,0,46)
AvatarFrame.Position=UDim2.new(0,10,0.5,-23)
AvatarFrame.BackgroundColor3=C.divider
AvatarFrame.BorderSizePixel=0; AvatarFrame.ZIndex=5; AvatarFrame.Parent=PlayerCard
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=AvatarFrame end
local AvatarStroke=Instance.new("UIStroke")
AvatarStroke.Thickness=2; AvatarStroke.Color=bSeq[1]
AvatarStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; AvatarStroke.Parent=AvatarFrame
addAnimStroke(AvatarStroke)

local AvatarImg=Instance.new("ImageLabel")
AvatarImg.Size=UDim2.new(1,0,1,0); AvatarImg.BackgroundTransparency=1
AvatarImg.Image=""; AvatarImg.ScaleType=Enum.ScaleType.Crop
AvatarImg.ZIndex=6; AvatarImg.Parent=AvatarFrame
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=AvatarImg end

task.spawn(function()
    pcall(function()
        local t=Players:GetUserThumbnailAsync(LocalPlayer.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100)
        AvatarImg.Image=t
    end)
end)

-- Display name
local DispLbl=Instance.new("TextLabel")
DispLbl.Size=UDim2.new(1,-68,0,18); DispLbl.Position=UDim2.new(0,64,0,10)
DispLbl.BackgroundTransparency=1; DispLbl.Text=LocalPlayer.DisplayName
DispLbl.TextColor3=C.white; DispLbl.Font=Enum.Font.GothamBlack
DispLbl.TextSize=13; DispLbl.TextXAlignment=Enum.TextXAlignment.Left
DispLbl.ZIndex=5; DispLbl.Parent=PlayerCard

-- @username
local UserLbl=Instance.new("TextLabel")
UserLbl.Size=UDim2.new(1,-68,0,13); UserLbl.Position=UDim2.new(0,64,0,28)
UserLbl.BackgroundTransparency=1; UserLbl.Text="@"..LocalPlayer.Name
UserLbl.TextColor3=C.dim; UserLbl.Font=Enum.Font.Gotham
UserLbl.TextSize=10; UserLbl.TextXAlignment=Enum.TextXAlignment.Left
UserLbl.ZIndex=5; UserLbl.Parent=PlayerCard

-- Premium badge (fits inside card, below username)
local PremBadge=Instance.new("Frame")
PremBadge.Size=UDim2.new(0,78,0,16); PremBadge.Position=UDim2.new(0,64,0,44)
PremBadge.BackgroundColor3=Color3.fromRGB(8,22,55)
PremBadge.BorderSizePixel=0; PremBadge.ZIndex=5; PremBadge.Parent=PlayerCard
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=PremBadge end
do local s=Instance.new("UIStroke"); s.Color=C.sky; s.Thickness=1; s.Parent=PremBadge end

local PremIco=Instance.new("TextLabel")
PremIco.Size=UDim2.new(0,16,1,0); PremIco.Position=UDim2.new(0,3,0,0)
PremIco.BackgroundTransparency=1; PremIco.Text="👑"
PremIco.Font=Enum.Font.GothamBold; PremIco.TextSize=8
PremIco.ZIndex=6; PremIco.Parent=PremBadge

local PremLbl=Instance.new("TextLabel")
PremLbl.Size=UDim2.new(1,-20,1,0); PremLbl.Position=UDim2.new(0,18,0,0)
PremLbl.BackgroundTransparency=1; PremLbl.Text="Premium"
PremLbl.TextColor3=C.sky; PremLbl.Font=Enum.Font.GothamBold
PremLbl.TextSize=8; PremLbl.TextXAlignment=Enum.TextXAlignment.Left
PremLbl.ZIndex=6; PremLbl.Parent=PremBadge

-- ---- TABS ----
local tabDefs = {
    {name="Combat"},
    {name="Movement"},
    {name="Visuals"},
    {name="Utility"},
    {name="Keybinds"},
    {name="Settings"},
}

local TabList=Instance.new("ScrollingFrame")
TabList.Size=UDim2.new(1,-10,1,-(196+110))   -- reduced height to give PromoCard more room
TabList.Position=UDim2.new(0,5,0,196)
TabList.BackgroundTransparency=1; TabList.ZIndex=3; TabList.Parent=Sidebar
TabList.ScrollBarThickness=2; TabList.ScrollBarImageColor3=C.sky
TabList.AutomaticCanvasSize=Enum.AutomaticSize.Y; TabList.CanvasSize=UDim2.new(0,0,0,0)
TabList.BorderSizePixel=0; TabList.ScrollingDirection=Enum.ScrollingDirection.Y
do local l=Instance.new("UIListLayout"); l.SortOrder=Enum.SortOrder.LayoutOrder; l.Padding=UDim.new(0,5); l.Parent=TabList end
do local p=Instance.new("UIPadding"); p.PaddingBottom=UDim.new(0,6); p.Parent=TabList end

-- ---- PROMO CARD — fixed 70px tall, sits between tab list and footer ----
-- TabList ends at: 196 + (H - 196 - 110) = H - 110 = 310
-- PromoCard: 310 + 4gap = Y:314, height=70, bottom=384, footer top=390. Clean fit.
local TABLIST_BOTTOM = H - 110           -- where tab list ends (matches new TabList height)
local PROMO_TOP_GAP  = 4                 -- gap between tab list bottom and promo card
local PROMO_BOT_GAP  = 4                 -- gap between promo card and footer divider
local PROMO_H = 68                       -- fixed height — big enough to show logo clearly
local PROMO_Y = TABLIST_BOTTOM + PROMO_TOP_GAP

local PromoCard=Instance.new("ImageLabel")
PromoCard.AnchorPoint=Vector2.new(0.5, 0)
PromoCard.Size=UDim2.new(1,-5,0,PROMO_H)
PromoCard.Position=UDim2.new(0.5,0,0,PROMO_Y)
PromoCard.BackgroundColor3=Color3.fromRGB(5,8,18)
PromoCard.BackgroundTransparency=0
PromoCard.Image="rbxassetid://133739031801572"
PromoCard.ScaleType=Enum.ScaleType.Fit   -- Fit so logo is fully shown and as large as possible
PromoCard.BorderSizePixel=0; PromoCard.ZIndex=3
PromoCard.ClipsDescendants=false
PromoCard.Parent=Sidebar
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,10); c.Parent=PromoCard end

local tabBtns   = {}
local tabSFs    = {}
local tabStrokes= {}
local activeTab = nil

-- ================================================
-- CONTENT AREA
-- ================================================
-- RightPanel has UICorner on all 4 corners. Sidebar has ZIndex=3 > RightPanel ZIndex=2,
-- so Sidebar naturally paints over RightPanel's left rounded corners. No patch needed.
local RightPanel=Instance.new("Frame")
RightPanel.Size=UDim2.new(1,-SB_W,1,0)
RightPanel.Position=UDim2.new(0,SB_W,0,0)
RightPanel.BackgroundColor3=C.content
RightPanel.BorderSizePixel=0; RightPanel.ZIndex=2; RightPanel.Parent=Main
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,CORNER); c.Parent=RightPanel end

-- Blue aura glow on content side (top-right area)
local AuraGlow=Instance.new("Frame")
AuraGlow.Size=UDim2.new(0,320,0,180)
AuraGlow.Position=UDim2.new(1,-300,0,-40)
AuraGlow.BackgroundTransparency=1
AuraGlow.BorderSizePixel=0; AuraGlow.ZIndex=1; AuraGlow.Parent=RightPanel
do
    local grd=Instance.new("UIGradient")
    grd.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30,80,200)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10,11,15)),
    })
    grd.Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.55),
        NumberSequenceKeypoint.new(1, 1),
    })
    grd.Rotation=135; grd.Parent=AuraGlow
end
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=AuraGlow end

-- Top bar inside right panel — has UICorner on top-right to match the RightPanel curve
local TopBar=Instance.new("Frame")
TopBar.Size=UDim2.new(1,0,0,TOP_H)
TopBar.Position=UDim2.new(0,0,0,0)
TopBar.BackgroundColor3=C.topbar
TopBar.BorderSizePixel=0; TopBar.ZIndex=5; TopBar.Parent=RightPanel
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,CORNER); c.Parent=TopBar end
-- Patch bottom-left and bottom-right back to square (extend slightly past corner for clean coverage)
do local f=Instance.new("Frame")
   f.Size=UDim2.new(1,0,0,CORNER+2); f.Position=UDim2.new(0,0,1,-(CORNER+2))
   f.BackgroundColor3=C.topbar; f.BorderSizePixel=0; f.ZIndex=6; f.Parent=TopBar end

-- Title "KNOX HUB"
local TitleLbl=Instance.new("TextLabel")
TitleLbl.Size=UDim2.new(0,260,0,28)
TitleLbl.Position=UDim2.new(0,20,0,6)
TitleLbl.BackgroundTransparency=1; TitleLbl.Text="KNOX HUB"
TitleLbl.TextColor3=C.white; TitleLbl.Font=Enum.Font.GothamBlack
TitleLbl.TextSize=22; TitleLbl.TextXAlignment=Enum.TextXAlignment.Left
TitleLbl.ZIndex=6; TitleLbl.Parent=TopBar
-- Shimmer gradient on title
do
    local tg=Instance.new("UIGradient")
    tg.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140,210,255)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(255,255,255)),
    })
    tg.Rotation=0; tg.Parent=TitleLbl
    -- Animate shimmer sweep
    local shimAngle=0
    RunService.Heartbeat:Connect(function(dt)
        shimAngle=(shimAngle+22*dt)%360
        tg.Rotation=shimAngle
    end)
end

-- Subtitle
local SubLbl=Instance.new("TextLabel")
SubLbl.Size=UDim2.new(0,300,0,16)
SubLbl.Position=UDim2.new(0,20,0,33)
SubLbl.BackgroundTransparency=1; SubLbl.Text="Dominate the game. Stay ahead."
SubLbl.TextColor3=C.dim; SubLbl.Font=Enum.Font.Gotham
SubLbl.TextSize=11; SubLbl.TextXAlignment=Enum.TextXAlignment.Left
SubLbl.ZIndex=6; SubLbl.Parent=TopBar

-- Minimize button
local MinBtn=Instance.new("TextButton")
MinBtn.Size=UDim2.new(0,28,0,28); MinBtn.Position=UDim2.new(1,-68,0.5,-14)
MinBtn.BackgroundColor3=C.row; MinBtn.BorderSizePixel=0
MinBtn.Text="–"; MinBtn.TextColor3=C.white
MinBtn.Font=Enum.Font.GothamBlack; MinBtn.TextSize=16
MinBtn.ZIndex=7; MinBtn.Parent=TopBar
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,10); c.Parent=MinBtn end
do local s=Instance.new("UIStroke"); s.Color=C.divider; s.Parent=MinBtn end
MinBtn.MouseEnter:Connect(function() MinBtn.BackgroundColor3=C.rowHover end)
MinBtn.MouseLeave:Connect(function() MinBtn.BackgroundColor3=C.row end)

-- Close button
local CloseBtn=Instance.new("TextButton")
CloseBtn.Size=UDim2.new(0,28,0,28); CloseBtn.Position=UDim2.new(1,-32,0.5,-14)
CloseBtn.BackgroundColor3=C.row; CloseBtn.BorderSizePixel=0
CloseBtn.Text="×"; CloseBtn.TextColor3=C.white
CloseBtn.Font=Enum.Font.GothamBlack; CloseBtn.TextSize=18
CloseBtn.ZIndex=7; CloseBtn.Parent=TopBar
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,10); c.Parent=CloseBtn end
do local s=Instance.new("UIStroke"); s.Color=C.divider; s.Parent=CloseBtn end
CloseBtn.MouseEnter:Connect(function() CloseBtn.BackgroundColor3=Color3.fromRGB(160,30,30) end)
CloseBtn.MouseLeave:Connect(function() CloseBtn.BackgroundColor3=C.row end)
CloseBtn.MouseButton1Click:Connect(function()
    -- Close confirmation dialog
    local overlay=Instance.new("Frame")
    overlay.Size=UDim2.new(1,0,1,0); overlay.Position=UDim2.new(0,0,0,0)
    overlay.BackgroundColor3=Color3.fromRGB(0,0,0); overlay.BackgroundTransparency=0.45
    overlay.BorderSizePixel=0; overlay.ZIndex=50; overlay.Active=true; overlay.Parent=Main

    local dialog=Instance.new("Frame")
    dialog.Size=UDim2.new(0,260,0,110); dialog.Position=UDim2.new(0.5,-130,0.5,-55)
    dialog.BackgroundColor3=Color3.fromRGB(13,14,20); dialog.BorderSizePixel=0; dialog.ZIndex=51; dialog.Parent=overlay
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,16); c.Parent=dialog end
    do local s=Instance.new("UIStroke"); s.Color=C.divider; s.Thickness=1.5; s.Parent=dialog end

    local dlgTitle=Instance.new("TextLabel")
    dlgTitle.Size=UDim2.new(1,0,0,32); dlgTitle.Position=UDim2.new(0,0,0,14)
    dlgTitle.BackgroundTransparency=1; dlgTitle.Text="Close Knox Hub?"
    dlgTitle.TextColor3=C.white; dlgTitle.Font=Enum.Font.GothamBlack; dlgTitle.TextSize=14
    dlgTitle.ZIndex=52; dlgTitle.Parent=dialog

    local dlgSub=Instance.new("TextLabel")
    dlgSub.Size=UDim2.new(1,-20,0,16); dlgSub.Position=UDim2.new(0,10,0,44)
    dlgSub.BackgroundTransparency=1; dlgSub.Text="Are you sure you want to close?"
    dlgSub.TextColor3=C.dim; dlgSub.Font=Enum.Font.Gotham; dlgSub.TextSize=11
    dlgSub.ZIndex=52; dlgSub.Parent=dialog

    local yesBtn=Instance.new("TextButton")
    yesBtn.Size=UDim2.new(0,100,0,28); yesBtn.Position=UDim2.new(0.5,-108,1,-40)
    yesBtn.BackgroundColor3=Color3.fromRGB(160,30,30); yesBtn.BorderSizePixel=0
    yesBtn.Text="Yes, Close"; yesBtn.TextColor3=C.white; yesBtn.Font=Enum.Font.GothamBold; yesBtn.TextSize=12
    yesBtn.ZIndex=52; yesBtn.Parent=dialog
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=yesBtn end
    yesBtn.MouseButton1Click:Connect(function() SG:Destroy() end)

    local noBtn=Instance.new("TextButton")
    noBtn.Size=UDim2.new(0,100,0,28); noBtn.Position=UDim2.new(0.5,8,1,-40)
    noBtn.BackgroundColor3=C.row; noBtn.BorderSizePixel=0
    noBtn.Text="Cancel"; noBtn.TextColor3=C.white; noBtn.Font=Enum.Font.GothamBold; noBtn.TextSize=12
    noBtn.ZIndex=52; noBtn.Parent=dialog
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=noBtn end
    do local s=Instance.new("UIStroke"); s.Color=C.divider; s.Parent=noBtn end
    noBtn.MouseButton1Click:Connect(function() overlay:Destroy() end)
end)

-- (TBDiv removed — not present in reference design)

-- Drag via topbar
local dragging,dragInput,dragStart,dragStartPos
TopBar.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=inp.Position; dragStartPos=Main.Position
        inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end)
    end
end)
TopBar.InputChanged:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then dragInput=inp end
end)
UserInputService.InputChanged:Connect(function(inp)
    if inp==dragInput and dragging and not cfg.lockUI then
        local d=inp.Position-dragStart
        Main.Position=UDim2.new(dragStartPos.X.Scale,dragStartPos.X.Offset+d.X,dragStartPos.Y.Scale,dragStartPos.Y.Offset+d.Y)
    end
end)

-- ---- BANNER IMAGE ----
-- Centered in the right panel content area, full width with symmetric margins
local BannerFrame=Instance.new("Frame")
BannerFrame.Size=UDim2.new(1,-28,0,110)
BannerFrame.Position=UDim2.new(0,14,0,TOP_H+6)
BannerFrame.BackgroundColor3=Color3.fromRGB(5,10,20)
BannerFrame.BorderSizePixel=0; BannerFrame.ZIndex=4; BannerFrame.ClipsDescendants=true
BannerFrame.Parent=RightPanel
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,14); c.Parent=BannerFrame end

local BannerImg=Instance.new("ImageLabel")
BannerImg.Size=UDim2.new(1,0,1,0)
BannerImg.BackgroundTransparency=1
BannerImg.Image="rbxassetid://134635591778411"
BannerImg.ScaleType=Enum.ScaleType.Stretch
BannerImg.ZIndex=5; BannerImg.Parent=BannerFrame

-- ---- TAB NAME LABEL + inline divider ----
local LABEL_Y = TOP_H + 6 + 110 + 12   -- 12px below banner bottom (increased gap)
local LABEL_H = 16

-- TAB NAME LABEL — auto-width so we can measure it
local TabNameLbl=Instance.new("TextLabel")
TabNameLbl.Size=UDim2.new(0,0,0,LABEL_H)
TabNameLbl.AutomaticSize=Enum.AutomaticSize.X
TabNameLbl.Position=UDim2.new(0,14,0,LABEL_Y)
TabNameLbl.BackgroundTransparency=1; TabNameLbl.Text="COMBAT"
TabNameLbl.TextColor3=Color3.new(1,1,1)   -- white base so UIGradient colours show fully
TabNameLbl.Font=Enum.Font.GothamBlack
TabNameLbl.TextSize=11; TabNameLbl.TextXAlignment=Enum.TextXAlignment.Left
TabNameLbl.ZIndex=6; TabNameLbl.Parent=RightPanel
-- Gradient: deep navy → teal → white → teal → deep navy (matches tab stroke gradient)
do
    local tg=Instance.new("UIGradient")
    tg.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(0,  10,  40)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(0, 160, 180)),
        ColorSequenceKeypoint.new(0.5,  Color3.new(1,  1,  1  )),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(0, 160, 180)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(0,  10,  40)),
    })
    tg.Rotation=0; tg.Parent=TabNameLbl
    -- Slow sweep left→right so gradient animates across the text
    local angle=0
    RunService.Heartbeat:Connect(function(dt)
        angle=(angle+18*dt)%360
        tg.Rotation=angle
    end)
end

-- DIVIDER LINE — spans the FULL width of RightPanel (touching both edges),
-- positioned 2px below the bottom of the label text so it never overlaps it.
-- The label (ZIndex=6) sits above the divider (ZIndex=5) so text is always readable.
local DIV_Y = LABEL_Y + LABEL_H + 2   -- 2px gap below text baseline
local TabDivLine=Instance.new("Frame")
TabDivLine.Size=UDim2.new(1,0,0,1)    -- full panel width, touches both sides
TabDivLine.Position=UDim2.new(0,0,0,DIV_Y)
TabDivLine.BackgroundColor3=Color3.fromRGB(45,52,75); TabDivLine.BorderSizePixel=0
TabDivLine.ZIndex=5; TabDivLine.Parent=RightPanel

-- ---- CONTENT SCROLLFRAME ----
local contentTop = DIV_Y + 1 + 4   -- 4px gap below the divider line
local contentBot = FOOT_H + 4
local ContentArea=Instance.new("Frame")
ContentArea.Name="ContentArea"
ContentArea.Size=UDim2.new(1,-30,1,-(contentTop+contentBot))
ContentArea.Position=UDim2.new(0,15,0,contentTop)
ContentArea.BackgroundTransparency=1
ContentArea.ClipsDescendants=true
ContentArea.BorderSizePixel=0; ContentArea.ZIndex=3; ContentArea.Parent=RightPanel

-- ================================================
-- FEATURE REGISTRATION API
-- ================================================
function _G.KnoxHub.addFeatureToTab(tabName, featureFrame)
    local sf = tabSFs[tabName]
    if sf then featureFrame.Parent = sf; return true end
    return false
end
function _G.KnoxHub.getTabFrame(tabName) return tabSFs[tabName] end

-- ---- FOOTER ----
local Footer=Instance.new("Frame")
Footer.Size=UDim2.new(1,0,0,FOOT_H)
Footer.Position=UDim2.new(0,0,1,-FOOT_H)
Footer.BackgroundColor3=C.footer
Footer.BorderSizePixel=0; Footer.ZIndex=5; Footer.Parent=RightPanel
-- Round bottom corners of footer to match RightPanel's UICorner
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,CORNER); c.Parent=Footer end
-- Patch ONLY the top-left corner of the footer back to square (interior join with content area).
-- We leave the top-right region alone so the bottom-right outer curve of RightPanel
-- is never covered by a rectangular patch — eliminating the |_ artifact at bottom-right.
-- The patch width stops CORNER+2 px short of the right edge.
do local f=Instance.new("Frame")
   f.Size=UDim2.new(1,-(CORNER+2),0,CORNER+2); f.Position=UDim2.new(0,0,0,0)
   f.BackgroundColor3=C.footer; f.BorderSizePixel=0; f.ZIndex=6; f.Parent=Footer end

-- Footer divider parented to RightPanel — spans from left edge of RightPanel to right edge
-- This means it naturally starts exactly where sidebar ends (no cover hack needed)
local FtDiv=Instance.new("Frame")
FtDiv.Size=UDim2.new(1,0,0,1); FtDiv.Position=UDim2.new(0,0,1,-FOOT_H)
FtDiv.BackgroundColor3=Color3.fromRGB(45,52,75); FtDiv.BorderSizePixel=0; FtDiv.ZIndex=5; FtDiv.Parent=RightPanel

local FtDiscord=Instance.new("TextLabel")
FtDiscord.Size=UDim2.new(0.5,0,1,0); FtDiscord.Position=UDim2.new(0,16,0,0)
FtDiscord.BackgroundTransparency=1; FtDiscord.Text="discord.gg/BAeRX4wPB"
FtDiscord.TextColor3=C.sky; FtDiscord.Font=Enum.Font.Gotham
FtDiscord.TextSize=11; FtDiscord.TextXAlignment=Enum.TextXAlignment.Left
FtDiscord.ZIndex=6; FtDiscord.Parent=Footer

local FtCredit=Instance.new("TextLabel")
FtCredit.Size=UDim2.new(0.5,0,1,0); FtCredit.Position=UDim2.new(0.5,-16,0,0)
FtCredit.BackgroundTransparency=1; FtCredit.Text="Made by Knox Team"
FtCredit.TextColor3=C.sky; FtCredit.Font=Enum.Font.GothamBold
FtCredit.TextSize=11; FtCredit.TextXAlignment=Enum.TextXAlignment.Right
FtCredit.ZIndex=6; FtCredit.Parent=Footer

-- Footer text pulse animation (white <-> sky blue cycle, offset so they alternate)
local footerColors={
    Color3.fromRGB(70,170,255),
    Color3.fromRGB(120,195,255),
    Color3.fromRGB(180,225,255),
    Color3.fromRGB(245,247,255),
    Color3.fromRGB(180,225,255),
    Color3.fromRGB(120,195,255),
}
local ftIdx1,ftIdx2=1,4  -- offset by half cycle so they pulse alternately
local ftTick=0
RunService.Heartbeat:Connect(function(dt)
    ftTick=ftTick+dt
    if ftTick>=0.38 then
        ftTick=0
        ftIdx1=(ftIdx1%#footerColors)+1
        ftIdx2=(ftIdx2%#footerColors)+1
        TweenService:Create(FtDiscord,TweenInfo.new(0.35,Enum.EasingStyle.Sine),{TextColor3=footerColors[ftIdx1]}):Play()
        TweenService:Create(FtCredit, TweenInfo.new(0.35,Enum.EasingStyle.Sine),{TextColor3=footerColors[ftIdx2]}):Play()
    end
end)

-- ================================================
-- TAB SYSTEM
-- ================================================
local function setTab(name)
    activeTab=name
    TabNameLbl.Text=string.upper(name)
    for n,b in pairs(tabBtns) do
        local act=(n==name)
        if act then
            b.BackgroundColor3=C.tabActive
            b.BackgroundTransparency=0
            -- Add left-edge accent glow if not present
            if not b:FindFirstChild("TabAccentGlow") then
                local glow=Instance.new("Frame")
                glow.Name="TabAccentGlow"
                glow.Size=UDim2.new(0,3,1,-8)
                glow.Position=UDim2.new(0,0,0,4)
                glow.BackgroundColor3=Color3.fromRGB(0,200,220)  -- teal accent
                glow.BorderSizePixel=0; glow.ZIndex=6; glow.Parent=b
                do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=glow end
                -- Soft radial bloom behind the bar
                local bloom=Instance.new("Frame")
                bloom.Name="TabAccentBloom"
                bloom.Size=UDim2.new(0,28,1,-4)
                bloom.Position=UDim2.new(0,0,0,2)
                bloom.BackgroundColor3=Color3.fromRGB(0,180,210)
                bloom.BackgroundTransparency=0; bloom.BorderSizePixel=0; bloom.ZIndex=5; bloom.Parent=b
                do
                    local g=Instance.new("UIGradient")
                    g.Color=ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(0,180,210)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(22,28,88)),
                    })
                    g.Transparency=NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.50),
                        NumberSequenceKeypoint.new(1, 1),
                    })
                    g.Rotation=0; g.Parent=bloom
                end
                do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=bloom end
            end
        else
            b.BackgroundTransparency=1
            -- Remove accent glow when inactive
            local glow=b:FindFirstChild("TabAccentGlow")
            if glow then glow:Destroy() end
            local bloom=b:FindFirstChild("TabAccentBloom")
            if bloom then bloom:Destroy() end
        end
        local s=tabStrokes[n]
        if s then
            if act then
                addTabAnimStroke(s)   -- sets Color=white, Thickness=1.8, attaches gradient
            else
                removeTabAnimStroke(s)
                s.Thickness=0
                s.Color=C.divider
            end
        end
        local lbl=b:FindFirstChild("TabLabel")
        if lbl then TweenService:Create(lbl,TweenInfo.new(0.15),{TextColor3=act and C.white or C.dim}):Play() end
    end
    for n,s in pairs(tabSFs) do s.Visible=(n==name) end
end

for i,td in ipairs(tabDefs) do
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,0,36)
    btn.BackgroundColor3=C.tabInact
    btn.BackgroundTransparency=1
    btn.BorderSizePixel=0; btn.Text=""
    btn.ZIndex=4; btn.LayoutOrder=i; btn.Parent=TabList
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,12); c.Parent=btn end
    local ts=Instance.new("UIStroke"); ts.Color=C.divider; ts.Thickness=1; ts.Parent=btn
    tabStrokes[td.name]=ts

    local lbl=Instance.new("TextLabel")
    lbl.Name="TabLabel"
    lbl.Size=UDim2.new(1,-14,1,0); lbl.Position=UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=td.name
    lbl.TextColor3=C.dim; lbl.Font=Enum.Font.GothamBold
    lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.ZIndex=5; lbl.Parent=btn
    tabBtns[td.name]=btn

    local sf=Instance.new("ScrollingFrame")
    sf.Size=UDim2.new(1,0,1,0)
    sf.BackgroundTransparency=1; sf.BorderSizePixel=0
    sf.ScrollBarThickness=3; sf.ScrollBarImageColor3=C.sky
    sf.ScrollBarImageTransparency=0.4
    sf.AutomaticCanvasSize=Enum.AutomaticSize.Y; sf.CanvasSize=UDim2.new(0,0,0,0)
    sf.ScrollingEnabled=true
    sf.ScrollingDirection=Enum.ScrollingDirection.Y   -- vertical only, no horizontal drift
    sf.ElasticBehavior=Enum.ElasticBehavior.Always
    sf.ClipsDescendants=true
    sf.Visible=false; sf.ZIndex=3; sf.Parent=ContentArea
    do local l=Instance.new("UIListLayout"); l.SortOrder=Enum.SortOrder.LayoutOrder; l.Padding=UDim.new(0,5); l.Parent=sf end
    do local p=Instance.new("UIPadding"); p.PaddingLeft=UDim.new(0,0); p.PaddingRight=UDim.new(0,6); p.PaddingTop=UDim.new(0,4); p.PaddingBottom=UDim.new(0,8); p.Parent=sf end
    tabSFs[td.name]=sf

    btn.Activated:Connect(function() setTab(td.name) end)
    btn.MouseEnter:Connect(function()
        if activeTab~=td.name then
            btn.BackgroundColor3=C.tabHover; btn.BackgroundTransparency=0
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab~=td.name then
            btn.BackgroundTransparency=1
        end
    end)
end

-- ================================================
-- GLOBAL API — fully populated now all vars exist
-- ================================================
_G.KnoxHub.GUI            = SG
_G.KnoxHub.Main           = Main
_G.KnoxHub.cfg            = cfg
_G.KnoxHub.tabSFs         = tabSFs
_G.KnoxHub.tabBtns        = tabBtns
_G.KnoxHub.tabStrokes     = tabStrokes
_G.KnoxHub.setTab         = setTab
_G.KnoxHub.makeToggle     = makeToggle
_G.KnoxHub.makeInput      = makeInput
_G.KnoxHub.makeKeybind    = makeKeybind
_G.KnoxHub.makeSectionHeader = makeSectionHeader
_G.KnoxHub.C              = C
_G.KnoxHub.addAnimStroke  = addAnimStroke
_G.KnoxHub.removeAnimStroke = removeAnimStroke
_G.KnoxHub.activeTab      = function() return activeTab end

-- ================================================
-- ROW BUILDERS
-- ================================================
local function hoverRow(f)
    f.MouseEnter:Connect(function() f.BackgroundColor3=C.rowHover end)
    f.MouseLeave:Connect(function() f.BackgroundColor3=C.row end)
end

function makeSectionHeader(parent,text,order)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,26)
    f.BackgroundTransparency=1; f.LayoutOrder=order; f.Parent=parent
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(0,100,0,18); l.Position=UDim2.new(0,2,0,0)
    l.BackgroundTransparency=1; l.Text=text
    l.TextColor3=C.sky; l.Font=Enum.Font.GothamBlack; l.TextSize=11
    l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=4; l.Parent=f
    -- Divider line flush left to right edge, same color as sidebar/section dividers
    local d=Instance.new("Frame"); d.Size=UDim2.new(1,0,0,1); d.Position=UDim2.new(0,0,1,-1)
    d.BackgroundColor3=Color3.fromRGB(45,52,75); d.BorderSizePixel=0; d.ZIndex=4; d.Parent=f
end

function makeToggle(parent,text,order,cb)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,40)
    f.BackgroundColor3=C.row; f.BorderSizePixel=0; f.LayoutOrder=order; f.Parent=parent
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,12); c.Parent=f end
    do local s=Instance.new("UIStroke"); s.Color=C.divider; s.Thickness=1; s.Parent=f end

    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-70,1,0); lbl.Position=UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=text; lbl.TextColor3=C.white
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.ZIndex=5; lbl.Parent=f

    local bg=Instance.new("Frame"); bg.Size=UDim2.new(0,46,0,26); bg.Position=UDim2.new(1,-56,0.5,-13)
    bg.BackgroundColor3=C.togOff; bg.BorderSizePixel=0; bg.ZIndex=5; bg.Parent=f
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=bg end
    local ts=Instance.new("UIStroke"); ts.Thickness=1.5; ts.Color=C.divider; ts.Parent=bg

    local dot=Instance.new("Frame"); dot.Size=UDim2.new(0,20,0,20); dot.Position=UDim2.new(0,3,0.5,-10)
    dot.BackgroundColor3=C.dotOff; dot.BorderSizePixel=0; dot.ZIndex=6; dot.Parent=bg
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=dot end

    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0)
    btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=7; btn.Parent=bg

    local on=false
    local function upd()
        if on then
            TweenService:Create(bg,TweenInfo.new(0.18),{BackgroundColor3=C.togOn}):Play()
            TweenService:Create(dot,TweenInfo.new(0.18),{Position=UDim2.new(1,-23,0.5,-10),BackgroundColor3=C.dotOn}):Play()
            addElemMarchStroke(ts)
        else
            TweenService:Create(bg,TweenInfo.new(0.18),{BackgroundColor3=C.togOff}):Play()
            TweenService:Create(dot,TweenInfo.new(0.18),{Position=UDim2.new(0,3,0.5,-10),BackgroundColor3=C.dotOff}):Play()
            removeElemMarchStroke(ts)
            TweenService:Create(ts,TweenInfo.new(0.1),{Color=C.divider}):Play()
        end
    end
    btn.Activated:Connect(function() on=not on; upd(); if cb then cb(on) end end)
    hoverRow(f)
    return f, function(v) on=v; upd() end
end

function makeInput(parent,text,def,order,cb)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,40)
    f.BackgroundColor3=C.row; f.BorderSizePixel=0; f.LayoutOrder=order; f.Parent=parent
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,12); c.Parent=f end
    do local s=Instance.new("UIStroke"); s.Color=C.divider; s.Thickness=1; s.Parent=f end

    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-90,1,0); lbl.Position=UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=text; lbl.TextColor3=C.white
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.ZIndex=5; lbl.Parent=f

    local box=Instance.new("TextBox"); box.Size=UDim2.new(0,66,0,24); box.Position=UDim2.new(1,-76,0.5,-12)
    box.BackgroundColor3=C.inputBg; box.BorderSizePixel=0; box.Text=tostring(def)
    box.TextColor3=C.white
    box.Font=Enum.Font.GothamBold; box.TextSize=12
    box.ClearTextOnFocus=false; box.ZIndex=6; box.Parent=f
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=box end
    do local s=Instance.new("UIStroke"); s.Color=C.divider; s.ZIndex=7; s.Parent=box end
    box.FocusLost:Connect(function() local v=tonumber(box.Text); if v and cb then cb(v) end end)
    hoverRow(f); return f, box
end

function makeKeybind(parent,text,key,order,cb)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,40)
    f.BackgroundColor3=C.row; f.BorderSizePixel=0; f.LayoutOrder=order; f.Parent=parent
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,12); c.Parent=f end
    do local s=Instance.new("UIStroke"); s.Color=C.divider; s.Thickness=1; s.Parent=f end

    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-90,1,0); lbl.Position=UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=text; lbl.TextColor3=C.white
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.ZIndex=5; lbl.Parent=f

    local kb=Instance.new("TextButton"); kb.Size=UDim2.new(0,66,0,24); kb.Position=UDim2.new(1,-76,0.5,-12)
    kb.BackgroundColor3=C.kbBg; kb.BorderSizePixel=0; kb.Text=key
    kb.TextColor3=C.white; kb.Font=Enum.Font.GothamBold; kb.TextSize=10; kb.ZIndex=6; kb.Parent=f
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=kb end
    do local s=Instance.new("UIStroke"); s.Color=C.divider; s.Parent=kb end

    local rowBtn=Instance.new("TextButton"); rowBtn.Size=UDim2.new(0.65,0,1,0)
    rowBtn.BackgroundTransparency=1; rowBtn.Text=""; rowBtn.ZIndex=4; rowBtn.Active=true; rowBtn.Parent=f
    rowBtn.Activated:Connect(function() if cb then cb() end end)
    hoverRow(f); return f, kb
end

-- ================================================
-- SETTINGS TAB
-- ================================================
local BB -- forward declare so toggle callback can reference it safely
local setsSF=tabSFs["Settings"]
makeSectionHeader(setsSF,"INTERFACE",1)
makeInput(setsSF,"UI Scale",100,2,function(v) UIScaleInst.Scale=v/100 end)
makeKeybind(setsSF,"Hide / Show GUI","LeftCtrl",3,nil)
makeSectionHeader(setsSF,"BILLBOARD",4)

local _,setBillboard=makeToggle(setsSF,"Billboard (Speed / Mode)",5,function(v)
    cfg.billboardEnabled=v
    task.defer(function()
        if BB then BB.Enabled=v end
    end)
end)

-- ================================================
-- BILLBOARD GUI
-- ================================================
BB=Instance.new("BillboardGui")
BB.Name="KnoxBillboard"; BB.Size=UDim2.new(0,160,0,52)
BB.StudsOffset=Vector3.new(0,3.5,0); BB.AlwaysOnTop=true; BB.Enabled=false
BB.LightInfluence=0
BB.Parent=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or SG

local SpeedLbl=Instance.new("TextLabel")
SpeedLbl.Size=UDim2.new(1,0,0,26); SpeedLbl.Position=UDim2.new(0,0,0,0)
SpeedLbl.BackgroundTransparency=1
SpeedLbl.Text="0.0"; SpeedLbl.TextColor3=C.white; SpeedLbl.Font=Enum.Font.GothamBold
SpeedLbl.TextScaled=true; SpeedLbl.TextStrokeTransparency=0
SpeedLbl.TextStrokeColor3=Color3.new(0,0,0); SpeedLbl.Parent=BB

local ModeLbl=Instance.new("TextLabel")
ModeLbl.Size=UDim2.new(1,0,0,22); ModeLbl.Position=UDim2.new(0,0,0,28)
ModeLbl.BackgroundTransparency=1; ModeLbl.Text="Normal"
ModeLbl.TextColor3=C.sky; ModeLbl.Font=Enum.Font.GothamBold; ModeLbl.TextScaled=true
ModeLbl.TextStrokeTransparency=0.1; ModeLbl.TextStrokeColor3=Color3.new(0,0,0); ModeLbl.Parent=BB

-- Live speed update loop
local bbSpeedConn = RunService.Heartbeat:Connect(function()
    if not BB.Enabled then return end
    local hrp = getHRP()
    if hrp then
        local vel = hrp.Velocity
        local speed = math.sqrt(vel.X*vel.X + vel.Z*vel.Z)
        SpeedLbl.Text = string.format("%.1f", speed)
    end
end)

-- Mode state — updated by toggles/external code
local bbMode = "Normal"
local function setBBMode(mode)
    bbMode = mode
    ModeLbl.Text = mode
end
-- expose so other scripts can call: _G.KnoxHub.setBBMode("Flying")
_G.KnoxHub.setBBMode = setBBMode

-- ================================================
-- KNOX MINI BUTTON (toggle/reopen button)
-- Larger box so KNOX text is readable; wings overflow outside button border for effect.
-- Animated: logo bobs up/down (flying) and wings pulse scale.
-- ================================================
local MINI_W = 90   -- wide enough to show KNOX text clearly
local MINI_H = 50

local KnoxMini=Instance.new("Frame")
KnoxMini.Name="KnoxMini"; KnoxMini.Size=UDim2.new(0,MINI_W,0,MINI_H)
KnoxMini.Position=UDim2.new(0,40,0,40)
KnoxMini.BackgroundColor3=Color3.fromRGB(13,14,22)
KnoxMini.BorderSizePixel=0; KnoxMini.ClipsDescendants=false
KnoxMini.ZIndex=20; KnoxMini.Visible=false; KnoxMini.Active=true; KnoxMini.Parent=SG
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,18); c.Parent=KnoxMini end
local MiniStroke=Instance.new("UIStroke")
MiniStroke.Thickness=2; MiniStroke.Color=bSeq[1]
MiniStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; MiniStroke.Parent=KnoxMini
addAnimStroke(MiniStroke)

-- Logo image: sized LARGER than the button so wings bleed outside the border
-- ClipsDescendants=false on KnoxMini allows this overflow
local MiniLogo=Instance.new("ImageLabel")
MiniLogo.Size=UDim2.new(0,MINI_W+28,0,MINI_H+20)   -- 14px overflow each side horizontally, 10px top+bottom
MiniLogo.Position=UDim2.new(0,-14,0,-10)             -- centered overflow
MiniLogo.BackgroundTransparency=1
MiniLogo.Image="rbxassetid://120025299102610"
MiniLogo.ScaleType=Enum.ScaleType.Fit
MiniLogo.ZIndex=21; MiniLogo.Parent=KnoxMini

-- Flying animation: smooth bob + sway + wing pulse scale — all in one loop
local miniLogoT = 0
RunService.Heartbeat:Connect(function(dt)
    if not KnoxMini.Visible then return end
    miniLogoT = miniLogoT + dt
    local scale = 1 + math.sin(miniLogoT * 3.5) * 0.06  -- ±6% scale pulse
    local w = (MINI_W + 28) * scale
    local h = (MINI_H + 20) * scale
    local ox = -14 - (w - (MINI_W+28)) * 0.5
    local oy = -10 - (h - (MINI_H+20)) * 0.5
    local bobY = math.sin(miniLogoT * 2.8) * 4          -- 4px vertical bob
    local sway = math.sin(miniLogoT * 1.4) * 1.5        -- subtle horizontal sway
    MiniLogo.Size = UDim2.new(0, w, 0, h)
    MiniLogo.Position = UDim2.new(0, ox + sway, 0, oy + bobY)
end)

do
    local md,ms,mp
    local MiniBtn=Instance.new("TextButton")
    MiniBtn.Size=UDim2.new(1,0,1,0); MiniBtn.BackgroundTransparency=1; MiniBtn.Text=""
    MiniBtn.ZIndex=22; MiniBtn.Parent=KnoxMini
    MiniBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            md=true; ms=inp.Position; mp=KnoxMini.Position
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then md=false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if md and not cfg.lockUI and
          (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-ms
            KnoxMini.Position=UDim2.new(mp.X.Scale,mp.X.Offset+d.X,mp.Y.Scale,mp.Y.Offset+d.Y)
        end
    end)
    MiniBtn.MouseButton1Click:Connect(function()
        Main.Visible=true; KnoxMini.Visible=false
    end)
end

MinBtn.MouseButton1Click:Connect(function() Main.Visible=false; KnoxMini.Visible=true end)

setTab("Combat")

-- ================================================
-- CHARACTER INIT
-- ================================================
local charConnection
local function onChar(char)
    local hrp=char:WaitForChild("HumanoidRootPart",10); if not hrp then return end
    BB.Adornee=hrp
    BB.Parent=hrp  -- re-parent to actual HRP so it renders above head
    BB.Enabled=cfg.billboardEnabled
end
if LocalPlayer.Character then task.spawn(onChar,LocalPlayer.Character) end
charConnection = LocalPlayer.CharacterAdded:Connect(onChar)

-- Cleanup function for re-execution safety
_G.KnoxHub_Cleanup = function()
    pcall(function() if charConnection then charConnection:Disconnect() end end)
    pcall(function() if bbSpeedConn then bbSpeedConn:Disconnect() end end)
    pcall(function() if BB then BB:Destroy() end end)
    pcall(function() if SG then SG:Destroy() end end)
end

-- ================================================
-- KEYBOARD INPUT (UI only)
-- ================================================
UserInputService.InputBegan:Connect(function(inp,gpe)
    if gpe then return end
    if inp.KeyCode==cfg.hideKey then
        Main.Visible=not Main.Visible; KnoxMini.Visible=not Main.Visible
    end
end)
