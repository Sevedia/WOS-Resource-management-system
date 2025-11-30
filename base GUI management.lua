--[[
*info that needs to be displayed

- the item type
- the total quantity of items
- the max quantity of items along with a potential percentage bar that shows how full the storage is
- every item type available 

- a list of various commands to manualy reorganize and realocate storage

- when you click on a certain resource group it should display extra information about that items such as{ 

    1. the amount of groups for the item
    2. the amount each item group holds 
    3. a graph of the resource over time

	Update the graph to show the time period it has data for along with a refresh button
} 
]]

local canvas = Network:GetPart("Screen"):GetCanvas()
local compnet = Network:GetSubnet(2)
local storageserver = compnet:GetPartFromPort(10,"Microcontroller")
local disk = Network:GetPart("Disk")


local raw_data_points = 1800 -- to get roughly an hours worth of history
local average_data_points = 12
local currentpage
local resources = {}
local GuiObjects = {}
local Raw_resource_data = {}


--[[
local resources = {
	["Unused"] = {
		Ports = {"port1","port2"}
	},
	["Iron"] = {
		Ports = {"port1","port2"},
		Filters = {"Filter1,Filter2"},
		Hatches = {"Hatch1,Hatch2"},
		Bins = {"Bin1,Bin2"},
		Totalresource = 4200,
		Maxresource = 10000,
	    ItemsperGroup = {2970,2960,}
	},
	["Copper"] = {
		Ports = {"port1","port2"},
		Filters = {"Filter1,Filter2"},
		Hatches = {"Hatch1,Hatch2"},
		Bins = {"Bin1,Bin2"},
		Totalresource = 6719,
		Maxresource = 10000,
		ItemsperGroup = {2420,2900,}
	},
	["Quartz"] = {
		Ports = {"port1","port2"},
		Filters = {"Filter1,Filter2"},
		Hatches = {"Hatch1,Hatch2"},
		Bins = {"Bin1,Bin2"},
		Totalresource = 6740,
		Maxresource = 10000,
		ItemsperGroup = {2350,2900,}
	},
	["Apple"] = {
		Ports = {"port1","port2"},
		Filters = {"Filter1,Filter2"},
		Hatches = {"Hatch1,Hatch2"},
		Bins = {"Bin1,Bin2"},
		Totalresource = 6900,
		Maxresource = 10000,
		ItemsperGroup = {2400,2905,2400,2901,2470,2935,2440,2605,}
	}

}

local resource_data = {
	Iron = {1000,1500,800,2000,5040,4000,3500,6000,5000}
}]]


local commands = {

}

local Colors = {
	Black = Color3.new(0, 0, 0),
	White = Color3.new(1, 1, 1),
	ButtonBlue = Color3.fromRGB(197, 241, 221),
	ButtonRed = Color3.fromRGB(255, 6, 10),
	PercentageGreen = Color3.fromRGB(10, 255, 26),
	BackgroundGreen = Color3.fromRGB(243, 255, 188),
	BackgroundGrey = Color3.fromRGB(161, 161, 161),
	ScrollGrey = Color3.fromRGB(20, 27, 58),
	linegreen = Color3.fromRGB(11, 119, 54)
}

print("-------------------------------------------")

--gui creation functions
function UICorner(parent,radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0, 8)
	corner.Parent = parent
end

function UIPad(parent,top,left,right,bottom)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = top or UDim.new(0, 5)
	pad.PaddingLeft = left or UDim.new(0, 5)
	pad.PaddingRight = right or UDim.new(0, 5)
	pad.PaddingBottom = bottom or UDim.new(0, 5)
	pad.Parent = parent
end

function newframe(parent,options: {color: Color3, size: UDim2, position: UDim2,name: string })
	local frame = Instance.new("Frame")
	frame.Size = options.size
	frame.Position = options.position
	frame.BackgroundColor3 = options.color
	frame.BorderSizePixel = 0
	frame.Name = options.name or "Frame"
	frame.Parent = parent
	return frame
end

function UITextlabel(parent, options: {color: Color3,size: UDim2,position: UDim2,text: string,name: string})
	local label = Instance.new("TextLabel")
	label.Size = options.size
	label.Position = options.position
	label.BackgroundColor3 = options.color
	label.BorderSizePixel = 0
	label.TextScaled = true
	label.Text = options.text
	label.Name = options.name or "TextLabel"
	label.Parent = parent
	return label
end

function createmainframes(gui)

	gui.mainframe = newframe(canvas,{
		color = Colors.Black,
		size = UDim2.fromScale(1,1),
		position = UDim2.fromOffset(0,0),
		name = "MainFrame"
	})
	UIPad(gui.mainframe)

	gui.infoframe = newframe(gui.mainframe,{
		color = Colors.BackgroundGrey,
		size = UDim2.new(0.7,-5,1,0),
		position = UDim2.fromOffset(0,0),
		name = "InfoFrame"
	})
	UICorner(gui.infoframe)


	gui.commandframe = Instance.new("ScrollingFrame")
	gui.commandframe.Size = UDim2.new(0.3,0,.65,0)
	gui.commandframe.Position = UDim2.new(0.7,0,0,0)
	gui.commandframe.BackgroundColor3 = Colors.BackgroundGrey
	gui.commandframe.ScrollBarImageColor3 = Colors.ScrollGrey
	gui.commandframe.ScrollBarThickness = 8
	gui.commandframe.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	gui.commandframe.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gui.commandframe.BorderSizePixel = 0 
	gui.commandframe.Name = "CommandFrame"
	gui.commandframe.Parent = gui.mainframe
	-- creates children of command frame
	UICorner(gui.commandframe)
	UIPad(gui.commandframe)

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0,5)
	list.Parent = gui.commandframe

	-- sets up the output frame
	gui.outputframe = newframe(gui.mainframe,{
		color = Colors.BackgroundGrey,
		size = UDim2.new(0.3, 0,0.35,-5),
		position = UDim2.new(0.7,0,0.65,5),
		name = "OutputFrame"
	})
	UICorner(gui.outputframe)
	UIPad(gui.outputframe)	

	gui.out1 = UITextlabel(gui.outputframe,{
		color = Colors.ButtonBlue,
		size = UDim2.new(1,0, 0.5,0),
		position = UDim2.new(0,0, 0,0),
		text = "output 1"
	})
	UICorner(gui.out1)

	gui.out2 = UITextlabel(gui.outputframe,{
		color = Colors.ButtonBlue,
		size = UDim2.new(1,0, 0.5,-5),
		position = UDim2.new(0,0, 0.5,5),
		text = "output 2"
	})
	UICorner(gui.out2)
	return gui
end

function NewresourceFrame(parent,resource,data)

	local Resourcepercentage

	if data.Totalresource and data.Maxresource then
		Resourcepercentage = data.Totalresource/data.Maxresource
	else
		Resourcepercentage = 0
	end

	local frame = newframe(parent,{
		color = Colors.Black,
		size = UDim2.new(0,0,0,0),
		position = UDim2.new(0,0,0,0),
		name = resource
	})

	UICorner(frame)
	UIPad(frame,UDim.new(0,3),UDim.new(0,3),UDim.new(0,3),UDim.new(0,3))	

	local Resourcebutton = Instance.new("TextButton")
	Resourcebutton.BackgroundColor3 = Colors.ButtonBlue
	Resourcebutton.Position = UDim2.new(0,0,0,0)
	Resourcebutton.BorderSizePixel = 0
	Resourcebutton.TextScaled = true
	Resourcebutton.Size = UDim2.new(1,0, 0.5,-1)
	Resourcebutton.Text = resource
	Resourcebutton.Parent = frame

	Resourcebutton.MouseButton1Click:Connect(function()
		switchpage(resource)

	end)
	UICorner(Resourcebutton)

	local box2 = UITextlabel(frame,{
		color = Colors.ButtonBlue,
		position = UDim2.new(0,0, 0.5,1),
		size = UDim2.new(0.5,-1, 0.5,-1),
		text = data.Totalresource or 0,
		name = "Totalresource"
	})
	UICorner(box2)

	local percentageframe = newframe(frame,{
		color = Colors.BackgroundGreen,
		position = UDim2.new(0.5,1, 0.5,1),
		size = UDim2.new(0.5,-1, 0.5,-1),
		name = "Percentage"
	})
	UICorner(percentageframe)
	UIPad(percentageframe,UDim.new(.05,0),UDim.new(.05,0),UDim.new(.05,0),UDim.new(.05,0))

	local percentbar = newframe(percentageframe,{
		color = Colors.PercentageGreen,
		position = UDim2.new(0,0, 0,0),
		size = UDim2.new(Resourcepercentage,0, 1,0),
		name = "Percent"
	})
	UICorner(percentbar)

	local percentbox = UITextlabel(percentageframe,{
		color = Colors.White,
		position = UDim2.new(0,0,0,0),
		size = UDim2.new(1,0,1,0),
		text = math.floor(Resourcepercentage*100) ..'%'--.." Full"
	})
	percentbox.BackgroundTransparency = 1
	UICorner(percentbox)

end

function SetupresourceFrames(gui, resources) 

	gui.resources = Instance.new("ScrollingFrame")
	gui.resources.Size = UDim2.new(1,0, 1,0)
	gui.resources.Position = UDim2.new(0,0,0,0)
	gui.resources.BackgroundColor3 = Colors.BackgroundGrey
	gui.resources.ScrollBarImageColor3 = Colors.ScrollGrey
	gui.resources.ScrollBarThickness = 8
	gui.resources.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	gui.resources.BorderSizePixel = 0 
	gui.resources.Name = "Resources"
	gui.resources.Parent = gui.infoframe

	gui.val = gui.resources:SetAttribute("FrameType","MainResources")

	UICorner(gui.resources)
	UIPad(gui.resources)

	currentpage = gui.resources

	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.new(0.01,0, 0.01,0)
	grid.CellSize = UDim2.new(0.325, 0, 0,115)
	grid.Parent = gui.resources

	-- all code after this line will need to be moved to a function that can update the gui

	-- sorts the list into alphabetical order
	local alphabetical = {}
	for i,v in pairs(resources) do 
		table.insert(alphabetical,i)
	end

	table.sort(alphabetical,function(first,second) return first:lower() < second:lower() end)
	-- create the frames in that new alphabetical order
	for i,v in alphabetical do
		if gui.resources:FindFirstChild(i) then 
			continue
		else 
			NewresourceFrame(gui.resources,v,resources[v])
			task.wait(.25)
		end

	end
end

function Creategraph(parentframe,points)
	local graph = {}
	local screensize = parentframe.AbsoluteSize
	local xspacing = (screensize.X/#points)
	local largestval = 0 
	local posvectors = {}

	for i,v in points do
		if v > largestval then 
			largestval = v 
		end
	end
	
	graph.mainfrrame = newframe(parentframe,{
		color = Colors.Black,
		size = UDim2.new(1,0, 1,0),
		position = UDim2.new(0,0,0,0)
	})
	UIPad(graph.mainfrrame,UDim.new(.02,0),UDim.new(.02,0),UDim.new(.02,0),UDim.new(.02,0))

	local layout = Instance.new("UITableLayout")
	layout.Padding = UDim2.new(.02,0, .02,0)
	layout.FillEmptySpaceColumns = true
	layout.FillEmptySpaceRows = true
	layout.Parent = graph.mainfrrame

	-- creates the grid for the graph
	for i=1,10 do 
		local row = newframe(graph.mainfrrame,{
			color = Colors.BackgroundGrey,
			size = UDim2.new(0,0,0,0),
			position = UDim2.new(0,0,0,0)
		})

		row.BackgroundTransparency = 1

		for i=1,10 do 
			local block = newframe(row,{
				color = Colors.White,
				position = UDim2.new(0,0,0,0),
				size = UDim2.new(0,0,0,0)
			})
		end
	end

	-- creates all the points

	for i,v in points do 
		local percentage = (v)/largestval
		posvectors[i] = Vector2.new((i-1)*xspacing+10,screensize.Y-(math.floor(percentage*screensize.Y)-10))

		local frame = newframe(parentframe,{
			color = Colors.PercentageGreen,
			size = UDim2.fromOffset(10,10),
			position = UDim2.new(0,posvectors[i].X,0,posvectors[i].Y)
		})
		frame.ZIndex = 5
		frame.AnchorPoint = Vector2.new(.5,.5)
		UICorner(frame,UDim.new(1,0),UDim.new(1,0),UDim.new(1,0),UDim.new(1,0))		
	end

	-- make the lines
	for i,v in posvectors do 
		if posvectors[i+1] then 
			local magnitude = (posvectors[i+1]-posvectors[i]).Magnitude
			local angle = math.atan2(posvectors[i+1].Y-posvectors[i].Y,posvectors[i+1].X-posvectors[i].X) * (180/math.pi)	


			local line = newframe(parentframe,{
				color = Colors.linegreen,
				size = UDim2.fromOffset(magnitude,5),
				position = UDim2.new(0,(posvectors[i+1].X+posvectors[i].X)/2,0,(posvectors[i+1].Y+posvectors[i].Y)/2)
			})
			line.AnchorPoint = Vector2.new(0.5,0.5)
			line.Rotation = angle
			line.ZIndex = 4
		end
	end
end

function createresourcepage(resource,data,gui,averagedpoints)
	local page = newframe(gui.infoframe,{
		color = Colors.BackgroundGrey,
		size = UDim2.new(1,0,1,0),
		position = UDim2.new(0,0,0,0),
		name = resource
	})
	UICorner(page)
	UIPad(page)

	local val = page:SetAttribute("FrameType","Resourcepage")

	local graphframe = newframe(page,{
		color = Colors.White,
		size = UDim2.new(.62,0,0.62,0),
		position = UDim2.new(0.41,0, 0.3,0),
		name = "Graph"
	})
	UICorner(graphframe)

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = graphframe

	local total = UITextlabel(page,{
		color = Colors.ButtonBlue,
		size = UDim2.new(0.3, 0, 0.08,0),
		position = UDim2.new(0.45,0, 0,0),
		text = "<b>Total Resource:</b>" ,
		name = "Totalresourcetext"
	})
	total.RichText = true
	UICorner(total)
	
	local total2 = UITextlabel(page,{
		color = Colors.ButtonBlue,
		size = UDim2.new(0.25, 0, 0.08,0),
		position = UDim2.new(0.75,0, 0,0),
		text = (data[resource].Totalresource or '0'),
		name = "Totalresourcenumber"
	})
	
	UICorner(total2)

	local resourcedisplay = UITextlabel(page,{
		color = Colors.ButtonBlue,
		size = UDim2.new(1,0, 0.2,0),
		position = UDim2.new(0,0, 0.09,0),
		text = resource,
		name = "Resourcetype"
	})
	UICorner(resourcedisplay)

	local backbutton = Instance.new("TextButton")
	backbutton.Size = UDim2.new(0.4,0, 0.08,0)
	backbutton.Position = UDim2.new(0,0,0,0)
	backbutton.BackgroundColor3 = Colors.ButtonRed
	backbutton.Parent = page
	backbutton.TextScaled = true
	backbutton.Text = "<--"
	UICorner(backbutton,UDim.new(1,0))

	-- creates the table and the graph of the resource over time
	local tablescrol = Instance.new("ScrollingFrame")
	tablescrol.BackgroundColor3 = Colors.Black
	tablescrol.Position = UDim2.new(0,0, 0.3,0)
	tablescrol.Size = UDim2.new(0.4,0,0.7,0)	
	tablescrol.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tablescrol.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	tablescrol.ScrollBarThickness = 8
	tablescrol.Parent = page
	tablescrol.AutomaticCanvasSize = Enum.AutomaticSize.Y
	UICorner(tablescrol)
	UIPad(tablescrol)

	if data[resource].Totalresource then 
		-- creates the graph and table
		local table_layout = Instance.new("UITableLayout")
		table_layout.Padding = UDim2.new(0,5, 0,5)
		table_layout.FillEmptySpaceColumns = true
		table_layout.SortOrder = Enum.SortOrder.LayoutOrder
		table_layout.Parent = tablescrol

		-- creates the tables index
		local guide = newframe(tablescrol,{
			color = Colors.Black,
			size = UDim2.new(0,0,0,0),
			position = UDim2.new(0,0,0,0),
			name = "Index"
		})
		UICorner(guide)

		local group = UITextlabel(guide,{
			color = Colors.ButtonBlue,
			size = UDim2.new(0,0,.15,0),
			position = UDim2.new(0,0,0,0),
			text = "Group",
			name = "Group"
		})
		UICorner(group)

		local group = UITextlabel(guide,{
			color = Colors.ButtonBlue,
			size = UDim2.new(0,0,.15,0),
			position = UDim2.new(0,0,0,0),
			text = "Quantity",
			name = "Quantity"
		})
		UICorner(group)

		for i,v in data[resource].ItemsperGroup do 
			local guide = newframe(tablescrol,{
				color = Colors.Black,
				size = UDim2.new(0,0,0,0),
				position = UDim2.new(0,0,0,0),
				name = "group"
			})
			UICorner(guide)

			local index = UITextlabel(guide,{
				color = Colors.ButtonBlue,
				size = UDim2.new(0,0,.15,0),
				position = UDim2.new(0,0,0,0),
				text = i,
                name = "Index"
			})
			UICorner(index)
			index:SetAttribute("Index",i)

			local Val = UITextlabel(guide,{
				color = Colors.ButtonBlue,
				size = UDim2.new(0,0,.15,0),
				position = UDim2.new(0,0,0,0),
				text = v,
                name = "Value"
			})
			UICorner(Val)

		end

		--create the graph
		if averagedpoints then 
			Creategraph(graphframe,averagedpoints)
		else 
			--leaves a message saying no data available
			local graphtext = UITextlabel(graphframe,{
				color = Colors.BackgroundGreen,
				size = UDim2.new(1,0,1,0),
				position = UDim2.fromScale(0,0),
				text = "No Data Available for graph"
			})
		end


	else 
		-- lists a error for both saying data not available
		local groupframe = UITextlabel(tablescrol,{
			color = Colors.BackgroundGreen,
			size = UDim2.new(1,-13,.5,0),
			position = UDim2.fromScale(0,0),
			text = "No Data Available"
		})

		local graphtext = UITextlabel(graphframe,{
			color = Colors.BackgroundGreen,
			size = UDim2.new(1,0,1,0),
			position = UDim2.fromScale(0,0),
			text = "No Data Available for graph"
		})

	end

	backbutton.MouseButton1Click:Connect(function()
		switchpage("Resources")
		for i,v in graphframe:GetChildren() do 
			if v.ClassName == "Frame" then 
				v:remove()
			end 

			if v.ClassName == "TextLabel" then 
				v:remove()
			end
		end 
	end)

	return page
end

function average(raw,numpoints)

	if not raw then 
		print("raw = not")
		return nil
	end 

	local pointsperaverage = math.floor(#raw/numpoints)
	local average = {}

	if pointsperaverage >= 1 then 
		for i=1, numpoints do 
			local startpoint = ((i*pointsperaverage) - pointsperaverage)+1
			average[i] = 0

			if (i*pointsperaverage) > #raw then 
				endpoint = #raw
			else 
				endpoint = (i*pointsperaverage)
			end 

			for k=startpoint, endpoint do 
				average[i] += raw[k]
			end 
			
			average[i] = average[i]/((endpoint-startpoint)+1)

		end 
	else 
		print("points too low")
		return nil
	end 

	return average
end 

function Updateresourceamount()
	storageserver:Send("refresh_resources")
	local listen = task.spawn(function()
		_, data = Microcontroller:Receive()

		for i, v in data do 
			if v.Totalresource then 
				if not Raw_resource_data[i] then 
					Raw_resource_data[i] = {}
				end 
				-- stores an hours worth of data points
				if #Raw_resource_data[i] < raw_data_points then 
					table.insert(Raw_resource_data[i],v.Totalresource)
				else
					table.remove(Raw_resource_data[i],1)
					table.insert(Raw_resource_data[i],v.Totalresource)
				end 
			end 
		end 
		
		resources = data
	end)
	
	task.wait(.5)
	task.cancel(listen)
end 

function switchpage(page)
	if GuiObjects.infoframe:FindFirstChild(page) then 
		--updateresourcepage()
		local frame = GuiObjects.infoframe:FindFirstChild(page)
		frame.Visible = true
		currentpage.Visible = false
		currentpage = frame

		if currentpage:GetAttribute("FrameType") == "Resourcepage" then 
			print("graph")
			local averagedpoints = average(Raw_resource_data[page],average_data_points)

			if resources[page].Totalresource and averagedpoints then 
				Creategraph(currentpage["Graph"],averagedpoints)
			else 
				local graphtext = UITextlabel(currentpage["Graph"],{
					color = Colors.BackgroundGreen,
					size = UDim2.new(1,0,1,0),
					position = UDim2.fromScale(0,0),
					text = "No Data Available for graph"
				})
			end 
		
		end 
		--GuiObjects.infoframe.resources.Visible = false
	else 
		currentpage.Visible = false		-- can prolly delete average_data_points from function
		currentpage = createresourcepage(page,resources,GuiObjects,average(Raw_resource_data[page],average_data_points))
	end

end

Updateresourceamount(resources)
GuiObjects = createmainframes(GuiObjects,Colors)
SetupresourceFrames(GuiObjects,resources)

-- main running 
while task.wait(2) do
    Updateresourceamount()
	local frametype = currentpage:GetAttribute("FrameType")

	if frametype == "MainResources" then 
		for i,v in currentpage:GetChildren() do 
			if v.ClassName == "Frame" then
				local percentage

				if resources[v.Name].Totalresource and resources[v.Name].Maxresource then
					percentage = resources[v.Name].Totalresource/resources[v.Name].Maxresource
				else
					percentage = 0
				end

				local button = v:FindFirstChild("TextButton")
				local percent = v:FindFirstChild("Percentage"):FindFirstChild("Percent")
				local percenttxt = v:FindFirstChild("Percentage"):FindFirstChild("TextLabel")
				local total = v:FindFirstChild("Totalresource")

				if button.Text ~= v.Name then 
					button.Text = v.Name
				end

				if total.Text ~= resources[v.Name].Totalresource or 0 then 
					total.Text = resources[v.Name].Totalresource or 0
				end

				if percenttxt.Text ~= math.floor(percentage*100) ..'%'--[[.." Full"]] then 
					percenttxt.Text = math.floor(percentage*100) ..'%' --[[.." Full"]]
					percent.Size = UDim2.new(percentage,0,1,0)
				end

				task.wait(.5)
			end

		end
	elseif frametype == "Resourcepage" then

		if currentpage["Totalresourcetext"].Text ~= "<b>Total Resource:</b>"  then 
			currentpage["Totalresourcetext"].Text = "<b>Total Resource:</b>" 
		end
		
		if currentpage["Totalresourcenumber"].Text ~= (resources[currentpage.Name].Totalresource or 0)  then 
			currentpage["Totalresourcenumber"].Text = (resources[currentpage.Name].Totalresource or 0)
		end
		
		if currentpage["Resourcetype"].Text ~= currentpage.Name then 
			currentpage["Resourcetype"].Text = currentpage.Name
		end
		-- updates the table frame
		if currentpage["ScrollingFrame"]:FindFirstChild("UITableLayout") then 
			
			if currentpage["ScrollingFrame"]["Index"]["Group"].Text ~= "Group" then 
				currentpage["ScrollingFrame"]["Index"]["Group"].Text = "Group"
			end 

			if currentpage["ScrollingFrame"]["Index"]["Quantity"].Text ~= "Quantity" then 
				currentpage["ScrollingFrame"]["Index"]["Quantity"].Text = "Quantity"
			end 

			for i,v in currentpage["ScrollingFrame"]:GetChildren() do 
				if v.Name == "group" then 
					if v["Index"].Text ~= v["Index"]:GetAttribute("Index") then 
						v["Index"].Text = v["Index"]:GetAttribute("Index")
					end

					if v["Value"].Text ~= resources[currentpage.Name].ItemsperGroup[v["Index"]:GetAttribute("Index")] then 
						v["Value"].Text = resources[currentpage.Name].ItemsperGroup[v["Index"]:GetAttribute("Index")]
					end

				end 
			end
		end 

		
	end
end