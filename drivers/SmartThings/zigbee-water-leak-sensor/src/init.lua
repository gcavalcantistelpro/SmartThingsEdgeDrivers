-- Copyright 2022 SmartThings
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

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local temperature_defaults = require "st.zigbee.defaults.temperatureMeasurement_defaults"
local constants = require "st.zigbee.constants"
local configurationMap = require "configurations"
local TemperatureMeasurement = (require "st.zigbee.zcl.clusters").TemperatureMeasurement

--- Default handler for Temperature measured value on the Temperature measurement cluster
---
--- This converts the Int16 value of the temp measured attribute to TemperatureMeasurement.temperature this will convert
--- to fahrenheit or celsius based on the device data
---
--- @param driver Driver The current driver running containing necessary context for execution
--- @param device ZigbeeDevice The device this message was received from containing identifying information
--- @param value Int16 the value of the measured temperature
--- @param zb_rx containing the full message this report came in

local function temperature_measurement_attr_handler(driver, device, value, zb_rx)
  local raw_temp = value.value
  local celc_temp = raw_temp / 100.0
  local temp_scale = "C"
  -- All events from drivers should be in celsius and without offset manipulation
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.temperatureMeasurement.temperature({value = celc_temp, unit = temp_scale }))
end

--- Default handler for Temperature min and max measured value on the Temperature measurement cluster
---
--- This starts initially by performing the same conversion in the temperature_measurement_attr_handler function.
--- It then sets the field of whichever measured value is defined by the @param and checks if the fields
--- correctly compare
---
--- @param minOrMax string the string that determines which attribute to set
--- @param driver Driver The current driver running containing necessary context for execution
--- @param device ZigbeeDevice The device this message was received from containing identifying information
--- @param value Int16 the value of the measured temperature
--- @param zb_rx containing the full message this report came in

local temperature_measurement_min_max_attr_handler = function(minOrMax)
  return function(driver, device, value, zb_rx)
    local raw_temp = value.value
    local celc_temp = raw_temp / 100.0
    local temp_scale = "C" 

    device:set_field(string.format("%s", minOrMax), celc_temp)

    local min = device:get_field(temperature_defaults.MIN_TEMP)
    local max = device:get_field(temperature_defaults.MAX_TEMP)

    if min ~= nil and max ~= nil then
      if min < max then
        device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.temperatureMeasurement.temperatureRange({ value = { minimum = min, maximum = max }, unit = temp_scale }))
        device:set_field(temperature_defaults.MIN_TEMP, nil)
        device:set_field(temperature_defaults.MAX_TEMP, nil)
      else
        device.log.warn_with({hub_logs = true}, string.format("Device reported a min temperature %d that is not lower than the reported max temperature %d", min, max))
      end
    end
  end
end

local function device_init(driver, device)
  local configuration = configurationMap.get_device_configuration(device)

  if configuration then
    for _, config in ipairs(configuration) do
      if config.use_battery_linear_voltage_handling then
        battery_defaults.build_linear_voltage_init(config.minV, config.maxV)(driver, device)
      elseif config.use_battery_voltage_table and config.battery_voltage_table then
        battery_defaults.enable_battery_voltage_table(device, config.battery_voltage_table)
      elseif (config.cluster) then
        device:add_configured_attribute(config)
        device:add_monitored_attribute(config)
      end
    end
  end
end

local zigbee_water_driver_template = {
  supported_capabilities = {
    capabilities.waterSensor,
    capabilities.temperatureAlarm,
    capabilities.temperatureMeasurement,
    capabilities.battery,
  },
  zigbee_handlers = {
    attr = {
      [TemperatureMeasurement.ID] = {
        [TemperatureMeasurement.attributes.MeasuredValue.ID] = temperature_measurement_attr_handler,
        [TemperatureMeasurement.attributes.MinMeasuredValue.ID] = temperature_measurement_min_max_attr_handler(temperature_defaults.MIN_TEMP),
        [TemperatureMeasurement.attributes.MaxMeasuredValue.ID] = temperature_measurement_min_max_attr_handler(temperature_defaults.MAX_TEMP),
      }
    }
  },
  lifecycle_handlers = {
    init = device_init
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
  sub_drivers = {
    require("aqara"),
    require("zigbee-water-freeze"),
    require("leaksmart"),
    require("frient"),
    require("thirdreality"),
    require("sengled"),
    require("sinope")
  },
}

defaults.register_for_default_handlers(zigbee_water_driver_template, zigbee_water_driver_template.supported_capabilities)
local zigbee_water_driver = ZigbeeDriver("zigbee-water", zigbee_water_driver_template)
zigbee_water_driver:run()
