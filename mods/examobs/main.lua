examobs.main=function(self, dtime)
	if self.timer1 > 0.1 then
		self.environment_timer = self.environment_timer + self.timer1
		self.environment_timer2 = self.environment_timer2 + self.timer1
		self.timer1 = 0
		if self.environment_timer > 0.2 and examobs.environment(self) then return end
	end
	if self.timer2 < self.updatetime then return end
	self.timer2 = 0

	if not self.static_save and examobs.global_lifetime > 1 and not self:on_lifedeadline() then
		self.object:set_properties({static_save = false})
		self.static_save = true

	elseif self.static_save and examobs.global_lifetime <= 1 then
		self.object:set_properties({static_save = true})
		self.static_save = nil
	end	

	if (self.dying or self.dead) and examobs.dying(self) then
		return
	elseif self.step(self) or self.target then
		return
	end
	if examobs.following(self) then return end
	if examobs.fighting(self) then return end
	if examobs.fleeing(self) then return end
	if examobs.exploring(self) then return end
end

examobs.register_mob=function(def)

	local name = minetest.get_current_modname() ..":" .. def.name

	def.hp =				def.hp or				20
	def.hp_max = 			def.hp
	def.physical =			def.physical or			def.physical ~= false
	def.collisionbox =			def.collisionbox or			{-0.35,-0.1,-0.35,0.35,1.8,0.35}
	def.visual =			def.visual or			"mesh"
	def.visual_size =			def.visual_size or			{x=1,y=1}
	def.mesh =			def.mesh or			"character.b3d"
	def.makes_footstep_sound =		def.makes_footstep_sound or		def.physical ~= false

	def.walk_speed =			def.walk_speed or			2
	def.walk_run =			def.walk_run or			4
	def.lay_on_death =			def.lay_on_death or		1
	def.textures =			def.textures or			{"character.png"}
	def.type =			def.type or			"npc"
	def.team =			def.team or			"default"
	def.step =			def.step or			function() end
	def.range =			def.range or			15
	def.reach =			def.reach or			2
	def.dmg =			def.dmg or			1
	def.punch_chance =		def.punch_chance or		5
	def.bottom =			def.bottom or			0
	def.breathing =			def.breathing or			1
	def.resist_nodes =			def.resist_nodes or			{}
	def.swiming =			def.swiming or			1
	def.inv = 				def.inv or				{}
	def.aggressivity =			def.aggressivity or			1
	def.flee_from_threats_only =		def.flee_from_threats_only or		0

	def.floating =			def.floating or			{}
	def.floating_in_group =		def.floating_in_group
	def.updatetime =			def.updatetime or			1
	def.spawn_chance =		def.spawn_chance or		100
	def.spawn_on =			def.spawn_on or			{"group:spreading_dirt_type","group:sand","default:snow"}
	def.spawn_in =			def.spawn_in
	def.light_min =			def.light_min or			9
	def.light_max =			def.light_max or			15
	def.lifetime =			def.lifetime or			300
	def.add_wear =			def.add_wear or			10000

	def.animation =			def.animation == "default" and 
	{
		stand={x=1,y=39,speed=30},
		walk={x=41,y=61,speed=30},
		run={x=41,y=61,speed=60},
		attack={x=65,y=75,speed=30},
		lay={x=113,y=123,speed=0},
	} or def.animation

	if def.animation then
		if def.animation.walk then
			def.animation.run = def.animation.run or {x=def.animation.walk.x,y=def.animation.walk.y,speed = 60}
		end
		for i, a in pairs(def.animation) do
			def.animation[i].speed = def.animation[i].speed or 30
		end
	end


	def.on_dying =			def.on_dying or			function() end
	def.death =			def.death or			function() end
	def.on_punched =			def.on_punched or			function() end
	def.on_punching =			def.on_punching or			function() end
	def.before_punching =		def.before_punching or		function() end
	def.on_click =			def.on_click or			function() end
	def.on_spawn =			def.on_spawn or			function() end
	def.on_load =			def.on_load or			function() end
	def.is_food =			def.is_food or			function() return true end
	def.on_lifedeadline =		def.on_lifedeadline or		function() end
	def.on_walk =			def.on_walk or			function() end
	def.on_fly =			def.on_fly or			function() end
	def.on_stand =			def.on_stand or			function() end

	def.timer1 = 0
	def.timer2 = 0
	def.environment_timer = 0
	def.environment_timer2 = 0
	def.lifetimer = def.lifetime
	def.examob = 0

	local egg = def.spawner_egg
	local bottom = def.bottom * -1
	def.spawner_egg = nil

	def.eat_item=function(self,item,add)
		local s
		if type(item) == "string" then
			s = string.split(item," ")
			s[2] = s[2] or 1
		elseif type(item) == "userdata" then
			s = {[1] = s:get_name(),[2] = s:get_count()}
		else
			return
		end
		local eatable = minetest.get_item_group(s[1],"eatable")
		local gaps = minetest.get_item_group(s[1],"gaps")
		self:heal((eatable > 0 and eatable) or add or 1,(gaps > 0 and gaps) or 1,tonumber(s[2]))
		examobs.stand(self)
		return true
	end
	def.heal=function(self,hp,gaps,num)
		num = num or 1
		gaps = gaps or 1
		local ohp = self.hp
		self.hp = self.hp + ((hp * gaps) * num )
		self.hp = (self.hp < self.hp_max and self.hp) or self.hp_max
		if ohp < self.hp_max then
			self.object:set_hp(self.hp)
			examobs.showtext(self,self.hp .. "/" .. self.hp_max,"00ff00")
		end
	end
	def.pos=function(self)
		return self.object:get_pos()
	end
	def.on_step=examobs.on_step
	def.on_rightclick=function(self, clicker)
		if self.fight or self.dead or self.dying then
			return
		end
		examobs.lookat(self,clicker)
		self.on_click(self,clicker)
	end
	def.get_staticdata = function(self)
		self.storage.dead = self.dead
		self.storage.dying = self.dying
		self.storage.hp = self.hp
		self.storage.lifetimer = self.lifetimer
		self.storage.inv = self.inv
		return minetest.serialize(self.storage)
	end
	def.on_activate=function(self, staticdata)
		self.storage = minetest.deserialize(staticdata) or {}
		self.examob = math.random(1,9999)

		self.dead = self.storage.dead or nil
		self.dying = self.storage.dying or nil
		self.hp = self.storage.hp or def.hp
		self.lifetimer = self.storage.lifetimer or def.lifetimer
		self.inv = self.storage.inv or table.copy(def.inv)
		self.otype = self.type

		self.object:set_velocity({x=0,y=-1,z=0})
		self.object:set_acceleration({x=0,y=-10,z =0})

		if self.dead or self.dying then
			examobs.anim(self,"lay")
		end

		if staticdata ~= "" then
			self.on_load(self)
		else
			self.on_spawn(self)
		end
	end
	def.hurt=function(self,dmg)
		self.hp = self.hp - dmg
		self.object:set_hp(self.hp)
		if self.dead then
			if self.dead <= 0 or self.hp <= 0 then
				self.object:remove()
			end
			return self
		elseif self.dying then
			if self.hp <= 0 then
				examobs.dying(self,2)
				return self
			end
		elseif self.hp <= 0 then
			local pos=self.object:get_pos()
			if self.lay_on_death == 1 then
				examobs.stand(self)
				examobs.dying(self,1)
				return self
			else
				self.death(self,pos)
				examobs.dropall(self)
				self.object:remove()
				return self
			end
		end
		examobs.showtext(self,self.hp .. "/" .. self.hp_max)
	end
	def.on_punch=function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		local en = puncher:get_luaentity()
		local dmg = 0
		self.last_punched_by = puncher or self.last_punched_by
		if not (en and en.examob == self.examob) then
			if self.aggressivity > 0 then
				self.fight = puncher
				if not examobs.known(self,puncher,"flee",true) then
					examobs.known(self,puncher,"fight")
				end
			elseif self.aggressivity < 0 then
				self.flee = puncher
				examobs.known(self,puncher,"flee")
			end
			examobs.lookat(self,self.fight)

			self.on_punched(self,puncher)
		end

		dmg = tool_capabilities.damage_groups.fleshy or 1

		if puncher:is_player() then
			local item = minetest.registered_tools[puncher:get_wielded_item():get_name()]
			if item and item.tool_capabilities and item.tool_capabilities.damage_groups then
				local d = tool_capabilities.damage_groups.fleshy
				if d and d > 0 then
					local tool = puncher:get_wielded_item()
					tool:add_wear(math.ceil(self.add_wear/(dmg*dmg)))
					puncher:set_wielded_item(tool)
				end
			end
		end

		local v={x = dir.x*3,y = self.object:get_velocity().y,z = dir.z*3}
		self.object:set_velocity(v)
		local r=math.random(1,99)
		self.onpunch_r=r
		minetest.after(0.5, function(self,v,r)
			if self and self.onpunch_r == r and self.object and self.object:get_pos() then
				self.object:set_velocity({x = 0,y = self.object:get_velocity().y,z = 0})
			end
		end, self,v,r)

		self:hurt(dmg)
		self:achievements()

		return self
	end

	def.achievements=function(self)
		if not self.achievemed and (self.dead or self.object:get_hp()<=0) and self.last_punched_by and self.last_punched_by:is_player() then
			self.achievemed = true
			if self.otype == "monster" then
				exaachievements.customize(self.last_punched_by,"Monsters_nightmare")
			elseif self.otype == "animal" then
				exaachievements.customize(self.last_punched_by,"Hunter")
			end
		end
	end

	def.on_death=function(self,killer)
		examobs.dropall(self)
	end
	minetest.register_entity(name,def)

	if not egg and def.visual == "mesh" then
		minetest.register_node(name .."_spawner", {
			description = def.name .." spawner",
			groups={not_in_craftguide=1},
			wield_scale={x=0.1,y=0.1,z=0.1},
			tiles = def.textures,
			drawtype="mesh",
			mesh=def.mesh,
			paramtype="light",
			visual_scale=0.1,
			walkable = true,
			pointable = false,
			on_place = function(itemstack, user, pointed_thing)
				if pointed_thing.type=="node" then
					local p = pointed_thing.above
					minetest.add_entity({x=p.x,y=p.y+1,z=p.z}, name):set_yaw(math.random(0,6.28))
					itemstack:take_item()
				minetest.after(0.5, function(p)
					minetest.add_node(p,{name="air"})
				end, p)
				end
				return itemstack
			end,
		})
	else
		minetest.register_craftitem(name .."_spawner", {
			description = def.name .." spawner",
			groups={not_in_craftguide=1},
			inventory_image = def.textures[1] .. "^examobs_alpha_egg.png^[makealpha:0,255,0",
			on_place = function(itemstack, user, pointed_thing)
				if pointed_thing.type=="node" then
					local p = pointed_thing.above
					minetest.add_entity({x=p.x,y=p.y+1,z=p.z}, name):set_yaw(math.random(0,6.28))
					itemstack:take_item()
				end
				return itemstack
			end
		})
	end

	minetest.register_abm({
		nodenames = def.spawn_on,
		interval = def.spawn_interval or 30,
		chance = def.spawn_chance,
		action = function(pos)
			local pos1 = apos(pos,0,1)
			local pos2 = apos(pos,0,2)
			local l=minetest.get_node_light(pos1)
			if examobs.global_lifetime <= 1 and l and math.random(1,def.spawn_chance) == 1 and l >= def.light_min and l <= def.light_max then
				local n1 = minetest.get_node(pos1).name
				if (def.spawn_in and (def.spawn_in==n1 and def.spawn_in==minetest.get_node(pos2).name or minetest.get_item_group(n1,def.spawn_in) > 0))  or not (walkable(pos1) and walkable(pos2)) then 
					minetest.add_entity(apos(pos1,0,bottom), name):set_yaw(math.random(0,6.28))
				end
			end
		end
	})
end