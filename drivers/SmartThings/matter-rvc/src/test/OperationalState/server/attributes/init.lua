-- Copyright 2022 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- DO NOT EDIT: this code is automatically generated by ZCL Advanced Platform generator.

local attr_mt = {}
attr_mt.__attr_cache = {}
attr_mt.__index = function(self, key)
  if attr_mt.__attr_cache[key] == nil then
    local req_loc = string.format("OperationalState.server.attributes.%s", key)
    local raw_def = require(req_loc)
    local cluster = rawget(self, "_cluster")
    raw_def:set_parent_cluster(cluster)
    attr_mt.__attr_cache[key] = raw_def
  end
  return attr_mt.__attr_cache[key]
end

--- @class OperationalStateServerAttributes
---
--- @field public PhaseList OperationalState.server.attributes.PhaseList
--- @field public CurrentPhase OperationalState.server.attributes.CurrentPhase
--- @field public CountdownTime OperationalState.server.attributes.CountdownTime
--- @field public OperationalStateList OperationalState.server.attributes.OperationalStateList
--- @field public OperationalState OperationalState.server.attributes.OperationalState
--- @field public OperationalError OperationalState.server.attributes.OperationalError
--- @field public AcceptedCommandList OperationalState.server.attributes.AcceptedCommandList
--- @field public EventList OperationalState.server.attributes.EventList
--- @field public AttributeList OperationalState.server.attributes.AttributeList
local OperationalStateServerAttributes = {}

function OperationalStateServerAttributes:set_parent_cluster(cluster)
  self._cluster = cluster
  return self
end

setmetatable(OperationalStateServerAttributes, attr_mt)

return OperationalStateServerAttributes

