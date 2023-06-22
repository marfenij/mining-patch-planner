local floor, ceil = math.floor, math.ceil
local min, max = math.min, math.max

local super_compact = require("layouts.super_compact")
local logistics =require("layouts.logistics")
local mpp_util = require("mpp_util")
local builder = require("builder")
local mpp_revert = mpp_util.revert

---@class CompactLogisticsLayout: SuperCompactLayout
local layout = table.deepcopy(super_compact)

layout.name = "compact_logistics"
layout.translation = {"mpp.settings_layout_choice_compact_logistics"}

layout.restrictions.lamp_available = false
layout.restrictions.belt_available = false
layout.restrictions.logistics_available = true

---@param self SuperCompactLayout
---@param state SuperCompactState
---@return DeconstructSpecification
function layout:_prepare_deconstruct_specification_ex(state)
	local m = state.miner
	local bounds = state.miner_bounds

	state.deconstruct_specification = {
		x = bounds.min_x-1 - m.near,
		y = bounds.min_y-1 - m.near,
		width = bounds.max_x - bounds.min_x+1 + m.near * 2,
		height = bounds.max_y - bounds.min_y+1 + m.near * 2,
	}

	return state.deconstruct_specification
end

function layout:prepare_belt_layout(state)
	return "prepare_pole_layout"
end

---@param self SimpleLayout
---@param state SimpleState
function layout:placement_belts(state)
	local c = state.coords
	local m = state.miner
	local g = state.grid
	local DIR = state.direction_choice
	local surface = state.surface
	local attempt = state.best_attempt
	local create_entity = builder.create_entity_builder(state)

	local power_poles = {}
	state.builder_power_poles = power_poles

	---@type table<number, MinerPlacement[]>
	local miner_lanes = {{}}
	local miner_lane_number = 0 -- highest index of a lane, because using # won't do the job if a lane is missing

	for _, miner in ipairs(attempt.miners) do
		local index = miner.line * 2 + miner.stagger - 2
		miner_lane_number = max(miner_lane_number, index)
		if not miner_lanes[index] then miner_lanes[index] = {} end
		local line = miner_lanes[index]
		if miner.center.x > (line.last_x or 0) then
			line.last_x = miner.center.x
			line.last_miner = miner
		end
		line[#line+1] = miner
	end

	local shift_x, shift_y = state.best_attempt.sx, state.best_attempt.sy


	local function place_logistics(start_x, end_x, y)
		local belt_start = 1 + shift_x + start_x
		if start_x ~= 0 then
			local miner = g:get_tile(shift_x+m.size, y)
			if miner and miner.built_on == "miner" then
				create_entity{
					name=state.logistics_choice,
					thing="belt",
					grid_x=shift_x+m.size+1,
					grid_y=y,
				}
				power_poles[#power_poles+1] = {
					x = shift_x,
					y = y,
					built=true,
				}
			end
		end

		for x = belt_start, end_x, m.size * 2 do
			local miner1 = g:get_tile(x, y-1) --[[@as GridTile]]
			local miner2 = g:get_tile(x, y+1) --[[@as GridTile]]
			local miner3 = g:get_tile(x+3, y) --[[@as GridTile]]
			local built = miner1.built_on == "miner" or miner2.built_on == "miner"
			local capped = miner3.built_on == "miner"
			local pole_built = built or capped

			if capped then
				create_entity{
					name=state.logistics_choice,
					thing="belt",
					grid_x=x+m.size*2,
					grid_y=y,
				}
			end
			if built then
				create_entity{
					name=state.logistics_choice,
					thing="belt",
					grid_x=x+1,
					grid_y=y,
				}
			end

			power_poles[#power_poles+1] = {
				x = x + 2,
				y = y,
				built=pole_built,
			}
		end
	end

	local stagger_shift = 1
	for i = 1, miner_lane_number do
		local lane = miner_lanes[i]
		if lane and lane.last_x then
			local y = m.size + shift_y - 1 + (m.size + 2) * (i-1)
			local x_start = stagger_shift % 2 == 0 and 3 or 0
			place_logistics(x_start, lane.last_x, y)
		end
		stagger_shift = stagger_shift + 1
	end
	return "placement_pole"
end

layout.finish = logistics.finish

return layout
