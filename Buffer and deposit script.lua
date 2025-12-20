local storagenet = Network:GetSubnet(2)
local storageserver = storagenet:GetPartFromPort(10, "Microcontroller")
local bins = Network:GetPartsFromPort(3, "Bin")
local sending_sorter = Network:GetPart("Sorter")

local bufferamount = 500
local resoucegroups = {}

local function GetResource()
	storageserver:Send("getall_resources")
	local listen = task.spawn(function()
		_, resoucegroups = Microcontroller:Receive()
	end)

	task.wait(0.5)
	task.cancel(listen)
end

while task.wait(1) do
	GetResource()
    bins = Network:GetPartsFromPort(3, "Bin")
	for i, v in bins do
        
		if v:GetAmount() >= bufferamount then
			local resourcetype = v.GetResource()
			if
				resoucegroups[resourcetype]
				and resoucegroups[resourcetype].Totalresource and resoucegroups[resourcetype].Totalresource < resoucegroups[resourcetype].Maxresource
			then
				storageserver:Send("Deposit", resourcetype, v:GetAmount())

				local recievetask = task.spawn(function()
					local recieved = Microcontroller:Receive()
					if recieved then
						sending_sorter.Resource = resourcetype
						sending_sorter:Sort(v:GetAmount())
                        task.wait(.2)
						storageserver:Send()
					end
				end)
				task.wait(0.5)
				task.cancel(recievetask)
			end
		end
	end
end


