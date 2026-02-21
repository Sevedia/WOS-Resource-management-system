--[[  example resource table 
    resources = {
    [Unused] = {
        Ports = {port1,port2}
        },
    ["Temp"] = {
    Ports = port
    
    }
    [Iron] = { 
        Ports = {port1,port2}
        Filters = {Filter1, Filter2}
        Hatches = {Hatch1,Hatch2}
        Bins = {Bin1,Bin2}
        Totalresource = 123
        Maxresource = 123
        ItemsperGroup = {2420,2900}
    }
    }
]]

--[[
TO-DO 
    * create a function that can self-test the storage system to verify that everything is connected the way it should be

    * modify the table code to properly use table.insert() 

    * would be nice to instead of filling up all groups randomly for a givin resource it could fill all groups one after another, but not a prority and also not sure if the added complexity is worth it

    * add in proper security so that on a station with muiltiple people certain items can be locked so only some people have access or some items can only be withdrawn by certain people 

]]

local storagenet = Network:GetSubnet(16)
local _repr: typeof(require("@wos/repr")) = (require :: any)("repr")
local partdata: typeof(require("@wos/partdata")) = (require :: any)("partdata")
local sorterin = storagenet:GetPartFromPort(5, "Sorter")
local sorterout = storagenet:GetPartFromPort(6, "Sorter")

local resourcegroups = {}
print("-------------------------------------------")

local printresourcegroups

--[[local specialgroups = {
    "Unused",
    "Temp",
}]]

-- while this function is currently a place holder eventually it will be very useful to ensure no items are moved around by unathorized partys
-- not exactly sure how this will work in the future but thats a future me problem, your welcome future me :3
function securitycheck(requestingmicro: Microcontroller)
	if requestingmicro:GetOwnerId() == 118486742 then
		return true
	else
		return false
	end
end

function togglehatch(hatch_array, newvalue, all: boolean)
	if all == true then
		for i, resource in resourcegroups do
			if resource.Hatches ~= nil then
				for k, hatch in resource.Hatches do
					hatch["SwitchValue"] = newvalue
				end
			end
		end
	else
		for i, hatch in hatch_array do
			hatch.SwitchValue = newvalue
		end
	end
end

local function verifyitemquanitiy(bins)
	local totalresource = 0
	for i, bin in bins do
		totalresource += bin:GetResourceAmount()
	end
	return totalresource
end

-- this tablle contains all functions that interact with outside microcontrollers
local requests = {
	--[[Deposit = function(requestingmicro, resources, itemtype, quantity)
		if resources[itemtype] and (resources[itemtype].Totalresource < resources[itemtype].Maxresource) then
			if securitycheck(requestingmicro) then
				togglehatch(resources[itemtype].Hatches, true)

				task.wait(.2)
				requestingmicro:Send(true) -- tells the micro it can send the items
				Microcontroller:Receive() -- recieves the signal that the items have moved
				resources[itemtype].Totalresource = resources[itemtype].Totalresource + quantity
				togglehatch(resources[itemtype].Hatches, false)
			else
				print("security check faield")
			end
		else
			print("request denied storage either full or no bins of that type exist, item type: ", itemtype)
			requestingmicro:Send(false)
		end
	end,

	Withdraw = function(requestingmicro, resources, itemtype, quantity)
		if securitycheck(requestingmicro) then
			if resources[itemtype] and (resources[itemtype].Totalresource - quantity >= 0) then
				togglehatch(resources[itemtype].Hatches, true)
				task.wait(.2)
				requestingmicro:Send(true)
				task.spawn(function()
					Microcontroller:Receive()
					resources[itemtype].Totalresource = resources[itemtype].Totalresource - quantity
					togglehatch(resources[itemtype].Hatches, false)
				end)
			else
				print(
					"request denied either not enough items of that type or no items of that type exist, item type: ",
					itemtype
				)
			end
		end
	end,]]
	Moveitem = function(requestingmicro, resources, action, itemtype, quantity)
		local function Withdraw(itemtype, quantity)
			local resource = resources[itemtype].Totalresource
			togglehatch(resources[itemtype].Hatches, true, false)
			sorterout.Resource = itemtype
			sorterout.Rate = 0
			sorterout.TriggerQuantity = 1
			task.wait()
			sorterout:Sort(quantity)
			task.wait()

			if resource - quantity ~= verifyitemquanitiy(resources[itemtype].Bins) then
				requestingmicro:Send(true, "Item has been moved")
			else
				requestingmicro:Send(false, "Item has failed to move")
			end
			
			togglehatch(resources[itemtype].Hatches, false, false)
			sorterout.Resource = nil
		end

		local function Deposit(itemtype, quantity)
			local resource = resources[itemtype].Totalresource
			togglehatch(resources[itemtype].Hatches, true, false)
			sorterin.Resource = itemtype
			sorterin.Rate = 0
			sorterin.TriggerQuantity = 1
			task.wait()
			sorterin:Sort(quantity)
			task.wait()

			if resource + quantity ~= verifyitemquanitiy(resources[itemtype].Bins) then
				requestingmicro:Send(true, "Item has been moved")
			else
				requestingmicro:Send(false, "Item has failed to move")
			end

			togglehatch(resources[itemtype].Hatches, false, false)
			sorterin.Resource = nil
		end

		if action == "Withdraw" then
			if securitycheck(requestingmicro) == true then
				if resources[itemtype] and (resources[itemtype].Totalresource - quantity >= 0) then
					Withdraw(itemtype, quantity)
				else
					requestingmicro:Send(
						false,
						"Either no resources of that type or requested more than whats in storage"
					)
				end
			else
				requestingmicro:Send(false, "Security check failed")
			end
		elseif action == "Deposit" then
			if securitycheck(requestingmicro) == true then
				if
					resources[itemtype]
					and (resources[itemtype].Totalresource + quantity <= resources[itemtype].Maxresource)
				then
					Deposit(itemtype, quantity)
				else
					requestingmicro:Send(false, "Either no resources of that type or storage is full")
					print(itemtype, quantity, resources[itemtype].Maxresource)
				end
			else
				requestingmicro:Send(false, "Security check failed")
			end
		else
			print("Storage Server: invalid command")
		end
	end,

	changegroup = function(requestingmicro, resources, old_resourcegroup, new_resourcegroup)
		if resources[old_resourcegroup] and #resources[old_resourcegroup].Ports > 0 then
			local port_group
			if securitycheck(requestingmicro) then
				for i, port in resources[old_resourcegroup].Ports do
					port_group = getportresourcegroup(port, storagenet)

					if port_group.Totalresource == 0 then
						if new_resourcegroup == "Unused" then
							port_group.Filters[1].Filter = ""
						else
							port_group.Filters[1].Filter = new_resourcegroup
						end

						resourcegroups = Getbingroups(storagenet)
						requestingmicro:Send(true)
						return
					end
				end
			else
				print("security check faield")
			end
		else
			print("no current group of that type exists or that group has no bins it can reasign")
			requestingmicro:Send(false)
		end
		-- printresourcegroups()
	end,

	Tempmove = function(requestingmicro, resources, resourcetomove, movedirection, port)
		if resources.Temp and securitycheck(requestingmicro) then
			if partdata.Parts[resourcetomove] and resources[resourcetomove] then
				local port_group = getportresourcegroup(port, storagenet)

				if string.lower(movedirection) == "fill" then -- fills the resource group from the temp bins
					resources.Temp.SorterOut.Resource = resourcetomove
					resources.Temp.SorterOut.Rate = 0
					resources.Temp.Hatch.SwitchValue = true
					port_group.Hatches[1].SwitchValue = true

					task.wait(0.2)
					resources.Temp.SorterOut:Sort(resources.Temp.Totalresource)

					resources.Temp.Hatch.SwitchValue = false
					port_group.Hatches[1].SwitchValue = false
					requestingmicro:Send(true, "Success")
				elseif string.lower(movedirection) == "empty" then -- empties the resource group into the temp bins
					for i, v in resources.Temp.Tempnet:GetParts("Bin") do
						v.Resource = resourcetomove
					end

					resources.Temp.SorterIn.Resource = resourcetomove
					resources.Temp.SorterIn.Rate = 0
					resources.Temp.Hatch.SwitchValue = true
					port_group.Hatches[1].SwitchValue = true

					task.wait(0.2)
					resources.Temp.SorterIn:Sort(port_group.Totalresource)

					resources.Temp.Hatch.SwitchValue = false
					port_group.Hatches[1].SwitchValue = false
					requestingmicro:Send(true, "Success")
				else
					requestingmicro:Send(false, "invalid direction")
					print("invalid direction")
				end
			else
				requestingmicro:Send(false, "resource doesnt exist")
				print("resource doesnt exist")
			end
		else
			requestingmicro:Send(false, "temp doesnt exist")
			print("temp doesnt exist")
		end
	end,

	printgroups = function()
		printresourcegroups()
	end,

	getall_resources = function(requestingmicro)
		requestingmicro:Send(resourcegroups)
	end,

	refresh_resources = function(requestingmicro)
		resourcegroups = Getbingroups(storagenet)
		requestingmicro:Send(resourcegroups)
	end,
}

function Getbingroups(net)
	local resources = {}
	resources.Unused = {}
	resources.Unused.Ports = {}
	resources.Unused.ItemsperGroup = {}

	for i, port in net:GetPorts(1) do
		local subnet = net:GetSubnet(port)
		local Filter_resource = subnet:GetPart("Filter").Filter

		if resources[Filter_resource] then
			resources[Filter_resource].Ports[#resources[Filter_resource].Ports + 1] = port
			resources[Filter_resource].Filters[#resources[Filter_resource].Filters + 1] = subnet:GetPart("Filter")
			resources[Filter_resource].Hatches[#resources[Filter_resource].Hatches + 1] = subnet:GetPart("Hatch")
			table.insert(resources[Filter_resource].ItemsperGroup, 0)
			for k, bin in subnet:GetParts("Bin") do
				resources[Filter_resource].Bins[#resources[Filter_resource].Bins + 1] = bin
				resources[Filter_resource].Totalresource = resources[Filter_resource].Totalresource
					+ bin:GetResourceAmount()
				resources[Filter_resource].Maxresource += (bin.Size.X * bin.Size.Y * bin.Size.Z)
				resources[Filter_resource].ItemsperGroup[#resources[Filter_resource].ItemsperGroup] = resources[Filter_resource].ItemsperGroup[#resources[Filter_resource].ItemsperGroup]
					+ bin:GetResourceAmount()
			end
		elseif #Filter_resource > 0 then
			resources[Filter_resource] = {}
			resources[Filter_resource].Ports = { port }
			resources[Filter_resource].Filters = { subnet:GetPart("Filter") }
			resources[Filter_resource].Hatches = { subnet:GetPart("Hatch") }
			resources[Filter_resource].Bins = {}
			resources[Filter_resource].Totalresource = 0
			resources[Filter_resource].Maxresource = 0
			resources[Filter_resource].ItemsperGroup = { 0 }

			for k, bin in subnet:GetParts("Bin") do
				bin.Resource = Filter_resource
				resources[Filter_resource].Bins[#resources[Filter_resource].Bins + 1] = bin
				resources[Filter_resource].Totalresource += bin:GetResourceAmount()
				resources[Filter_resource].Maxresource += (bin.Size.X * bin.Size.Y * bin.Size.Z)
				resources[Filter_resource].ItemsperGroup[#resources[Filter_resource].ItemsperGroup] += bin:GetResourceAmount()
			end
		else
			table.insert(resources.Unused.Ports, port)
			table.insert(resources.Unused.ItemsperGroup, 0)
			--resources.Unused.Ports[#resources.Unused+1] = port
		end
		--task.wait()
	end

	if net:GetSubnet(5) then
		local tempnet = net:GetSubnet(5)
		resources.Temp = {}
		resources.Temp.Tempnet = tempnet
		resources.Temp.SorterIn = tempnet:GetPartFromPort(1, "Sorter")
		resources.Temp.SorterOut = tempnet:GetPartFromPort(2, "Sorter")
		resources.Temp.Hatch = tempnet:GetPart("Hatch")
		resources.Temp.Totalresource = 0
		resources.Temp.Maxresource = 0
		resources.Temp.ItemsperGroup = {}

		for i, bin in tempnet:GetParts("Bin") do
			resources.Temp.Totalresource = resources.Temp.Totalresource + bin:GetResourceAmount()
			resources.Temp.Maxresource = resources.Temp.Maxresource + (bin.Size.X * bin.Size.Y * bin.Size.Z)

			if resources.Temp.ItemsperGroup[bin:GetResource()] then
				resources.Temp.ItemsperGroup[bin:GetResource()] += bin:GetResourceAmount()
			elseif bin:GetResource() == nil then
				if resources.Temp.ItemsperGroup["Empty"] then
					resources.Temp.ItemsperGroup["Empty"] += bin:GetResourceAmount()
				else
					resources.Temp.ItemsperGroup["Empty"] = bin:GetResourceAmount()
				end
			else
				resources.Temp.ItemsperGroup[bin:GetResource()] = bin:GetResourceAmount()
			end
		end
	end
	return resources
end

function getportresourcegroup(port, net)
	local portnet = net:GetSubnet(port)
	local port_group = {}
	--port_group.Bins = {}
	port_group.Totalresource = 0
	port_group.Maxresource = 0

	port_group.Ports = { port }
	port_group.Filters = { portnet:GetPart("Filter") }
	port_group.Hatches = { portnet:GetPart("Hatch") }

	for i, bin in portnet:GetParts("Bin") do
		--table.insert(port_group.Bins, bin)
		port_group.Totalresource += bin:GetResourceAmount()

		port_group.Maxresource += (bin.Size.X * bin.Size.Y * bin.Size.Z)
	end

	return port_group
end

resourcegroups = Getbingroups(storagenet)

function printresourcegroups()
	for i, v in resourcegroups do
		print(i, " | ", v)

		--[[for k,l in v do 
            print(v," | ",k, " || ",l)
        end]]
	end
end

printresourcegroups()

-- main function
while task.wait() do
	local values = { Microcontroller:Receive() }
	local thread
	--if requests[values[2]] then the original function before implementing threads to prevent any task getting stuck sending or recieving signal
	--requests[values[2]](values[1], resourcegroups, table.unpack(values, 3))
	--end]]
	
	if requests[values[2]] then
		thread = task.spawn(requests[values[2]], values[1], resourcegroups, table.unpack(values, 3))

		task.delay(0.5, function(thread)
			if coroutine.status(thread) ~= "dead" then
				print("Storage server closing connection")
				task.cancel(thread)
			end
		end, thread)

		repeat
			task.wait()
		until coroutine.status(thread) == "dead"
		-- ensure all hatches are closed and checks all resources in storage
		togglehatch({}, false, true)
		resourcegroups = Getbingroups(storagenet)
	end
end
