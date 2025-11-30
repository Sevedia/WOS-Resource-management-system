
--[[  example resource table 
    resources = {
    [Unused] = {
        Ports = {port1,port2}
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
local repr = require("repr")

local resourcegroups = {}
print("-------------------------------------------")

local requests = {
    Deposit = function(requestingmicro,resources, itemtype, quantity)
            if resources[itemtype] and (resources[itemtype].Totalresource + quantity <= resources[itemtype].Maxresource)then
                if securitycheck(requestingmicro) then 
                    togglehatch(resources[itemtype].Hatches,true)

                    requestingmicro:Send(true)    -- tells the micro it can send the items
                    Microcontroller:Receive() -- recieves the signal that the items have moved
                    resources[itemtype].Totalresource += quantity
                    togglehatch(resources[itemtype].Hatches,false)
                else 
                    print("security check faield")
                end 
            else 
                print("request denied storage either full or no bins of that type exist, item type: ",itemtype)
                requestingmicro:Send(false)
            end 

    end, 
    
    withdraw = function(requestingmicro,resources,itemtype,quantity)
        if securitycheck() then 
            if resources[itemtype] and (resources[itemtype].Totalresource - quantity >=0) then 
                togglehatch(resources[itemtype].Hatches,true)

                requestingmicro:Send(true)
                task.spawn(function()
                    Microcontroller:Receive()
                    resources[itemtype].Totalresource -= quantity
                    togglehatch(resources[itemtype].Hatches,false)
                end)
                
            else 
                print("request denied either not enough items of that type or no items of that type exist, item type: ",itemtype)

            end 
            print("security check failed")
        end 
    end,

    changegroup = function(requestingmicro,resources, old_resourcegroup, new_resourcegroup) 
        
        if resources[old_resourcegroup] and #resources[old_resourcegroup].Ports > 0 then 
            local port_group
            if securitycheck(requestingmicro) then 
                for i,port in resources[old_resourcegroup].Ports do 
                    port_group = getportresourcegroup(port,storagenet)
                
                    if port_group.Totalresource == 0 then 
                        port_group.Filters[1].Filter = new_resourcegroup 
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

    printgroups = function()
        printresourcegroups()
    end, 
    
    getall_resources = function(requestingmicro)
        requestingmicro:Send(resourcegroups)
    end,

    refresh_resources = function(requestingmicro)
        resourcegroups = Getbingroups(storagenet)
        requestingmicro:Send(resourcegroups)
    end

} 

function Getbingroups(net) 
    local resources = {}
    resources.Unused = {}
    resources.Unused.Ports = {}

    for i, port in net:GetPorts(1) do 
        
        local subnet = net:GetSubnet(port) 
        local Filter_resource = subnet:GetPart("Filter").Filter
        
        if resources[Filter_resource] then 
            resources[Filter_resource].Ports[#resources[Filter_resource].Ports+1] = port
            resources[Filter_resource].Filters[#resources[Filter_resource].Filters+1] =  subnet:GetPart("Filter")
            resources[Filter_resource].Hatches[#resources[Filter_resource].Hatches+1] = subnet:GetPart("Hatch")
            table.insert(resources[Filter_resource].ItemsperGroup,0)
            for k,bin in subnet:GetParts("Bin") do 
                 
                resources[Filter_resource].Bins[#resources[Filter_resource].Bins+1] = bin
                resources[Filter_resource].Totalresource = resources[Filter_resource].Totalresource + bin:GetResourceAmount()
                resources[Filter_resource].Maxresource = resources[Filter_resource].Maxresource + (bin.Size.X * bin.Size.Y * bin.Size.Z)
                resources[Filter_resource].ItemsperGroup[#resources[Filter_resource].ItemsperGroup] += bin:GetResourceAmount() 
            end 

        elseif #Filter_resource > 0 then 
            
            resources[Filter_resource] = {}
            resources[Filter_resource].Ports = {port}
            resources[Filter_resource].Filters =  {subnet:GetPart("Filter")}
            resources[Filter_resource].Hatches = {subnet:GetPart("Hatch")}
            resources[Filter_resource].Bins = {} 
            resources[Filter_resource].Totalresource = 0 
            resources[Filter_resource].Maxresource = 0
            resources[Filter_resource].ItemsperGroup = {0}

            for k,bin in subnet:GetParts("Bin") do 
                resources[Filter_resource].Bins[#resources[Filter_resource].Bins+1] = bin
                resources[Filter_resource].Totalresource = resources[Filter_resource].Totalresource + bin:GetResourceAmount()
                resources[Filter_resource].Maxresource = resources[Filter_resource].Maxresource + (bin.Size.X * bin.Size.Y * bin.Size.Z)
                resources[Filter_resource].ItemsperGroup[#resources[Filter_resource].ItemsperGroup] += bin:GetResourceAmount() 
            end 
        else 
            table.insert(resources.Unused.Ports,port)
            
            --resources.Unused.Ports[#resources.Unused+1] = port
           
        end
        --task.wait()
    end 

    return resources    
end 

-- while this function is currently and place holder eventually it will be very useful to ensure no items are moved around by unathorized partys 
-- not exactly sure how this will work in the future but thats a future me problem, your welcome future me :3
function securitycheck(requestingmicro) 
    print(type(requestingmicro:GetOwnerId()))
    if requestingmicro:GetOwnerId() == 118486742 then 
        return true
    end 
    return false
end 

function togglehatch(hatch_array, newvalue)
    for i,hatch in hatch_array do 
        hatch.SwitchValue = newvalue
    end 
end 

function getportresourcegroup(port,net) 
    portnet = net:GetSubnet(port)
    local port_group = {} 
    port_group.Bins = {}
    port_group.Totalresource = 0
    port_group.Maxresource = 0

    port_group.Ports = {port}
    port_group.Filters = {portnet:GetPart("Filter")}
    port_group.Hatches = {portnet:GetPart("Hatch")}

    for i,bin in portnet:GetParts("Bin") do 
        table.insert(port_group.Bins,bin)
        port_group.Totalresource += bin:GetResourceAmount()
        port_group.Maxresource += (bin.Size.X * bin.Size.Y * bin.Size.Z)
    end 

    return port_group

end

resourcegroups = Getbingroups(storagenet)

function printresourcegroups()
    for i,v in resourcegroups.Copper.ItemsperGroup do 
        print(i," | ",v)
        
        --[[for k,l in v do 
            print(v," | ",k, " || ",l)
        end]]
    end 
end

printresourcegroups()
-- main function
while task.wait() do
    local values = {Microcontroller:Receive()}
    if requests[values[2]] then  
        requests[values[2]](values[1],resourcegroups,table.unpack(values,3))
    end 
    
end

