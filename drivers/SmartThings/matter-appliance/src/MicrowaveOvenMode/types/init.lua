local types_mt = {}
types_mt.__types_cache = {}
types_mt.__index = function(self, key)
  if types_mt.__types_cache[key] == nil then
    local req_loc = string.format("MicrowaveOvenMode.types.%s", key)
    local cluster_type = require(req_loc)
    types_mt.__types_cache[key] = cluster_type
  end
  return types_mt.__types_cache[key]
end

local MicrowaveOvenModeTypes = {}

setmetatable(MicrowaveOvenModeTypes, types_mt)

return MicrowaveOvenModeTypes
