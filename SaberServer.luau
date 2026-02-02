local TS = game:GetService("TweenService")
local RepStorage = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")

local GroupModule = require(RepStorage:FindFirstChild("Modules"):FindFirstChild("GroupModule"))
local OtherModule = require(RepStorage:FindFirstChild("Modules"):FindFirstChild("OtherModule"))

local module = {}

local lastPlayed = {}
local function getRandomFromFolder(container: Instance, folderName: string)
	local folder = container:FindFirstChild(folderName)
	if folder and folder:IsA("Folder") then
		local pool = {}
		for _, obj in ipairs(folder:GetChildren()) do
			if obj:IsA("Sound") then
				table.insert(pool, obj)
			end
		end
		local count = #pool
		if count > 0 then
			if count > 1 then
				local choice
				repeat
					choice = pool[math.random(1, count)]
				until choice ~= lastPlayed[folder]
				lastPlayed[folder] = choice
				return choice
			else
				lastPlayed[folder] = pool[1]
				return pool[1]
			end
		end
	end
	return nil
end

function module.ServerInfo(player, formdata, tool, keyword, extra1, extra2, extra3)
	if keyword == "dash" or keyword == "Dash" or keyword == "dash_start" or keyword == "dash_end" or keyword == "Dashing" then
		return
	end

	task.spawn(function()
		local player_data = require(game.ReplicatedStorage:WaitForChild("IR_System").Workbench.BenchServer)
		local saber_parts = require(game.ReplicatedStorage:WaitForChild("IR_System").SaberParts.SaberParts)

		local function playSound(s, part, range)
			local sound = s:Clone()
			sound.Parent = part

			if range ~= nil then
				sound.PlaybackSpeed += Random.new():NextNumber(-range, range)
			end

			local function getActiveBlades(char, tool)
				local blades = {}

				if tool and tool.Parent and (tool.Parent == char or tool.Parent == char:FindFirstChildOfClass("Backpack")) then
					local model = tool:FindFirstChild("Model")
					if model then
						local b1 = model:FindFirstChild("Blade")
						if b1 then table.insert(blades, b1) end
						if tool:FindFirstChild("SaberType")
							and tool.SaberType.Value == "Double"
							and not tool:GetAttribute("SingleBladeMode") then
							local b2 = model:FindFirstChild("Blade2")
							if b2 then table.insert(blades, b2) end
						end
					end
				end

				local ls2 = char and char:FindFirstChild("Lightsaber2")
				if ls2 and ls2:FindFirstChild("Blade") then
					table.insert(blades, ls2.Blade)
				end

				return blades
			end

			local function emitParryFXOnChar(char, tool)
				for _, blade in ipairs(getActiveBlades(char, tool)) do
					local clash = blade:FindFirstChild("Clash")
					if clash and clash:FindFirstChild("parry") then
						clash.parry.Enabled = true
						task.delay(0.2, function()
							if clash and clash:FindFirstChild("parry") then
								clash.parry.Enabled = false
							end
						end)
					end
					local parry_light = blade:FindFirstChild("PLight")
					if parry_light then
						parry_light.Enabled = true
						task.delay(0.2, function()
							if parry_light then parry_light.Enabled = false end
						end)
					end
				end
			end

			local function emitClashFXOnChar(char, tool)
				for _, blade in ipairs(getActiveBlades(char, tool)) do
					local clash = blade:FindFirstChild("Clash")
					if clash and clash:FindFirstChild("sparks") then
						clash.sparks.Enabled = true
						task.delay(0.2, function()
							if clash and clash:FindFirstChild("sparks") then
								clash.sparks.Enabled = false
							end
						end)
					end
					local light = blade:FindFirstChild("Clight")
					if light then
						light.Enabled = true
						task.delay(0.2, function()
							if light then light.Enabled = false end
						end)
					end
				end
			end

			sound:Play()
			game.Debris:AddItem(sound, 2)
		end

		local function find_id_in_data(tabl, id, key)
			for i, slot in pairs(tabl) do
				if slot[key] == id then
					return slot
				end
			end
			return nil
		end

		local partsinfo = game.ReplicatedStorage:WaitForChild("Tbc_System").SaberParts
		local saberinfo = game.ReplicatedStorage:WaitForChild("Tbc_System").Lightsaber
		local character = player.Character
		local hrp = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChild("Humanoid")

		local sabers = {}

		local mainBlade = tool.Model:FindFirstChild("Blade")
		if mainBlade then
			table.insert(sabers, mainBlade)
		end

		if tool.SaberType.Value == "Double" and not tool:GetAttribute("SingleBladeMode") then
			local b2 = tool.Model:FindFirstChild("Blade2")
			if b2 then
				table.insert(sabers, b2)
			end
		elseif tool.SaberType.Value == "Dual" and character:FindFirstChild("Lightsaber2") then
			local dualBlade = character.Lightsaber2:FindFirstChild("Blade")
			if dualBlade then
				table.insert(sabers, dualBlade)
			end
		end

		if tool.SaberType.Value == "Crossguard" then
			local side1 = tool.Model:FindFirstChild("Blade2")
			local side2 = tool.Model:FindFirstChild("Blade3")
			if side1 then
				table.insert(sabers, side1)
			end
			if side2 then
				table.insert(sabers, side2)
			end
		end

		if keyword == "setup_saber" then
			for i, v in pairs(tool.Model.SABER_MODEL:GetChildren()) do
				v:Destroy()
			end

			if tool:FindFirstChild("SaberType").Value ~= "Vibro" then
				local data = player:FindFirstChild("Data")

				local emitter, hilt, pommel
				if data then
					emitter = partsinfo.Emitter[data.Saber.Emitter.Value]:Clone()
					hilt = partsinfo.Hilt[data.Saber.Hilt.Value]:Clone()
					pommel = partsinfo.Pommel[data.Saber.Pommel.Value]:Clone()

					local colorEntry = find_id_in_data(saber_parts.Colors, data.Saber.Color.Value, "Name")

					local baseColor = Color3.fromRGB(255, 255, 255)
					local innerColor = baseColor
					local outerColor = baseColor

					if colorEntry then
						baseColor = colorEntry.Color or baseColor
						innerColor = colorEntry.Inner or baseColor
						outerColor = colorEntry.Outer or baseColor

						if outerColor.r == 0 and outerColor.g == 0 and outerColor.b == 0 then
							outerColor = Color3.fromRGB(20, 20, 20)
						end

						if tool:FindFirstChild("SaberColor") then
							baseColor = tool.SaberColor.Value
							innerColor = baseColor
							outerColor = baseColor
						end

						tool:SetAttribute("IsSaber", true)

						if player.Name == "-" then
							task.spawn(function()
								task.wait(2)
								tool.Model:FindFirstChild("Blade").inner.Color = ColorSequence.new(Color3.fromRGB(233, 109, 175))
								tool.Model:FindFirstChild("Blade").Trail.Color = ColorSequence.new(Color3.fromRGB(233, 109, 175))
								tool.Model:FindFirstChild("Blade").light.Color = Color3.new(0.913725, 0.427451, 0.686275)
								tool.Model:FindFirstChild("Blade").outer.Color = Color3.new(0.913725, 0.427451, 0.686275)
								tool.Model:FindFirstChild("Blade2").inner.Color = ColorSequence.new(Color3.fromRGB(233, 109, 175))
								tool.Model:FindFirstChild("Blade2").Trail.Color = ColorSequence.new(Color3.fromRGB(233, 109, 175))
								tool.Model:FindFirstChild("Blade2").light.Color = Color3.new(0.913725, 0.427451, 0.686275)
								tool.Model:FindFirstChild("Blade2").outer.Color = Color3.new(0.913725, 0.427451, 0.686275)

								tool.Model:FindFirstChild("Blade").glow.Attachment0 = tool.Model:FindFirstChild("Blade"):WaitForChild("TWEEN")
								tool.Model:FindFirstChild("Blade").glow.Attachment1 = tool.Model:FindFirstChild("Blade"):WaitForChild("LOWER")

								character:WaitForChild("Lightsaber2"):FindFirstChild("Blade").inner.Color = ColorSequence.new(Color3.fromRGB(233, 109, 175))
								character:WaitForChild("Lightsaber2"):FindFirstChild("Blade").Trail.Color = ColorSequence.new(Color3.fromRGB(233, 109, 175))
								character:WaitForChild("Lightsaber2"):FindFirstChild("Blade").light.Color = Color3.new(0.913725, 0.427451, 0.686275)
								character:WaitForChild("Lightsaber2"):FindFirstChild("Blade").outer.Color = Color3.new(0.913725, 0.427451, 0.686275)

								character:WaitForChild("Lightsaber2"):FindFirstChild("Blade").glow.Attachment0 = character:WaitForChild("Lightsaber2"):FindFirstChild("Blade"):WaitForChild("TWEEN")
								character:WaitForChild("Lightsaber2"):FindFirstChild("Blade").glow.Attachment1 = character:WaitForChild("Lightsaber2"):FindFirstChild("Blade"):WaitForChild("LOWER")
							end)
						else
							for _, blade in pairs(sabers) do
								if blade:FindFirstChild("inner") then
									blade.inner.Color = ColorSequence.new(innerColor)
								end
								if blade:FindFirstChild("outer") then
									blade.outer.Color = outerColor
								end
								if blade:FindFirstChild("glow") then
									blade.glow.Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, outerColor),
										ColorSequenceKeypoint.new(1, outerColor),
									})
								end
								if blade:FindFirstChild("Trail") then
									blade.Trail.Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, innerColor),
										ColorSequenceKeypoint.new(1, innerColor),
									})
								end
								if blade:FindFirstChild("light") then
									blade.light.Color = outerColor
								end
							end
						end
					end
				else
					emitter = partsinfo.Emitter.E_Initiate:Clone()
					hilt = partsinfo.Hilt.H_Initiate:Clone()
					pommel = partsinfo.Pommel.P_Initiate:Clone()
				end

				if player.Team == game.Teams[GroupModule.MainGroup.TeamName] or player.Team == game.Teams[GroupModule.Divisions.TG.TeamName] then
					if player:IsInGroup(GroupModule.MainGroup.GroupID) then
						if player:GetRankInGroup(GroupModule.MainGroup.GroupID) >= GroupModule.MainGroup.Ranks.Initiate then
							if data.Emitters["E_Initiate"].Value == false or data.Hilts["H_Initiate"].Value == false or data.Pommels["P_Initiate"].Value == false then
								data.Emitters["E_Initiate"].Value = true
								data.Hilts["H_Initiate"].Value = true
								data.Pommels["P_Initiate"].Value = true
							end
						end
					end

					if player:IsInGroup(GroupModule.Divisions.TG.GroupID) then
						if data.Emitters["E_Guardian"].Value == false or data.Hilts["H_Guardian"].Value == false or data.Pommels["P_Guardian"].Value == false then
							data.Emitters["E_Guardian"].Value = true
							data.Hilts["H_Guardian"].Value = true
							data.Pommels["P_Guardian"].Value = true
						end
					else
						if data.Emitters["E_Guardian"].Value == true or data.Hilts["H_Guardian"].Value == true or data.Pommels["P_Guardian"].Value == true then
							data.Emitters["E_Guardian"].Value = false
							data.Hilts["H_Guardian"].Value = false
							data.Pommels["P_Guardian"].Value = false

							if data.Saber.Emitter.Value == "E_Guardian" then
								data.Saber.Emitter.Value = "E_Initiate"
							end

							if data.Saber.Hilt.Value == "H_Guardian" then
								data.Saber.Hilt.Value = "H_Initiate"
							end

							if data.Saber.Pommel.Value == "P_Guardian" then
								data.Saber.Pommel.Value = "P_Initiate"
							end
						end
					end
				end

				if tool:FindFirstChild("SaberType").Value == "Double" then
					tool.Model.Center.Weld.C0 = CFrame.new(0, -0.4, 0)
				elseif tool:FindFirstChild("SaberType").Value == "Pike" then
					tool.Model.Center.Weld.C0 = CFrame.new(0, -0.8, 0)
				end

				hilt.Primary.Weld.Part1 = tool.Model.Center.Spawn
				hilt.Parent = tool.Model.SABER_MODEL
				hilt.Name = "Hilt"

				if tool:FindFirstChild("IsReversed") then
					hilt.Primary.Weld.C0 *= CFrame.Angles(0, math.rad(180), 0)
				end

				emitter.Hilt.Weld.Part1 = hilt.Emitter
				emitter.Parent = tool.Model.SABER_MODEL
				emitter.Name = "Emitter"

				pommel.Hilt.Weld.Part1 = hilt.Pommel
				pommel.Parent = tool.Model.SABER_MODEL
				pommel.Name = "Pommel"

				local function recolor(model)
					for i, parts in pairs(model:GetDescendants()) do
						if parts.Name == "PRIMARY" then
							local RGBValues = string.split(data.Saber.Primary.Value, ", ")
							parts.Color = Color3.new(table.unpack(RGBValues))
						elseif parts.Name == "SECONDARY" then
							local RGBValues = string.split(data.Saber.Secondary.Value, ", ")
							parts.Color = Color3.new(table.unpack(RGBValues))
						end
					end
				end

				recolor(emitter)
				recolor(hilt)
				recolor(pommel)
			else
				local model = partsinfo.Vibro:Clone()
				model.Center.Weld.Part1 = tool.Model.Center
				model.Parent = tool.Model.SABER_MODEL
				model.Name = "Hilt"

				local color = Color3.fromRGB(218, 133, 65)

				for i, blade in pairs(sabers) do
					blade.glow.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(1, color)})
					blade.Trail.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(1, color)})
					blade.light.Color = color
				end

				tool.Model.Blade.glow.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 1)})
			end

			for i, v in pairs(tool.Model.SABER_MODEL:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
					v.CanQuery = false
					v.CanTouch = false
					v.Massless = true
				elseif v:IsA("WeldConstraint") then
					v.Enabled = true
				end
			end

		elseif keyword == "equip" then
			if character:FindFirstChild("WHilt") then
				character:FindFirstChild("WHilt"):Destroy()
			end

			for i, part in pairs(tool.Model.SABER_MODEL:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0
					if part:FindFirstChild("Revert") then
						part.Transparency = part.Revert.Value
					end
				end
			end

			if tool.SaberType.Value == "Dual" then
				if character:FindFirstChild("WHilt2") then
					character:FindFirstChild("WHilt2"):Destroy()
				end

				local lhg = saberinfo.LeftHandGrip:Clone()
				lhg.Parent = character
				lhg.Weld.Part1 = character.LeftHand

				local hilt = tool.Model:Clone()
				hilt.Parent = character
				hilt.Name = "Lightsaber2"
				hilt.Center.Weld.Part1 = lhg.SaberSpot

				hilt.Hitbox:Destroy()
				hilt.Reflect:Destroy()

			elseif tool.SaberType.Value == "Double" then
				if character:FindFirstChild("WHilt2") then
					character:FindFirstChild("WHilt2"):Destroy()
				end

				local grip = saberinfo.DoubleGrip:Clone()
				grip.Parent = character
				grip.Weld.Part1 = character.RightHand

				local hilt = tool.Model:Clone()
				hilt.Parent = character
				hilt.Name = "Lightsaber2"
				hilt.Center.Weld.Part1 = grip.SaberSpot
				hilt.Center.Weld.C0 = CFrame.new(0, 0.3, 0)

				hilt.Hitbox:Destroy()
				hilt.Reflect:Destroy()
			end

		elseif keyword == "unequip" then
			local saberType = tool:FindFirstChild("SaberType") and tool.SaberType.Value or "Single"
			local sws = character:FindFirstChild("SaberWeldSpots")

			local wanted = "Default"
			if saberType == "Pike" then
				wanted = "Pike"
			elseif saberType == "Vibro" then
				wanted = "Upper"
			end

			if sws and sws:GetAttribute("SWS_Type") ~= wanted then
				sws:Destroy()
				sws = nil
			end

			if not sws then
				if saberType == "Pike" then
					sws = saberinfo.SaberWeldSpotsPike:Clone()
					sws.Center.Weld.Part1 = character:WaitForChild("UpperTorso")
					sws:SetAttribute("SWS_Type", "Pike")
				elseif saberType == "Vibro" then
					sws = saberinfo.SaberWeldSpotsUpper:Clone()
					sws.Center.Weld.Part1 = character:WaitForChild("UpperTorso")
					sws:SetAttribute("SWS_Type", "Upper")
				else
					sws = saberinfo.SaberWeldSpots:Clone()
					sws.Center.Weld.Part1 = character:WaitForChild("LowerTorso")
					sws:SetAttribute("SWS_Type", "Default")
				end

				sws.Name = "SaberWeldSpots"
				sws.Parent = character
			end

			local hilt = tool.Model:Clone()
			hilt.Parent = character
			hilt.Name = "WHilt"
			hilt.Center.Weld.Part1 = sws.Saber1
			hilt.Blade:Destroy()

			if tool.SaberType.Value == "Double" then
				hilt.Center.Weld.C0 = CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(180), 0, 0)
			end

			for i, part in pairs(hilt.SABER_MODEL:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0
					if part:FindFirstChild("Revert") then
						part.Transparency = part.Revert.Value
					end
				end
			end

			if tool.SaberType.Value == "Dual" then
				if character:FindFirstChild("Lightsaber2") then
					character.Lightsaber2.Center.Weld.Part1 = nil
					character.Lightsaber2:Destroy()
				end

				local h2 = tool.Model:Clone()
				h2.Parent = character
				h2.Name = "WHilt2"
				h2.Center.Weld.Part1 = sws.Saber2
				if h2:FindFirstChild("Blade") then h2.Blade:Destroy() end

			elseif tool.SaberType.Value == "Double" then
				if character:FindFirstChild("Lightsaber2") then
					character.Lightsaber2.Center.Weld.Part1 = nil
					character.Lightsaber2:Destroy()
				end

				local h2 = tool.Model:Clone()
				h2.Parent = character
				h2.Name = "WHilt2"
				h2.Center.Weld.Part1 = sws:FindFirstChild("Double")
				if h2:FindFirstChild("Blade") then h2.Blade:Destroy() end
				if h2:FindFirstChild("Blade2") then h2.Blade2:Destroy() end

				h2.Center.Weld.C0 = CFrame.new(0, 0.1, 0) * CFrame.Angles(math.rad(180), 0, 0)

			elseif tool.SaberType.Value == "Pike" then
				hilt.Center.Weld.C0 = CFrame.new(0, -0.8, -0.8) * CFrame.Angles(math.rad(-65), math.rad(90), 0)

			elseif tool.SaberType.Value == "Vibro" then
				hilt.Center.Weld.C0 = CFrame.new()
			end

		elseif keyword == "TDual" then
			if tool:GetAttribute("IsReversed") then
				return
			end
			local wasIgnited = extra1
			if tool.SaberType.Value == "Dual" then
				if wasIgnited and character:FindFirstChild("Lightsaber2") then
					local offBlade = character.Lightsaber2:FindFirstChild("Blade")
					if offBlade then
						TS:Create(offBlade.TWEEN, TweenInfo.new(0.5), {Position = offBlade.LOWER.Position}):Play()
						TS:Create(offBlade.light, TweenInfo.new(0.5), {Range = 0}):Play()
						offBlade.Trail.Enabled = false
					end
					if player.UserId == 1 then
						playSound(tool.Handle.AhsokaDisIgnite, hrp)
					else
						playSound(tool.Handle.deactivate, hrp)
					end
				end
				if character:FindFirstChild("Lightsaber2") then
					character.Lightsaber2.Center.Weld.Part1 = nil
					character.Lightsaber2:Destroy()
				end
				local sws = character:FindFirstChild("SaberWeldSpots")
				if not sws then
					if tool:FindFirstChild("SaberType").Value ~= "Vibro" then
						sws = saberinfo.SaberWeldSpotsUpper:Clone()
						sws.Center.Weld.Part1 = character:WaitForChild("UpperTorso")
						sws.Name = "SaberWeldSpots"
					else
						sws = saberinfo.SaberWeldSpots:Clone()
						sws.Center.Weld.Part1 = character:WaitForChild("LowerTorso")
					end
					sws.Parent = character
				end
				local hilt2 = tool.Model:Clone()
				hilt2.Parent = character
				hilt2.Name = "WHilt2"
				hilt2.Center.Weld.Part1 = sws.Saber2
				local b2 = hilt2:FindFirstChild("Blade")
				if b2 then b2:Destroy() end
				if hilt2:FindFirstChild("Hitbox") then hilt2.Hitbox:Destroy() end
				if hilt2:FindFirstChild("Reflect") then hilt2.Reflect:Destroy() end
				for _, part in pairs(hilt2.SABER_MODEL:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Transparency = 0
						if part:FindFirstChild("Revert") then
							part.Transparency = part.Revert.Value
						end
					end
				end
				tool.SaberType.Value = "Single"
			elseif tool.SaberType.Value == "Single" then
				if character:FindFirstChild("WHilt2") then
					character:FindFirstChild("WHilt2"):Destroy()
				end
				local lhg = saberinfo.LeftHandGrip:Clone()
				lhg.Parent = character
				lhg.Weld.Part1 = character.LeftHand
				local hilt2 = tool.Model:Clone()
				hilt2.Parent = character
				hilt2.Name = "Lightsaber2"
				hilt2.Center.Weld.Part1 = lhg.SaberSpot
				if hilt2:FindFirstChild("Hitbox") then hilt2.Hitbox:Destroy() end
				if hilt2:FindFirstChild("Reflect") then hilt2.Reflect:Destroy() end
				if wasIgnited then
					local blade2 = hilt2:FindFirstChild("Blade")
					if blade2 then
						TS:Create(blade2.TWEEN, TweenInfo.new(0.5), {Position = blade2.UPPER.Position}):Play()
						TS:Create(blade2.light, TweenInfo.new(0.5), {Range = 9}):Play()
						if tool:FindFirstChild("SaberType").Value ~= "Vibro" then
							blade2.Trail.Enabled = true
						end
					end
					if player.UserId == 4947166724 or player.UserId == 59959490 or player.UserId == 2337274642 or player.UserId == 1910520938 then
						playSound(tool.Handle.kamiIgnition, hrp)
						tool.Handle.KamiIdle:Play()
					else
						local data = player:FindFirstChild("Data")
						local usedCustom = false
						if data and data:FindFirstChild("Saber") and data.Saber:FindFirstChild("Color") then
							local entry = find_id_in_data(saber_parts.Colors, data.Saber.Color.Value, "Name")
							if entry and entry.SoundId and tostring(entry.SoundId) ~= "" then
								local customSound = Instance.new("Sound")
								customSound.SoundId = "rbxassetid://" .. tostring(entry.SoundId)
								if tool.Handle and tool.Handle:FindFirstChild("activate") then
									customSound.Volume = tool.Handle.activate.Volume
								end
								usedCustom = true
								playSound(customSound, hrp)
							end
						end
						if not usedCustom then
							playSound(tool.Handle.activate, hrp)
						end
						tool.Handle.hum:Play()
					end
				end
				tool.SaberType.Value = "Dual"
			end
			return
		elseif keyword == "TDouble" then
			if tool:GetAttribute("IsReversed") then
				return
			end
			local wasIgnited = extra1
			if not tool:GetAttribute("SingleBladeMode") then
				tool:SetAttribute("SingleBladeMode", true)
				local blade2 = tool.Model:FindFirstChild("Blade2")
				if blade2 then
					TS:Create(blade2.TWEEN, TweenInfo.new(0.5), {Position = blade2.LOWER.Position}):Play()
					TS:Create(blade2.light, TweenInfo.new(0.5), {Range = 0}):Play()
					blade2.Trail.Enabled = false
				end
				if player.UserId == 1 then
					playSound(tool.Handle.AhsokaDisIgnite, hrp)
				else
					playSound(tool.Handle.deactivate, hrp)
				end
			else
				tool:SetAttribute("SingleBladeMode", nil)
				local blade2 = tool.Model:FindFirstChild("Blade2")
				if blade2 then
					if wasIgnited then
						TS:Create(blade2.TWEEN, TweenInfo.new(0.5), {Position = blade2.UPPER.Position}):Play()
						TS:Create(blade2.light, TweenInfo.new(0.5), {Range = 9}):Play()
						if not (tool:FindFirstChild("SaberType") and tool.SaberType.Value == "Vibro") then
							blade2.Trail.Enabled = true
						end
					end
				end
				if wasIgnited then
					if player.UserId == 4947166724 or player.UserId == 59959490 or player.UserId == 2337274642 or player.UserId == 1910520938 then
						playSound(tool.Handle.kamiIgnition, hrp)
						tool.Handle.KamiIdle:Play()
					else
						local data = player:FindFirstChild("Data")
						local usedCustom = false
						if data and data:FindFirstChild("Saber") and data.Saber:FindFirstChild("Color") then
							local entry = find_id_in_data(saber_parts.Colors, data.Saber.Color.Value, "Name")
							if entry and entry.SoundId and tostring(entry.SoundId) ~= "" then
								local customSound = Instance.new("Sound")
								customSound.SoundId = "rbxassetid://" .. tostring(entry.SoundId)
								if tool.Handle and tool.Handle:FindFirstChild("activate") then
									customSound.Volume = tool.Handle.activate.Volume
								end
								usedCustom = true
								playSound(customSound, hrp)
							end
						end
						if not usedCustom then
							playSound(tool.Handle.activate, hrp)
						end
						tool.Handle.hum:Play()
					end
				end
			end
			return
		elseif keyword == "ignite" then
			local data = player:FindFirstChild("Data")

			for i, blade in pairs(sabers) do
				TS:Create(blade.TWEEN, TweenInfo.new(0.5), {Position = blade.UPPER.Position}):Play()
				TS:Create(blade.light, TweenInfo.new(0.5), {Range = 9}):Play()
				if not (tool:FindFirstChild("SaberType") and tool.SaberType.Value == "Vibro") then
					blade.Trail.Enabled = true
				end
			end

			if tool:FindFirstChild("SaberType") and tool.SaberType.Value == "Vibro" then
				for i = 1, 3 do
					TS:Create(tool.Model.SABER_MODEL.Hilt["Blade" .. i], TweenInfo.new(0.5), {Transparency = 0}):Play()
				end
			end

			if player.UserId == 4947166724 or player.UserId == 59959490 or player.UserId == 2337274642 or player.UserId == 1910520938 then
				playSound(tool.Handle.kamiIgnition, hrp)
				tool.Handle.KamiIdle:Play()
			else
				local data2 = player:FindFirstChild("Data")
				local usedCustom = false
				if data2 and data2:FindFirstChild("Saber") and data2.Saber:FindFirstChild("Color") then
					local entry = find_id_in_data(saber_parts.Colors, data2.Saber.Color.Value, "Name")
					if entry and entry.SoundId and tostring(entry.SoundId) ~= "" then
						local customSound = Instance.new("Sound")
						customSound.SoundId = "rbxassetid://" .. tostring(entry.SoundId)
						if tool.Handle and tool.Handle:FindFirstChild("activate") then
							customSound.Volume = tool.Handle.activate.Volume
						end
						usedCustom = true
						playSound(customSound, hrp)
					end
				end
				if not usedCustom then
					playSound(tool.Handle.activate, hrp)
				end
				tool.Handle.hum:Play()
			end

		elseif keyword == "disignite" then
			for _, blade in pairs(sabers) do
				if blade and blade:FindFirstChild("TWEEN") and blade:FindFirstChild("LOWER") then
					TS:Create(blade.TWEEN, TweenInfo.new(0.5), {Position = blade.LOWER.Position}):Play()
				end
				if blade and blade:FindFirstChild("light") then
					TS:Create(blade.light, TweenInfo.new(0.5), {Range = 0}):Play()
				end
				if blade and blade:FindFirstChild("Trail") then
					blade.Trail.Enabled = false
				end
			end

			if tool:FindFirstChild("SaberType") and tool.SaberType.Value == "Vibro" then
				for i = 1, 3 do
					TS:Create(tool.Model.SABER_MODEL.Hilt["Blade" .. i], TweenInfo.new(0.5), {Transparency = 1}):Play()
				end
			end

			if player.UserId == 4947166724 or player.UserId == 59959490 or player.UserId == 2337274642 or player.UserId == 1910520938 then
				playSound(tool.Handle.deactivate, hrp)
				tool.Handle.KamiIdle:Stop()
			else
				playSound(tool.Handle.deactivate, hrp)
				tool.Handle.hum:Stop()
			end

		elseif keyword == "swing" then
			if character:GetAttribute("Downed") then return end
			if character:FindFirstChild("Dashing") then return end
			if humanoid and (humanoid:GetState() == Enum.HumanoidStateType.Jumping or humanoid:GetState() == Enum.HumanoidStateType.Freefall) then return end
			local s
			if player.UserId == 59959490 or player.UserId == 1910520938 then
				s = getRandomFromFolder(tool.Handle, "Swings")
				if not s then
					local name = "AhsokaSwing" .. math.random(1, 2)
					s = tool.Handle:FindFirstChild(name)
				end
			else
				s = getRandomFromFolder(tool.Handle, "Swings")
				if not s then
					local name = "swing" .. math.random(1, 2)
					s = tool.Handle:FindFirstChild(name)
				end
			end
			if s then
				playSound(s, tool.Handle, 0.1)
			end

		elseif keyword == "HTarget" then
			if character:GetAttribute("Downed") then return end
			if extra2 and extra2:GetAttribute("Downed") then return end

			local function rewardOnKill(targetHumanoid: Humanoid)
				task.delay(0.05, function()
					if targetHumanoid and targetHumanoid.Health <= 0 then
						if humanoid and humanoid.Health > 0 then
							humanoid.Health = math.min(humanoid.Health + 50, humanoid.MaxHealth)
						end
					end
				end)
			end

			if extra2 and extra2:FindFirstChild("HumanoidRootPart") and extra2:FindFirstChild("Humanoid") and not character:FindFirstChild("_Stunned") then
				local targetChar = extra2
				local targetHumanoid = targetChar.Humanoid
				local targetHRP = targetChar.HumanoidRootPart

				local fact_check = (extra1.Position - targetHRP.Position).Magnitude
				if fact_check >= 15 then return end

				local function markRaiderKOS()
					local plr = game.Players[player.Name]
					if plr and plr.Team == game.Teams.Raiders then
						local head = player.Character and player.Character:FindFirstChild("Head")
						local division = head and head:FindFirstChild("Division")
						local label = division and division:FindFirstChild("TextLabel")
						if label and label.Text ~= "Kill on Sight" then
							label.Text = "Kill on Sight"
						end
					end
				end

				if not targetChar:FindFirstChild("!Blocking") and not targetChar:FindFirstChild("!Parry") then
					local isStrongHit = (extra3 == 4 or extra3 == 5 or extra3 == 6)
					if isStrongHit then
						targetHumanoid.Health -= formdata.StrongHit
					else
						targetHumanoid.Health -= formdata.Hit
					end
					rewardOnKill(targetHumanoid)
					markRaiderKOS()
					local hitS = getRandomFromFolder(tool.Handle, "Hits") or tool.Handle:FindFirstChild("hit")
					if hitS then
						playSound(hitS, tool.Handle, 0.1)
					end

				elseif targetChar:FindFirstChild("!Parry") then
					markRaiderKOS()

					if targetHRP then
						targetHRP.Velocity = Vector3.new(0, 0, 0)
						targetHRP.RotVelocity = Vector3.new(0, 0, 0)
					end

					local regenBlock = Instance.new("BoolValue", targetChar)
					regenBlock.Name = "_RegenBlock"
					game.Debris:AddItem(regenBlock, 0.5)

					local parryAnim = targetHumanoid:LoadAnimation(saberinfo.Anim["parry" .. math.random(1, 3)])
					parryAnim.Priority = Enum.AnimationPriority.Action4
					parryAnim:Play(0.1)
					delay(0.5, function()
						parryAnim:Stop(0.1)
					end)

					local stunnedAnim = humanoid:LoadAnimation(saberinfo.Anim.stunned)
					stunnedAnim.Priority = Enum.AnimationPriority.Action4
					stunnedAnim:Play(3)
					stunnedAnim:AdjustSpeed(0.5)
					delay(1.7, function()
						stunnedAnim:Stop(0.1)
					end)

					local stunFlag = Instance.new("BoolValue")
					stunFlag.Name = "_Stunned"
					stunFlag.Parent = character
					game.Debris:AddItem(stunFlag, 1.5)

					if humanoid then
						humanoid:SetAttribute("OldWalkSpeed", humanoid.WalkSpeed)
						humanoid:SetAttribute("OldJumpPower", humanoid.JumpPower)
						humanoid.WalkSpeed = 0
						humanoid.JumpPower = 0
						task.delay(1.7, function()
							if humanoid then
								humanoid.WalkSpeed = humanoid:GetAttribute("OldWalkSpeed") or 16
								humanoid.JumpPower = humanoid:GetAttribute("OldJumpPower") or 50
							end
						end)
					end

					local BV2 = Instance.new("BodyVelocity", hrp)
					BV2.MaxForce = Vector3.new(100000, 0, 100000)
					BV2.Velocity = hrp.CFrame.LookVector * -3
					game.Debris:AddItem(BV2, 0.75)

					local parryS = getRandomFromFolder(tool.Handle, "Parries") or tool.Handle:FindFirstChild("parry")
					if parryS then
						playSound(parryS, tool.Handle, 0.1)
					end

					for _, blade in pairs(sabers) do
						if blade:FindFirstChild("Clash") and blade.Clash:FindFirstChild("parry") then
							blade.Clash.parry.Enabled = true
							delay(0.2, function()
								if blade.Clash and blade.Clash:FindFirstChild("parry") then
									blade.Clash.parry.Enabled = false
								end
							end)
						end
						if blade:FindFirstChild("PLight") then
							blade.parry_light.Enabled = true
							delay(0.2, function()
								if blade:FindFirstChild("PLight") then
									blade.parry_light.Enabled = false
								end
							end)
						end
					end

				elseif targetChar:FindFirstChild("!Blocking") then
					markRaiderKOS()

					local removeBlock = Instance.new("BoolValue", targetChar)
					removeBlock.Name = "_RemoveBlock"
					game.Debris:AddItem(removeBlock, 0.5)

					local parryAnim = targetHumanoid:LoadAnimation(saberinfo.Anim["parry" .. math.random(1, 3)])
					parryAnim.Priority = Enum.AnimationPriority.Action4
					parryAnim:Play(0.1)
					delay(0.5, function()
						parryAnim:Stop(0.1)
					end)

					targetHumanoid.Health -= formdata.BlockHit
					rewardOnKill(targetHumanoid)

					local clashS = getRandomFromFolder(tool.Handle, "Clashes") or tool.Handle:FindFirstChild("clash")
					if clashS then
						playSound(clashS, tool.Handle, 0.1)
					end

					for _, blade in pairs(sabers) do
						if blade:FindFirstChild("Clash") and blade.Clash:FindFirstChild("sparks") then
							blade.Clash.sparks.Enabled = true
							delay(0.2, function()
								if blade.Clash and blade.Clash:FindFirstChild("sparks") then
									blade.Clash.sparks.Enabled = false
								end
							end)
						end
						if blade:FindFirstChild("CLight") then
							blade.clash_light.Enabled = true
							delay(0.2, function()
								if blade:FindFirstChild("CLight") then
									blade.clash_light.Enabled = false
								end
							end)
						end
					end
				end
			end

		elseif keyword == "block" then
			local bool = Instance.new("BoolValue", character)
			bool.Name = "!Blocking"

			local bool3 = Instance.new("BoolValue", character)
			bool3.Name = "!BlasterParry"
			game.Debris:AddItem(bool3, formdata.BulletBounce)

			if extra1 > 0 then
				local bool2 = Instance.new("BoolValue", character)
				bool2.Name = "!Parry"
				game.Debris:AddItem(bool2, formdata.ParryWindow)

				local highlight = Instance.new("Highlight", character)
				highlight.Adornee = character
				highlight.Name = "PLight"
				highlight.DepthMode = "Occluded"
				highlight.FillTransparency = 1
				highlight.OutlineColor = Color3.fromRGB(255, 170, 0)

				TS:Create(highlight, TweenInfo.new(formdata.ParryWindow, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {OutlineTransparency = 1}):Play()
				game.Debris:AddItem(highlight, formdata.ParryWindow)
			end
		elseif keyword == "unblock" then
			if character:FindFirstChild("!Blocking") then
				character:FindFirstChild("!Blocking"):Destroy()
			end
			if character:FindFirstChild("!BlasterParry") then
				character:FindFirstChild("!BlasterParry"):Destroy()
			end
			if character:FindFirstChild("!Parry") then
				character:FindFirstChild("!Parry"):Destroy()
				if character:FindFirstChild("PLight") then
					character:FindFirstChild("PLight"):Destroy()
				end
			end
		end
	end)
end

return module
