local module = {}

local function serializeDataFolder(folder)
	local t = {}
	for _,v in ipairs(folder:GetDescendants()) do
		if v:IsA("ValueBase") then
			t[#t+1] = {Name = v.Name, Value = v.Value}
		end
	end
	return t
end

local function applySaberSelection(folder, info)
	if folder.Crystals[info.Color].Value then
		folder.Saber.Color.Value = info.Color
	end
	if folder.Emitters[info.Emitter].Value then
		folder.Saber.Emitter.Value = info.Emitter
	end
	if folder.Hilts[info.Hilt].Value then
		folder.Saber.Hilt.Value = info.Hilt
	end
	if folder.Pommels[info.Pommel].Value then
		folder.Saber.Pommel.Value = info.Pommel
	end
	folder.Saber.Primary.Value = tostring(info.Primary)
	folder.Saber.Secondary.Value = tostring(info.Secondary)
end

function module.ServerInfo(player, keyword, extra1, extra2, extra3)
	local dataFolder = player:FindFirstChild("Data")
	if not dataFolder then return end

	if keyword == "request_data" then
		return serializeDataFolder(dataFolder)
	end

	if keyword == "update_data" then
		applySaberSelection(dataFolder, extra1)
	end
end

return module
