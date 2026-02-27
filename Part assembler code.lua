local compnet = Network:GetSubnet(2)
local assemnet = Network:GetSubnet(3)
local storageserver = compnet:GetPartFromPort(10, "Microcontroller")
local assemblers = assemnet:GetPartsFromPort(4, "Assembler")
local buffernet = assemnet:GetSubnet(5)
local bufferbins = buffernet:GetParts("Bin")
local partdata: typeof(require("@wos/partdata")) = (require :: any)("partdata")
local hatch = buffernet:GetPart("Hatch")
local _repr: typeof(require("@wos/repr")) = (require :: any)("repr")

local resourcegroups = {}
local craftsteps = {
	Steps = {},
	Raw = {},
	Enoughbins = true,
}

local function sendmessage(command, arguments)
	-- this contains all functions that comunicate with external micro controllers
	local functions = {

		GetResources = function()
			storageserver:Send("getall_resources")
			_, resourcegroups = Microcontroller:Receive()
		end,

		DepositItem = function(item, quantity,success)
			storageserver:Send("Moveitem", "Deposit", item, quantity,hatch)
			local val = { Microcontroller:Receive() }

			if val[2] == true then
				print("items moved: ", val[3])
			else
				print("item failed to move, error: ", val[3])
			end
		end,

		WithdrawItem = function(item, quantity,success)
			storageserver:Send("Moveitem", "Withdraw", item, quantity,hatch)
			local val = { Microcontroller:Receive() }

			if val[2] == true then
				print("items moved: ", val[3])
			else
				print("item failed to move, error: ", val[3])
				print(item,quantity)
				success[1] = false
			end
		end
	}
	-- managing the thread creation and canceling if required
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
		until coroutine.status(thread) == "dead"

		hatch.SwitchValue = false
	end
end

local function buffercheck(quantity)
	local bineeded = 1
	for i, v in bufferbins do
		local maxamount = (v.Size.X * v.Size.Y * v.Size.Z)

		if v:GetResourceAmount() == 0 then
			if maxamount > quantity then
				quantity = 0
				return bineeded
			else
				quantity = quantity - maxamount
				bineeded += 1
				continue
			end
		else
			continue
		end
	end
	return bineeded
end

local function resourcestored(item, quantity)
	if resourcegroups[item] then
		if resourcegroups[item].Totalresource >= quantity then
			return 0
		else
			return (quantity - resourcegroups[item].Totalresource)
		end
	else
		return quantity
	end
end

local function allocatebins(recipe) 
	local success = {true}
	for item,quantity in recipe do 
		local amountleft = quantity
		for i,bin in bufferbins do 
			if bin:GetResourceAmount() == 0 then 
				local size = (bin.Size.X * bin.Size.Y * bin.Size.Z)
				amountleft -= size
				bin.Resource = item
				if amountleft <= 0 then 
					break;
				end 
			end 
		end 
		if resourcegroups[item] then
			if craftsteps.Raw[item] and craftsteps.Raw[item] >= 0 then 
				sendmessage("WithdrawItem", table.pack(item,quantity,success))
				craftsteps.Raw[item] -= quantity
			end
		end 
	end
	
	if success[1] == true then 
		return true
	else 
		return false
	end 
end 

-- this is for past me i finally fixed this function
local function GetRecipe(resource, quantity, crafttable)
	if partdata.Parts[resource].Recipe then
		local step = {
			Item = resource,
			Quantity = quantity,
			Recipe = assemblers[1]:GetRecipe(resource),
			Bins = 0,
		}
		step.Bins += buffercheck(quantity)

		for item, v in step.Recipe do
			step.Recipe[item] = v * quantity
			step.Bins += buffercheck(step.Recipe[item])
		end

		if step.Bins > #bufferbins then
			crafttable.Enoughbins = false
		end

		table.insert(crafttable.Steps, step)

		for item, v in step.Recipe do
			local needed
			if crafttable.Raw[item] then
				needed = resourcestored(item, crafttable.Raw[item] + v)
				crafttable.Raw[item] += (v - needed)
			else
				needed = resourcestored(item, v)
				if (v - needed) ~= 0 then
					crafttable.Raw[item] = (v - needed)
				end
			end

			if needed > 0 then
				crafttable = GetRecipe(item, needed, crafttable)
			else
				continue
			end
		end
	else
		if craftsteps.Raw[resource] then
			crafttable.Raw[resource] += quantity
		else
			crafttable.Raw[resource] = quantity
		end
	end
	return crafttable
end

local function craft(craftsteps)
	if craftsteps.Enoughbins == false then 
		print("there are not enough buffer bins to complete full craft")
		return false 
	end 

	for item,v in craftsteps.Raw do 
		if resourcestored(item,v) == 0 then 
			continue
		else 
			print("unable to craft not enough raw materials in storage")
			return false 
		end 
	end 

	for craftindex = #craftsteps.Steps, 1, -1 do 
		local success = allocatebins(craftsteps.Steps[craftindex].Recipe)

		local success2 = allocatebins({[craftsteps.Steps[craftindex].Item] = craftsteps.Steps[craftindex].Quantity})
		if success ~= true and success2 ~= true then 
			print("items have failed to move, canceling craft")
			break;
		end 

		local function assemcraft(step,assemb:Assembler) 
			while task.wait() do 
				if step.Quantity > 0 then 
					step.Quantity -= 1
					local crafted = assemb:Craft(step.Item)
					if crafted == true  then 
						continue
					else 
						step.Quantity += 1
						print("craft failed")
						return
					end
				else
					 return 
				end 
			end 
		end 
		local crafttasks = {}
		for i,v in assemblers do 
			table.insert(crafttasks,task.spawn(assemcraft,craftsteps.Steps[craftindex],v))
		end 
		
		repeat 
			local craftdone = true 
			for i,v in crafttasks do 
				if coroutine.status(v) ~= "dead" then
					craftdone = false
				end 
			end
			task.wait(1)
		until craftdone == true

		if craftsteps.Steps[craftindex].Quantity ~= 0 then 
			print("something went wrong")
			break;
		end 
	end 

	return true
end 

sendmessage("GetResources")
GetRecipe("Screen", 1, craftsteps)
print("crafting")
craft(craftsteps)

print(_repr(craftsteps))

--allocatebins({Copper = 3})

