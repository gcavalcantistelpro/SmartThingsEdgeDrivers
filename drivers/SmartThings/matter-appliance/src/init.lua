-- Copyright 2023 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local MatterDriver = require "st.matter.driver"
local capabilities = require "st.capabilities"
local clusters = require "st.matter.clusters"
local im = require "st.matter.interaction_model"

local log = require "log"
local utils = require "st.utils"

local setpoint_limit_device_field = {
  MIN_TEMP = "MIN_TEMP",
  MAX_TEMP = "MAX_TEMP",
}

local applianceOperatingStateId = "spacewonder52282.applianceOperatingState"
local applianceOperatingState = capabilities[applianceOperatingStateId]
local supportedTemperatureLevels = {}

local function device_init(driver, device)
  device:subscribe()
end

local function do_configure(driver, device)
  local tn_eps = device:get_endpoints(clusters.TemperatureControl.ID, {feature_bitmap = clusters.TemperatureControl.types.Feature.TEMPERATURE_NUMBER})

  --Query setpoint limits if needed
  local setpoint_limit_read = im.InteractionRequest(im.InteractionRequest.RequestType.READ, {})
  if #tn_eps ~= 0 then
    if device:get_field(setpoint_limit_device_field.MIN_TEMP) == nil then
      setpoint_limit_read:merge(clusters.TemperatureControl.attributes.MinTemperature:read())
    end
    if device:get_field(setpoint_limit_device_field.MAX_TEMP) == nil then
      setpoint_limit_read:merge(clusters.TemperatureControl.attributes.MaxTemperature:read())
    end
  end
  if #setpoint_limit_read.info_blocks ~= 0 then
    device:send(setpoint_limit_read)
  end
end

-- Matter Handlers --
local function on_off_attr_handler(driver, device, ib, response)
  if ib.data.value then
    device:emit_event_for_endpoint(ib.endpoint_id, capabilities.switch.switch.on())
  else
    device:emit_event_for_endpoint(ib.endpoint_id, capabilities.switch.switch.off())
  end
end

local function temperature_setpoint_attr_handler(driver, device, ib, response)
  log.info_with({ hub_logs = true },
    string.format("temperature_setpoint_attr_handler: %d", ib.data.value))

  local min = device:get_field(setpoint_limit_device_field.MIN_TEMP) or 0
  local max = device:get_field(setpoint_limit_device_field.MAX_TEMP) or 100
  local unit = "C"
  local range = {
    minimum = {
      value = min,
      unit = unit
    },
    maximum = {
      value = max,
      unit = unit
    }
  }
  device:emit_event_for_endpoint(ib.endpoint_id, capabilities.temperatureSetpoint.temperatureSetpointRange({value = range, unit = unit}))

  local temp = ib.data.value / 100.0
  device:emit_event_for_endpoint(ib.endpoint_id, capabilities.temperatureSetpoint.temperatureSetpoint({value = temp, unit = unit}))
end

local function setpoint_limit_handler(limit_field)
  return function(driver, device, ib, response)
    local val = ib.data.value / 100.0
    log.info("Setting " .. limit_field .. " to " .. string.format("%s", val))
    device:set_field(limit_field, val, { persist = true })
  end
end

-- TODO Create temperatureLevel
-- local function selected_temperature_level_attr_handler(driver, device, ib, response)
--   log.info_with({ hub_logs = true },
--     string.format("selected_temperature_level_attr_handler: %s", ib.data.value))

--   local temperatureLevel = ib.data.value
--   for i, tempLevel in ipairs(supportedTemperatureLevels) do
--     if i - 1 == temperatureLevel then
--       device:emit_event_for_endpoint(ib.endpoint_id, capabilities.temperatureLevel.temperatureLevel(tempLevel))
--       break
--     end
--   end
-- end

-- TODO Create temperatureLevel
-- local function supported_temperature_levels_attr_handler(driver, device, ib, response)
--   log.info_with({ hub_logs = true },
--     string.format("supported_temperature_levels_attr_handler: %s", ib.data.value))

--   supportedTemperatureLevels = {}
--   for _, tempLevel in ipairs(ib.data.elements) do
--     table.insert(supportedTemperatureLevels, tempLevel.value)
--   end
--   device:emit_event_for_endpoint(ib.endpoint_id, capabilities.temperatureLevel.supportedTemperatureLevels(supportedTemperatureLevels))
-- end

-- Capability Handlers --
local function handle_switch_on(driver, device, cmd)
  local endpoint_id = device:component_to_endpoint(cmd.component)
  local req = clusters.OnOff.server.commands.On(device, endpoint_id)
  device:send(req)
end

local function handle_switch_off(driver, device, cmd)
  local endpoint_id = device:component_to_endpoint(cmd.component)
  local req = clusters.OnOff.server.commands.Off(device, endpoint_id)
  device:send(req)
end

local function handle_temperature_setpoint(driver, device, cmd)
  log.info_with({ hub_logs = true },
    string.format("handle_temperature_setpoint: %s", cmd.args.setpoint))

  local value = cmd.args.setpoint
  local cached_temp_val, temp_setpoint = device:get_latest_state(
    cmd.component, capabilities.temperatureSetpoint.ID,
    capabilities.temperatureSetpoint.temperatureSetpoint.NAME,
    0, { value = 0, unit = "C" }
  )
  local min = device:get_field(setpoint_limit_device_field.MIN_TEMP) or 0
  local max = device:get_field(setpoint_limit_device_field.MAX_TEMP) or 100
  if value < min or value > max then
    log.warn(string.format(
      "Invalid setpoint (%s) outside the min (%s) and the max (%s)",
      value, min, max
    ))
    device:emit_event(capabilities.temperatureSetpoint.temperatureSetpoint(temp_setpoint))
    return
  end

  local ENDPOINT = 1
  device:send(clusters.TemperatureControl.commands.SetTemperature(device, ENDPOINT, utils.round(value * 100.0), nil))
end

-- TODO Create temperatureLevel
-- local function handle_temperature_level(driver, device, cmd)
--   log.info_with({ hub_logs = true },
--     string.format("handle_temperature_level: %s", cmd.args.temperatureLevel))

--   local ENDPOINT = 1
--   for i, tempLevel in ipairs(supportedTemperatureLevels) do
--     if cmd.args.temperatureLevel == tempLevel then
--       device:send(clusters.TemperatureControl.commands.SetTemperature(device, ENDPOINT, nil, i - 1))
--       return
--     end
--   end
-- end

local matter_driver_template = {
  lifecycle_handlers = {
    init = device_init,
    doConfigure = do_configure,
  },
  matter_handlers = {
    attr = {
      [clusters.OnOff.ID] = {
        [clusters.OnOff.attributes.OnOff.ID] = on_off_attr_handler,
      },
      [clusters.TemperatureControl.ID] = {
        [clusters.TemperatureControl.attributes.TemperatureSetpoint.ID] = temperature_setpoint_attr_handler,
        [clusters.TemperatureControl.attributes.MinTemperature.ID] = setpoint_limit_handler(setpoint_limit_device_field.MIN_TEMP),
        [clusters.TemperatureControl.attributes.MaxTemperature.ID] = setpoint_limit_handler(setpoint_limit_device_field.MAX_TEMP),
      },
    }
  },
  subscribed_attributes = {
    [capabilities.switch.ID] = {
      clusters.OnOff.attributes.OnOff
    },
    [capabilities.temperatureSetpoint.ID] = {
      clusters.TemperatureControl.attributes.TemperatureSetpoint
    },
    [applianceOperatingStateId] = {
      clusters.OperationalState.attributes.OperationalState,
      clusters.OperationalState.attributes.OperationalError,
    },
    [capabilities.mode.ID] = {
      clusters.TemperatureControl.attributes.SelectedTemperatureLevel,
      clusters.TemperatureControl.attributes.SupportedTemperatureLevels,
      clusters.DishwasherMode.attributes.SupportedModes,
      clusters.DishwasherMode.attributes.CurrentMode,
      clusters.LaundryWasherMode.attributes.SupportedModes,
      clusters.LaundryWasherMode.attributes.CurrentMode,
      clusters.LaundryWasherControls.attributes.SpinSpeeds,
      clusters.LaundryWasherControls.attributes.SpinSpeedCurrent,
      clusters.RefrigeratorAndTemperatureControlledCabinetMode.attributes.SupportedModes,
      clusters.RefrigeratorAndTemperatureControlledCabinetMode.attributes.CurrentMode,
    },
    [capabilities.laundryWasherRinseMode.ID] = {
      clusters.LaundryWasherControls.attributes.NumberOfRinses,
      clusters.LaundryWasherControls.attributes.SupportedRinses,
    },
    [capabilities.contactSensor.ID] = {
      clusters.DishwasherAlarm.attributes.State,
      clusters.RefrigeratorAlarm.attributes.State,
    },
    [capabilities.temperatureMeasurement.ID] = {
      clusters.TemperatureMeasurement.attributes.MeasuredValue
    },
    [capabilities.waterFlowAlarm.ID] = {
      clusters.DishwasherAlarm.attributes.State
    },
    [capabilities.temperatureAlarm.ID] = {
      clusters.DishwasherAlarm.attributes.State
    },
  },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = handle_switch_on,
      [capabilities.switch.commands.off.NAME] = handle_switch_off,
    },
    [capabilities.temperatureSetpoint.ID] = {
      [capabilities.temperatureSetpoint.commands.setTemperatureSetpoint.NAME] = handle_temperature_setpoint,
    },
  },
  sub_drivers = {
    require("matter-dishwasher"),
    require("matter-laundry-washer"),
    require("matter-refrigerator"),
  }
}

local matter_driver = MatterDriver("matter-appliance", matter_driver_template)
log.info_with({hub_logs=true}, string.format("Starting %s driver, with dispatcher: %s", matter_driver.NAME, matter_driver.matter_dispatcher))
matter_driver:run()