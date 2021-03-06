--[[
Minetest Mod Storage Drawers - A Mod adding storage drawers

Copyright (C) 2017-2019 Linus Jahn <lnj@kaidan.im>

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

-- Load support for intllib.
local MP = core.get_modpath(core.get_current_modname())
local S, NS = dofile(MP.."/intllib.lua")
local unstackable_enabled =  core.settings:get_bool("drawers_hold_unstackable_enabled",true)


core.register_entity("drawers:visual", {
	initial_properties = {
		hp_max = 1,
		physical = false,
		collide_with_objects = false,
		collisionbox = {-0.4374, -0.4374, 0,  0.4374, 0.4374, 0}, -- for param2 0, 2
		visual = "upright_sprite", -- "wielditem" for items without inv img?
		visual_size = {x = 0.6, y = 0.6},
		textures = {"blank.png"},
		spritediv = {x = 1, y = 1},
		initial_sprite_basepos = {x = 0, y = 0},
		is_visible = true,
	},

	get_staticdata = function(self)
		return core.serialize({
			drawer_posx = self.drawer_pos.x,
			drawer_posy = self.drawer_pos.y,
			drawer_posz = self.drawer_pos.z,
			texture = self.texture,
			drawerType = self.drawerType,
			visualId = self.visualId
		})
	end,

	on_activate = function(self, staticdata, dtime_s)
		-- Restore data
		local data = core.deserialize(staticdata)
		if data then
			self.drawer_pos = {
				x = data.drawer_posx,
				y = data.drawer_posy,
				z = data.drawer_posz,
			}
			self.texture = data.texture
			self.drawerType = data.drawerType or 1
			self.visualId = data.visualId or ""

			-- backwards compatibility
			if self.texture == "drawers_empty.png" then
				self.texture = "blank.png"
			end
		else
			self.drawer_pos = drawers.last_drawer_pos
			self.texture = drawers.last_texture or "blank.png"
			self.visualId = drawers.last_visual_id
			self.drawerType = drawers.last_drawer_type
		end

		local node = minetest.get_node(self.object:get_pos())
		if not node.name:match("^drawers:") then
			self.object:remove()
			return
		end

		-- add self to public drawer visuals
		-- this is needed because there is no other way to get this class
		-- only the underlying LuaEntitySAO
		-- PLEASE contact me, if this is wrong
		local vId = self.visualId
		if vId == "" then vId = 1 end
		local posstr = core.serialize(self.drawer_pos)
		if not drawers.drawer_visuals[posstr] then
			drawers.drawer_visuals[posstr] = {[vId] = self}
		else
			drawers.drawer_visuals[posstr][vId] = self
		end

		-- get meta
		self.meta = core.get_meta(self.drawer_pos)

		-- collisionbox
		node = core.get_node(self.drawer_pos)
		local colbox
		if self.drawerType ~= 2 then
			if node.param2 == 1 or node.param2 == 3 then
				colbox = {0, -0.4374, -0.4374,  0, 0.4374, 0.4374}
			else
				colbox = {-0.4374, -0.4374, 0,  0.4374, 0.4374, 0} -- for param2 = 0 or 2
			end
			-- only half the size if it's a small drawer
			if self.drawerType > 1 then
				for i,j in pairs(colbox) do
					colbox[i] = j * 0.5
				end
			end
		else
			if node.param2 == 1 or node.param2 == 3 then
				colbox = {0, -0.2187, -0.4374,  0, 0.2187, 0.4374}
			else
				colbox = {-0.4374, -0.2187, 0,  0.4374, 0.2187, 0} -- for param2 = 0 or 2
			end
		end

		-- visual size
		local visual_size = {x = 0.6, y = 0.6}
		if self.drawerType >= 2 then
			visual_size = {x = 0.3, y = 0.3}
		end


		-- drawer values
		local vid = self.visualId
		self.count = self.meta:get_int("count"..vid)
		self.itemName = self.meta:get_string("name"..vid)
		self.maxCount = self.meta:get_int("max_count"..vid)
		self.itemStackMax = self.meta:get_int("base_stack_max"..vid)
		self.stackMaxFactor = self.meta:get_int("stack_max_factor"..vid)
		self.metaItemStack = self.meta:get_string("meta_itemstack"..vid)
		self.itemStackWear = self.meta:get_int("itemstack_wear"..vid)

		-- infotext
		local infotext = self.meta:get_string("entity_infotext"..vid) .. "\n\n\n\n\n"

		self.object:set_properties({
			collisionbox = colbox,
			infotext = infotext,
			textures = {self.texture},
			visual_size = visual_size
		})

		-- make entity undestroyable
		self.object:set_armor_groups({immortal = 1})
	end,

	on_rightclick = function(self, clicker)
		if core.is_protected(self.drawer_pos, clicker:get_player_name()) then
			core.record_protection_violation(self.drawer_pos, clicker:get_player_name())
			return
		end

		-- used to check if we need to play a sound in the end
		local inventoryChanged = false

		--### addon swap stack ### begin
		-- is want to swap the selection
		local swaping = clicker:get_player_control().aux1
		if swaping then
			-- target info
			local drawer_target_visualid = self.visualId
			local drawer_target_pos = self.object:get_pos()
			
			-- retriview entity
			local playermeta = clicker:get_meta()
			-- if nothing select then abort
			local drawer_selected_pos = core.deserialize(playermeta:get_string("drawer_selected_pos"))
			if drawer_selected_pos == nil then return end
			local drawer_selected_visualid = playermeta:get_string("drawer_selected_visualid")
			if drawer_selected_visualid == nil then return end

			-- local function too rollback transaction between drawers if cant swap totally the items (maxcount)
			local rollback_if_not_totally_added = function(leftover, from,fromItemName,fromCount,to,toItemName,toCount)
				if (leftover:get_count() > 0) then
					from.count = fromCount
					from.itemName = fromItemName
					to.count = toCount
					to.itemName = toItemName

					from:updateInfotext()
					from:updateTexture()
					from:saveMetaData()

					to:updateInfotext()
					to:updateTexture()
					to:saveMetaData()

					core.sound_play("drawers_wrong", {
						pos = self.object:get_pos(),
						max_hear_distance = 6,
						gain = 0.2
					})
					-- thanks to Heshl for the select sound
					-- at  https://freesound.org/people/Heshl/sounds/269149/
					-- under creative common licence https://creativecommons.org/licenses/by/3.0/
					-- file not modified except the name
					
				end
				return leftover:get_count() > 0
			end

			-- get data from selected to swap
			local objs = core.get_objects_inside_radius(drawer_selected_pos, 0.56)
			
			if not objs then return end
			for _, obj in pairs(objs) do
				if obj and obj:get_luaentity() and obj:get_luaentity().name == "drawers:visual" then
					if tostring(obj:get_luaentity().visualId) == tostring(drawer_selected_visualid)	then
						--init selected entity var

						local source = obj:get_luaentity()
						local sourceCount = source.count
						local sourceItemName = source.itemName
						local sourcestack = ItemStack(sourceItemName)

						sourcestack:set_count(sourceCount)
						sourcestack:set_wear(source.itemStackWear)

						-- set stack meta
						local metalist =  minetest.deserialize(source.metaItemStack)
						local meta_itemstack = sourcestack:get_meta()
						local meta_type
						if metalist ~= nil then
							for key, value in pairs(metalist["fields"]) do
								meta_type = type(value)
								if meta_type == "number" then
									if string.find(tostring(value), "^[-+]?[0-9]*\\.?[0-9]+$") ~= nil then  -- float
										meta_itemstack:set_float(key, value)
									else
										meta_itemstack:set_int(key,value)
									end
								elseif meta_type == "string"  then
									meta_itemstack:set_string(key,value)
								elseif meta_type == "table"  then
									meta_itemstack:set_string(key,minetest.serialize(value)) -- table store as string
								end
							end
						end
						meta_type = nil
						metalist = nil


						--init targeted entity var
						local vid = self.visualId
						local target = self
						local targetCount = target.count
						local targetItemName = target.itemName

						local targetstack = ItemStack(targetItemName)
						targetstack:set_count(targetCount)
						targetstack:set_wear(target.itemStackWear)

						-- set stack meta
						metalist =  minetest.deserialize(target.metaItemStack)
						local meta_itemstack2 = targetstack:get_meta()
						local meta_type
						if metalist ~= nil then
							for key, value in pairs(metalist["fields"]) do
								meta_type = type(value)
								if meta_type == "number" then
									if string.find(tostring(value), "^[-+]?[0-9]*\\.?[0-9]+$") ~= nil then  -- float
										meta_itemstack2:set_float(key, value)
									else
										meta_itemstack2:set_int(key,value)
									end
								elseif meta_type == "string"  then
									meta_itemstack2:set_string(key,value)
								elseif meta_type == "table"  then
									meta_itemstack2:set_string(key,minetest.serialize(value)) -- table store as string
								end
							end
						end
						meta_type = nil
						metalist = nil


						-- prevent double quantity if lmb then rmb clicked at the same visual 
						if source == target then return end

						-- remove item from target
						target:take_items(targetCount)
						-- remove item from selected
						source:take_items(sourceCount)


						-- add source item to target empty slot
						local leftover = target:try_insert_stack(sourcestack , true)

						-- if same item as source then join the 2 stack in 1
						if (sourceItemName == targetItemName  and   source.metaItemStack == target.metaItemStack and source.itemStackWear  == target.itemStackWear          ) or sourceItemName == "" or targetItemName == "" then
							if leftover:get_count() > 0 then
								-- put back leftofer in the source 
								source:try_insert_stack(leftover, true)
							end

							-- add target item back to target slot filled with source item (join stack)
							leftover = target:try_insert_stack(targetstack, true)
							
							if leftover:get_count() > 0 then
								-- put back leftofer in the source 
								source:try_insert_stack(leftover, true)
							end
						else
							if rollback_if_not_totally_added(leftover,source,sourceItemName,sourceCount,target,targetItemName,targetCount) then return end

							-- add target  item to empty selected slot
							leftover = source:try_insert_stack(targetstack, true)
							if rollback_if_not_totally_added(leftover,source,sourceItemName,sourceCount,target,targetItemName,targetCount) then return end
						end
						self:play_interact_sound()
						break
					end
				end
			end
			
			-- reset selected entity data if swap is success
			playermeta:set_string("drawer_selected_pos",nil)
			playermeta:set_string("drawer_selected_visualid",nil)

			return
		end
		--### addon swap stack ### end			
			
			
			
		-- When the player uses the drawer with their bare hand all
		-- stacks from the inventory will be added to the drawer.
		if self.itemName ~= "" and
		   clicker:get_wielded_item():get_name() == "" and
		   not clicker:get_player_control().sneak then
			-- try to insert all items from inventory
			local i = 0
			local inv = clicker:get_inventory()

			while i <= inv:get_size("main") do
				-- set current stack to leftover of insertion
				local leftover = self.try_insert_stack(
					self,
					inv:get_stack("main", i),
					true
				)

				-- check if something was added
				if leftover:get_count() < inv:get_stack("main", i):get_count() then
					inventoryChanged = true
				end

				-- set new stack
				inv:set_stack("main", i, leftover)
				i = i + 1
			end
		else
			-- try to insert wielded item only
			local leftover = self.try_insert_stack(
				self,
				clicker:get_wielded_item(),
				not clicker:get_player_control().sneak
			)

			-- check if something was added
			if clicker:get_wielded_item():get_count() > leftover:get_count() then
				inventoryChanged = true
			end
			-- set the leftover as new wielded item for the player
			clicker:set_wielded_item(leftover)
		end

		if inventoryChanged then
			self:play_interact_sound()
		end
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		local node = minetest.get_node(self.object:get_pos())
		if not node.name:match("^drawers:") then
			self.object:remove()
			return
		end
		local add_stack = not puncher:get_player_control().sneak
		if core.is_protected(self.drawer_pos, puncher:get_player_name()) then
		   core.record_protection_violation(self.drawer_pos, puncher:get_player_name())
		   return
		end
			
		--### addon swap stack ### begin
		-- if player want to select a drawer visual entity with aux1 (ex: to swap)
		local playercontrol = puncher:get_player_control()
		add_stack = not playercontrol.sneak and not playercontrol.aux1     --  /!\ add_stack override
		local selecting = playercontrol.aux1 and not playercontrol.sneak

		local pmeta = puncher:get_meta()
		if selecting then
			-- unselect previous if one
			if pmeta:get_string("drawer_selected_visualid") ~= nil
				and core.deserialize(pmeta:get_string("drawer_selected_pos")) ~= nil   then

				local drawer_selected_pos = core.deserialize(pmeta:get_string("drawer_selected_pos"))
				local drawer_selected_visualid = pmeta:get_string("drawer_selected_visualid")

				-- récupératrion des infos de la selection
				local objs = core.get_objects_inside_radius(drawer_selected_pos, 0.56)
				for _, obj in pairs(objs) do
					if obj and obj:get_luaentity() and obj:get_luaentity().name == "drawers:visual" then
						if tostring(obj:get_luaentity().visualId) == tostring(drawer_selected_visualid)	then
							--init selected entity var
							local source = obj:get_luaentity()
							source.texture = drawers.get_inv_image(source.itemName,false) -- reset normal texture (with false param)
							source.object:set_properties({
								textures = {source.texture}
							})
							break
						end
					end
				end

				-- if  re-clicking on already seleted slot then after reset texture to normal one (unselecting), we abort
				if core.serialize(drawer_selected_pos) == core.serialize(self.drawer_pos) and drawer_selected_visualid == self.visualId then 
					pmeta:set_string("drawer_selected_visualid",nil)
					pmeta:set_string("drawer_selected_pos",nil)
					core.sound_play("drawers_select", {
						pos = self.object:get_pos(),
						max_hear_distance = 6,
						gain = 0.2
					})
					return 
				end
			end

			-- select drawer slot (entity)
			-- storing selected drawer to retriview it when needed
			pmeta:set_string("drawer_selected_visualid",self.visualId)
			pmeta:set_string("drawer_selected_pos",core.serialize(self.drawer_pos))
			self.texture = drawers.get_inv_image(self.itemName,true)
			self.object:set_properties({
				textures = {self.texture}
			})
			core.sound_play("drawers_select", {
				pos = self.object:get_pos(),
				max_hear_distance = 6,
				gain = 0.2
			})
			-- thanks to LittleRobotSoundFactory for the select sound
			-- at  https://freesound.org/people/LittleRobotSoundFactory/sounds/270401/
			-- under creative common licence https://creativecommons.org/licenses/by/3.0/
			-- file not modified except the name

			return
		end

		-- if not swaping : reset of selected visual
		pmeta:set_string("drawer_selected_pos",nil)
		pmeta:set_string("drawer_selected_visualid",nil)
		pmeta = nil
		--### addon swap stack ### end	
			

		local is_fullfilling = playercontrol.aux1 and playercontrol.sneak
		if is_fullfilling then add_stack = true end

		local inv = puncher:get_inventory()
		if inv == nil then
			return
		end
		local spaceChecker = ItemStack(self.itemName)
		if add_stack then
			spaceChecker:set_count(spaceChecker:get_stack_max())
		end
		if not inv:room_for_item("main", spaceChecker) then
			return
		end

		repeat 

			if not inv:room_for_item("main", spaceChecker) then
				return
			end

			local stack
			if add_stack then
				stack = self:take_stack()
			else
				stack = self:take_items(1)
			end

			if stack ~= nil then
				-- add removed stack to player's inventory
				inv:add_item("main", stack)

				-- play the interact sound
				self:play_interact_sound()
			end

		until not is_fullfilling or stack == nil

	end,

	take_items = function(self, removeCount)
		--local meta = core.get_meta(self.drawer_pos)
		self:loadMetaData()

		if self.count <= 0 then
			return
		end

		if removeCount > self.count then
			removeCount = self.count
		end

		local stack = ItemStack(self.itemName)
		stack:set_count(removeCount)

		-- set stack wear
		stack:set_wear(self.itemStackWear)

		-- set stack meta
		local metalist =  minetest.deserialize(self.metaItemStack)
		local meta_itemstack = stack:get_meta()
		local meta_type
		if metalist ~= nil then
			for key, value in pairs(metalist["fields"]) do
				meta_type = type(value)
				if meta_type == "number" then
					if string.find(tostring(value), "^[-+]?[0-9]*\\.?[0-9]+$") ~= nil then  -- float
						meta_itemstack:set_float(key, value)
					else
						meta_itemstack:set_int(key,value)
					end
				elseif meta_type == "string"  then
					meta_itemstack:set_string(key,value)
				elseif meta_type == "table"  then
					meta_itemstack:set_string(key,minetest.serialize(value)) -- table store as string
				end
			end
		end
		meta_type = nil
		metalist = nil

		-- update the drawer count
		self.count = self.count - removeCount

		self:updateInfotext()
		self:updateTexture()
		self:saveMetaData()

		-- return the stack that was removed from the drawer
		return stack
	end,

	take_stack = function(self)
		return self:take_items(ItemStack(self.itemName):get_stack_max())
	end,

	try_insert_stack = function(self, itemstack, insert_stack)
		self:loadMetaData()
		local stackCount = itemstack:get_count()
		local stackName = itemstack:get_name()

		-- if nothing to be added, return
		if stackCount <= 0 then return itemstack end
		-- if no itemstring, return
		if stackName == "" then return itemstack end

		-- only add one, if player holding sneak key
		if not insert_stack then
			stackCount = 1
		end

		-- set wear (for tools)
		local itemStackWear = itemstack:get_wear()

		-- set item stack meta
		local metaItemStack_table = itemstack:get_meta():to_table()

		local metaItemStack = ""
		if next(metaItemStack_table["fields"]) ~= nil then
			metaItemStack = minetest.serialize(metaItemStack_table)
		end

		-- if current itemstring is not empty
		if self.itemName ~= "" then
			-- check if same item (with same meta and same wear )
			if stackName ~= self.itemName or self.metaItemStack ~= metaItemStack or self.itemStackWear ~= itemStackWear  then return itemstack end
		else -- is empty
			self.itemName = stackName
			self.count = 0

			self.metaItemStack = metaItemStack
			self.itemStackWear = itemStackWear

			-- get new stack max
			self.itemStackMax = ItemStack(self.itemName):get_stack_max()
			self.maxCount = self.itemStackMax * self.stackMaxFactor
		end

		if not unstackable_enabled then
		-- Don't add items stackable only to 1 
			if self.itemStackMax == 1 then
				self.itemName = ""
				return itemstack
			end
		end

		-- set new counts:
		-- if new count is more than max_count
		if (self.count + stackCount) > self.maxCount then
			itemstack:set_count(self.count + stackCount - self.maxCount)
			self.count = self.maxCount
		else -- new count fits
			self.count = self.count + stackCount
			-- this is for only removing one
			itemstack:set_count(itemstack:get_count() - stackCount)
		end

		-- update infotext, texture
		self:updateInfotext()
		self:updateTexture()

		self:saveMetaData()

		if itemstack:get_count() == 0 then itemstack = ItemStack("") end
		return itemstack
	end,

	updateInfotext = function(self)
		local itemDescription = ""
		if core.registered_items[self.itemName] then
			itemDescription = core.registered_items[self.itemName].description
		end

		if self.count <= 0 then
			self.itemName = ""
			self.meta:set_string("name"..self.visualId, self.itemName)
			self.texture = "blank.png"
			itemDescription = S("Empty")
		end

		local infotext = drawers.gen_info_text(itemDescription,
			self.count, self.stackMaxFactor, self.itemStackMax)
		self.meta:set_string("entity_infotext"..self.visualId, infotext)

		self.object:set_properties({
			infotext = infotext .. "\n\n\n\n\n"
		})
	end,

	updateTexture = function(self)
		-- texture
		self.texture = drawers.get_inv_image(self.itemName)

		self.object:set_properties({
			textures = {self.texture}
		})
	end,

	dropStack = function(self, itemStack)
		-- print warning if dropping higher stack counts than allowed
		if itemStack:get_count() > itemStack:get_stack_max() then
			core.log("warning", "[drawers] Dropping item stack with higher count than allowed")
		end
		-- find a position containing air
		local dropPos = core.find_node_near(self.drawer_pos, 1, {"air"}, false)
		-- if no pos found then drop on the top of the drawer
		if not dropPos then
			dropPos = self.pos
			dropPos.y = dropPos.y + 1
		end
		-- drop the item stack
		core.item_drop(itemStack, nil, dropPos)
	end,

	dropItemOverload = function(self)
		-- drop stacks until there are no more items than allowed
		while self.count > self.maxCount do
			-- remove the overflow
			local removeCount = self.count - self.maxCount
			-- if this is too much for a single stack, only take the
			-- stack limit
			if removeCount > self.itemStackMax then
				removeCount = self.itemStackMax
			end
			-- remove this count from the drawer
			self.count = self.count - removeCount
			-- create a new item stack having the size of the remove
			-- count
			local stack = ItemStack(self.itemName)
			stack:set_count(removeCount)
			print(stack:to_string())
			-- drop the stack
			self:dropStack(stack)
		end
	end,

	setStackMaxFactor = function(self, stackMaxFactor)
		self:loadMetaData()
		self.stackMaxFactor = stackMaxFactor
		self.maxCount = self.stackMaxFactor * self.itemStackMax

		-- will drop possible overflowing items
		self:dropItemOverload()
		self:updateInfotext()
		self:saveMetaData()
	end,

	play_interact_sound = function(self)
		core.sound_play("drawers_interact", {
			pos = self.object:get_pos(),
			max_hear_distance = 6,
			gain = 2.0
		})
	end,

	saveMetaData = function(self)
		self.meta:set_int("count"..self.visualId, self.count)
		self.meta:set_string("name"..self.visualId, self.itemName)
		self.meta:set_int("max_count"..self.visualId, self.maxCount)
		self.meta:set_int("base_stack_max"..self.visualId, self.itemStackMax)
		self.meta:set_int("stack_max_factor"..self.visualId, self.stackMaxFactor)
		self.meta:set_string("meta_itemstack"..self.visualId, self.metaItemStack)
		self.meta:set_int("itemstack_wear"..self.visualId, self.itemStackWear)	
end,
	
	loadMetaData = function(self)
		local vid = self.visualId
		self.count = self.meta:get_int("count"..vid)
		self.itemName = self.meta:get_string("name"..vid)
		self.maxCount = self.meta:get_int("max_count"..vid)
		self.itemStackMax = self.meta:get_int("base_stack_max"..vid)
		self.stackMaxFactor = self.meta:get_int("stack_max_factor"..vid)
	end,
})

core.register_lbm({
	name = "drawers:restore_visual",
	nodenames = {"group:drawer"},
	run_at_every_load = true,
	action  = function(pos, node)
		local meta = core.get_meta(pos)
		-- create drawer upgrade inventory
		meta:get_inventory():set_size("upgrades", 5)
		-- set the formspec
		meta:set_string("formspec", drawers.drawer_formspec)

		-- count the drawer visuals
		local drawerType = core.registered_nodes[node.name].groups.drawer
		local foundVisuals = 0
		local objs = core.get_objects_inside_radius(pos, 0.54)
		if objs then
			for _, obj in pairs(objs) do
				if obj and obj:get_luaentity() and
						obj:get_luaentity().name == "drawers:visual" then
					foundVisuals = foundVisuals + 1
				end
			end
		end
		-- if all drawer visuals were found, return
		if foundVisuals == drawerType then
			return
		end

		-- not enough visuals found, remove existing and create new ones
		drawers.remove_visuals(pos)
		drawers.spawn_visuals(pos)
	end
})
