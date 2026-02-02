local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local SGUI = game:GetService("StarterGui")

local module = {}

local function saberType(tool)
	return tool:FindFirstChild("SaberType").Value
end

function module.Initialize(tool)
	local player = game.Players.LocalPlayer
	local character = player.Character
	local humanoid = character:WaitForChild("Humanoid")
	local hrp = character:WaitForChild("HumanoidRootPart")

	local mouse = player:GetMouse()

	local saberinfo = game.ReplicatedStorage:WaitForChild("IR_System").Lightsaber
	local event = saberinfo.Remote
	local downedEvent = game.ReplicatedStorage:WaitForChild("DownedAction")

	local Params = RaycastParams.new()
	Params.FilterDescendantsInstances = {character}
	Params.FilterType = Enum.RaycastFilterType.Exclude

	local jump_con

	local anim = saberinfo.Anim
	local allanims = {
		["equip"] = humanoid:LoadAnimation(anim.equip),
		["unequip"] = humanoid:LoadAnimation(anim.unequip),
		["doublejump"] = humanoid:LoadAnimation(anim.doublejump),
		["push"] = humanoid:LoadAnimation(anim.push),
		["heal"] = humanoid:LoadAnimation(anim.heal),
	}
	local swaplist, allforms, formanimations, formstats = require(script:WaitForChild("Forms")).GetForms(humanoid, "Reversed")
	if not tool:FindFirstChild("IsReversed") then
		swaplist, allforms, formanimations, formstats = require(script:WaitForChild("Forms")).GetForms(humanoid, tool.SaberType.Value)
	end

	allanims["equip"].Priority = Enum.AnimationPriority.Action
	allanims["unequip"].Priority = Enum.AnimationPriority.Action

	local PlayerHud = player.PlayerGui:FindFirstChild("PlayerHUD")

	local force = 100
	local block_percent = 100
	local can_use = true

	local equipped = false
	local ignited = false
	local swinging = false
	local blocking = false
	local form = swaplist[1]

	local global_db = false
	local atk_db = false
	local force_equip = false

	local last_attack = 1
	local attack_time = tick()
	local blocking_anim
	local swing

	local block_after_swing_cooldown = false

	local selected_force = "Push"
	local force_index = 1

	local doubleSingleMode = false
	local fCooldown = false
	local swap_index = 1
	local doublejump = false
	local lastDoubleJumpTime = 0
	local doubleJumpCooldown = 0

	local force_heal_cd = false
	local force_push_cd = false
	local force_judgement_cd = false

	local function cooldown(t)
		global_db = true
		task.delay(t, function()
			global_db = false
		end)
	end
	local function attack_cooldown(t)
		atk_db = true
		task.delay(t, function()
			atk_db = false
		end)
	end
	local function playSound(s, part)
		local sound = s:Clone()
		sound.Parent = part
		sound:Play()
		game.Debris:AddItem(sound, 2)
	end
	local function updateUi()
		PlayerHud.Frame.Text.FormName.Text = "(Z) " .. form .. " "
		PlayerHud.Frame.Text.ForceName.Text = ""
		TS:Create(PlayerHud.Frame.StaminaBar.Bar, TweenInfo.new(0.25), {Size = UDim2.new(force / 100, 0, 1, 0)}):Play()
		TS:Create(PlayerHud.Frame.BlockBar.Bar, TweenInfo.new(0.25), {Size = UDim2.new(block_percent / 100, 0, 1, 0)}):Play()
	end
	local function GetTouchingParts(part)
		local connection = part.Touched:Connect(function() end)
		local results = part:GetTouchingParts()
		connection:Disconnect()
		return results
	end
	local function findTable(haystack, needle)
		for i, t in haystack do
			if t.Name == needle.Name then
				return true
			end
		end
		return false
	end
	local function lerp(a, b, t)
		return a + (b - a) * t
	end

	local force_order = {}
	local force_list = {}

	local function toggleSaber(mode)
		if mode == true then
			event:FireServer(formstats[form], tool, "ignite")
			formanimations[form].stance:Play(0.1)
			ignited = true
		elseif mode == false then
			if character:GetAttribute("KeepSaberOn") == true then
				return
			end
			event:FireServer(formstats[form], tool, "disignite")
			formanimations[form].stance:Stop(0.1)
			ignited = false
		end
	end

	local function handleDownedChanged()
		if character:GetAttribute("SpecialSelfReviving") == true then
			return
		end

		local isDowned = character:GetAttribute("Downed")

		if isDowned == true then
			if ignited then
				toggleSaber(false)
			end
		end
	end

	character:GetAttributeChangedSignal("Downed"):Connect(handleDownedChanged)
	handleDownedChanged()

	downedEvent.OnClientEvent:Connect(function(action)
		if action ~= "ForceUnblock" then return end
		if blocking then
			pcall(function()
				event:FireServer(formstats[form], tool, "unblock")
			end)
			blocking = false
			if blocking_anim then
				pcall(function()
					blocking_anim:Stop(0.1)
				end)
			end
			global_db = false
		end
	end)

	event:FireServer(formstats[form], tool, "setup_saber")
	event:FireServer(formstats[form], tool, "unequip")
	updateUi()

	tool.Equipped:Connect(function()
		if not can_use then return end

		local menu_open = false
		if player.PlayerGui:FindFirstChild("TbcWorkbenchUi") and player.PlayerGui.TbcWorkbenchUi.Enabled == true then menu_open = true end

		if menu_open then
			can_use = false
			task.wait(0.1)
			can_use = true
			humanoid:UnequipTools()
		elseif force_equip == true then
			force_equip = false
		else
			event:FireServer(formstats[form], tool, "equip")
			allanims["equip"]:Play()
			equipped = true
			PlayerHud.Frame.Abilities.Tool.Visible = true
			PlayerHud.Frame.Text.Visible = true
		end

		updateUi()
	end)

	tool.Unequipped:Connect(function()
		if not can_use then return end

		if global_db == true then
			force_equip = true
			task.wait(0.05)
			humanoid:EquipTool(tool)
		else
			if ignited then toggleSaber(false) end
			event:FireServer(formstats[form], tool, "unequip")
			allanims["unequip"]:Play()
			PlayerHud.Frame.Abilities.Tool.Visible = false
			PlayerHud.Frame.Text.Visible = false
			equipped = false
			ignited = false
		end
	end)

	mouse.Button1Down:Connect(function()
		if not can_use then return end
		if block_percent == 0 then return end
		if character:FindFirstChild("_Stunned") then return end

		if equipped and ignited and not blocking then
			if atk_db or global_db then return end

			local now = tick()
			if now - attack_time > 1 or last_attack > 3 then
				last_attack = 1
			end

			attack_time = now
			local currentAttack = last_attack

			swing = formanimations[form]["atk" .. tostring(currentAttack)]
			if not swing then return end

			event:FireServer(formstats[form], tool, "swing")
			swing:Play(0.1)

			if tool.SaberType.Value == "Dual" then
				swing:AdjustSpeed(1.1)
			elseif tool.SaberType.Value == "Single" then
				swing:AdjustSpeed(1.1)
			elseif tool.SaberType.Value == "Double" then
				swing:AdjustSpeed(1.1)
			elseif tool.SaberType.Value == "Reversed" then
				swing:AdjustSpeed(1.1)
			elseif tool.SaberType.Value == "Vibro" then
				swing:AdjustSpeed(1.1)
			elseif tool.SaberType.Value == "Crossguard" then
				swing:AdjustSpeed(1.1)
			elseif tool.SaberType.Value == "Pike" then
				swing:AdjustSpeed(1)
			end

			swinging = true
			block_after_swing_cooldown = true
			last_attack = currentAttack + 1

			task.spawn(function()
				task.wait(swing.Length)
				swinging = false
				block_after_swing_cooldown = false
			end)

			if currentAttack == 3 then
				attack_cooldown(swing.Length + 0.35)
				last_attack = 1
			else
				attack_cooldown(swing.Length)
			end
		end
	end)

	mouse.Button2Down:Connect(function()
		if not can_use then return end
		if character:FindFirstChild("_Stunned") then return end
		if block_percent < 20 then return end
		if block_after_swing_cooldown then return end

		if equipped and ignited and not swinging then
			if global_db then return end
			global_db = true

			PlayerHud.Frame.BlockBar.Bar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
			TS:Create(PlayerHud.Frame.BlockBar.Bar, TweenInfo.new(formstats[form].ParryWindow), {BackgroundColor3 = Color3.fromRGB(229, 158, 71)}):Play()

			event:FireServer(formstats[form], tool, "block", force)
			blocking_anim = formanimations[form]["block"]
			blocking_anim:Play(0.1)
			blocking = true
		end
	end)

	mouse.Button2Up:Connect(function()
		if not can_use then return end

		if blocking and equipped and ignited then
			event:FireServer(formstats[form], tool, "unblock")
			blocking = false
			blocking_anim:Stop(0.1)
			cooldown(0.31)
		end
	end)

	local forceAbilityCd = false

	UIS.InputBegan:Connect(function(input, gpe)
		if not can_use then return end
		if gpe then return end

		if input.KeyCode == Enum.KeyCode.Q and equipped and not global_db then
			if character:GetAttribute("Downed") == true then
				return
			end

			cooldown(0.5)

			if ignited == true then
				toggleSaber(false)
			else
				toggleSaber(true)
			end
		elseif input.KeyCode == Enum.KeyCode.F and equipped and ignited then
			if fCooldown then return end
			fCooldown = true
			task.delay(0.5, function() fCooldown = false end)
			if saberType(tool) == "Dual" or (saberType(tool) == "Single" and (character:FindFirstChild("Lightsaber2") or character:FindFirstChild("WHilt2"))) then
				if ignited then
					formanimations[form].stance:Stop(0.1)
				end
				event:FireServer(formstats[form], tool, "TDual", ignited)
				if saberType(tool) == "Dual" then
					tool.SaberType.Value = "Single"
					swaplist, allforms, formanimations, formstats = require(script:WaitForChild("Forms")).GetForms(humanoid, "Single")
				else
					tool.SaberType.Value = "Dual"
					swaplist, allforms, formanimations, formstats = require(script:WaitForChild("Forms")).GetForms(humanoid, "Dual")
				end
				swap_index = 1
				form = swaplist[1]
				if ignited then
					formanimations[form].stance:Play(0.1)
				end
				updateUi()
			elseif saberType(tool) == "Double" then
				if ignited then
					formanimations[form].stance:Stop(0.1)
				end
				event:FireServer(formstats[form], tool, "TDouble", ignited)
				doubleSingleMode = not doubleSingleMode
				if doubleSingleMode then
					swaplist, allforms, formanimations, formstats = require(script:WaitForChild("Forms")).GetForms(humanoid, "Single")
				else
					swaplist, allforms, formanimations, formstats = require(script:WaitForChild("Forms")).GetForms(humanoid, "Double")
				end
				swap_index = 1
				form = swaplist[swap_index]
				if ignited then
					formanimations[form].stance:Play(0.1)
				end
				updateUi()
			end
		elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.X then
			return
		elseif input.KeyCode == Enum.KeyCode.Z and equipped and not global_db then
			if swap_index + 1 > #swaplist then
				swap_index = 1
			else
				swap_index += 1
			end

			if equipped and ignited then
				formanimations[form].stance:Stop(0.1)
				form = swaplist[swap_index]
				formanimations[form].stance:Play(0.1)
			else
				form = swaplist[swap_index]
			end

			updateUi()
		elseif input.KeyCode == Enum.KeyCode.Space and not global_db and saberType(tool) ~= "Vibro" and not character:FindFirstChild("_Stunned") then
			if character:GetAttribute("Downed") == true or character:GetAttribute("CanDoubleJump") == false then
				return
			end

			local currentTime = tick()
			if (humanoid:GetState() == Enum.HumanoidStateType.Jumping or humanoid:GetState() == Enum.HumanoidStateType.Freefall)
				and doublejump == false
				and force >= 20
				and (currentTime - lastDoubleJumpTime >= doubleJumpCooldown) then

				doublejump = true
				lastDoubleJumpTime = currentTime
				force = math.clamp(force - 20, 0, 100)
				updateUi()

				humanoid.JumpPower = 70
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				allanims["doublejump"]:Play(0.2)

				if UIS:IsKeyDown(Enum.KeyCode.S) then
					allanims["doublejump"]:AdjustSpeed(-1)
				else
					allanims["doublejump"]:AdjustSpeed(1)
				end

				task.wait(allanims["doublejump"].Length - 0.1)
				allanims["doublejump"]:Stop(0.1)
				humanoid.JumpPower = 60
			end
		end
	end)

	task.spawn(function()
		local last_force = force
		local regen_wait = -1

		local last_block = block_percent
		local regen_wait2 = -1
		while task.wait(0.1) do
			if not can_use then return end
			if last_force ~= force then
				regen_wait = 10
			end
			if regen_wait == -1 then
				force = math.clamp(force + 2, 0, 100)
				updateUi()
			else
				regen_wait = math.clamp(regen_wait - 1, -1, 99999999)
			end
			last_force = force

			if last_block ~= block_percent then
				regen_wait2 = 25
			end
			if regen_wait2 == -1 then
				block_percent = math.clamp(block_percent + 1, 0, 100)
				updateUi()
			else
				regen_wait2 = math.clamp(regen_wait2 - 1, -1, 99999999)
			end
			last_block = block_percent

			if block_percent == 0 then
				if blocking and equipped and ignited then
					event:FireServer(formstats[form], tool, "unblock")
					blocking = false
					blocking_anim:Stop(0.1)
					cooldown(0.1)
				end
			end

			local l = 0
			if block_percent < 25 then
				l = 8
			end

			game.Lighting.block_stun.Size = lerp(game.Lighting.block_stun.Size, l, 0.2)
		end
	end)

	tool.Model.Hitbox.Touched:Connect(function(part)
		if not can_use then return end
		if character:FindFirstChild("_Stunned") then return end

		if swinging and ignited and equipped then
			if part.Parent:FindFirstChild("Humanoid") and part.Parent:FindFirstChild("HumanoidRootPart") and part.Parent:FindFirstChild("Humanoid").Health > 0 then
				swinging = false
				event:FireServer(formstats[form], tool, "hit_target", hrp, part.Parent, last_attack)

				local tween_fov = 0
				if part.Parent:FindFirstChild("!Parry") then
					tween_fov = 70
				elseif part.Parent:FindFirstChild("!Blocking") then
					tween_fov = 55
				end

				if tween_fov ~= 0 then
					local current_fov = workspace.CurrentCamera.FieldOfView
					local target_fov = tween_fov
					local tween_info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

					local tween = TS:Create(workspace.CurrentCamera, tween_info, {FieldOfView = target_fov})
					tween:Play()

					tween.Completed:Connect(function()
						TS:Create(workspace.CurrentCamera, TweenInfo.new(0.75), {FieldOfView = 55}):Play()
					end)
				end
			end
		end
	end)

	character.ChildAdded:Connect(function(child)
		if not can_use then return end

		if child.Name == "_RegenBlock" then
			block_percent = math.clamp(block_percent + 25, 0, 100) updateUi()
		elseif child.Name == "_RemoveBlock" then
			block_percent = math.clamp(block_percent - 20, 0, 100) updateUi()
		elseif child.Name == "_BlasterShot" then
			block_percent = math.clamp(block_percent - math.random(6, 10), 0, 100) updateUi()
		elseif child.Name == "_Stunned" and ignited and equipped then
			humanoid.JumpPower = 0
			jump_con = child.Destroying:Connect(function()
				humanoid.JumpPower = 50
				jump_con:Disconnect()
			end)

			swinging = false
			force = math.clamp(force - 10, 0, 100) updateUi()
		elseif child.Name == "_Shocked" then
			humanoid.WalkSpeed = 6
			task.wait(0.6)
			humanoid.WalkSpeed = 14
		end
	end)

	humanoid.StateChanged:Connect(function(oldState, newState)
		if not can_use then return end
		if newState == Enum.HumanoidStateType.Landed then
			doublejump = false
		end
	end)
	humanoid.Died:Connect(function()
		can_use = false
		game.Lighting.block_stun.Size = 0
		if jump_con ~= nil then
			jump_con:Disconnect()
			jump_con = nil
		end
	end)
end

return module
