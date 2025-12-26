local assemnet = Network:GetSubnet(3)
local assemblers = assemnet:GetPartsFromPort(4,"Assembler")
local partdata: typeof(require("@wos/partdata")) = (require :: any)("partdata")
local compnet = Network:GetSubnet(2)
local storageserver = compnet:GetPartFromPort(10,"Microcontroller")
local buffernet = assemnet:GetSubnet(5)

local bufferbins = buffernet:GetParts("Bin")
local repr: typeof(require("@wos/repr")) = (require :: any)("repr")

--local tocraft = { Port = 3, Hatch = 4, Sorter = 2, Silicon = 60 } 
local tocraft = {Port = 20}

local resourcegroups = {}

local bins = {
    BinQuantity = 0,
    Totalspace = 0,
    Currentresources = {},
    Usedbins = 0,
    Sorterin = buffernet:GetPartFromPort(1,"Sorter"),
    Sorterout =  buffernet:GetPartFromPort(2,"Sorter")
}

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
craftingoperations.Quantity = 0
craftingoperations.Craftingmats = {}
craftingoperations.Rawmats = {}
craftingoperations.Rawmats.enoughbins = true
craftingoperations.Steps = {}


function getnumbins(quan,recipe)
    local numbin = math.ceil(quan/1000)
    
    for i,v in recipe do 
        numbin += math.ceil(v/1000)
    end 
    return numbin
end 

function isresourcestored(resource,amount)
    if resourcegroups[resource] then 
        if resourcegroups[resource].Totalresource >= amount then 
            return true
        else 
            return false
        end 
    else 
        return false
    end 
end

function setupbufferbins()
    for i,v in bufferbins do 
        local itemamount = v:GetAmount()
        local resource = v:GetResource()
        bins.BinQuantity += 1
        bins.Totalspace += (v.Size.X * v.Size.Y * v.Size.Z)
        if itemamount ~= 0 then 
            bins.Usedbins += 1
            if bins.Currentresources[resource] then
                bins.Currentresources[resource] += itemamount
            else 
                bins.Currentresources[resource] = itemamount
            end
        end 
    end 
end 

-- PLEASE OF PLEASE FUTURE ME FIX THIS FUNCTION cuz rn its wayy too ugly for me....
-- recursive function to get all raw and craftable ingredients for an item
function GetRecipe(startitem,quantity,raw,craftable,step)
    local recipe = assemblers[1]:GetRecipe(startitem)

     for i,v in recipe do 
        recipe[i] = (v * quantity)
    end 

    local steptable = {
        Item = startitem,
        Amount = quantity,
        Recipe = recipe,
        Bins = getnumbins(quantity,recipe)
    }

    if steptable.Bins > bins.BinQuantity then 
        raw.enoughbins = false
    end 

    if not step then 
        step = {}
    end

    if isresourcestored(startitem,quantity) then
        if raw[startitem] then 
            raw[startitem] += quantity
        else
            raw[startitem] = quantity
        end
        return raw, craftable, step
    else 
        table.insert(step,steptable)
    end 

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

function Moveresourcetobuffer(resource,quantity)
    storageserver:Send("Withdraw", resource, quantity)

    local recievetask = task.spawn(function()
        local recieved = Microcontroller:Receive()
        if recieved then
            bins.Sorterin.Resource = resource
            bins.Sorterin:Sort(quantity)
            task.wait(.2)
            storageserver:Send()
        end
    end)

    task.wait(0.5)
    task.cancel(recievetask)
end


function allocatebins(recipe)
    local function setbins(resource,quantity)
        local binsconverted = 0

        for i,v in bufferbins do 
            if binsconverted < quantity then
                if v:GetAmount() == 0 then 
                    binsconverted += 1
                    v.Resource = resource
                end 
            else 
                return
            end 
        end 
    end

    for item,amount in recipe do 
        local binsneeded = math.ceil(amount/1000)
        local itemneeded
        if bins.Currentresources[item] then 
            if bins.Currentresources[item] < amount then 
                itemneeded = amount - bins.Currentresources[item]
                local currentbins = math.ceil(bins.Currentresources[item]/1000)
                local newbinsneeded = binsneeded - currentbins
                setbins(item,newbinsneeded)
                Moveresourcetobuffer(item,itemneeded)
            end
        else 
            setbins(item,binsneeded)
            Moveresourcetobuffer(item,amount)
        end 
    end 

end 

function startscraft(step)
    if bins.Usedbins > 1 then
        print("Bins must be empty to start a craft")
        return
    end

    if craftingoperations.Rawmats.enoughbins == true then
        for i = #step, 1, -1 do 
            local resources = step[i].Recipe
            resources[step[i].Item] = step[i].Amount
            allocatebins(resources)

        end 
    else 
        print("Not enough buffer bins for craft")
        return
    end 

end 


GetResource()
setupbufferbins()


-- main running logic
for item,quantity in tocraft do 
   
    craftingoperations.Rawmats, craftingoperations.Craftingmats, craftingoperations.Steps = GetRecipe(item,quantity,craftingoperations.Rawmats,craftingoperations.Craftingmats)
    -- assing every resource in recipe to be a Raw mat or Crafting material
end 
startscraft(craftingoperations.Steps)
print(repr(craftingoperations.Steps))

for i,v in craftingoperations.Rawmats do 
    print(i,v)
end