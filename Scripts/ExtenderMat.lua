function KTUI_ResetScripts()
	broadcastToAll("Reloading KT UI Extender")
	local r = 0
	for _, obj in ipairs(getAllObjects()) do
		if obj.hasTag("KTUIMini") then
			obj.reload()
			r = r + 1
		end
	end
	broadcastToAll("Reloaded " .. r .. " items")
end

function detectItemOnTop() --casts a ball that detects all the items on top
	local start = { self.getPosition()[1], self.getPosition()[2] + 3.1, self.getPosition()[3] }
	local hitList = Physics.cast({
		origin = start,
		direction = { 0, 1, 0 },
		type = 2,
		size = { 15, 15, 15 },
		max_distance = 3,
		debug = false,
	})
	return hitList
end

function ExtendUI(player)
	WebRequest.get(
		"https://raw.githubusercontent.com/mal20k/KTUI/refs/heads/main/Scripts/MiniatureScript24.lua",
		function(req)
			if req.is_error then
				log(req.error)
			else
				local allTops = detectItemOnTop()
				local script = req.text

				for _, hitlist in ipairs(allTops) do
					local object = hitlist["hit_object"]
					UpdateModelScript(player, object, script)
				end
			end
		end
	)
end

function SaveAllPositions(player)
	for _, obj in ipairs(getAllObjects()) do
		if obj.hasTag("KTUIMini") then
			local op = obj.call("getOwningPlayer")
			if op ~= nil then
				obj.call("savePosition")
			end
		end
	end
	player.broadcast("All positions saved")
end

function LoadAllPositions(player)
	for _, obj in ipairs(getAllObjects()) do
		if obj.hasTag("KTUIMini") then
			local op = obj.call("getOwningPlayer")
			if op ~= nil then
				obj.call("loadPosition")
			end
		end
	end
	player.broadcast("All positions saved")
end

function ReadyAllOperatives(player)
	for _, obj in ipairs(getAllObjects()) do
		if obj.hasTag("KTUIMini") then
			local op = obj.call("getOwningPlayer")
			if op ~= nil then
				obj.call("KTUI_ReadyOperative")
			end
		end
	end
	player.broadcast("All operatives have been readied")
end

function CleanAllOperatives(player)
	local allTops = detectItemOnTop()
	for _, hitlist in ipairs(allTops) do
		local obj = hitlist["hit_object"]
		if obj.hasTag("KTUIMini") then
			local op = obj.call("getOwningPlayer")
			if op ~= nil then
				obj.call("KTUI_CleanOperative")
			end
		end
	end
	player.broadcast("All operatives have cleaned of their tokens")
end

function UpdateModelScript(player, object, script)
	if object.tag == "Figurine" then
		somethingExtended = true
		object.setLuaScript(script)
		object = object.reload()
		object.addTag("KTUIMini")
		Wait.frames(function()
			object.call("setOwningPlayer", player.steam_id)
		end, 1)
	end
end

function UpdateScript(player)
	WebRequest.get(
		"https://raw.githubusercontent.com/mal20k/KTUI/refs/heads/main/Scripts/MiniatureScript24.lua",
		function(req)
			if req.is_error then
				log(req.error)
			else
				local allTops = detectItemOnTop()
				local script = req.text

				for _, hitlist in ipairs(allTops) do
					local object = hitlist["hit_object"]
					UpdateModelScript(player, object, script)
				end
			end
		end
	)
end

function textColorXml(color, text)
	return string.format('<textcolor color="#%s">%s</textcolor>', color, text)
end

function textColorMd(color, text)
	return string.format("[%s]%s[-]", color, text)
end

function magiclines(str)
	local pos = 1
	return function()
		if not pos then
			return nil
		end
		local p1, p2 = string.find(str, "\r?\n", pos)
		local line
		if p1 then
			line = str:sub(pos, p1 - 1)
			pos = p2 + 1
		else
			line = str:sub(pos)
			pos = nil
		end
		return line
	end
end

function ParseWeapons(desc)
	local lines = {}
	local in_weapons_section = false

	for line in magiclines(desc) do
		if line:find("Weapons") then
			in_weapons_section = true
		elseif line:find("%-%-%-") then
			break
		elseif in_weapons_section then
			table.insert(lines, line)
		end
	end

	local weapons = {}
	local current_weapon = {}

	for i, line in ipairs(lines) do
		if line == "" then
			if #current_weapon > 0 then
				table.insert(weapons, current_weapon)
				current_weapon = {}
			end
		else
			table.insert(current_weapon, line)
		end
	end

	if #current_weapon > 0 then
		table.insert(weapons, current_weapon)
	end

	return weapons
end

function ParseExtra(desc)
	local lines = {}
	local in_extra_section = false

	for line in magiclines(desc) do
		if in_extra_section then
			table.insert(lines, line)
		elseif line:find("%-%-%-") then
			in_extra_section = true
		end
	end

	return lines
end

function UpdateOldModels(player)
	WebRequest.get(
		"https://raw.githubusercontent.com/mal20k/KTUI/refs/heads/main/Scripts/MiniatureScript24.lua",
		function(req)
			local allTops = detectItemOnTop()
			local script = req.text

			for _, hitlist in ipairs(allTops) do
				local object = hitlist["hit_object"]
				UpdateOldState(object)
				UpdateModelScript(player, object, script)
			end
		end
	)
end

function UpdateOldState(object)
	if object.tag == "Figurine" then
		local state = JSON.decode(object.script_state)

		if state.stats.M then
			state.stats.Move = state.stats.M * 2
		end

		-- if state.stats.APL then
		-- state.stats.APL = state.stats.APL
		-- end

		if state.stats.SV then
			state.stats.Save = state.stats.SV
		end

		if state.stats.W then
			state.stats.Wounds = state.stats.W
		end

		-- We remove the old stats to avoid issues with attempts to detect which stats are used.
		state.stats.M = nil
		state.stats.SV = nil
		state.stats.W = nil

		local desc = object.getDescription() or ""

		local innerUpdate = function(oldStat, newStat)
			local sstring = "%[84E680%]" .. oldStat .. "%[%-%]%s*%[ffffff%]%s*(%d+).*%[%-%]"
			for match in string.gmatch(desc, "%b[]") do
				local s = match:match(sstring)
				if s then
					local ss = state.stats[newStat]
					if ss and ss == tonumber(s) then
						return false
					end
					state.stats[newStat] = tonumber(s)
					return true
				end
			end
			return false
		end
		innerUpdate("M", "Move")
		innerUpdate("APL", "APL")
		innerUpdate("SV", "Save")
		innerUpdate("W", "Wounds")

		local weapons = ParseWeapons(desc)
		local newWeapons = {}
		for i, weaponLines in ipairs(weapons) do
			local newWeapon = {
				stats = {},
			}
			newWeapon.name = weaponLines[1]:gsub("^%([MR]%) ", "")

			local weaponStats = weaponLines[2]
			newWeapon.stats["ATK"] = weaponStats:match("%[84E680%]A%[%-%] (%d+)")
			newWeapon.stats["HIT"] = weaponStats:match("%[84E680%]WS/BS%[%-%] (%d+%+)")
			newWeapon.stats["DMG"] = weaponStats:match("%[84E680%]D%[%-%] (%d+/%d+)")

			local specialRules = "-"
			if #weaponLines == 3 then
				specialRules = weaponLines[3]:match(": (.*)") or "-"
			end
			newWeapon.stats["WR"] = specialRules
			table.insert(newWeapons, newWeapon)
		end
		state.info.weapons = newWeapons

		object.setDescription(UpdateDescription(state, ParseExtra(desc)))

		object.script_state = JSON.encode(state)
	end
end

function subsymbol(s, tbl)
	local st = s
	for o, sub in pairs(tbl) do
		st = string.gsub(st, o, sub)
	end
	return st
end

function UpdateDescription(state, extra)
	local desc = {}

	local catex = function(cat, title, func, sep)
		if next(cat) ~= nil then
			table.insert(desc, title)
			local ot = {}
			for k, v in pairs(cat) do
				table.insert(ot, func(k, v))
			end
			table.insert(desc, table.concat(ot, sep or "\n"))
		end
	end

	table.insert(
		desc,
		string.format(
			'[D36B3E][[84E680]APL[-] [ffffff]%s[-]] [[84E680]MOVE[-] [ffffff]%s"[-]]\n[[84E680]SAVE[-] [ffffff]%s+[-]] [[84E680]WOUNDS[-] [ffffff]%s[-]][-]',
			state.stats.APL or "X",
			state.stats.Move or "X",
			state.stats.Save or "X",
			state.stats.Wounds or "X"
		)
	)
	table.insert(desc, "[C5C5C5]" .. table.concat(state.info.categories, ", ") .. "[-]")

	if #state.info.weapons ~= 0 then
		catex(state.info.weapons, "[31B32B]Weapons[-]", function(k, v)
			-- log(v)
			local vs = v.stats
			local ATK = vs["ATK"] or "-"
			local HIT = vs["HIT"] or "-"
			local DMG = vs["DMG"] or "-/-"
			local WR = vs["WR"]

			local ostr = string.format(
				"%s\n[84E680]ATK[-] %s [84E680]HIT[-] %s [84E680]DMG[-] %s",
				v.name or "X",
				ATK or "X",
				HIT or "X",
				DMG or "X"
			)

			if WR and WR ~= "-" then
				ostr = ostr .. string.format("\n[84E680]WR[-]: %s", WR)
			end

			return ostr
		end, "\n\n")
	end

	table.insert(desc, "---")

	for _, extraLine in ipairs(extra) do
		table.insert(desc, extraLine)
	end

	return table.concat(desc, "\n")
end
