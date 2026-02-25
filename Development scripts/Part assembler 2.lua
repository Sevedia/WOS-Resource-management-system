local assemnet = Network:GetSubnet(3)
local assemblers = assemnet:GetPartsFromPort(4, "Assembler")
local partdata: typeof(require("@wos/partdata")) = (require :: any)("partdata")
local compnet = Network:GetSubnet(2)
local storageserver = compnet:GetPartFromPort(10, "Microcontroller")
local buffernet = assemnet:GetSubnet(5)
local bufferbins = buffernet:GetParts("Bin")
local repr: typeof(require("@wos/repr")) = (require :: any)("repr")

--local tocraft = { Port = 3, Hatch = 4, Sorter = 2, Silicon = 60 }
local tocraft = { HyperDrive = 2 }

local resourcegroups = {}

local bins = {
	BinQuantity = 0,
	Totalspace = 0,
	Currentresources = {},
	Usedbins = 0,
	Sorterin = buffernet:GetPartFromPort(1, "Sorter"),
	Sorterout = buffernet:GetPartFromPort(2, "Sorter"),
    Hatch = buffernet:GetPart("Hatch")
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

local function sendmessage(command, arguments)
	local functions = {

		GetResources = function()
			storageserver:Send("getall_resources")
			_, resourcegroups = Microcontroller:Receive()
		end,

		DepositItem = function(item, quantity)
			bins.Hatch.SwitchValue = true

			storageserver:Send("Moveitem", "Deposit", item, quantity)
			local val = { Microcontroller:Receive() }

			if val[2] == true then
				print("items moved: ", val[3])
			else
				print("item failed to move, error: ", val[3])
			end
			bins.Hatch.SwitchValue = false
		end,

		WithdrawItem = function(item, quantity)
			bins.Hatch.SwitchValue = true

			storageserver:Send("Moveitem", "Withdraw", item, quantity)
			local val = { Microcontroller:Receive() }

			if val[2] == true then
				print("items moved: ", val[3])
			else
				print("item failed to move, error: ", val[3])
			end
			bins.Hatch.SwitchValue = false
		end

	}

	if functions[command] then
		local thread
		if arguments then
			thread = task.spawn(functions[command], table.unpack(arguments))
		else
			thread = task.spawn(functions[command])
		end

		task.delay(0.5, function(thread)
			if coroutine.status(thread) ~= "dead" then
				print("Client unable to perform action")
				task.cancel(thread)
			end
		end, thread)

		repeat
			task.wait()
		until coroutine.status(thread)

		bins.Hatch.SwitchValue = false
	end
end

function getnumbins(quan, recipe)
	local numbin = math.ceil(quan / 1000)

	for i, v in recipe do
		numbin += math.ceil(v / 1000)
	end
	return numbin
end

function isresourcestored(resource, amount)
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
	for i, v in bufferbins do
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

function countbins()
    bins.Currentresources = {}
    for i,v in bufferbins do 
        local itemamount = v:GetAmount()
		local resource = v:GetResource()
        if itemamount ~= 0 then
           
			if bins.Currentresources[resource] then
				bins.Currentresources[resource] += itemamount
			else
				bins.Currentresources[resource] = itemamount
			end
		end
    end 
end 

-- PLEASE Oh PLEASE FUTURE ME FIX THIS FUNCTION cuz rn its wayy too ugly for me.... maybe later, -Future me :3
-- recursive function to get all raw and craftable ingredients for an item
-- one day
function GetRecipe(startitem, quantity, raw, craftable, step)
	local recipe = assemblers[1]:GetRecipe(startitem)

	for i, v in recipe do
		recipe[i] = (v * quantity)
	end

	local steptable = {
		Item = startitem,
		Amount = quantity,
		Recipe = recipe,
		Bins = getnumbins(quantity, recipe),
	}

	if steptable.Bins > bins.BinQuantity then
		raw.enoughbins = false
	end

	if not step then
		step = {}
	end

	if isresourcestored(startitem, quantity) then
		if raw[startitem] then
			raw[startitem] += quantity
		else
			raw[startitem] = quantity
		end
		return raw, craftable, step
	else
		table.insert(step, steptable)
	end

	for item, amount in recipe do
		if partdata.Parts[item].Craftable then
			if craftable[item] then
				craftable[item] += amount
			else
				craftable[item] = amount
			end
			raw, craftable, step = GetRecipe(item, amount, raw, craftable, step)
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

--[[
function Moveresourcetobuffer(resource, quantity)
    
	storageserver:Send("Withdraw", resource, quantity)
    --print(Microcontroller:Receive())
	local recievetask = task.spawn(function()
        
		local recieved = Microcontroller:Receive()
        print("recieved: ", recieved)
		if recieved then
            bins.Hatch.SwitchValue = true
            task.wait(.2)
			bins.Sorterin.Resource = resource
            print("sorting quantity: ", quantity)
			bins.Sorterin:Sort(quantity)
			storageserver:Send()
            bins.Hatch.SwitchValue = false
        else 
            print("no response from storageserver")
		end
	end)

	task.wait(0.5)
	task.cancel(recievetask)
end]]

function allocatebins(recipe,outitem,quantity)
    countbins()
	local function 
		setbins(resource, quantity)
		local binsconverted = 0

		for i, v in bufferbins do
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
    
	for item, amount in recipe do
		local binsneeded = math.ceil(amount / 1000)
		local itemneeded
		if bins.Currentresources[item] then
            print("wrong code running")
			if bins.Currentresources[item] < amount then
				itemneeded = amount - bins.Currentresources[item]
				local currentbins = math.ceil(bins.Currentresources[item] / 1000)
				local newbinsneeded = binsneeded - currentbins
				setbins(item, newbinsneeded)
                print(item,amount)
				sendmessage("WithdrawItem",table.pack(item, itemneeded))
			end
		else
            print("setting bins: ",item)
			setbins(item, binsneeded)
            print(item,amount)
			sendmessage("WithdrawItem",table.pack(item, amount))
		end
        -- ensures the item did move and in the right quantity
        countbins()
        print(repr(bins.Currentresources))
        if bins.Currentresources[item] ~= amount then 
            return false
        end 

	end

    setbins(outitem, quantity)
    return true
end

function startscraft(step)

	for resource,quantity in craftingoperations.Rawmats do 
		if resource ~= "enoughbins" then 
			local val = isresourcestored(quantity)
			if val == false then 
				return false 
			end 
		else 
			continue
		end 
	end 

	if bins.Usedbins > 1 then
		print("Bins must be empty to start a craft")
		return
	end

	if craftingoperations.Rawmats.enoughbins == true then
		for i = #step, 1, -1 do
			
            if allocatebins(step[i].Recipe,step[i].Item,step[i].Amount) == false then 
                print("error items failed to move")
                break;
            end 
            print(step[i].Item, repr(step[i].Recipe))

            ---start crafting
            local craftingops = {}
            local function craft(steptable, assemb: Assembler)
                while true do 
                    print(steptable.Amount)
                    if steptable.Amount > 0 then

                        steptable.Amount -= 1
                        local success = assemb:Craft(steptable.Item)
                        if success == false then
                            print("Craft failed")
                            steptable.Amount += 1
                            return
                        else 
                            print("Item crafted")
                            
                        end
                    else
                        print("returning ")
                        return
                    end 
                end 
            end

            for k, v in pairs(assemblers) do
                table.insert(craftingops, task.spawn(craft, step[i], v))
            end

            repeat
                local craftdone = true
                for k, v in pairs(craftingops) do
                    if coroutine.status(v) ~= "dead" then
                        craftdone = false
                    end
                end
                task.wait(1)
            until craftdone == true

            if step[i].Amount ~= 0 then 
                print("something went wrong")
                break;
            end 
        end
		return
	else
		print("Not enough buffer bins for craft")
		return
	end
end

--GetResource()
sendmessage("GetResources")
setupbufferbins()

-- main running logic
for item, quantity in tocraft do
	craftingoperations.Rawmats, craftingoperations.Craftingmats, craftingoperations.Steps =
		GetRecipe(item, quantity, craftingoperations.Rawmats, craftingoperations.Craftingmats)
	-- assing every resource in recipe to be a Raw mat or Crafting material
end
print("crtafting: ", startscraft(craftingoperations.Steps))
print(repr(craftingoperations.Steps))

for i, v in craftingoperations.Rawmats do
	print(i, v)
end
