local assemnet = Network:GetSubnet(3)
local assembler = Network:GetPart("Assembler")
local partdata: typeof(require("@wos/partdata")) = (require :: any)("partdata")
local compnet = Network:GetSubnet(2)
local storageserver = compnet:GetPartFromPort(10,"Microcontroller")
local craftbufferbins = assemnet:GetSubnet(5):GetPartFromPort(1,"Bin")
local repr: typeof(require("@wos/repr")) = (require :: any)("repr")

--local tocraft = { Port = 3, Hatch = 4, Sorter = 2, Silicon = 60 } 
local tocraft = { Warhead = 3}
local resourcegroups = {}


--[[
Totalmats = {
Copper 12k,
Plutonium 40,
}

Crafts = {
{Port = 4, Wire = 3},
{Rubber = 4, Copper = 6}

}

]]

--[[
craftingops = {
    Port = { 
        Quantity = 3,
        Rawmaterials = {Sillicon = 10,
            Copper = 3 
        },
        Craftingmaterials = {
            Rubber = 3,
            EthernetCable = 3
        }

    }

}
]]
print("Running_______________")

local craftingoperations = {}

function isresourcestored(resource,amount)
    if resourcegroups[resource] then 
        if resourcegroups[resource] then 
            return true
        else 
            return false
        end 
    else 
        return false
    end 
end


-- recursive function to get all raw and craftable ingredients for an item
function GetRecipe(startitem,quantity,raw,craftable,step)
    local recipe = assembler:GetRecipe(startitem)

     for i,v in recipe do 
        recipe[i] = (v * quantity)
        print(i,v,quantity,(v * quantity),startitem )
    end 

    local steptable = {
        Item = startitem,
        Amount = quantity,
        Recipe = recipe
    }

    if not step then 
        step = {}
    end

    table.insert(step,steptable)

    for item,amount in recipe do 
        if partdata.Parts[item].Craftable then
            if craftable[item] then 
                craftable[item] += amount
            else 
                craftable[item] = amount
            end
            raw, craftable, step = GetRecipe(item, amount, raw, craftable,step)
        else 
            if raw[item] then 
                raw[item] += amount
            else
                raw[item] = amount
            end
        end 
    end 
    return raw, craftable, step
end 


local function GetResource()
	storageserver:Send("getall_resources")
	local listen = task.spawn(function()
		_, resourcegroups = Microcontroller:Receive()
	end)

	task.wait(0.5)
	task.cancel(listen)
end


-- main running logic
for item,quantity in tocraft do 
    craftingoperations.Quantity = quantity
    craftingoperations.Craftingmats = {}
    craftingoperations.Rawmats = {}
    craftingoperations.Steps = {}
    quantity = 1
    craftingoperations.Rawmats, craftingoperations.Craftingmats, craftingoperations.Steps = GetRecipe(item,quantity,craftingoperations.Rawmats,craftingoperations.Craftingmats)

    -- assing every resource in recipe to be a Raw mat or Crafting material
end 

print(repr(craftingoperations.Steps))

for i,v in craftingoperations.Rawmats do 
    print(i,v)
end 