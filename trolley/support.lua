--[[
supported_nodes
This table stores all nodes that are compatible with the drawers.trolley addon.
--]]

drawers.trolley_META_TYPE_INT = 0
drawers.trolley_META_TYPE_FLOAT = 1
drawers.trolley_META_TYPE_STRING = 2
drawers.trolley_META_TYPE_TABLE = 3 

local INT, STRING, FLOAT, TABLE  =
	drawers.trolley_META_TYPE_INT,
	drawers.trolley_META_TYPE_STRING,
	drawers.trolley_META_TYPE_FLOAT,
	drawers.trolley_META_TYPE_TABLE



drawers.trolley_registered_nodes = { }

function drawers:trolley_original_name(name)
	for key, value in pairs(self.registered_nodes) do
		if name == value.name then
			return key
		end
	end
end

function drawers:trolley_register_node(name, def)
	if minetest.registered_nodes[name] then
	    self.trolley_registered_nodes[name] = def
	end
end

