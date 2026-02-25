local storagenet = Network:GetSubnet(2)
local storageserver = storagenet:GetPartFromPort(10, "Microcontroller")
local bins = Network:GetPartsFromPort(3, "Bin")
local hatch = Network:GetPart("Hatch")

local bufferamount = 0
local resourcegroups = {}

print("_________________________")

local function sendmessage(command, arguments)
	local functions = {

		GetResources = function()
			storageserver:Send("getall_resources")
			_, resourcegroups = Microcontroller:Receive()
		end,

		DepositItem = function(item, quantity)
			storageserver:Send("Moveitem", "Deposit", item, quantity, hatch)
			local val = { Microcontroller:Receive() }

			if val[2] == true then
				print("items moved: ", val[3])
			else
				print("item failed to move, error: ", val[3])
			end
		end,
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
				storageserver = storagenet:GetPartFromPort(10, "Microcontroller")
				task.cancel(thread)
			end
		end, thread)

		repeat
			task.wait()
		until coroutine.status(thread) == "dead"

		hatch.SwitchValue = false 
	end
end

while task.wait(1) do
	sendmessage("GetResources")
	bins = Network:GetPartsFromPort(3, "Bin")
	for i, v in bins do
		if v:GetResourceAmount() >= bufferamount then
			task.wait(0.1)
			local resourcetype = v.GetResource()
			if
				resourcegroups[resourcetype]
				and resourcegroups[resourcetype].Totalresource
				and resourcegroups[resourcetype].Totalresource < resourcegroups[resourcetype].Maxresource
			then
				local maxtosend = resourcegroups[resourcetype].Maxresource - resourcegroups[resourcetype].Totalresource
				local request_amount
				if maxtosend < v:GetResourceAmount() then
					request_amount = maxtosend
				else
					request_amount = v:GetResourceAmount()
				end
				sendmessage("DepositItem", table.pack(resourcetype, request_amount))
			end
		end
	end
end
