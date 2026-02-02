local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")

local RepStorage = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
local GroupModule = require(RepStorage:FindFirstChild("Modules"):FindFirstChild("GroupModule"))
local OtherModule = require(RepStorage:FindFirstChild("Modules"):FindFirstChild("OtherModule"))

local module = {}

function module.Initialize()
	task.wait(0.5)

	local player = game.Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local hrp = character:WaitForChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera

	local mouse = player:GetMouse()

	local ui = player.PlayerGui:FindFirstChild("IRWorkbenchUi")
	local ShopUI = player.PlayerGui:FindFirstChild("Shop")
	local PlayerHud = player.PlayerGui:FindFirstChild("PlayerHUD")

	local se = workspace:WaitForChild("SaberEditor")
	local parts = game.ReplicatedStorage:WaitForChild("IR_System"):WaitForChild("SaberParts")
	local saberinfo = game.ReplicatedStorage:WaitForChild("IR_System"):WaitForChild("Workbench")
	local event = saberinfo:WaitForChild("Remote")
	local settingsmodule = require(game.ReplicatedStorage:WaitForChild("IR_System").SaberParts.SaberParts)

	local bladeModel = nil
	local editing = false
	local ignited = false
	local debounce = false
	local lastCameraCF = CFrame.new()
	local rotation = 0
	local editingBench = nil
	local interactAttach = nil
	local interactPart = nil

	local newSaber = {
		Color = "",
		Hilt = "",
		Emitter = "",
		Pommel = "",
		Primary = Color3.new(1,1,1),
		Secondary = Color3.new(1,1,1),
	}

	local editColorMode = "Primary"
	local paintConnections = {}

	local function setDb(t)
		if debounce then return false end
		debounce = true
		task.delay(t, function()
			debounce = false
		end)
		return true
	end

	local function lerp(a, b, t)
		return a + (b - a) * t
	end

	local function getColorDelta(c, sDelta)
		local h, s, v = c:ToHSV()
		return Color3.fromHSV(h, math.clamp(s + sDelta / 100, 0, 1), v)
	end

	local function findEntry(list, key, value)
		for _,v in pairs(list) do
			if v[key] == value then
				return v
			end
		end
	end

	local function findInFlatData(data, key, value)
		for _,v in ipairs(data) do
			if v[key] == value then
				return v
			end
		end
	end

	local function recolorModel(model)
		for _,p in ipairs(model:GetDescendants()) do
			if p.Name == "PRIMARY" then
				p.Color = newSaber.Primary
			elseif p.Name == "SECONDARY" then
				p.Color = newSaber.Secondary
			end
		end
	end

	local function updateColorSwatches()
		if not ui or not ui:FindFirstChild("Frame") then return end
		ui.Frame.Primary.Frame.BackgroundColor3 = newSaber.Primary
		ui.Frame.Secondary.Frame.BackgroundColor3 = newSaber.Secondary
	end

	local function clearWorkbenchModel()
		if se.SaberModel:FindFirstChild("Hilt") then se.SaberModel.Hilt:Destroy() end
		if se.SaberModel:FindFirstChild("Pommel") then se.SaberModel.Pommel:Destroy() end
		if se.SaberModel:FindFirstChild("Emitter") then se.SaberModel.Emitter:Destroy() end
	end

	local function tweenTransparency(model)
		for _,p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				local last = p.Transparency
				p.Transparency = 1
				TS:Create(p, TweenInfo.new(0.2), {Transparency = last}):Play()
			end
		end
	end

	local function applyBenchNeon()
		if not editingBench then return end
		if not editingBench:FindFirstChild("Neon") then return end
		local c = editingBench:FindFirstChild("BenchColor")
		if not c then return end
		for _,v in ipairs(editingBench.Neon:GetChildren()) do
			local fromColor = getColorDelta(c.Value, 100)
			v.Color = fromColor
			TS:Create(v, TweenInfo.new(1), {Color = c.Value}):Play()
		end
	end

	local function placeSaberParts()
		local hilt = parts.Hilt[newSaber.Hilt]:Clone()
		local pommel = parts.Pommel[newSaber.Pommel]:Clone()
		local emitter = parts.Emitter[newSaber.Emitter]:Clone()

		for _,p in ipairs(hilt:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end
		for _,p in ipairs(pommel:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end
		for _,p in ipairs(emitter:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end

		recolorModel(hilt)
		recolorModel(pommel)
		recolorModel(emitter)
		updateColorSwatches()

		hilt:SetPrimaryPartCFrame(editingBench.SaberSpot.CFrame)
		pommel:SetPrimaryPartCFrame(hilt.Pommel.CFrame)
		emitter:SetPrimaryPartCFrame(hilt.Emitter.CFrame)

		hilt.Name = "Hilt"
		pommel.Name = "Pommel"
		emitter.Name = "Emitter"

		hilt.Parent = se.SaberModel
		pommel.Parent = se.SaberModel
		emitter.Parent = se.SaberModel

		se.SaberModel.PrimaryPart = hilt.Primary

		if bladeModel then
			bladeModel:SetPrimaryPartCFrame(hilt.Emitter.CFrame)
			bladeModel.Parent = se.SaberModel
		end
	end

	local function loadSaber(tweenType)
		clearWorkbenchModel()
		applyBenchNeon()
		placeSaberParts()

		if tweenType == "emitter" and se.SaberModel:FindFirstChild("Emitter") then
			tweenTransparency(se.SaberModel.Emitter)
		elseif tweenType == "hilt" and se.SaberModel:FindFirstChild("Hilt") then
			tweenTransparency(se.SaberModel.Hilt)
		elseif tweenType == "pommel" and se.SaberModel:FindFirstChild("Pommel") then
			tweenTransparency(se.SaberModel.Pommel)
		elseif tweenType == "all" then
			if se.SaberModel:FindFirstChild("Emitter") then tweenTransparency(se.SaberModel.Emitter) end
			if se.SaberModel:FindFirstChild("Hilt") then tweenTransparency(se.SaberModel.Hilt) end
			if se.SaberModel:FindFirstChild("Pommel") then tweenTransparency(se.SaberModel.Pommel) end
		end
	end

	local function setBladeState(state)
		if not bladeModel then return end
		local blade = bladeModel:FindFirstChild("Blade")
		if not blade then return end

		if state then
			ignited = true
			TS:Create(blade.TWEEN, TweenInfo.new(0.35), {Position = blade.UPPER.Position}):Play()
			TS:Create(blade.light, TweenInfo.new(0.35), {Range = 9}):Play()
			if blade:FindFirstChild("activate") then blade.activate:Play() end
			if blade:FindFirstChild("hum") then blade.hum:Play() end
		else
			ignited = false
			TS:Create(blade.TWEEN, TweenInfo.new(0.35), {Position = blade.LOWER.Position}):Play()
			TS:Create(blade.light, TweenInfo.new(0.35), {Range = 0}):Play()
			if blade:FindFirstChild("deactivate") then blade.deactivate:Play() end
			if blade:FindFirstChild("hum") then blade.hum:Stop() end
		end
	end

	local function toggleBlade(mode)
		if not bladeModel then return end
		setBladeState(mode)
	end

	local function changeSaberColor(colorName, igniteBlade)
		if not setDb(0.1) then return end
		local entry = findEntry(settingsmodule.Colors, "Name", colorName)
		if not (entry and bladeModel) then return end
		local blade = bladeModel:FindFirstChild("Blade")
		if not blade then return end

		local c = entry.Color or Color3.new(1,1,1)
		if blade:FindFirstChild("glow") then
			blade.glow.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, c),
				ColorSequenceKeypoint.new(1, c),
			})
		end
		if blade:FindFirstChild("light") then
			blade.light.Color = c
		end

		newSaber.Color = colorName

		if not ignited and igniteBlade then
			setBladeState(true)
		end
	end

	local function changeSaberPart(kind, name)
		if not setDb(0.1) then return end
		if kind == "emitter" then
			newSaber.Emitter = name
		elseif kind == "hilt" then
			newSaber.Hilt = name
		elseif kind == "pommel" then
			newSaber.Pommel = name
		end
		loadSaber(kind)
	end

	local function setEditColorMode(kind)
		editColorMode = kind
		if ui and ui:FindFirstChild("Frame") then
			ui.Frame.EditColor.Text = "EDITING COLOR: "..string.upper(kind)
		end
	end

	local function applyPaintColor(color)
		newSaber[editColorMode] = color
		loadSaber("all")
	end

	local function clearPaintPage()
		if not ui or not ui:FindFirstChild("Frame") then return end
		for _,v in ipairs(ui.Frame.PaintColors:GetChildren()) do
			if v:IsA("TextButton") then
				v:Destroy()
			end
		end
		for _,c in ipairs(paintConnections) do
			c:Disconnect()
		end
		table.clear(paintConnections)
	end

	local function buildPaintPage(name)
		if not ui or not ui:FindFirstChild("Frame") then return end
		clearPaintPage()
		local paintInfo = findEntry(settingsmodule.Paint, "Name", name)
		if not paintInfo then return end

		local layout = ui.Frame.PaintColors:FindFirstChild("UIGridLayout")
		if not layout then return end
		local template = layout:FindFirstChild("Template")
		if not template then return end

		for _,color in ipairs(paintInfo.Colors) do
			local btn = template:Clone()
			btn.BackgroundColor3 = color
			btn.Name = "NewColor"
			btn.Parent = ui.Frame.PaintColors

			local conn = btn.MouseButton1Down:Connect(function()
				if not player.Backpack:FindFirstChild("Lightsaber") then return end
				if script:FindFirstChild("Paint") then
					script.Paint:Play()
				end
				applyPaintColor(color)
			end)
			table.insert(paintConnections, conn)
		end
	end

	local function unlockButtonsFromData(frame, data)
		for _,btn in ipairs(frame:GetChildren()) do
			if btn:IsA("TextButton") then
				local entry = findInFlatData(data, "Name", btn.Name)
				if entry then
					if entry.Value == true then
						btn.Lock.Visible = false
						btn.UIStroke.Color = Color3.fromRGB(255,255,255)
						btn.TextColor3 = Color3.fromRGB(255,255,255)
					else
						btn.Lock.Visible = true
						btn.UIStroke.Color = Color3.fromRGB(255,0,0)
						btn.TextColor3 = Color3.fromRGB(255,0,0)
					end
				end
			end
		end
	end

	local function resetBenchNeon()
		if not editingBench then return end
		if not editingBench:FindFirstChild("Neon") then return end
		for _,v in ipairs(editingBench.Neon:GetChildren()) do
			TS:Create(v, TweenInfo.new(1), {Color = Color3.fromRGB(0,0,0)}):Play()
		end
	end

	local function applyRankUIOnExit()
		if not PlayerHud then return end
		if player.Team == game.Teams[GroupModule.MainGroup.TeamName] then
			if player:IsInGroup(GroupModule.MainGroup.GroupID) then
				if player:GetRankInGroup(GroupModule.MainGroup.GroupID) >= GroupModule.MainGroup.Ranks.Initiate then
					PlayerHud.Frame.ShopButton.Visible = true
				end
			end
		end
	end

	local function applyRankUIOnEnter()
		if not PlayerHud then return end

		if player.Team == game.Teams[GroupModule.MainGroup.TeamName] then
			if player:IsInGroup(GroupModule.MainGroup.GroupID) then
				if player:GetRankInGroup(GroupModule.MainGroup.GroupID) >= GroupModule.MainGroup.Ranks.Initiate then
					if ShopUI then
						ShopUI.Enabled = false
					end
					PlayerHud.Frame.ShopButton.Visible = false
				end
			end

		elseif player.Team == game.Teams[GroupModule.SithGroup.TeamName] then
			if player:IsInGroup(GroupModule.SithGroup.GroupID) then
				if player:GetRankInGroup(GroupModule.SithGroup.GroupID) >= GroupModule.SithGroup.Ranks.Sinitiate then
					if ShopUI then
						ShopUI.Enabled = false
					end
					PlayerHud.Frame.ShopButton.Visible = false
				end
			end
		end
	end


	local function configureStarterPage()
		if not ui then return end
		local f = ui.Frame
		f.Colors.Visible = true
		f.Emitters.Visible = false
		f.Hilts.Visible = false
		f.Pommels.Visible = false
		f.Paint.Visible = false
		f.PaintColors.Visible = false
		f.PageText.Text = "CRYSTALS"
		f.Left.Visible = true
		f.Right.Visible = true

		if player.Team == game.Teams[GroupModule.MainGroup.TeamName] then
			if player:IsInGroup(GroupModule.MainGroup.GroupID) then
				if player:GetRankInGroup(GroupModule.MainGroup.GroupID) <= GroupModule.MainGroup.Ranks.Y3 then
					f.Colors.Visible = true
					f.Emitters.Visible = false
					f.Hilts.Visible = false
					f.Pommels.Visible = false
					f.Paint.Visible = false
					f.PaintColors.Visible = false
					f.PageText.Text = "CRYSTALS"
					f.Left.Visible = false
					f.Right.Visible = false
				end
			end
		end

		clearPaintPage()
	end

	local function destroyWorkbenchVisuals()
		if bladeModel then
			bladeModel:Destroy()
			bladeModel = nil
		end
		clearWorkbenchModel()
	end

	local function exitEditor(save)
		if not setDb(0) then return end
		if character:FindFirstChild("Lightsaber") then return end

		local tool = player.Backpack:FindFirstChild("Lightsaber")
		if not tool then
			editing = false
			ignited = false
			debounce = false
			return
		end

		if ui then ui.Enabled = false end
		if ShopUI then ShopUI.Enabled = false end
		applyRankUIOnExit()
		resetBenchNeon()

		if editingBench and editingBench:FindFirstChild("SaberEditorCam") then
			local light = editingBench.SaberEditorCam:FindFirstChild("PointLight")
			if light then
				TS:Create(light, TweenInfo.new(1), {Range = 0}):Play()
			end
		end

		if ignited then setBladeState(false) end

		TS:Create(camera, TweenInfo.new(0.75), {CFrame = lastCameraCF}):Play()
		task.wait(0.75)
		camera.CameraType = Enum.CameraType.Follow
		hrp.Anchored = false

		destroyWorkbenchVisuals()

		if save and event then
			event:InvokeServer("update_data", newSaber)
		end

		local lRemote = game.ReplicatedStorage.IR_system.Lightsaber.Remote
		lRemote:FireServer(nil, tool, "setup_saber")

		ignited = false
		editing = false
		debounce = false
	end

	local function openEditor(bench)
		if editing then return end
		local tool = player.Backpack:FindFirstChild("Lightsaber")
		if not tool then return end

		local data = event:InvokeServer("request_data")
		if not data then return end

		local colorEntry = findInFlatData(data, "Name", "Color")
		local hiltEntry = findInFlatData(data, "Name", "Hilt")
		local emitterEntry = findInFlatData(data, "Name", "Emitter")
		local pommelEntry = findInFlatData(data, "Name", "Pommel")
		local primaryEntry = findInFlatData(data, "Name", "Primary")
		local secondaryEntry = findInFlatData(data, "Name", "Secondary")

		if not (colorEntry and hiltEntry and emitterEntry and pommelEntry and primaryEntry and secondaryEntry) then
			return
		end

		local pVals = string.split(primaryEntry.Value, ", ")
		local sVals = string.split(secondaryEntry.Value, ", ")

		newSaber.Color = colorEntry.Value
		newSaber.Hilt = hiltEntry.Value
		newSaber.Emitter = emitterEntry.Value
		newSaber.Pommel = pommelEntry.Value
		newSaber.Primary = Color3.new(table.unpack(pVals))
		newSaber.Secondary = Color3.new(table.unpack(sVals))

		local function applyUnlocks()
			if not ui then return end
			unlockButtonsFromData(ui.Frame.Colors, data)
			unlockButtonsFromData(ui.Frame.Emitters, data)
			unlockButtonsFromData(ui.Frame.Hilts, data)
			unlockButtonsFromData(ui.Frame.Pommels, data)
			unlockButtonsFromData(ui.Frame.Paint, data)
		end

		applyUnlocks()
		setEditColorMode("Primary")

		editingBench = bench
		bladeModel = parts.Blade:Clone()

		if bladeModel and bladeModel:FindFirstChild("Blade") then
			local info = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true)
			for _,b in ipairs(bladeModel.Blade:GetChildren()) do
				if b:IsA("Beam") then
					local props = {Width0 = b.Width0 + 0.25, Width1 = b.Width1 + 0.25}
					TS:Create(b, info, props):Play()
				end
			end
		end

		changeSaberColor(newSaber.Color, false)
		configureStarterPage()
		loadSaber("all")

		if ui then ui.Enabled = true end
		applyRankUIOnEnter()

		camera.CameraType = Enum.CameraType.Scriptable
		lastCameraCF = camera.CFrame

		if editingBench:FindFirstChild("SaberEditorCam") then
			TS:Create(camera, TweenInfo.new(0.75), {CFrame = editingBench.SaberEditorCam.CFrame}):Play()
			local light = editingBench.SaberEditorCam:FindFirstChild("PointLight")
			if light then
				TS:Create(light, TweenInfo.new(1), {Range = 12}):Play()
			end
		end

		hrp.Anchored = true
		editing = true
	end

	if ui then
		ui.Frame.ExitLeave.MouseButton1Down:Connect(function()
			exitEditor(false)
		end)

		ui.Frame.ExitSave.MouseButton1Down:Connect(function()
			exitEditor(true)
		end)

		ui.Frame.EditColor.MouseButton1Down:Connect(function()
			if editColorMode == "Primary" then
				setEditColorMode("Secondary")
			else
				setEditColorMode("Primary")
			end
		end)

		ui.Frame.ToggleBlade.MouseButton1Down:Connect(function()
			if not player.Backpack:FindFirstChild("Lightsaber") then return end
			if not bladeModel then return end
			setBladeState(not ignited)
		end)

		for _,btn in ipairs(ui.Frame.Colors:GetChildren()) do
			if btn:IsA("TextButton") then
				btn.MouseButton1Down:Connect(function()
					if not player.Backpack:FindFirstChild("Lightsaber") then return end
					if btn.Lock.Visible then return end
					changeSaberColor(btn.Name, true)
				end)
			end
		end

		for _,btn in ipairs(ui.Frame.Emitters:GetChildren()) do
			if btn:IsA("TextButton") then
				btn.MouseButton1Down:Connect(function()
					if not player.Backpack:FindFirstChild("Lightsaber") then return end
					if btn.Lock.Visible then return end
					changeSaberPart("emitter", btn.Name)
				end)
			end
		end

		for _,btn in ipairs(ui.Frame.Hilts:GetChildren()) do
			if btn:IsA("TextButton") then
				btn.MouseButton1Down:Connect(function()
					if not player.Backpack:FindFirstChild("Lightsaber") then return end
					if btn.Lock.Visible then return end
					changeSaberPart("hilt", btn.Name)
				end)
			end
		end

		for _,btn in ipairs(ui.Frame.Pommels:GetChildren()) do
			if btn:IsA("TextButton") then
				btn.MouseButton1Down:Connect(function()
					if not player.Backpack:FindFirstChild("Lightsaber") then return end
					if btn.Lock.Visible then return end
					changeSaberPart("pommel", btn.Name)
				end)
			end
		end

		for _,btn in ipairs(ui.Frame.Paint:GetChildren()) do
			if btn:IsA("TextButton") then
				btn.MouseButton1Down:Connect(function()
					if not player.Backpack:FindFirstChild("Lightsaber") then return end
					if btn.Lock.Visible then return end
					buildPaintPage(btn.Name)
					ui.Frame.PaintColors.Visible = true
				end)
			end
		end
	end

	UIS.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		local tool = player.Backpack:FindFirstChild("Lightsaber")
		if not tool then return end
		if debounce then return end
		if humanoid.Health <= 0 then return end
		if tool:FindFirstChild("SaberType") and tool.SaberType.Value == "Vibro" then return end

		if input.KeyCode == Enum.KeyCode.Q and editing then
			if not bladeModel then return end
			setDb(0.5)
			setBladeState(not ignited)
		elseif input.KeyCode == Enum.KeyCode.H and editing then
			setDb(0.5)
			exitEditor(false)
		elseif input.KeyCode == Enum.KeyCode.Y and editing then
			setDb(0.5)
			exitEditor(true)
		elseif input.KeyCode == Enum.KeyCode.G and not editing then
			setDb(0.5)
			local bench = nil
			for _,v in ipairs(se.BenchEditAreas:GetChildren()) do
				if v:FindFirstChild("InteractPoint") then
					if (v.Position - hrp.Position).Magnitude <= v.Size.X / 2 then
						bench = v
						break
					end
				end
			end
			if bench then
				openEditor(bench)
			end
		end
	end)

	local function updateInteractHint()
		if interactPart and interactAttach then
			interactPart.Position = interactAttach.WorldPosition
			interactPart.CFrame = interactPart.CFrame:Lerp(CFrame.new(interactAttach.WorldPosition, camera.CFrame.Position), 0.25)
			return
		end

		if editing then
			if interactPart then
				interactPart:Destroy()
				interactPart = nil
				interactAttach = nil
			end
			return
		end

		local nearby = nil
		for _,v in ipairs(se.BenchEditAreas:GetChildren()) do
			if v:FindFirstChild("InteractPoint") then
				local dist = (v.InteractPoint.WorldPosition - hrp.Position).Magnitude
				if dist <= 5 then
					nearby = v
					break
				end
			end
		end

		if nearby and not interactPart then
			local ih = saberinfo.InteractPart:Clone()
			ih.Parent = nearby
			interactPart = ih
			interactAttach = nearby.InteractPoint

			local tTime = 0.5
			for _,d in ipairs(ih.SurfaceGui:GetDescendants()) do
				if d:IsA("Frame") then
					local last = d.BackgroundTransparency
					d.BackgroundTransparency = 1
					TS:Create(d, TweenInfo.new(tTime), {BackgroundTransparency = last}):Play()
				elseif d:IsA("TextLabel") then
					local last = d.TextTransparency
					d.TextTransparency = 1
					TS:Create(d, TweenInfo.new(tTime), {TextTransparency = last}):Play()
				elseif d:IsA("UIStroke") then
					local last = d.Transparency
					d.Transparency = 1
					TS:Create(d, TweenInfo.new(tTime), {Transparency = last}):Play()
				end
			end

			ih.CFrame = CFrame.new(interactAttach.WorldPosition, camera.CFrame.Position)
		elseif not nearby and interactPart then
			local c = interactPart:Clone()
			c.Parent = interactPart.Parent
			interactPart:Destroy()
			interactPart = nil
			interactAttach = nil

			local tTime = 0.25
			for _,d in ipairs(c.SurfaceGui:GetDescendants()) do
				if d:IsA("Frame") then
					TS:Create(d, TweenInfo.new(tTime), {BackgroundTransparency = 1}):Play()
				elseif d:IsA("TextLabel") then
					TS:Create(d, TweenInfo.new(tTime), {TextTransparency = 1}):Play()
				elseif d:IsA("UIStroke") then
					TS:Create(d, TweenInfo.new(tTime), {Transparency = 1}):Play()
				end
			end
			game.Debris:AddItem(c, tTime)
		end
	end

	local function updateEditorRotation()
		if not editing then return end
		if UIS:IsKeyDown(Enum.KeyCode.W) then
			rotation = math.clamp(rotation + 0.2, -5, 5)
		elseif UIS:IsKeyDown(Enum.KeyCode.S) then
			rotation = math.clamp(rotation - 0.2, -5, 5)
		else
			rotation = lerp(rotation, 0, 0.1)
		end
		if se.SaberModel.PrimaryPart then
			se.SaberModel:SetPrimaryPartCFrame(se.SaberModel.PrimaryPart.CFrame * CFrame.Angles(0,0,math.rad(rotation)))
		end
	end

	RS.RenderStepped:Connect(function()
		updateInteractHint()
		updateEditorRotation()
	end)

	humanoid.Died:Connect(function()
		if editing then
			exitEditor(false)
		end
	end)
end

return module
