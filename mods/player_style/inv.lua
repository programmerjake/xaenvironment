player_style.register_button=function(def)
	local b = (def.type and (def.type .. "_button") or "button")
	.. (def.exit and "_exit" or "")
	.. "["..player_style.buttons.num..",7.2;1,1;"
	.. (((def.type == "image" or def.type == "item_image") and def.image and (def.image .. ";")) or "")
	.. def.name ..";"
	.. (def.label or "") .."]"
	..(def.info and ("tooltip["..def.name..";"..def.info.."]") or "")
	player_style.buttons.text = player_style.buttons.text .. b
	player_style.buttons.num = player_style.buttons.num + 1
	player_style.buttons.action[def.name]=def.action
end

minetest.register_privilege("creative", {
	description = "Creative",
	give_to_singleplayer= false,
	on_grant=function(name)
		minetest.after(0,function(name)
			player_style.inventory(minetest.get_player_by_name(name))
		end,name)
	end,
	on_revoke=function(name)
		minetest.after(0,function(name)
			player_style.inventory(minetest.get_player_by_name(name))
		end,name)
	end
})

player_style.register_button({
	name="Backpack",
	image="player_style_backpack.png",
	type="image",
	info="Backpack",
	action=function(player)
		local name = player:get_player_name()
		local invp = player_style.players[name].inv
		local bn = invp.backpackslot:get_stack("main",1):get_name()
		if minetest.get_item_group(bn,"backpack") > 0 then

			return minetest.show_formspec(player:get_player_name(), "backpack",
				"size[8,8]" 
				.."listcolors[#77777777;#777777aa;#000000ff]"
				.."list[current_player;main;0,4;8,4;]"
				.."list[detached:backpack;main;1,0;6,3;]"
				.."listring[current_player;main]"
				.."listring[detached:backpack;main]"
			)
		end
	end
})

player_style.inventory=function(player)
	local name = player:get_player_name()
	player_style.players[name].inv = player_style.players[name].inv or {}
	local invp = player_style.players[name].inv

	if not invp.backpack then

--detached inventory
		invp.backpackslot = minetest.create_detached_inventory("backpackslot", {
			allow_put = function(inv, listname, index, stack, player)
				return minetest.get_item_group(stack:get_name(),"backpack") > 0 and stack:get_count() or 0
			end,
			allow_take = function(inv, listname, index, stack, player)
				return invp.backpack:is_empty("main") and stack:get_count() or 0
			end,
			on_put = function(inv, listname, index, stack, player)
				player:get_meta():set_string("backpackslot",minetest.serialize(stack:to_table()))
			end,
			on_take = function(inv, listname, index, stack, player)
				player:get_meta():set_string("backpackslot","")
			end
		})
		invp.backpackslot:set_size("main",1)
		invp.backpackslot:set_stack("main",1,ItemStack(minetest.deserialize(player:get_meta():get_string("backpackslot") or "")) or {})

		invp.backpack = minetest.create_detached_inventory("backpack", {
			on_put = function(inv, listname, index, stack, player)
				local name = player:get_player_name()
				local d = {}
				for i,v in pairs(inv:get_list("main")) do
					d[i]=v:to_table()
				end
				player:get_meta():set_string("backpack",minetest.serialize(d))
			end,
			on_take = function(inv, listname, index, stack, player)
				local name = player:get_player_name()
				local d = {}
				for i,v in pairs(inv:get_list("main")) do
					d[i]=v:to_table()
				end
				player:get_meta():set_string("backpack",minetest.serialize(d))
			end

		})
		invp.backpack:set_size("main",18)
		local list = {}
		for i,v in pairs(minetest.deserialize(player:get_meta():get_string("backpack") or "") or {}) do
			list[i]=ItemStack(v)
		end
		invp.backpack:set_list("main", list)
	end

	if not (player_style.creative or minetest.check_player_privs(name, {creative=true})) then
--default inventory
		player:set_inventory_formspec(
			"size[8,8]" 
			.."listcolors[#77777777;#777777aa;#000000ff]"
			.."list[current_player;main;0,3;8,4;]"
			.."list[current_player;craft;4,0;3,3;]"
			.."list[current_player;craftpreview;7,1;1,1;]"
			.."list[detached:backpackslot;main;7,0;1,1;]"
			.."listring[current_player;main]"
			.."listring[current_player;craft]"
			..player_style.buttons.text
		)
	else
--creative inventory items
		if not player_style.inventory_items then
			player_style.inventory_items={}
			for i,it in pairs(minetest.registered_items) do
				if not (it.groups and it.groups.not_in_creative_inventory) then
					table.insert(player_style.inventory_items,it.name)
				end
			end
			table.sort(player_style.inventory_items)

			minetest.create_detached_inventory("deleteslot", {
				on_put = function(inv, listname, index, stack, player)
					inv:set_stack("main",1,"")
				end
			}):set_size("main", 1)
		end
--creative inventory
		invp.index = invp.index or 1
		invp.size = invp.size or 34
		invp.search = invp.search and invp.search.text ~= "" and invp.search or nil

		local itemlist = invp.search and invp.search.items or player_style.inventory_items
		local pages = math.floor(#itemlist/player_style.players[name].inv.size)
		local page = math.floor(player_style.players[name].inv.index/player_style.players[name].inv.size)
		local itembutts = ""
		local x=8
		local y=0

		for i=invp.index,invp.index+invp.size do
			local it = itemlist[i]
			if it then
				itembutts = itembutts.."item_image_button["..x..","..y..";1,1;"..it..";itembut_"..it..";]"
				x = x + 0.8
				if x >= 12 then
					y = y + 0.9
					x = 8
				end
			end
		end
		player:set_inventory_formspec(
			"size[12,8]" 
			.."listcolors[#77777777;#777777aa;#000000ff]"
			.."list[current_player;main;0,3;8,4;]"
			.."list[current_player;craft;4,0;3,3;]"
			.."list[current_player;craftpreview;7,1;1,1;]"
			.."list[detached:backpackslot;main;7,0;1,1;]"
			.."listring[current_player;main]"
			.."listring[current_player;craft]"
			..player_style.buttons.text
			.."image_button[8,7;1,1;default_crafting_arrowleft.png;creinvleft;]"
			.."image_button[9,7;1,1;default_crafting_arrowright.png;creinvright;]"
			.."image_button[10,7;1,1;synth_repeat.png;reset;]"
			.."image_button[11,7;1,1;default_bucket.png;clean;]"
			.."tooltip[creinvleft;Back]"
			.."tooltip[creinvright;Forward]"
			.."tooltip[reset;Reset]"
			.."tooltip[clean;Clean your inventory]"
			.."image[7,2;1,1;default_bucket.png]list[detached:deleteslot;main;7,2;1,1;]"
			.."label[9.6,7.9;"..page.."/"..pages.."]"

			.."field[8.3,6.5;3,1;searchbox;;"..(invp.search and invp.search.text or "").."]"
			.."image_button[11,6.3;1,0.8;;search;]"

			..itembutts
		)
	end
end

minetest.register_on_player_receive_fields(function(player, form, pressed)
	if form == "" then
		local name = player:get_player_name()
		for i,v in pairs(pressed) do
			if player_style.buttons.action[i] then
				player_style.buttons.action[i](player)
				return
			end
		end
		local invp = player_style.players[name].inv
		if invp then
			if pressed.quit then
				player_style.players[name].inv.clean = nil
				return
			elseif pressed.creinvright and invp.index+invp.size < (invp.search and #invp.search.items or #player_style.inventory_items) then
				invp.index = invp.index + invp.size+1
				player_style.inventory(player)
				return
			elseif pressed.creinvleft and invp.index > 1 then
				invp.index = invp.index - invp.size-1
				player_style.inventory(player)
				return
			elseif pressed.reset then
				invp.index = 1
				invp.search = nil
				player_style.inventory(player)
				return
			elseif pressed.clean then
				if not invp.clean then
					minetest.chat_send_player(name,"Press again to clean you inventory")
					invp.clean = true
				else
					local inv = player:get_inventory()
					for i,v in pairs(inv:get_list("main")) do
						inv:set_stack("main",i,"")
					end
					player_style.players[name].inv.clean = nil
				end
			elseif pressed.search then
				local its = {}
				local s = pressed.searchbox:lower()
				for i,it in pairs(player_style.inventory_items) do
					if it:find(s) or (minetest.registered_items[it].description or ""):lower():find(s) then
						table.insert(its,it)
					end
				end
				invp.index = 1
				invp.search={
					text = s,
					items = its
				}
				player_style.inventory(player)
				return
			end
			for i,v in pairs(pressed) do
				if i:sub(1,8) == "itembut_" then
					local t = i:sub(9,-1)
					player:get_inventory():add_item("main",t.." "..minetest.registered_items[t].stack_max)
				end
			end
		end
	end
end)