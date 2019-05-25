apos=function(pos,x,y,z)
	return {x=pos.x+(x or 0),y=pos.y+(y or 0),z=pos.z+(z or 0)}
end

walkable=function(pos)
	local n = minetest.get_node(pos).name
	return (n ~= "air" and false) or examobs.def(n).walkable
end

examobs.jump=function(self)
	local v = self.object:get_velocity()
	if v.y == 0 then
		self.object:set_velocity({x=v.x, y=5.5, z=v.z})
	end
end

examobs.environment=function(self)
	self.environment_timer = 0
	if (self.flee or self.fight or self.folow or self.target) and not (self.dead or self.dying) then
		self.lifetimer = self.lifetime
		if not (self.updatetime_reset or self.folow) then
			self.updatetime_reset = self.updatetime
			self.updatetime = self.updatetime*0.1
		end
	elseif self.updatetime_reset then
		self.updatetime = self.updatetime_reset
		self.updatetime_reset = nil
	elseif self.lifetimer < 0 then
		if self:on_lifedeadline() then
			self.lifetimer = self.lifetime
		else
			self.object:remove()
		end
		return self
	end
	local pos = self:pos()
	local posf = examobs.pointat(self)
	pos = apos(pos,0,self.bottom)
	posf = apos(posf,0,self.bottom)
	local def = examobs.defpos(pos)
	local deff = examobs.defpos(posf)
	local v = self.object:get_velocity()
--jumping

	if not (self.dying or self.dead or self.is_floating) then
		local target = self.fight or self.flee or self.folow
		if def.walkable and v.x+v.z ~= 0 then
			if walkable(apos(pos,0,1)) and walkable(apos(pos,0,2)) and (minetest.get_node_light(pos,0,1) or 0) == 0 then
				self:hurt(1)
			else
				examobs.jump(self)
			end
		elseif v.x+v.z ~= 0 and deff.walkable or (target and examobs.gethp(target) > 0 and not walkable(apos(posf,0,-1)) and target:get_pos().y >= pos.y) then
			examobs.jump(self)
		elseif (deff.damage_per_second or 0) > 0 then
			examobs.stand(self)
		end
	end

--drowning & breath

	if self.breathing > 0 and not self.dead and self.environment_timer2 > 1 then
		if (def.drowning or 0) > 0 then
			self.breath = (self.breath or 20) -1
			if self.breath <= 0 then
				self.breath = 0
				self:hurt(1)
			else
				examobs.showtext(self,self.breath .."/20","0000ff")
			end
		else
			self.breath = 20
		end	
	end

--damage

	if self.environment_timer2 > 1 and (def.damage_per_second or 0) > 0 and not self.resist_nodes[def.name] then
		self:hurt(def.damage_per_second)
		if not (self.dying or self.dead) then
			self.object:set_yaw(math.random(0,6.28))
			examobs.jump(self)
			examobs.walk(self,true)
		end

		if minetest.get_item_group(def.name, "igniter") > 0 then
			minetest.add_particlespawner({
				amount = 5,
				time =0.2,
				minpos = {x=pos.x-0.5, y=pos.y, z=pos.z-0.5},
				maxpos = {x=pos.x+0.5, y=pos.y, z=pos.z+0.5},
				minvel = {x=0, y=0, z=0},
				maxvel = {x=0, y=math.random(3,6), z=0},
				minacc = {x=0, y=2, z=0},
				maxacc = {x=0, y=0, z=0},
				minexptime = 1,
				maxexptime = 3,
				minsize = 3,
				maxsize = 8,
				texture = "default_item_smoke.png",
				collisiondetection = true,
			})
		end
	end

-- timer = 0

	if self.environment_timer2 > 1 then
		self.environment_timer2 = 0
	end

--floating

	if self.floating[def.name] then
		if not self.is_floating then
			self.is_floating = true
			local v = self.object:get_velocity()
			self.object:set_acceleration({x =0, y=0, z =0})
			self.object:set_velocity({x=v.x, y=0, z =v.y})
		end
		return
	elseif self.is_floating then
		self.is_floating = nil
		local v = self.object:get_velocity()
		self.object:set_acceleration({x =0, y=-10, z =0})
	elseif not self.is_floating then
		if v.y < 0 and not self.falling then
			self.falling = pos.y
		end
		if self.falling and v.y >= 0 and walkable(apos(pos,0,-1)) then
			local d = math.floor(self.falling+0.5) - math.floor(pos.y+0.5)
			if d >= 10 then
				self:hurt(d)
			end
			self.falling = nil
		end
	end

--liquid and viscosity

	if def.liquid_viscosity > 0 then
		self.in_liquid = true
		local s=1
		local v=self.object:get_velocity()
		if self.dying or self.dead then s=-1 end

		if self.swiming < 1 and s == 1 then
			s = -1
			self:hurt(1)
			if not (self.dying or self.dead) then
				examobs.stand(self)
				examobs.anim(self,"run")
				if math.random(1,2) == 1 then
					self.object:set_yaw(math.random(0,6.28))
				end
			end
			if v.y < 0 then
				self.object:set_acceleration({x =0, y=20, z =0})
				self.object:set_velocity({x =0, y=v.y/2, z =0})
			elseif v.y > 0 then
				self.object:set_velocity({x =0, y=0, z =0})
				self.object:set_acceleration({x =0, y=0, z =0})
			end
			return true
		end

		self.object:set_acceleration({x =0, y =0.1*s, z =0})
		
		if v.y<-0.1 then
			self.object:set_velocity({x = v.x, y =v.y/2, z =v.z})
			return self
		end
		self.object:set_velocity({x = v.x, y =1*s - (def.liquid_viscosity*0.1), z = v.z})
		return self
	elseif self.in_liquid and (examobs.defpos(apos(pos,0,-1)).liquid_viscosity or 0) > 0 then
		local v=self.object:get_velocity()
		self.object:set_acceleration({x=0, y=0, z=0})
		self.object:set_velocity({x=v.x, y=0, z=v.z})
		if walkable(apos(posf,0,-1)) then
			examobs.jump(self)
			self.object:set_acceleration({x=0, y=-10, z=0})
		end
	elseif self.in_liquid then
		self.in_liquid = nil
		self.object:set_acceleration({x =0, y = -10, z =0})
	end
end

examobs.defpos=function(pos)
	return minetest.registered_items[minetest.get_node(pos).name] or {}
end

examobs.def=function(name)
	return minetest.registered_items[name] or {}
end

examobs.following=function(self)
	if self.folow and examobs.visiable(self.object,self.folow) then
		local d = examobs.distance(self.object,self.folow)
		if d > self.range/2 then
			examobs.lookat(self,self.folow)
			examobs.walk(self,true)
			return true
		elseif d > self.reach then
			examobs.lookat(self,self.folow)
			examobs.walk(self)
			return true
		end
	elseif self.folow then
		self.folow = nil
	end
end

examobs.exploring=function(self)
	if math.random(1,2) == 1 and examobs.find_objects(self) then return end

	local r = math.random(1,10)
	if r <= 5 and self.walking then		-- keep walk
		examobs.walk(self)
	elseif r <= 2 then					-- rnd walk
		self.object:set_yaw(math.random(0,6.28))
		self.walking = true
		examobs.walk(self)
	elseif r == 3 then					-- rnd look
		self.walking = nil
		examobs.stand(self)
		self.object:set_yaw(math.random(0,6.28))
	else						-- stand
		self.walking = nil
		examobs.stand(self)
	end
end

examobs.fleeing=function(self)
	if self.flee and examobs.gethp(self.flee) > 0 and (examobs.viewfield(self,self.flee) or examobs.distance(self.object,self.flee) <= self.range/2) then
		local p = examobs.pointat(self)
		if walkable(p) and walkable(apos(p,0,1)) then
			if  self.aggressivity > -2 and examobs.distance(self.object,self.flee) <= self.reach then
				examobs.lookat(self,self.flee)
				local flee = self.flee
				self.fight = self.flee
				minetest.after(2, function(self,flee)
					if self and self.object and flee then
						self.fight = nil
						self.flee = flee
					end
				end, self,flee)
			else
				self.object:set_yaw(math.random(0,6.28))
				examobs.jump(self)
				examobs.walk(self,true)
				
			end
			return self
		end

		examobs.lookat(self,self.flee)
		local yaw=examobs.num(self.object:get_yaw())
		self.object:set_yaw(yaw+math.pi)
		examobs.walk(self,true)
		return self
	elseif self.flee then
		self.flee = nil
	end
end

examobs.fighting=function(self)
	if self.fight and examobs.gethp(self.fight) > 0 and examobs.visiable(self.object,self.fight) then
		if examobs.distance(self.object,self.fight) <= self.reach then
			examobs.stand(self)
			examobs.lookat(self,self.fight)
			examobs.walk(self,true)
			if math.random(1,self.punch_chance) == 1 then
				if self.fight:get_pos().y > self:pos().y then
					examobs.jump(self)
				end
				local en = self.fight:get_luaentity()
				if en and en.itemstring then
					self:eat_item(en.itemstring)
				end
				examobs.punch(self.object,self.fight,self.dmg)
				examobs.anim(self,"attack")
				if examobs.gethp(self.fight) < 1 then
					self.fight = nil
				end
			end
		else
			examobs.lookat(self,self.fight)
			examobs.walk(self,true)
		end

		for _, ob in pairs(minetest.get_objects_inside_radius(self:pos(), self.range)) do
			local en = ob:get_luaentity()
			if en and en.examob and not en.fight and en.team == self.team and en.examob ~= self.examob and examobs.visiable(self,ob) then
				en.fight = self.fight
				examobs.lookat(en,en.fight)
			end
		end
		return true
	else
		self.fight = nil
		examobs.stand(self)
	end
end

examobs.stand=function(self)
	self.object:set_velocity({
		x = 0,
		y = self.object:get_velocity().y,
		z = 0})
	if not self.on_stand(self) then
		examobs.anim(self,"stand")
	end
	return self
end

examobs.fly=function(self,run)
	if self.fight or self.folow or self.flee then
		local pos1 = self:pos()
		local pos2 = (self.fight and self.fight:get_pos()) or (self.folow and self.folow:get_pos()) or (self.flee and self.flee:get_pos())
		run = run and self.walk_run*5 or self.walk_speed
		if not self.flee then
			run = run *-1
		end
		local d = examobs.distance(pos1,pos2)
		local x = ((pos1.x-pos2.x)/d)*run
		local y = ((pos1.y-pos2.y)/d)*run
		local z = ((pos1.z-pos2.z)/d)*run
		self.object:set_velocity({x=x,y=y,z=z})
		self.on_fly(self,x,y,z)
		return true
	end
end

examobs.walk=function(self,run)
	if self.is_floating and examobs.fly(self,run) then return end
	local yaw=examobs.num(self.object:get_yaw())
	local running = run
	self.movingspeed = run and self.run_speed or self.walk_speed
	local x = (math.sin(yaw) * -1) * self.movingspeed
	local z = (math.cos(yaw) * 1) * self.movingspeed
	local y = self.object:get_velocity().y

	self.object:set_velocity({
		x = x,
		y = y,
		z = z
	})

	if self.on_walk(self,x,y,z) then return end

	if running then
		examobs.anim(self,"run")
	else
		examobs.anim(self,"walk")
	end

	return self
end

examobs.lookat=function(self,pos2)
	if type(pos2) == "userdata" then
		pos2=pos2:get_pos()
	end
	if not (pos2 and pos2.z) then
		return
	end
	local pos1=self.object:get_pos()
	local vec = {x=pos1.x-pos2.x, y=pos1.y-pos2.y, z=pos1.z-pos2.z}
	local yaw = examobs.num(math.atan(vec.z/vec.x)-math.pi/2)
	if pos1.x >= pos2.x then yaw = yaw+math.pi end
	self.object:set_yaw(yaw)
end

examobs.num=function(a)
	return (a == math.huge or a == -math.huge or a ~= a) == false and a or 0
end

examobs.anim=function(self,type)
	if self.visual ~= "mesh" or type == self.anim then return end
	local a=self.animation[type]
	if not a then return end
	self.object:set_animation({x=a.x, y=a.y,},a.speed,false,a.loop)
	self.anim=type
	return self
end

examobs.team=function(target)
	if not target then return "" end
	local en = target:get_luaentity()
	return (en and (en.team or en.type or "")) or target:is_player() and "default"
end

examobs.find_objects=function(self)
	if self.aggressivity == 0 or self.fight or self.flee then return end
	local flee = self.aggressivity == -2
	local fight = self.aggressivity == 2
	local obs = {}
	local hungry = self.hp < self.hp_max
	for _, ob in pairs(minetest.get_objects_inside_radius(self.object:get_pos(), self.range)) do
		local en = ob:get_luaentity()
		if not (en and (not en.type or (en.examob == self.examob))) and examobs.visiable(self.object,ob) then
			local infield = examobs.viewfield(self,ob)
			local team = examobs.team(ob)
			local known = examobs.known(self,ob)
			local player = ob:is_player()
			if player then
				self.lifetimer = self.lifetime
			end
			if player and examobs.hiding[ob:get_player_name()] then
			elseif infield and ((self.aggressivity == 1 and self.hp < self.hp_max and self.team ~= team) or known == "fight") then
				self.fight = ob
				return
			elseif known == "flee" or (flee and team ~= self.team) or (self.aggressivity == -1 and en and en.type == "monster") then
				self.flee = ob
				return
			elseif known == "folow" then
				self.folow = ob
				return
			elseif infield and ((self.aggressivity == 1 and en and en.type == "monster") or self.aggressivity == 2) and team ~= self.team then
				table.insert(obs,ob)
			end
		elseif hungry and en and en.itemstring and examobs.visiable(self.object,ob) and examobs.viewfield(self,ob) then
			if minetest.get_item_group(string.split(en.itemstring," ")[1],"eatable") > 0 and self.is_food(self,string.split(en.itemstring," ")[1]) then
				self.fight = ob
				return
			end
		end
	end
	if #obs > 0 then
		self.fight = obs[#obs]
		examobs.known(self,self.fight,"fight")
		return true
	end
end

examobs.known=function(self,ob,type,get)
	if not ob then return end
	self.storage.known = self.storage.known or {}
	local en = ob:get_luaentity()
	local name = (en and (en.examob or en.type or en.name)) or (ob:is_player() and ob:get_player_name()) or ""
	if not type then
		return self.storage.known[name]
	elseif get then
		return self.storage.known[name] == type
	else
		self.storage.known[name] = type
	end
end

examobs.visiable=function(pos1,pos2)
	pos1 = type(pos1) == "userdata" and pos1:get_pos() or pos1.object and pos1.object:get_pos() or pos1
	pos2 = type(pos2) == "userdata" and pos2:get_pos() or pos2	

	local v = {x = pos1.x - pos2.x, y = pos1.y - pos2.y-1, z = pos1.z - pos2.z}
	v.y=v.y-1
	local amount = (v.x ^ 2 + v.y ^ 2 + v.z ^ 2) ^ 0.5
	local d=vector.distance(pos1,pos2)
	v.x = (v.x  / amount)*-1
	v.y = (v.y  / amount)*-1
	v.z = (v.z  / amount)*-1
	for i=1,d,1 do
		local node = minetest.registered_nodes[minetest.get_node({x=pos1.x+(v.x*i),y=pos1.y+(v.y*i),z=pos1.z+(v.z*i)}).name]
		if node and node.walkable then
			return false
		end
	end
	return true
end

examobs.gethp=function(ob,even_dead)
	if not (ob and ob:get_pos()) then
		return 0
	elseif ob:is_player() then
		return ob:get_hp()
	end
	local en = ob:get_luaentity()
	return en and ((even_dead and en.examob and en.dead and en.hp) or (en.examob and en.dead and 0) or en.hp or en.health) or ob:get_hp() or 0
end

examobs.viewfield=function(self,ob)
	if not (self and self.object and ob) then return false end
	local pos1=self.object:get_pos()
	local pos2 = type(ob) == "userdata" and ob:get_pos() or ob
	return examobs.distance(pos1,pos2)>examobs.distance(examobs.pointat(self,0.1),pos2)
end

examobs.pointat=function(self,d)
	local pos=self.object:get_pos()
	local yaw=examobs.num(self.object:get_yaw())
	d=d or 1
	local x =math.sin(yaw) * -d
	local z =math.cos(yaw) * d
	return {x=pos.x+x,y=pos.y,z=pos.z+z}
end

examobs.distance=function(pos1,pos2)
	pos1 = type(pos1) == "userdata" and pos1:get_pos() or pos1
	pos2 = type(pos2) == "userdata" and pos2:get_pos() or pos2
	return pos2 and pos1.z and pos2.z and vector.distance(pos1,pos2) or 0
end

examobs.punch=function(puncher,target,damage)
	target:punch(puncher,1,{full_punch_interval=1,damage_groups={fleshy=damage}})
end

examobs.showtext=function(self,text,color)
	self.delstatus=math.random(0,1000) 
	local del=self.delstatus
	color=color or "ff0000"
	self.object:set_properties({nametag=text,nametag_color="#" ..  color})
	minetest.after(1.5, function(self,del)
		if self and self.object and self.delstatus==del then
			self.delstatus = nil
			self.object:set_properties({nametag="",nametag_color=""})
		end
	end, self,del)
	return self
end

examobs.dropall=function(self)
	local pos = self:pos()
	if not pos then
		return
	end
	for i,v in pairs(self.inv) do
		if minetest.registered_items[i] then
			minetest.add_item(pos,i .. " " .. v):set_velocity({
				x=math.random(-1.5,1.5),
				y=math.random(0.5,1),
				z=math.random(-1.5,1.5)
			})
		end
		self.inv[i] = nil
	end
end

examobs.dying=function(self,set)
	if self.lay_on_death ~= 1 then return end
	if set and set==1 then
		examobs.anim(self,"lay")
		self.object:set_acceleration({x=0,y=-10,z =0})
		self.object:set_velocity({x=0,y=-3,z =0})
		if self.hp<=self.hp_max*-1 then
			examobs.dying(self,2)
			return self
		end
		self.dying={step=self.hp_max+self.hp,try=self.hp+self.hp_max/2}
		self.hp=self.hp_max/2
		self.object:set_hp(self.hp)
	elseif set and set==2 then
		minetest.after(0.1, function(self)
			if self.object:get_luaentity() then
				examobs.anim(self,"lay")
			end
		end, self)
		self.object:set_properties({nametag=""})
		self.type=""
		self.hp=self.hp_max
		self.object:set_hp(self.hp)
		self.dying=nil
		self.dead=20
		self.death(self)
		examobs.dropall(self)
	elseif set and set==3 and (self.dying or self.dead) then
		self.dying={step=0,try=self.hp_max*2}
		self.dead=nil
	end

	if self.dying then
		self.object:set_velocity({x=0,y=self.object:get_velocity().y,z=0})
		if self.hp<=self.hp_max*-1 then
			examobs.dying(self,2)
			return self
		end
		self.dying.try=self.dying.try+math.random(-1,1)
		self.dying.step=self.dying.step-1
		examobs.showtext(self,(self.dying.try+self.hp) .."/".. self.hp_max,"ff5500")
		self.on_dying(self)

		if self.dying.step<1 and self.dying.try+self.hp>=self.hp_max then
			local h=math.random(1,5)
			self.dying=nil
			self.hp=h
			self.object:set_hp(h)
			examobs.stand(self)
			examobs.showtext(self,"")
			return self
		elseif self.dying.step<1 and self.dying.try+self.hp<self.hp_max then
			examobs.dying(self,2)
			return self
		end
		return self
	elseif self.dead then
		self.dead=self.dead-1
		if self.dead<0 then
			examobs.dropall(self)
			self.object:remove()
		end
		return self
	end
end