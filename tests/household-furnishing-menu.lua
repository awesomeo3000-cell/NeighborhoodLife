package.path = arg[1] .. '/42/media/lua/client/?.lua;' .. package.path
local callback
Events = {OnFillWorldObjectContextMenu={Add=function(fn) callback=fn end}}
local requested
NLHouseholdClient = {request=function(index, command, args)
    requested = {index=index, command=command, args=args}
end}
local player = {dead=false}
function player:isDead() return self.dead end
function player:getPlayerNum() return 0 end
function player:Say(text) self.said=text end
function getSpecificPlayer() return player end
local options, subOptions = {}, {}
local context = {
    addOption=function(_, label, target, fn) options[#options+1]={label=label,target=target,fn=fn}; return options[#options] end,
    addSubMenu=function() end,
}
ISContextMenu = {getNew=function()
    return {addOption=function(_, label, target, fn, value)
        subOptions[#subOptions+1]={label=label,target=target,fn=fn,value=value}
    end}
end}
dofile(arg[1] .. '/42/media/lua/client/NL/HouseholdFurnishingMenu.lua')
local object = {getModData=function() return {NeighborhoodHouseholdFurnishing='storage'} end}
callback(0, context, {object})
assert(#options == 1 and options[1].label == 'Household storage', 'storage menu identifies the native furnishing')
assert(#subOptions == 2, 'storage menu exposes store and retrieve actions')
subOptions[1].fn(subOptions[1].target, subOptions[1].value)
assert(requested and requested.command == 'furnishing' and requested.args.action == 'store',
    'store action routes through production household request')
subOptions[2].fn(subOptions[2].target, subOptions[2].value)
assert(requested.args.action == 'retrieve', 'retrieve action routes through production household request')
print('PASS: household furnishing world menu identity and action routing')
