local rng = _radiant.math.get_default_rng()

local CropComponent = require 'stonehearth.components.crop.crop_component'
local AceCropComponent = class()

AceCropComponent._old_activate = CropComponent.activate
function AceCropComponent:activate()
   self:_old_activate()
   
   if not self._sv.megacrop_chance then
      local json = radiant.entities.get_json(self)
      self._sv.megacrop_chance = (json and json.megacrop_chance) or stonehearth.constants.farming.BASE_MEGACROP_CHANCE
   end
end

function AceCropComponent:set_consider_megacrop()
   if not self._sv.consider_megacrop then
      self._sv.consider_megacrop = true
      self.__saved_variables:mark_changed()
   end
end

function AceCropComponent:apply_megacrop_chance_multiplier(multiplier)
   if multiplier ~= 1 and self._sv.megacrop_chance ~= 0 then
      self._sv.megacrop_chance = self._sv.megacrop_chance * multiplier
      self.__saved_variables:mark_changed()
   end
end

--- As we grow, change the resources we yield and, if appropriate, command harvest
AceCropComponent._old__on_grow_period = CropComponent._on_grow_period
function AceCropComponent:_on_grow_period(e)
   local was_harvestable = self._sv.harvestable
   self:_old__on_grow_period(e)
   
   -- if we just became harvestable, consider mega crop
   if was_harvestable ~= self._sv.harvestable and self._sv.consider_megacrop then
      if rng:get_real(0, 1) < self._sv.megacrop_chance then
         self:_set_megacrop()
      end
   end
end

function AceCropComponent:is_megacrop()
   return self._sv.is_megacrop
end

function AceCropComponent:_set_megacrop()
   self._sv.is_megacrop = true
   local render_info = self._entity:get_component('render_info')
   render_info:set_scale(render_info:get_scale() * (2 + rng:get_real(-0.05, 0.05)))
   self.__saved_variables:mark_changed()
end

return AceCropComponent