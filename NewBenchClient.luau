--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Modules = Assets:WaitForChild("Modules")
local GroupModule = require(Modules:WaitForChild("GroupModule"))
local OtherModule = require(Modules:WaitForChild("OtherModule"))
local IRSystem = ReplicatedStorage:WaitForChild("IR_System")
local SaberParts = IRSystem:WaitForChild("SaberParts")
local Workbench = IRSystem:WaitForChild("Workbench")
local Remote = Workbench:WaitForChild("Remote")
local Settings = require(SaberParts:WaitForChild("SaberParts"))

local Module = {}

function Module.Initialize()
	task.wait(0.5)

	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Humanoid = Character:WaitForChild("Humanoid")
	local Root = Character:WaitForChild("HumanoidRootPart")
	local UI = Player.PlayerGui:FindFirstChild("IRWorkbenchUi")
	local ShopUI = Player.PlayerGui:FindFirstChild("Shop")
	local PlayerHUD = Player.PlayerGui:FindFirstChild("PlayerHUD")
	local Editor = workspace:WaitForChild("SaberEditor")
	local Editing = false
	local Ignited = false
	local Busy = false
	local CurrentBench
	local BladeModel
	local LastCameraCF = CFrame.identity
	local Rotation = 0
	local InteractPart
	local InteractAttachment
	local EditColorTarget = "Primary"
	local PaintConnections = {}
	local SaberData = {Color="",Hilt="",Emitter="",Pommel="",Primary=Color3.new(1,1,1),Secondary=Color3.new(1,1,1)}

	local function Lock(t)
		if Busy then return false end
		Busy = true
		task.delay(t,function() Busy=false end)
		return true
	end

	local function Lerp(a,b,t) return a+(b-a)*t end
	local function Find(list,key,value) for _,v in ipairs(list) do if v[key]==value then return v end end end
	local function FindFlat(data,key,value) for _,v in ipairs(data) do if v[key]==value then return v end end end

	local function Recolor(model)
		for _,p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name=="PRIMARY" then p.Color=SaberData.Primary
				elseif p.Name=="SECONDARY" then p.Color=SaberData.Secondary end
			end
		end
	end

	local function ClearWorkbench()
		for _,name in ipairs({"Hilt","Emitter","Pommel"}) do
			local obj = Editor.SaberModel:FindFirstChild(name)
			if obj then obj:Destroy() end
		end
	end

	local function TweenTransparency(model)
		for _,p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				local last=p.Transparency
				p.Transparency=1
				TweenService:Create(p,TweenInfo.new(0.2),{Transparency=last}):Play()
			end
		end
	end

	local function ApplyBenchNeon()
		if not CurrentBench or not CurrentBench:FindFirstChild("Neon") then return end
		local c = CurrentBench:FindFirstChild("BenchColor")
		if not c then return end
		for _,v in ipairs(CurrentBench.Neon:GetChildren()) do
			local fromColor = Color3.fromHSV(c.Value:ToHSV())
			v.Color=fromColor
			TweenService:Create(v,TweenInfo.new(1),{Color=c.Value}):Play()
		end
	end

	local function PlaceSaberParts()
		local Hilt = SaberParts.Hilt[SaberData.Hilt]:Clone()
		local Pommel = SaberParts.Pommel[SaberData.Pommel]:Clone()
		local Emitter = SaberParts.Emitter[SaberData.Emitter]:Clone()
		for _,part in ipairs({Hilt,Pommel,Emitter}) do
			for _,p in ipairs(part:GetDescendants()) do if p:IsA("BasePart") then p.Anchored=true end end
			Recolor(part)
		end
		Hilt:SetPrimaryPartCFrame(CurrentBench.SaberSpot.CFrame)
		Pommel:SetPrimaryPartCFrame(Hilt.Pommel.CFrame)
		Emitter:SetPrimaryPartCFrame(Hilt.Emitter.CFrame)
		Hilt.Name="Hilt" Pommel.Name="Pommel" Emitter.Name="Emitter"
		Hilt.Parent=Editor.SaberModel Pommel.Parent=Editor.SaberModel Emitter.Parent=Editor.SaberModel
		Editor.SaberModel.PrimaryPart=Hilt.Primary
		if BladeModel then BladeModel:SetPrimaryPartCFrame(Hilt.Emitter.CFrame) BladeModel.Parent=Editor.SaberModel end
	end

	local function BuildSaber(tweenType)
		ClearWorkbench() ApplyBenchNeon() PlaceSaberParts()
		if tweenType=="all" then
			for _,name in ipairs({"Hilt","Pommel","Emitter"}) do
				local p=Editor.SaberModel:FindFirstChild(name)
				if p then TweenTransparency(p) end
			end
		else
			local p=Editor.SaberModel:FindFirstChild(tweenType:sub(1,1):upper()..tweenType:sub(2))
			if p then TweenTransparency(p) end
		end
	end

	local function SetBlade(state)
		if not BladeModel then return end
		local Blade = BladeModel:FindFirstChild("Blade")
		if not Blade then return end
		Ignited=state
		local pos=state and Blade.UPPER.Position or Blade.LOWER.Position
		local range=state and 9 or 0
		TweenService:Create(Blade.TWEEN,TweenInfo.new(0.35),{Position=pos}):Play()
		TweenService:Create(Blade.light,TweenInfo.new(0.35),{Range=range}):Play()
		if state then if Blade.activate then Blade.activate:Play() end if Blade.hum then Blade.hum:Play() end
		else if Blade.deactivate then Blade.deactivate:Play() end if Blade.hum then Blade.hum:Stop() end end
	end

	local function ChangeSaberColor(name,ignite)
		if not Lock(0.1) then return end
		local entry=Find(Settings.Colors,"Name",name)
		if not (entry and BladeModel) then return end
		local Blade=BladeModel:FindFirstChild("Blade")
		if not Blade then return end
		local c=entry.Color
		if Blade:FindFirstChild("glow") then Blade.glow.Color=ColorSequence.new(c,c) end
		if Blade:FindFirstChild("light") then Blade.light.Color=c end
		SaberData.Color=name
		if ignite and not Ignited then SetBlade(true) end
	end

	local function ChangeSaberPart(kind,name)
		if not Lock(0.1) then return end
		SaberData[kind:sub(1,1):upper()..kind:sub(2)]=name
		BuildSaber(kind)
	end

	local function SetEditColorMode(mode)
		EditColorTarget=mode
		if UI and UI.Frame then UI.Frame.EditColor.Text="EDITING COLOR: "..mode:upper() end
	end

	local function ApplyPaint(color)
		SaberData[EditColorTarget]=color
		BuildSaber("all")
	end

	local function ClearPaintPage()
		if not UI or not UI.Frame then return end
		for _,btn in ipairs(UI.Frame.PaintColors:GetChildren()) do if btn:IsA("TextButton") then btn:Destroy() end end
		for _,conn in ipairs(PaintConnections) do conn:Disconnect() end
		table.clear(PaintConnections)
	end

	local function BuildPaintPage(name)
		if not UI or not UI.Frame then return end
		ClearPaintPage()
		local paintInfo=Find(Settings.Paint,"Name",name)
		if not paintInfo then return end
		local layout=UI.Frame.PaintColors:FindFirstChild("UIGridLayout")
		local template=layout and layout:FindFirstChild("Template")
		if not layout or not template then return end
		for _,color in ipairs(paintInfo.Colors) do
			local btn=template:Clone()
			btn.BackgroundColor3=color btn.Name="NewColor" btn.Parent=UI.Frame.PaintColors
			local conn=btn.MouseButton1Down:Connect(function()
				if not Player.Backpack:FindFirstChild("Lightsaber") then return end
				if script:FindFirstChild("Paint") then script.Paint:Play() end
				ApplyPaint(color)
			end)
			table.insert(PaintConnections,conn)
		end
	end

	local function UnlockButtons(frame,data)
		for _,btn in ipairs(frame:GetChildren()) do
			if btn:IsA("TextButton") then
				local entry=FindFlat(data,"Name",btn.Name)
				if entry then
					if entry.Value==true then
						btn.Lock.Visible=false btn.UIStroke.Color=Color3.fromRGB(255,255,255) btn.TextColor3=Color3.fromRGB(255,255,255)
					else
						btn.Lock.Visible=true btn.UIStroke.Color=Color3.fromRGB(255,0,0) btn.TextColor3=Color3.fromRGB(255,0,0)
					end
				end
			end
		end
	end

	local function ExitEditor(save)
		if not Lock(0) then return end
		if UI then UI.Enabled=false end
		if ShopUI then ShopUI.Enabled=false end
		if Ignited then SetBlade(false) end
		TweenService:Create(Camera,TweenInfo.new(0.75),{CFrame=LastCameraCF}):Play()
		task.wait(0.75)
		Camera.CameraType=Enum.CameraType.Follow
		Root.Anchored=false
		if BladeModel then BladeModel:Destroy() end
		ClearWorkbench()
		if save then Remote:InvokeServer("update_data",SaberData) end
		Editing=false Ignited=false Busy=false
	end

	local function OpenEditor(bench)
		if Editing then return end
		local Tool=Player.Backpack:FindFirstChild("Lightsaber")
		if not Tool then return end
		local Data=Remote:InvokeServer("request_data")
		if not Data then return end
		for _,entry in ipairs(Data) do
			if SaberData[entry.Name]~=nil then
				if entry.Name=="Primary" or entry.Name=="Secondary" then
					local v=string.split(entry.Value,", ")
					SaberData[entry.Name]=Color3.new(v[1],v[2],v[3])
				else
					SaberData[entry.Name]=entry.Value
				end
			end
		end
		BladeModel=SaberParts.Blade:Clone()
		CurrentBench=bench
		BuildSaber("all")
		ChangeSaberColor(SaberData.Color,false)
		if UI then UI.Enabled=true end
		LastCameraCF=Camera.CFrame
		Camera.CameraType=Enum.CameraType.Scriptable
		if bench:FindFirstChild("SaberEditorCam") then TweenService:Create(Camera,TweenInfo.new(0.75),{CFrame=bench.SaberEditorCam.CFrame}):Play() end
		Root.Anchored=true
		Editing=true
	end

	local function UpdateInteractHint()
		if InteractPart and InteractAttachment then
			InteractPart.Position=InteractAttachment.WorldPosition
			InteractPart.CFrame=InteractPart.CFrame:Lerp(CFrame.new(InteractAttachment.WorldPosition,Camera.CFrame.Position),0.25)
			return
		end
		if Editing then if InteractPart then InteractPart:Destroy() InteractPart=nil InteractAttachment=nil end return end
		local nearby=nil
		for _,v in ipairs(Editor.BenchEditAreas:GetChildren()) do
			if v:FindFirstChild("InteractPoint") and (v.InteractPoint.WorldPosition-Root.Position).Magnitude<=5 then nearby=v break end
		end
		if nearby and not InteractPart then
			local ih=SaberParts.InteractPart:Clone()
			ih.Parent=nearby
			InteractPart=ih
			InteractAttachment=nearby.InteractPoint
			local tTime=0.5
			for _,d in ipairs(ih.SurfaceGui:GetDescendants()) do
				if d:IsA("Frame") then TweenService:Create(d,TweenInfo.new(tTime),{BackgroundTransparency=d.BackgroundTransparency}):Play()
				elseif d:IsA("TextLabel") then TweenService:Create(d,TweenInfo.new(tTime),{TextTransparency=d.TextTransparency}):Play()
				elseif d:IsA("UIStroke") then TweenService:Create(d,TweenInfo.new(tTime),{Transparency=d.Transparency}):Play() end
			end
			ih.CFrame=CFrame.new(InteractAttachment.WorldPosition,Camera.CFrame.Position)
		elseif not nearby and InteractPart then
			local c=InteractPart:Clone()
			c.Parent=InteractPart.Parent
			InteractPart:Destroy()
			InteractPart=nil
			InteractAttachment=nil
			local tTime=0.25
			for _,d in ipairs(c.SurfaceGui:GetDescendants()) do
				if d:IsA("Frame") then TweenService:Create(d,TweenInfo.new(tTime),{BackgroundTransparency=1}):Play()
				elseif d:IsA("TextLabel") then TweenService:Create(d,TweenInfo.new(tTime),{TextTransparency=1}):Play()
				elseif d:IsA("UIStroke") then TweenService:Create(d,TweenInfo.new(tTime),{Transparency=1}):Play() end
			end
			Debris:AddItem(c,tTime)
		end
	end

	UserInputService.InputBegan:Connect(function(input,gpe)
		if gpe or Busy then return end
		if Humanoid.Health<=0 then return end
		if input.KeyCode==Enum.KeyCode.G and not Editing then
			for _,v in ipairs(Editor.BenchEditAreas:GetChildren()) do
				if v:FindFirstChild("InteractPoint") and (v.InteractPoint.WorldPosition-Root.Position).Magnitude<=5 then
					OpenEditor(v) break
				end
			end
		elseif Editing then
			if input.KeyCode==Enum.KeyCode.Q then Lock(0.5) SetBlade(not Ignited)
			elseif input.KeyCode==Enum.KeyCode.H then Lock(0.5) ExitEditor(false)
			elseif input.KeyCode==Enum.KeyCode.Y then Lock(0.5) ExitEditor(true) end
		end
	end)

	RunService.RenderStepped:Connect(function()
		UpdateInteractHint()
		if Editing then
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then Rotation=math.clamp(Rotation+0.2,-5,5)
			elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then Rotation=math.clamp(Rotation-0.2,-5,5)
			else Rotation=Lerp(Rotation,0,0.1) end
			if Editor.SaberModel.PrimaryPart then
				Editor.SaberModel:SetPrimaryPartCFrame(Editor.SaberModel.PrimaryPart.CFrame*CFrame.Angles(0,0,math.rad(Rotation)))
			end
		end
	end)

	Humanoid.Died:Connect(function() if Editing then ExitEditor(false) end end)
end

return Module
