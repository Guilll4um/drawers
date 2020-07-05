--[[
Trolley addon for drawers

mainly based on technic:wrench mod .. thanks to theirs contributors - Guill4Um

Adds a trolley that allows the player to move drawers that contain an inventory
with items or metadata that needs perserving.
The trolley has the same tool capability as the normal hand.
To pickup a node simply right click on it. If the node contains a formspec,
you will need to shift+right click instead.
--]]

-- settings from settingtypes.txt
local craftable = core.settings:get_bool("drawers_trolley_craftable",false)
local saturation_consumption = tonumber(core.settings:get("darwers_trolley_saturation_consumption")) or 0.75
local only_one = core.settings:get_bool("drawers_trolley_one_drawers_with_items_in_player_inv",true)
local times_used_before_break = tonumber(core.settings:get("drawers_trolley_times_used_before_break")) or 40


local LATEST_SERIALIZATION_VERSION = 1

local modpath = minetest.get_modpath(minetest.get_current_modname())
dofile(modpath.."/trolley/support.lua")
dofile(modpath.."/trolley/drawers.lua")

-- Boilerplate to support localized strings if intllib mod is installed.
local S = rawget(_G, "intllib") and intllib.Getter() or function(s) return s end

local function get_meta_type(name, metaname)
	local def = drawers.trolley_registered_nodes[name]
	return def and def.metas and def.metas[metaname] or nil
end

local function get_pickup_name(name)
	return "drawers:trolley_picked_up_"..(name:gsub(":", "_"))
end

local function restore(pos, placer, itemstack)
	local name = itemstack:get_name()
	local meta_itemstack = itemstack:get_meta()
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local data = itemstack:get_meta():get_string("data")
	data = (data ~= "" and data) or	itemstack:get_metadata()
	data = minetest.deserialize(data)
	if not data then
		minetest.remove_node(pos)
		minetest.log("error", placer:get_player_name().." wanted to place "..
				name.." at "..minetest.pos_to_string(pos)..
				", but it had no data.")
		minetest.log("verbose", "itemstack: "..itemstack:to_string())
		return true
	end
	minetest.set_node(pos, {name = data.name, param2 = node.param2})
	for name, value in pairs(data.metas) do
		local meta_type = get_meta_type(data.name, name)
		if meta_type == drawers.trolley_META_TYPE_INT then
			meta:set_int(name, value)
		elseif meta_type == drawers.trolley_META_TYPE_FLOAT then
			meta:set_float(name, value)
		elseif meta_type == drawers.trolley_META_TYPE_STRING then
			meta:set_string(name, value)
		elseif meta_type == drawers.trolley_META_TYPE_TABLE then
			meta:set_string(name, value)
		end
	end
	local lists = data.lists
	for listname, list in pairs(lists) do
		inv:set_list(listname, list)
	end

	local wear = 65535
	if (times_used_before_break > 0) then
		-- retriview trolley wear
		 wear = meta_itemstack:get_int("drawer_trolley_wear")
	end		

	-- give back trolley with its wear 
	itemstack:replace("drawers:trolley")

	if (times_used_before_break > 0) then
		itemstack:set_wear(wear)
		if wear <= 0 then  itemstack:clear()   end -- trolley removed if wear = 0
		meta_itemstack:set_string("drawer_trolley_wear",nil)
	end	




	-- force reset visuals
	drawers.remove_visuals(pos)
	drawers.spawn_visuals(pos)

	-- change player saturation coz it's  heavy to carry a drawers !
	if core.get_modpath("stamina") and stamina then
		stamina.change_saturation(placer, -1 * saturation_consumption)
	end

	return itemstack
end

for name, info in pairs(drawers.trolley_registered_nodes) do
	local olddef = minetest.registered_nodes[name]
	if olddef then
		local newdef = {}
		for key, value in pairs(olddef) do
			newdef[key] = value
		end
		newdef.stack_max = 1
		newdef.description = S("%s with items"):format(newdef.description)
		newdef.groups = {}
		newdef.groups.not_in_creative_inventory = 1
		newdef.on_construct = nil
		newdef.on_destruct = nil
		newdef.after_place_node = restore
		newdef.inventory_image =  "([combine:192x192:-6,25="..drawers.get_inv_image(name)..")^drawers_trolley.png"
		newdef.wield_image = newdef.inventory_image
		minetest.register_node(":"..get_pickup_name(name), newdef)

	end
end







-- function used to limit only to one 
local function is_containing_picked_up_drawer(player_name,player_inv,pos) 
	for listname, list in pairs(player_inv:get_lists()) do
		local size = player_inv:get_size(listname)
		if size then
			for i = 1, size, 1 do
				local current_stack = player_inv:get_stack(listname, i)

				-- check stacks name
				if string.find(current_stack:get_name(), "drawers:trolley_picked_up_") then
					minetest.chat_send_player(player_name, S("You've already picked up a drawer. Put it down before!"))
					core.sound_play("drawers_wrong", { pos = pos, max_hear_distance = 6, gain = 0.2 })
					-- thanks to Heshl for the select sound at  https://freesound.org/people/Heshl/sounds/269149/ under creative common licence https://creativecommons.org/licenses/by/3.0/ file not modified except the name
					return true
				end

				-- check stack meta ( as example : chest with item of technic:wrench mod or inventorybag ... or anything else containing items)
				local player_inv_stack_meta = current_stack:get_meta()
				if (player_inv_stack_meta ~= nil) then
					local player_inv_stack_meta_txt = minetest.serialize(player_inv_stack_meta:to_table())
					if (player_inv_stack_meta_txt ~= nil) and string.find(player_inv_stack_meta_txt, "drawers:trolley_picked_up_") ~= nil then
						minetest.chat_send_player(player_name, S("You've already picked up a drawer in your %s. Put it down before!"):format(current_stack:get_definition().description))
						core.sound_play("drawers_wrong", { pos = pos, max_hear_distance = 6, gain = 0.2 })
						return true
					end
				end
			end
		end
	end
	return false
end

-- check if  we already got a drawers with item in inventory when picking up another one from in world
if (only_one) then
	local old_punch = minetest.registered_entities["__builtin:item"].on_punch
	minetest.registered_entities["__builtin:item"].on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if string.find(self.itemstring, "drawers:trolley_picked_up_") then
			if is_containing_picked_up_drawer(puncher:get_player_name(),puncher:get_inventory(),puncher:get_pos()) then
				return
			end
		end
		old_punch(self, puncher, time_from_last_punch, tool_capabilities, dir)
	end
	-- check if  we aleady got a drawers with item in inventory when picking up another one form another inventory (chest, bag, machine..)
	minetest.register_allow_player_inventory_action(function(player, action, inventory, inventory_info) 
		if action == "put" then
			-- if inventory == player:get_inventory() then
			if inventory_info.listname == "main"    then
				local is_to_check = false
				if string.find(inventory_info.stack:get_name(), "drawers:trolley_picked_up_") then
					is_to_check = true
				else 
					local player_inv_stack_meta = inventory_info.stack:get_meta()
					if (player_inv_stack_meta ~= nil) then
						local player_inv_stack_meta_txt = minetest.serialize(player_inv_stack_meta:to_table())
						if (player_inv_stack_meta_txt ~= nil) and string.find(player_inv_stack_meta_txt, "drawers:trolley_picked_up_") ~= nil then
							is_to_check = true
						end
					end
				end
				if is_to_check and is_containing_picked_up_drawer(player:get_player_name(),player:get_inventory(),player:get_pos()) then
					return 0
				end 
			end
		end
	end)
end


minetest.register_tool("drawers:trolley", {
	description = S("Trolley"),
	inventory_image = "drawers_trolley.png", -- from http://icons8.com/
	tool_capabilities = {
		full_punch_interval = 0.9,
		max_drop_level = 0,
		groupcaps = {
			crumbly = {times={[2]=3.00, [3]=0.70}, uses=0, maxlevel=1},
			snappy = {times={[3]=0.40}, uses=0, maxlevel=1},
			oddly_breakable_by_hand = {times={[1]=7.00,[2]=4.00,[3]=1.40},
						uses=0, maxlevel=3}
		},
		damage_groups = {fleshy=1},
	},
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.under
		if not placer or not pos then
			return
		end
		local player_name = placer:get_player_name()
		if minetest.is_protected(pos, player_name) then
			minetest.record_protection_violation(pos, player_name)
			return
		end
		local name = minetest.get_node(pos).name
		local def = drawers.trolley_registered_nodes[name]
		if not def then
			return
		end

		local stack = ItemStack(get_pickup_name(name))
		local player_inv = placer:get_inventory()

		-- if not player_inv:room_for_item("main", stack) then
		-- 	return
		-- end

		local meta = minetest.get_meta(pos)
		if def.owned and not minetest.check_player_privs(placer, "protection_bypass") then
			local owner = meta:get_string("owner")
			if owner and owner ~= player_name then
				minetest.log("action", player_name..
					" tried to pick up an owned node belonging to "..
					owner.." at "..
					minetest.pos_to_string(pos))
					minetest.chat_send_player(player_name, S("%s is protected by %s."):format(name,owner))	
				return
			end
		end

		
		-- limiting to one drawer picked up 
		if only_one and is_containing_picked_up_drawer(player_name,player_inv,pos) then
			return
		end

		local metadata = {}
		metadata.name = name
		metadata.version = LATEST_SERIALIZATION_VERSION

		local inv = meta:get_inventory()
		local lists = {}
		for _, listname in pairs(def.lists or {}) do
			local list = inv:get_list(listname)
			for i, stack in pairs(list) do
				list[i] = stack:to_string()
			end
			lists[listname] = list
		end
		metadata.lists = lists

		local item_meta = stack:get_meta()
		metadata.metas = {}
		for name, meta_type in pairs(def.metas or {}) do
			if meta_type == drawers.trolley_META_TYPE_INT then
				metadata.metas[name] = meta:get_int(name)
			elseif meta_type == drawers.trolley_META_TYPE_FLOAT then
				metadata.metas[name] = meta:get_float(name)
			elseif meta_type == drawers.trolley_META_TYPE_STRING then
				metadata.metas[name] = meta:get_string(name)
			elseif meta_type == drawers.trolley_META_TYPE_TABLE then
				metadata.metas[name] = minetest.deserialize(meta:get_string(name))
			end
		end
		


		item_meta:set_string("data", minetest.serialize(metadata))
		
		minetest.remove_node(pos)
	    if (times_used_before_break > 0) then
			itemstack:add_wear(65535 / times_used_before_break)
			item_meta:set_int("drawer_trolley_wear",itemstack:get_wear())  -- saving item wear
		end
		

		core.sound_play("drawers_interact", {
			pos = pos,
			max_hear_distance = 6,
			gain = 2.0
		})

		-- change player saturation coz it's  heavy to carry a drawers !
		if core.get_modpath("stamina") and stamina then
			stamina.change_saturation(placer, -1 * saturation_consumption)
		end

		return stack  -- leftover return is use to replace the trolley with the picked up drawers 
	end,
})

if craftable then
	if core.get_modpath("technic") and core.get_modpath("dye") then
		minetest.register_craft({
			output = "drawers:trolley",
			recipe = {
				{ "","technic:stainless_steel_ingot", "dye:orange"},
				{"","technic:stainless_steel_ingot", "dye:blue"},
				{"technic:stainless_steel_ingot","technic:stainless_steel_ingot", "technic:rubber"}
			}
		})
	elseif core.get_modpath("default") and core.get_modpath("wool") and core.get_modpath("dye") then
		minetest.register_craft({
			output = "drawers:trolley",
			recipe = {
				{ "","default:ladder_steel", "wool:orange"},
				{"","default:ladder_steel", "dye:blue"},
				{"default:shovel_steel","default:ladder_steel", "wool:black"}
			}
		})
	elseif core.get_modpath("default") then
		minetest.register_craft({
			output = "drawers:trolley",
			recipe = {
				{ "","default:ladder_steel", "default:steel_ingot"},
				{"","default:ladder_steel", ""},
				{"default:shovel_steel","default:ladder_steel", ""}
			}
		})
	end
end

if only_one then -- wrench override only if need to check if inventory is_containing_picked_up_drawer to limit to one
	if core.get_modpath("wrench") and wrench then
		local function wrench_get_pickup_name(name)
			return "wrench:picked_up_"..(name:gsub(":", "_"))
		end
		minetest.log("action","/!\\ overrinding wrench for limiting drawers to 1 in player inventory")

		minetest.override_item("wrench:wrench", {
			on_place = function(itemstack, placer, pointed_thing)
				local pos = pointed_thing.under
				if not placer or not pos then
					return
				end
				local player_name = placer:get_player_name()
				if minetest.is_protected(pos, player_name) then
					minetest.record_protection_violation(pos, player_name)
					return
				end
				local name = minetest.get_node(pos).name
				local def = wrench.registered_nodes[name]
				if not def then
					return
				end

				local stack = ItemStack(wrench_get_pickup_name(name))  -- ADDON to original wrench register - MODIFY  wrench_get_pickup_name  : prevent add a chest with a picked up drawer in player inventory that already contained one
				local player_inv = placer:get_inventory()
				if not player_inv:room_for_item("main", stack) then
					return
				end
				local meta = minetest.get_meta(pos)
				if def.owned and not minetest.check_player_privs(placer, "protection_bypass") then
					local owner = meta:get_string("owner")
					if owner and owner ~= player_name then
						minetest.log("action", player_name..
							" tried to pick up an owned node belonging to "..
							owner.." at "..
							minetest.pos_to_string(pos))
						return
					end
				end

				local metadata = {}
				metadata.name = name
				metadata.version = LATEST_SERIALIZATION_VERSION

				local inv = meta:get_inventory()
				local lists = {}
				for _, listname in pairs(def.lists or {}) do
					local list = inv:get_list(listname)
					for i, stack in pairs(list) do
						list[i] = stack:to_string()
					end
					lists[listname] = list
				end
				metadata.lists = lists

				local item_meta = stack:get_meta()
				metadata.metas = {}
				for name, meta_type in pairs(def.metas or {}) do
					if meta_type == wrench.META_TYPE_INT then
						metadata.metas[name] = meta:get_int(name)
					elseif meta_type == wrench.META_TYPE_FLOAT then
						metadata.metas[name] = meta:get_float(name)
					elseif meta_type == wrench.META_TYPE_STRING then
						metadata.metas[name] = meta:get_string(name)
					end
				end

				-- ADDON to original wrench register -  BEGIN : prevent add a chest with a picked up drawer in player inventory that already contained one
				if core.get_modpath("drawers") and drawers then
					if string.find(minetest.serialize(metadata), "drawers:trolley_picked_up_") then
						
						if is_containing_picked_up_drawer(player_name,player_inv,pos)  then
							return
						end
					end
				end
				-- ADDON to original wrench register -  END : prevent add a chest with a picked up drawer in player inventory that already contained one

				item_meta:set_string("data", minetest.serialize(metadata))
				minetest.remove_node(pos)
				itemstack:add_wear(65535 / 20)
				player_inv:add_item("main", stack)
				return itemstack
			end,
		}) -- end wrench override
	end
end
