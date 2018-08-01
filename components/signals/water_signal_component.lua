local csg_lib = require 'lib.csg.csg_lib'
local Point3 = _radiant.csg.Point3
local Cube3 = _radiant.csg.Cube3
local Region3 = _radiant.csg.Region3
local log = radiant.log.create_logger('water_signal')

local WaterSignalComponent = class()

function WaterSignalComponent:initialize()
	local json = radiant.entities.get_json(self)
	self._sv._signal_region = json and json.signal_region and Region3(json.signal_region)
	self._sv.ticks_per_check = math.max((json and json.ticks_per_check) or 2, 1)
	self.__saved_variables:mark_changed()
end

function WaterSignalComponent:create()
	self._is_create = true
end

function WaterSignalComponent:post_activate()
	if self._is_create then
		if not self._sv._signal_region then
			local component = self._entity:get_component('region_collision_shape')
			if component then
				self._sv._signal_region = component:get_region():get()
			else
				self._sv._signal_region = Region3(Cube3(Point3.zero, Point3.one))
			end
		end
	end
   
	self._current_tick = 0
	self._tick_listener = radiant.events.listen(stonehearth.hydrology, 'stonehearth:hydrology:tick', function()
			self:_on_tick()
		end)
end

function WaterSignalComponent:destroy()
	if self._tick_listener then
		self._tick_listener:destroy()
		self._tick_listener = nil
	end
end

function WaterSignalComponent:_reset()
	self._sv._water_exists = nil
	self._sv._water_volume = nil
	self._sv._waterfall_exists = nil
	self._sv._waterfall_volume = nil
	self.__saved_variables:mark_changed()
end

function WaterSignalComponent:set_region(region)
	self._sv._signal_region = region
	self:_reset()
end

function WaterSignalComponent:set_ticks_per_check(ticks)
	self._sv.ticks_per_check = math.max(ticks, 1)
	self.__saved_variables:mark_changed()
end

function WaterSignalComponent:get_water_exists()
	return self._sv._water_exists
end

function WaterSignalComponent:set_water_exists(water_entities)
	local exists = next(water_entities) ~= nil

	local prev_exists = self._water_exists
	self._sv._water_exists = exists
	
	if exists ~= prev_exists then
		radiant.events.trigger(self._entity, 'stonehearth_ace:water_signal:water_exists_changed', exists)
	end
end

function WaterSignalComponent:get_water_volume()
	return self._sv._water_volume
end

function WaterSignalComponent:set_water_volume(water_entities)
	local volume = 0
	for i, w in pairs(water_entities) do
		volume = volume + w:get_volume()
	end

	local prev_volume = self._water_volume
	self._sv._water_volume = volume

	if volume ~= prev_volume then
		radiant.events.trigger(self._entity, 'stonehearth_ace:water_signal:water_volume_changed', volume)
	end
end

function WaterSignalComponent:get_waterfall_exists()
	return self._sv._waterfall_exists
end

function WaterSignalComponent:set_waterfall_exists(waterfall_components)
	local exists = next(waterfall_components) ~= nil

	local prev_exists = self._waterfall_exists
	self._sv._waterfall_exists = exists
	
	if exists ~= prev_exists then
		radiant.events.trigger(self._entity, 'stonehearth_ace:water_signal:waterfall_exists_changed', exists)
	end
end

function WaterSignalComponent:get_waterfall_volume()
	return self._sv._waterfall_volume
end

function WaterSignalComponent:set_waterfall_volume(waterfall_entities)
	local volume = 0
	for i, w in pairs(waterfall_entities) do
		volume = volume + w:get_volume()
	end

	local prev_volume = self._waterfall_volume
	self._sv._waterfall_volume = volume

	if volume ~= prev_volume then
		radiant.events.trigger(self._entity, 'stonehearth_ace:water_signal:waterfall_volume_changed', volume)
	end
end

function WaterSignalComponent:_on_tick()
	if not self._sv._signal_region then
		return
	end
	
	self._current_tick = self._current_tick + 1
	if self._current_tick % self._sv.ticks_per_check ~= 0 then
		return
	end
	
	-- do we really need to update the water regions we're checking every single tick?
	-- not sure how expensive this is
	local location = radiant.entities.get_world_grid_location(self._entity)
	if not location then
		self:_reset()
		return
	end
	
	local region = self._sv._signal_region and self._sv._signal_region:translated(location)
	local water_components, waterfall_components = self:_get_water(region)

	self:set_water_exists(water_components)
	self:set_water_volume(water_components)
	self:set_waterfall_exists(waterfall_components)
	self:set_waterfall_volume(waterfall_components)
	
	self.__saved_variables:mark_changed()
end

function WaterSignalComponent:_get_water(region)
	if not region then
		return {}, {}
	end

	local entities = radiant.terrain.get_entities_in_region(region)
	local water_components = {}
	local waterfall_components = {}
	for _, e in pairs(entities) do
		local water_component = e:get_component('stonehearth:water')
		if water_component then
			table.insert(water_components, water_component)
		end

		local waterfall_component = e:get_component('stonehearth:waterfall')
		if waterfall_component then
			table.insert(waterfall_components, waterfall_component)
		end
	end

	return water_components, waterfall_components
end

return WaterSignalComponent