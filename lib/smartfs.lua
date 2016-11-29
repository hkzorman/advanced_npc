---------------------------
-- SmartFS: Smart Formspecs
-- License: CC0 or WTFPL
--    by Rubenwardy
---------------------------

smartfs = {
	_fdef = {},
	_edef = {},
	opened = {},
	inv = {}
}

local function boolToStr(v)
	return v and "true" or "false"
end

-- the smartfs() function
function smartfs.__call(self, name)
	return smartfs.get(name)
end

function smartfs.get(name)
	return smartfs._fdef[name]
end

-- Register forms and elements
function smartfs.create(name, onload)
	assert(not smartfs._fdef[name],
			"SmartFS - (Error) Form "..name.." already exists!")
	assert(not smartfs.loaded or smartfs._loaded_override,
			"SmartFS - (Error) Forms should be declared while the game loads.")

	smartfs._fdef[name] = {
		form_setup_callback = onload,
		name = name,
		show = smartfs._show_,
		attach_to_node = smartfs._attach_to_node_
	}

	return smartfs._fdef[name]
end

function smartfs.override_load_checks()
	smartfs._loaded_override = true
end

minetest.after(0, function()
	smartfs.loaded = true
end)

function smartfs.dynamic(name,player)
	if not smartfs._dynamic_warned then
		smartfs._dynamic_warned = true
		minetest.log("warning", "SmartFS - (Warning) On the fly forms are being used. May cause bad things to happen")
	end

	local state = smartfs._makeState_({name=name}, player, nil, false)
	state.show = state._show_
	smartfs.opened[player] = state
	return state
end

function smartfs.element(name, data)
	assert(not smartfs._edef[name],
			"SmartFS - (Error) Element type "..name.." already exists!")

	assert(data.onCreate, "element requires onCreate method")
	smartfs._edef[name] = data
	return smartfs._edef[name]
end

function smartfs.inventory_mod()
	if unified_inventory then
		return "unified_inventory"
	elseif inventory_plus then
		return "inventory_plus"
	else
		return nil
	end
end

function smartfs.add_to_inventory(form, icon, title)
	if unified_inventory then
		unified_inventory.register_button(form.name, {
			type = "image",
			image = icon,
		})
		unified_inventory.register_page(form.name, {
			get_formspec = function(player, formspec)
				local name = player:get_player_name()
				local opened = smartfs._show_(form, name, nil, true)
				return {formspec = opened:_buildFormspec_(false)}
			end
		})
		return true
	elseif inventory_plus then
		minetest.register_on_joinplayer(function(player)
			inventory_plus.register_button(player, form.name, title)
		end)
		minetest.register_on_player_receive_fields(function(player, formname, fields)
			if formname == "" and fields[form.name] then
				local name = player:get_player_name()
				local opened = smartfs._show_(form, name, nil, true)
				inventory_plus.set_inventory_formspec(player, opened:_buildFormspec_(true))
			end
		end)
		return true
	else
		return false
	end
end

function smartfs._makeState_(form, newplayer, params, is_inv, nodepos)
	-- Object to manage players
	local function _make_players_(form, newplayer)
		local self = {
			_list = {}
		}

		function self.connect(self, player)
			if player then
				self._list[player] = player
			end
		end

		function self.disconnect(self, player)
			self._list[player] = nil
		end

		function self.get_first(self)
			return next(self._list)
		end

		self:connect(newplayer)
		return self
	end

	-- create object to handle formspec location
	local function _make_location_(form, newplayer, params, is_inv, nodepos)
		local self = {}
		if nodepos then
			self.type = "nodemeta"
			self.pos = nodepos
		elseif newplayer then
			if is_inv then
				self.type = "inventory"
			else
				self.type = "player"
			end
			self.player = newplayer
		end
		return self
	end

	-- create returning state object
	return {
		_ele = {},
		def = form,
		players = _make_players_(form, newplayer),
		location = _make_location_(form, newplayer, params, is_inv, nodepos),
		is_inv = is_inv, -- obsolete. Please use location.type="inventory" instead
		player = newplayer, -- obsolete. Please use location.player
		param = params or {},
		get = function(self,name)
			return self._ele[name]
		end,
		close = function(self)
			self.closed = true
		end,
		size = function(self,w,h)
			self._size = {w=w,h=h}
		end,
		_buildFormspec_ = function(self,size)
			local res = ""
			if self._size and size then
				res = "size["..self._size.w..","..self._size.h.."]"
			end
			for key,val in pairs(self._ele) do
				res = res .. val:build()
			end
			return res
		end,
		_show_ = function(self)
			local res = self:_buildFormspec_(true)
			if self.location.type == "inventory" then
				if unified_inventory then
					unified_inventory.set_inventory_formspec(minetest.get_player_by_name(self.location.player), self.def.name)
				elseif inventory_plus then
					inventory_plus.set_inventory_formspec(minetest.get_player_by_name(self.location.player), res)
				end
			elseif self.location.type == "player" then
				minetest.show_formspec(self.location.player, form.name, res)
			elseif self.location.type == "nodemeta" then
				local meta = minetest.get_meta(self.location.pos)
				meta:set_string("formspec", res)
				meta:set_string("smartfs_name", self.def.name)
			end
		end,
		onInput = function(self, func)
			self._onInput = func -- (fields, player)
		end,
		load = function(self,file)
			local file = io.open(file, "r")
			if file then
				local table = minetest.deserialize(file:read("*all"))
				if type(table) == "table" then
					if table.size then
						self._size = table.size
					end
					for key,val in pairs(table.ele) do
						self:element(val.type,val)
					end
					return true
				end
			end
			return false
		end,
		save = function(self,file)
			local res = {ele={}}

			if self._size then
				res.size = self._size
			end

			for key,val in pairs(self._ele) do
				res.ele[key] = val.data
			end

			local file = io.open(file, "w")
			if file then
				file:write(minetest.serialize(res))
				file:close()
				return true
			end
			return false
		end,
		setparam = function(self,key,value)
			if not key then return end
			self.param[key] = value
			return true
		end,
		getparam = function(self,key,default)
			if not key then return end
			return self.param[key] or default
		end,
		element = function(self,typen,data)
			local type = smartfs._edef[typen]
			assert(type, "Element type "..typen.." does not exist!")
			assert(not self._ele[data.name], "Element "..data.name.." already exists")

			data.type = typen
			local ele = {
				name = data.name,
				root = self,
				data = data,
				remove = function(self)
					self.root._ele[self.name] = nil
				end
			}

			for key, val in pairs(type) do
				ele[key] = val
			end

			self._ele[data.name] = ele

			type.onCreate(ele)

			return self._ele[data.name]
		end,


		--
		-- ELEMENT CONSTRUCTORS
		--
		button = function(self, x, y, w, h, name, text, exitf)
			return self:element("button", {
				pos    = {x=x,y=y},
				size   = {w=w,h=h},
				name   = name,
				value  = text,
				closes = exitf or false
			})
		end,
		label = function(self, x, y, name, text)
			return self:element("label", {
				pos   = {x=x,y=y},
				name  = name,
				value = text
			})
		end,
		toggle = function(self, x, y, w, h, name, list)
			return self:element("toggle", {
				pos  = {x=x, y=y},
				size = {w=w, h=h},
				name = name,
				id   = 1,
				list = list
			})
		end,
		field = function(self, x, y, w, h, name, label)
			return self:element("field", {
				pos   = {x=x, y=y},
				size  = {w=w, h=h},
				name  = name,
				value = "",
				label = label
			})
		end,
		pwdfield = function(self, x, y, w, h, name, label)
			local res = self:element("field", {
				pos   = {x=x, y=y},
				size  = {w=w, h=h},
				name  = name,
				value = "",
				label = label
			})
			res:isPassword(true)
			return res
		end,
		textarea = function(self, x, y, w, h, name, label)
			local res = self:element("field", {
				pos   = {x=x, y=y},
				size  = {w=w, h=h},
				name  = name,
				value = "",
				label = label
			})
			res:isMultiline(true)
			return res
		end,
		image = function(self, x, y, w, h, name, img)
			return self:element("image", {
				pos   = {x=x, y=y},
				size  = {w=w, h=h},
				name  = name,
				value = img
			})
		end,
		checkbox = function(self, x, y, name, label, selected)
			return self:element("checkbox", {
				pos   = {x=x, y=y},
				name  = name,
				value = selected,
				label = label
			})
		end,
		listbox = function(self, x, y, w, h, name, selected, transparent)
			return self:element("list", {
				pos         = {x=x, y=y},
				size        = {w=w, h=h},
				name        = name,
				selected    = selected,
				transparent = transparent
			})
		end,
		inventory = function(self, x, y, w, h, name)
			return self:element("inventory", {
				pos  = {x=x, y=y},
				size = {w=w, h=h},
				name = name
			})
		end,
	}
end

-- Show a formspec to a user
function smartfs._show_(form, name, params, is_inv)
	assert(form)
	assert(type(name) == "string", "smartfs: name needs to be a string")
	assert(minetest.get_player_by_name(name), "player does not exist")

	local state = smartfs._makeState_(form, name, params, is_inv)
	state.show = state._show_
	if form.form_setup_callback(state) ~= false then
		if not is_inv then
			smartfs.opened[name] = state
			state:_show_()
		else
			smartfs.inv[name] = state
		end
	end
	return state
end

-- Attach a formspec to a node
function smartfs._attach_to_node_(form, nodepos, placer)
	assert(form)
	assert(nodepos and nodepos.x)

	-- No attached user, no params, no inventory integration:
	local state = smartfs._makeState_(form, nil, nil, nil, nodepos)
	state:setparam("node_placer", placer:get_player_name())
	if form.form_setup_callback(state) then
		state:_show_()
	end
	return state
end

-- Receive fields from formspec
local function _sfs_recieve_(state, player, fields)
	assert(state)
	assert(player)

	for key,val in pairs(fields) do
		if state._ele[key] then
			state._ele[key].data.value = val
		end
	end
	for key,val in pairs(state._ele) do
		if val.submit then
			val:submit(fields, player)
		end
	end

	-- call onInput hook if enabled
	if state._onInput then
		state:_onInput(fields, player)
	end

	if not fields.quit and not state.closed then
		state:_show_()
	else
		-- to be closed
		state.players:disconnect(player)
		if state.location.type == "player" then
			smartfs.opened[player] = nil
		end
		if not fields.quit and state.closed then
			--closed by application (without fields.quit). currently not supported, see: https://github.com/minetest/minetest/pull/4675
			minetest.show_formspec(player,"","size[5,1]label[0,0;Formspec closing not yet created!]")
		end
	end
	return true
end

-- Receive input from sender to the node form
function smartfs.nodemeta_on_receive_fields(nodepos, formname, fields, sender, params)
	local meta = minetest.get_meta(nodepos)
	local nodeform = meta:get_string("smartfs_name")
	if not nodeform then
		print("SmartFS - (Warning) smartfs.nodemeta_on_receive_fields for node without smarfs data")
		return false
	end

	-- get the currentsmartfs state
	local opened_id = minetest.pos_to_string(nodepos)
	local state
	local form = smartfs.get(nodeform)
	if not smartfs.opened[opened_id] or      -- If opened first time
 			smartfs.opened[opened_id].def.name ~= nodeform then -- Or form is changed
		state = smartfs._makeState_(form, nil, params, nil, nodepos)
		smartfs.opened[opened_id] = state
		form.form_setup_callback(state)
	else
		state = smartfs.opened[opened_id]
	end

	-- Set current sender check for multiple users on node
	local name = sender:get_player_name()
	state.players:connect(name)

	-- take the input
	_sfs_recieve_(state, name, fields)

	-- Reset form if all players disconnected
	if not state.players:get_first() then
		state._ele = {}
		if form.form_setup_callback(state) then
			state:_show_()
		end
		smartfs.opened[opened_id] = nil
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if smartfs.opened[name] and smartfs.opened[name].location.type == "player" then
		if smartfs.opened[name].def.name == formname then
			local state = smartfs.opened[name]
			return _sfs_recieve_(state,name,fields)
		else
			smartfs.opened[name] = nil
		end
	elseif smartfs.inv[name] and smartfs.inv[name].location.type == "inventory" then
		local state = smartfs.inv[name]
		_sfs_recieve_(state,name,fields)
	end
	return false
end)


-----------------------------------------------------------------
-------------------------  ELEMENTS  ----------------------------
-----------------------------------------------------------------

smartfs.element("button", {
	onCreate = function(self)
		assert(self.data.pos and self.data.pos.x and self.data.pos.y, "button needs valid pos")
		assert(self.data.size and self.data.size.w and self.data.size.h, "button needs valid size")
		assert(self.name, "button needs name")
		assert(self.data.value, "button needs label")
	end,
	build = function(self)
		if self.data.img then
			return "image_button["..
				self.data.pos.x..","..self.data.pos.y..
				";"..
				self.data.size.w..","..self.data.size.h..
				";"..
				self.data.img..
				";"..
				self.name..
				";"..
				minetest.formspec_escape(self.data.value)..
				"]"
		else
			if self.data.closes then
				return "button_exit["..
					self.data.pos.x..","..self.data.pos.y..
					";"..
					self.data.size.w..","..self.data.size.h..
					";"..
					self.name..
					";"..
					minetest.formspec_escape(self.data.value)..
					"]"
			else
				return "button["..
					self.data.pos.x..","..self.data.pos.y..
					";"..
					self.data.size.w..","..self.data.size.h..
					";"..
					self.name..
					";"..
					minetest.formspec_escape(self.data.value)..
					"]"
			end
		end
	end,
	submit = function(self, fields, player)
		if fields[self.name] and self._click then
			self:_click(self.root, player)
		end
	end,
	setPosition = function(self,x,y)
		self.data.pos = {x=x,y=y}
	end,
	getPosition = function(self,x,y)
		return self.data.pos
	end,
	setSize = function(self,w,h)
		self.data.size = {w=w,h=h}
	end,
	getSize = function(self,x,y)
		return self.data.size
	end,
	onClick = function(self,func)
		self._click = func
	end,
	click = function(self,func)
		self._click = func
	end,
	setText = function(self,text)
		self.data.value = text
	end,
	getText = function(self)
		return self.data.value
	end,
	setImage = function(self,image)
		self.data.img = image
	end,
	getImage = function(self)
		return self.data.img
	end,
})

smartfs.element("toggle", {
	onCreate = function(self)
		assert(self.data.pos and self.data.pos.x and self.data.pos.y, "toggle needs valid pos")
		assert(self.data.size and self.data.size.w and self.data.size.h, "toggle needs valid size")
		assert(self.name, "toggle needs name")
		assert(self.data.list, "toggle needs data")
	end,
	build = function(self)
		return "button["..
			self.data.pos.x..","..self.data.pos.y..
			";"..
			self.data.size.w..","..self.data.size.h..
			";"..
			self.name..
			";"..
			minetest.formspec_escape(self.data.list[self.data.id])..
			"]"
	end,
	submit = function(self, fields, player)
		if fields[self.name] then
			self.data.id = self.data.id + 1
			if self.data.id > #self.data.list then
				self.data.id = 1
			end
			if self._tog then
				self:_tog(self.root, player)
			end
		end
	end,
	onToggle = function(self,func)
		self._tog = func
	end,
	setPosition = function(self,x,y)
		self.data.pos = {x=x,y=y}
	end,
	getPosition = function(self,x,y)
		return self.data.pos
	end,
	setSize = function(self,w,h)
		self.data.size = {w=w,h=h}
	end,
	getSize = function(self,x,y)
		return self.data.size
	end,
	setId = function(self,id)
		self.data.id = id
	end,
	getId = function(self)
		return self.data.id
	end,
	getText = function(self)
		return self.data.list[self.data.id]
	end
})

smartfs.element("label", {
	onCreate = function(self)
		assert(self.data.pos and self.data.pos.x and self.data.pos.y, "label needs valid pos")
		assert(self.data.value, "label needs text")
	end,
	build = function(self)
		return "label["..
			self.data.pos.x..","..self.data.pos.y..
			";"..
			minetest.formspec_escape(self.data.value)..
			"]"
	end,
	setPosition = function(self,x,y)
		self.data.pos = {x=x,y=y}
	end,
	getPosition = function(self,x,y)
		return self.data.pos
	end,
	setText = function(self,text)
		self.data.value = text
	end,
	getText = function(self)
		return self.data.value
	end
})

smartfs.element("field", {
	onCreate = function(self)
		assert(self.data.pos and self.data.pos.x and self.data.pos.y, "field needs valid pos")
		assert(self.data.size and self.data.size.w and self.data.size.h, "field needs valid size")
		assert(self.name, "field needs name")
		self.data.value = self.data.value or ""
		self.data.label = self.data.label or ""
	end,
	build = function(self)
		if self.data.ml then
			return "textarea["..
				self.data.pos.x..","..self.data.pos.y..
				";"..
				self.data.size.w..","..self.data.size.h..
				";"..
				self.name..
				";"..
				minetest.formspec_escape(self.data.label)..
				";"..
				minetest.formspec_escape(self.data.value)..
				"]"
		elseif self.data.pwd then
			return "pwdfield["..
				self.data.pos.x..","..self.data.pos.y..
				";"..
				self.data.size.w..","..self.data.size.h..
				";"..
				self.name..
				";"..
				minetest.formspec_escape(self.data.label)..
				"]"
		else
			return "field["..
				self.data.pos.x..","..self.data.pos.y..
				";"..
				self.data.size.w..","..self.data.size.h..
				";"..
				self.name..
				";"..
				minetest.formspec_escape(self.data.label)..
				";"..
				minetest.formspec_escape(self.data.value)..
				"]"
		end
	end,
	setPosition = function(self,x,y)
		self.data.pos = {x=x,y=y}
	end,
	getPosition = function(self,x,y)
		return self.data.pos
	end,
	setSize = function(self,w,h)
		self.data.size = {w=w,h=h}
	end,
	getSize = function(self,x,y)
		return self.data.size
	end,
	setText = function(self,text)
		self.data.value = text
	end,
	getText = function(self)
		return self.data.value
	end,
	isPassword = function(self,bool)
		self.data.pwd = bool
	end,
	isMultiline = function(self,bool)
		self.data.ml = bool
	end
})

smartfs.element("image", {
	onCreate = function(self)
		assert(self.data.pos and self.data.pos.x and self.data.pos.y, "image needs valid pos")
		assert(self.data.size and self.data.size.w and self.data.size.h, "image needs valid size")
		self.data.value = self.data.value or ""
	end,
	build = function(self)
		return "image["..
			self.data.pos.x..","..self.data.pos.y..
			";"..
			self.data.size.w..","..self.data.size.h..
			";"..
			self.data.value..
			"]"
	end,
	setPosition = function(self,x,y)
		self.data.pos = {x=x,y=y}
	end,
	getPosition = function(self,x,y)
		return self.data.pos
	end,
	setSize = function(self,w,h)
		self.data.size = {w=w,h=h}
	end,
	getSize = function(self,x,y)
		return self.data.size
	end,
	setImage = function(self,text)
		self.data.value = text
	end,
	getImage = function(self)
		return self.data.value
	end
})

smartfs.element("checkbox", {
	onCreate = function(self)
		assert(self.data.pos and self.data.pos.x and self.data.pos.y, "checkbox needs valid pos")
		assert(self.name, "checkbox needs name")
		self.data.value = minetest.is_yes(self.data.value)
		self.data.label = self.data.label or ""
	end,
	build = function(self)
		if self.data.value then
			self.data.value = "true"
		else
			self.data.value = "false"
		end
		return "checkbox["..
			self.data.pos.x..","..self.data.pos.y..
			";"..
			self.name..
			";"..
			minetest.formspec_escape(self.data.label)..
			";" .. boolToStr(self.data.value) .."]"
	end,
	submit = function(self, fields, player)
		if fields[self.name] then
			-- self.data.value already set by value transfer
			-- call the toggle function if defined
			if self._tog then
				self:_tog(self.root, player)
			end
		end
	end,
	setPosition = function(self,x,y)
		self.data.pos = {x=x,y=y}
	end,
	getPosition = function(self,x,y)
		return self.data.pos
	end,
	setValue = function(self, value)
		self.data.value = minetest.is_yes(value)
	end,
	getValue = function(self)
		return self.data.value
	end,
	onToggle = function(self,func)
		self._tog = func
	end,
})

smartfs.element("list", {
	onCreate = function(self)
		assert(self.data.pos and self.data.pos.x and self.data.pos.y, "list needs valid pos")
		assert(self.data.size and self.data.size.w and self.data.size.h, "list needs valid size")
		assert(self.name, "list needs name")
		self.data.value = minetest.is_yes(self.data.value)
		self.data.label = self.data.label or ""
		self.data.items = self.data.items or {}
	end,
	build = function(self)
		if not self.data.items then
			self.data.items = {}
		end
		local listformspec = "textlist["..
				self.data.pos.x..","..self.data.pos.y..
				";"..
				self.data.size.w..","..self.data.size.h..
				";"..
				self.data.name..
				";"..
				table.concat(self.data.items, ",")..
				";"..
				tostring(self.data.selected or "")..
				";"..
				tostring(self.data.transparent or "false").."]"

		return listformspec
	end,
	submit = function(self, fields, player)
		if fields[self.name] then
			local _type = string.sub(fields[self.data.name], 1, 3)
			local index = tonumber(string.sub(fields[self.data.name], 5))
			self.data.selected = index
			if _type == "CHG" and self._click then
				self:_click(self.root, index, player)
			elseif _type == "DCL" and self._doubleClick then
				self:_doubleClick(self.root, index, player)
			end
		end
	end,
	onClick = function(self, func)
		self._click = func
	end,
	click = function(self, func)
		self._click = func
	end,
	onDoubleClick = function(self, func)
		self._doubleClick = func
	end,
	doubleclick = function(self, func)
		self._doubleClick = func
	end,
	setPosition = function(self,x,y)
		self.data.pos = {x=x,y=y}
	end,
	getPosition = function(self,x,y)
		return self.data.pos
	end,
	setSize = function(self,w,h)
		self.data.size = {w=w,h=h}
	end,
	getSize = function(self,x,y)
		return self.data.size
	end,
	addItem = function(self, item)
		if not self.data.items then
			self.data.items = {}
		end
		table.insert(self.data.items, item)
	end,
	removeItem = function(self,idx)
		if not self.data.items then
			self.data.items = {}
		end
		table.remove(self.data.items,idx)
	end,
	getItem = function(self, idx)
		if not self.data.items then
			self.data.items = {}
		end
		return self.data.items[idx]
	end,
	popItem = function(self)
		if not self.data.items then
			self.data.items = {}
		end
		local item = self.data.items[#self.data.items]
		table.remove(self.data.items)
		return item
	end,
	clearItems = function(self)
		self.data.items = {}
	end,
	setSelected = function(self,idx)
		self.data.selected = idx
	end,
	getSelected = function(self)
		return self.data.selected
	end,
	getSelectedItem = function(self)
		return self:getItem(self:getSelected())
	end,
})

smartfs.element("inventory", {
	onCreate = function(self)
		assert(self.data.pos and self.data.pos.x and self.data.pos.y, "list needs valid pos")
		assert(self.data.size and self.data.size.w and self.data.size.h, "list needs valid size")
		assert(self.name, "list needs name")
	end,
	build = function(self)
		return "list["..
			(self.data.location or "current_player") ..
			";"..
			self.name..
			";"..
			self.data.pos.x..","..self.data.pos.y..
			";"..
			self.data.size.w..","..self.data.size.h..
			";"..
			(self.data.index or "") ..
			"]"
	end,
	setPosition = function(self,x,y)
		self.data.pos = {x=x,y=y}
	end,
	getPosition = function(self,x,y)
		return self.data.pos
	end,
	setSize = function(self,w,h)
		self.data.size = {w=w,h=h}
	end,
	getSize = function(self,x,y)
		return self.data.size
	end,
	-- available inventory locations
	-- "current_player": Player to whom the menu is shown
	-- "player:<name>": Any player
	-- "nodemeta:<X>,<Y>,<Z>": Any node metadata
	-- "detached:<name>": A detached inventory
	-- "context" does not apply to smartfs, since there is no node-metadata as context available
	setLocation = function(self,location)
		self.data.location = location
	end,
	getLocation = function(self)
		return self.data.location or "current_player"
	end,
	usePosition = function(self, pos)
		self.data.location = string.format("nodemeta:%d,%d,%d", pos.x, pos.y, pos.z)
	end,
	usePlayer = function(self, name)
		self.data.location = "player:" .. name
	end,
	useDetached = function(self, name)
		self.data.location = "detached:" .. name
	end,
	setIndex = function(self,index)
		self.data.index = index
	end,
	getIndex = function(self)
		return self.data.index
	end
})

smartfs.element("code", {
	onCreate = function(self)
		self.data.code = self.data.code or ""
	end,
	build = function(self)
		if self._build then
			self:_build()
		end

		return self.data.code
	end,
	submit = function(self, fields, player)
		if self._sub then
			self:_sub(self.root, fields, player)
		end
	end,
	onSubmit = function(self,func)
		self._sub = func
	end,
	onBuild = function(self,func)
		self._build = func
	end,
	setCode = function(self,code)
		self.data.code = code
	end,
	getCode = function(self)
		return self.data.code
	end
})
