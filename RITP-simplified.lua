-- this is similar to the other RITP.lua however the standard isnt set here and the code isnt standalone
-- this sendmessage() function is capable of handling all comunications with the storage server including withdrawing and storing items
local storageserver = Network:GetPartFromPort(10,"Microcontroller")
local bins = Network:GetParts("Bin")
local _resourcegroups = {}

local function sendmessage(command, arguments)
	-- this contains all functions that comunicate with external micro controllers
	local functions = {

		GetResources = function()
			storageserver:Send("getall_resources")
			_, _resourcegroups = Microcontroller:Receive()
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
		until coroutine.status(thread)

		bins.Hatch.SwitchValue = false
	end
end

-- this is the format to use the function the first argument is the name of the function within sendmessage() to call 
--then the second argument accepts a table with all the arguments required for that function
sendmessage("DepositItem", table.pack("Iron",5))


-- this is the code on my storage server this doesnt include the task handling but it handles all of the item movement
-- the task handling is handled by the main while loop in the servers code
--variables it uses but ima leave empty since they are all on the main server

function togglehatch(hatch_array,value,all) end 
local sorterout = type("Sorter")
local sorterin = type("Sorter")
function verifyitemquanitiy(bins) end 
function securitycheck(micro) end

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
end