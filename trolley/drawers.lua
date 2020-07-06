local INT, STRING, FLOAT, TABLE  =
	drawers.trolley_META_TYPE_INT,
	drawers.trolley_META_TYPE_STRING,
	drawers.trolley_META_TYPE_FLOAT,
	drawers.trolley_META_TYPE_TABLE

local to_register = { }

if core.get_modpath("default") and default then
	to_register = {"drawers:wood",
    "drawers:acacia_wood",
	"drawers:aspen_wood",
	"drawers:junglewood",
	"drawers:pine_wood" }
elseif core.get_modpath("mcl_core") and mcl_core then
	to_register = {"drawers:oakwood",
	"drawers:acaciawood",
	"drawers:birchwood",
	"drawers:darkwood",
	"drawers:junglewood",
	"drawers:sprucewood"}
else
	to_register = {"drawers:wood"}
end

local definition = {
	lists = {"upgrades"},
	metas = {infotext = STRING,
		formspec = STRING,
	}
}

local trolley_set_meta  = function (def,vid) 
	def.metas["name"..vid] = STRING
	def.metas["count"..vid] = INT
	def.metas["max_count"..vid] = INT
	def.metas["base_stack_max"..vid] = INT
	def.metas["entity_infotext"..vid] = STRING
	def.metas["stack_max_factor"..vid] = INT
	def.metas["meta_itemstack"..vid] = TABLE -- for meta of item in the stack
	def.metas["itemstack_wear"..vid] = INT -- for tool wear that is not a default meta
	return def
end

for _, drawer_node_name in pairs(to_register) do
	local type = "1"
	if drawers.enable_1x1 and minetest.registered_nodes[drawer_node_name ..type] then
		drawers:trolley_register_node(drawer_node_name..type,trolley_set_meta(table.copy(definition),"")) -- rergister darwer type 1
	end
	local def = table.copy(definition)
	type = "2"
	if drawers.enable_1x2 and minetest.registered_nodes[drawer_node_name .. type] then
		def = trolley_set_meta(def,"1") -- start with darwer slot 1
		def = trolley_set_meta(def,type) -- add drawer darwer slot 2
		drawers:trolley_register_node(drawer_node_name..type,table.copy(def))    -- rergister darwer type 2
	end
	type = "3"
	def = trolley_set_meta(def,type) -- add drawer darwer slot 3
	type = "4"
	if drawers.enable_2x2 and minetest.registered_nodes[drawer_node_name .. type] then
		def = trolley_set_meta(def,type)  -- add drawer darwer slot 4
		drawers:trolley_register_node(drawer_node_name..type,table.copy(def)) -- rergister darwer type 4
	end
end