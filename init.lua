-- afk_protective_kick/init.lua
-- Kick AFK players facing dangers
--[[
    afk_protective_kick: Kick AFK players facing dangers
    Copyright (C) 2024  1F616EMO

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
]]

afk_protective_kick = {}
local _ak = afk_protective_kick
local _ai = afk_indicator
local kick = minetest.disconnect_player or minetest.kick_player
local logger = logging.logger("afk_protective_kick")
local S = minetest.get_translator("afk_protective_kick")

local _ = S("AFK Protective Kick") -- ContentDB translation key

local inactive_time = tonumber(minetest.settings:get("afk_protective_kick.inactive_time")) or 90

_ak.registered_indicators = {}
function _ak.register_indicator(func)
    _ak.registered_indicators[#_ak.registered_indicators + 1] = func
end

function _ak.run_indicators(player)
    for _, func in ipairs(_ak.registered_indicators) do
        local msg = func(player)
        if msg then
            return true, msg
        end
    end
    return false
end

local function loop()
    for name, time in pairs(_ai.get_all_longer_than(inactive_time)) do
        local status, msg = _ak.run_indicators(minetest.get_player_by_name(name))
        if status then
            local info = minetest.get_player_information(name)
            local lang = info.lang_code
            if lang == "" then lang = "en" end

            local kick_msg = S("AFK Protective Kick: @1", msg)
            logger:action("Kicked " .. name .. " by the following reason: " ..
                minetest.get_translated_string("en", kick_msg))
            kick(name, minetest.get_translated_string(lang, kick_msg))
        end
    end
    minetest.after(1, loop)
end
minetest.after(1, loop)

if minetest.settings:get_bool("enable_damage", false) then
    -- node checks
    local function check_node(player, pos)
        local node = minetest.get_node(pos)
        local def = minetest.registered_nodes[node.name]
        if not def then return end

        -- Check for constant damage
        if def.damage_per_second and def.damage_per_second > 0 then
            return S("You stayed inside a damage-dealing block: @1", def.description)
        end

        -- Check for drowning damage
        if def.drowning and def.drowning > 0 then
            local breath = player:get_breath()
            if breath <= 0 then
                return S("You suffocated in this block: @1", def.description)
            end
        end
    end
    _ak.register_indicator(function(player)
        local pos = vector.round(player:get_pos())
        for _, check_pos in ipairs({
            pos,
            vector.new(pos.x, pos.y + 1, pos.z)
        }) do
            local armor_groups = player:get_armor_groups()
            if armor_groups.immortal then return end

            local msg = check_node(player, check_pos)
            if msg then return msg end
        end
    end)

    -- Hunger detection
    if minetest.get_modpath("hbhunger") then
        _ak.register_indicator(function(player)
            local name = player:get_player_name()
            local hunger = tonumber(hbhunger.hunger[name]) or 2
            if hunger <= 1 then
                local prop = player:get_properties()
                local hp = player:get_hp()
                local hp_max = prop.hp_max or minetest.PLAYER_MAX_HP_DEFAULT

                if (hp / hp_max) < 0.5 then
                    return S("You starved.")
                end
            end
        end)
    end
end


