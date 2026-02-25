-- this is the file for the "Robust Item Transport Protocol" 
-- transporting items robustly between two microcontrolled inventory systems has been harder than originally thought
-- Problems to be solved in this protocol 

--[[
* Items Not getting delivered to the destination because the hatches didnt open in time or some other reason
*> Prevent more items from getting removed from storage than allowed
*> Avoid microcontroller hangs if one micro fails to respond to the message 
* ensure the storage micro can keep proper track of the items stored without always checking all the bins 
*> proper error handling that lets the program know items werent moved or the improper amount was moved

]]
-- use warn to display errors the "error" command if necessary
--[[
How the standard works 
1. ensure that all bins are ready by having the bin.resource value be the item you intend to transport 
2. spawn a task that either withdraws or deposits an item 
3. ensure the item request is valid and can be fufilled, if not send the apropiate signal to the client and do not transport any items
- this spawned task is the only thing allowed to comunicate directly with the other micro
3. in the withdrawel/deposit function ensure the sorter.Resource is set correctly along with the sorter.Rate = 1 and sorter.TriggerQuantity= 1
4. kill the task after a period of time has passed if it hasnt already ended to and raise an error if it needs to end the task
5. once the task either ends or is killed check to see if the appropiate amount of items have been moved

-- below are my first attempts to implement this protocol they will need to be heavily modified to work within another script but set the foundation for this protocol
]]

--[[ server sided code
local _repr: typeof(require("@wos/repr")) = (require :: any)("repr")
--local network = Network:GetSubnet(1)
local insorter = GetPartFromPort(3,"Sorter")
local outsorter = GetPartFromPort(2,"Sorter")
local hatch = Network:GetPart("Hatch")
local bin = Network:GetPart("Bin")

-- logic to move an item
--[[outsorter.Resource = "Iron"
outsorter.Rate = 0
outsorter.TriggerQuantity = 1
hatch.SwitchValue = true

outsorter.Sort(1)

hatch.SwitchValue = false 
-- reseting the sorter for testing
outsorter.Resource = "nil"
outsorter.Rate = math.huge
outsorter.TriggerQuantity = 0 ]]

--[[
function itemmove(micro, action, item, quantity)
	local function _calculatemax(bin)
        return (bin.Size.X * bin.Size.Y * bin.Size.Z)
    end

    local function Withdraw(micro,item, quantity)
        outsorter.Resource = item
        outsorter.Rate = 0
        outsorter.TriggerQuantity = 1
        hatch.SwitchValue = true
        task.wait()
        outsorter:Sort(quantity)
        micro:Send(true)
        hatch.SwitchValue = false 
    end

    local function Deposit(micro, item, quantity)
        insorter.Resource = item
        insorter.Rate = 0
        insorter.TriggerQuantity = 1
        hatch.SwitchValue = true
        task.wait()
        insorter:Sort(quantity)
        micro:Send(true)
        hatch.SwitchValue = false 
    end

    local function controlflow(micro, action, item, quantity)
        local binbefore = bin:GetAmount()
        local thread
      

        --create a thread that handles the items so if anything goes wrong it wont crash the micro or halt any other code
        if action == "Withdraw" then
            thread = task.spawn(Withdraw,micro, item, quantity)
        else
            thread = task.spawn(Deposit, micro, item, quantity)
        end

        -- autmomatically closes the thread if it hangs from either not sending a signal or recieving it
        task.delay(0.5, function(thread)
            if coroutine.status(thread) ~= "dead" then
                print("server closing connection")
                task.cancel(thread)
            end
        end, thread)

        -- ensures the items have finished moving before continuing
        repeat
            task.wait()
        until coroutine.status(thread) == "dead"

        -- ensurance that no matter what the hatch will get turned off
        hatch.SwitchValue = false

        -- verify the items have succesfully moved in the right quantity
        if action == "Withdraw" then 
            if bin:GetAmount() == binbefore - quantity then
                
                --print("item succesfully moved")
                return true
            else 
                print("i duunno what went wrong but items movement failed")
                return false
            end
        else 
            if bin:GetAmount() == binbefore + quantity then 
                --print("item succesfully moved")
                return true
            else
                print("i duunno what went wrong but items movement failed")
                return false
            end
        end 

        
    end

    if action == "Withdraw" then 
        if bin:GetResource() == item and bin:GetAmount() - quantity >= 0 then 
            print(bin:GetAmount() - quantity >= 0 )
            controlflow(micro, action, item, quantity)
        else 
            warn("either no items of that type or not enough items in storage for withdrawel")
        end 
    elseif action == "Deposit" then
        if bin:GetResource() == item and calculatemax(bin) <= quantity + bin:GetAmount() then 
            controlflow(micro, action, item, quantity)
        else 
            warn("either no items of that type or not enough items in storage for withdrawel")
        end 
    end 

end

-- listen for commands not exactly specific just needs to be here to test the prototcol
while task.wait() do 
    local command = { Microcontroller:Receive() }
    itemmove(command[1],table.unpack(command,2))
    
end 

--[[ client sided code ---------------------------------------------------------------------------------
local net = Network:GetSubnet(1)
local server = net:GetPartFromPort(1, "Microcontroller")
local hatch = Network:GetPart("Hatch")
local bin = Network:GetPart("Bin")
local item = "Iron"
local quantity = 3
local action = "Withdraw"

function calculatemax(bin)
	return (bin.Size.X * bin.Size.Y * bin.Size.Z)
end

function controlflow(action, item, quantity)

	local function Withdraw(item, quantity)
		hatch.SwitchValue = true
		server:Send("Withdraw", item, quantity)

		local val = { Microcontroller:Receive() }
        hatch.SwitchValue = false
		if val[2] == true then
			print("server tried to move the item")
		else
			print("server didnt move the item")
		end
		
	end

	local function Deposit(item, quantity)
		hatch.SwitchValue = true
		server:Send("Withdraw", item, quantity)
		local val = { Microcontroller:Receive() }

		if val[2] == true then
			print("server tried to move the item")
		else
			print("server didnt move the item")
		end

		hatch.SwitchValue = false
	end

	local binbefore = bin:GetAmount()
	local thread

	--create a thread that handles the items so if anything goes wrong it wont crash the micro or halt any other code
	if action == "Withdraw" then
		thread = task.spawn(Withdraw, item, quantity)
	else
		thread = task.spawn(Deposit, item, quantity)
	end

	-- autmomatically closes the thread if it hangs from either not sending a signal or recieving it
	task.delay(0.5, function(thread)
		if coroutine.status(thread) ~= "dead" then
			print("Client canceling item movement most likely due to no response from server")
			task.cancel(thread)
		end
	end, thread)

	-- ensures the items have finished moving before continuing
	repeat
		task.wait()
	until coroutine.status(thread) == "dead"
    -- ensurance that no matter what the hatch will get turned off
    hatch.SwitchValue = false

	-- verify the items have succesfully moved in the right quantity

    if action == "Withdraw" then 
        if bin:GetAmount() == binbefore + quantity then
            print("item succesfully moved")
            return true
        elseif bin:GetAmount() > binbefore + quantity then
            warn("moved too many items")
            return false
        elseif bin:GetAmount() < binbefore + quantity then 
            warn("moved too few items or none")
            return false
        else 
            print("i duunno what went wrong but items movement failed")
            return false
        end
    else 
        if bin:GetAmount() == binbefore - quantity then 
            print("item succesfully moved")
            return true
        elseif bin:GetAmount() > binbefore - quantity then 
            warn("moved too many items")
            return false
        elseif bin:GetAmount() == binbefore then
            warn("failed to move any items")
            return false
        else
            print("i duunno what went wrong but items movement failed")
            return false
        end
    end 

	
end

-- prepare the bins or bin for the item.. this function can be changed depending on the needs

if action == "Withdraw" and bin:GetAmount() + quantity <= calculatemax(bin) then

	if bin:GetResource() == item then
		controlflow(action, item, quantity)
	elseif bin:GetAmount() <= 0 then
		bin.Resource = item
		controlflow(action, item, quantity)
	else
		print("no bins of that type")
	end
elseif action == "Deposit" and bin:GetAmount() - quantity >= 0 then

	if bin:GetResource() == item then
		controlflow(action, item, quantity)
	elseif bin:GetAmount() <= 0 then
		bin.Resource = item
		controlflow(action, item, quantity)
	else
		print("no bins of that type")
	end
else
	print("no valid action selected")
end]]
