-- this is similar to the other RITP.lua however the standard isnt set here and the code isnt standalone

--[[ this contains all the code except for the thread handling part
function RITP_client(resourcebins,Action,item,quantity)
    Moveitem = function(requestingmicro, resources, action, itemtype, quantity)
		local function Withdraw(itemtype,quantity)
			togglehatch(resources[itemtype].Hatches, true,false)
			sorterout.Resource = itemtype
			sorterout.Rate = 0
			sorterout.TriggerQuantity = 1
			task.wait()
			sorterout:Sort(quantity)
			requestingmicro:Send(true,"Item has been moved")
			togglehatch(resources[itemtype].Hatches, false,false)
			sorterout.Resource = nil
		end 

		local function Deposit(itemtype,quantity) 
			togglehatch(resources[itemtype].Hatches, true,false)
			sorterin.Resource = itemtype
			sorterin.Rate = 0
			sorterin.TriggerQuantity = 1
			task.wait()
			sorterin:Sort(quantity)
			requestingmicro:Send(true,"Item has been moved")
			togglehatch(resources[itemtype].Hatches, false,false)
			sorterin.Resource = nil
		end 

		if action == Withdraw() then 
			if securitycheck(requestingmicro) == true then
				if resources[itemtype] and (resources[itemtype].Totalresource - quantity >= 0) then 
					Withdraw(itemtype,quantity)
				else 
					requestingmicro:Send(false,"Either no resources of that type or requested more than whats in storage")
				end 
			else 
				requestingmicro:Send(false,"Security check failed")
			end 
			
		elseif action == Deposit() then 
			if securitycheck(requestingmicro) == true then
				if resources[itemtype] and (resources[itemtype].Totalresource + quantity <= resources[itemtype].Maxresource) then 
					Deposit(itemtype,quantity)
				else 
					requestingmicro:Send(false,"Either no resources of that type or storage is full")
				end 
			else 
				requestingmicro:Send(false,"Security check failed")
			end 
		end 


	end
end --]]
