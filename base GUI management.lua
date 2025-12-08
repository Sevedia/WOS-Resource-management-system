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

	add a button to the graph to delete the graph data
} 
]]

local screen = Network:GetPart("Screen")
local canvas = screen:GetCanvas()
local compnet = Network:GetSubnet(2)
local storageserver = compnet:GetPartFromPort(10, "Microcontroller")
local disk = Network:GetPart("Disk")
local keyboard = Network:GetPart("Keyboard")
-- i dont know if this code will run but it silences the error
--local partdata = require("partdata")
local partdata: typeof(require("@wos/partdata")) = (require :: any)("partdata")

local raw_data_points = 1800 -- to get roughly an hours worth of history
local average_data_points = 12
local currentpage
local resources = {}
local Raw_resource_data = {}
local Keyboard_inputs = {}

if disk:Read("Raw_resource_data") then
	Raw_resource_data = disk:Read("Raw_resource_data")
end

local Colors = {
	Black = Color3.new(0, 0, 0),
	White = Color3.new(1, 1, 1),
	ButtonBlue = Color3.fromRGB(197, 241, 221),
	ButtonRed = Color3.fromRGB(255, 6, 10),
	PercentageGreen = Color3.fromRGB(10, 255, 26),
	BackgroundGreen = Color3.fromRGB(243, 255, 188),
	BackgroundGrey = Color3.fromRGB(161, 161, 161),
	ScrollGrey = Color3.fromRGB(20, 27, 58),
	linegreen = Color3.fromRGB(11, 119, 54),
}

local GuiObjects = {}

-- these next few lines are to basically to silence my text editor
GuiObjects = {
	["Out1"] = nil,
	["Out2"] = nil,
	["commandframe"] = nil,
	["resources"] = nil,
	["infoframe"] = nil,
}

local switchpage
local newcommandframe

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
}]]

-- here lies the actual script and code now that the setup variables are finished

print("-------------------------------------------")

local commands
commands = {
	changegroup = {
		setup = function()
			commands.changegroup.Data.Objects = newcommandframe("Convert group", true)

			commands.changegroup.Data.Objects.commandbutton.MouseButton1Click:Connect(function()
				if commands.changegroup.Data.Pressed == false then
					table.clear(Keyboard_inputs)
					commands.changegroup.Data.Pressed = true
					GuiObjects.Out1.Text = "Enter Resource 1"
					GuiObjects.Out2.Text = "Enter Resource 2"
				else
					return
				end

				repeat
					task.wait(0.1)
					if commands.changegroup.Data.Pressed == false then
						return
					end
					-- Gets the two input values from the keyboard and ensures they are valid material types or Unused for blank groups
					for i, v in Keyboard_inputs do
						Keyboard_inputs[i] = string.match(v, "[^\n]*")
						if partdata.Parts[Keyboard_inputs[i]] or Keyboard_inputs[i] == "Unused" then
							if GuiObjects.Out1.Text ~= Keyboard_inputs[i] and i == 1 then
								GuiObjects.Out1.Text = Keyboard_inputs[i]
							elseif GuiObjects.Out2.Text ~= Keyboard_inputs[i] and i == 2 then
								GuiObjects.Out2.Text = Keyboard_inputs[i]
							end
						else
							if i == 1 then
								GuiObjects.Out1.Text = "type doesnt exist"
							elseif i == 2 then
								GuiObjects.Out2.Text = "type doesnt exist"
							end

							print("Resource type doesnt exist")
							Keyboard_inputs[i] = nil
						end
					end

				until #Keyboard_inputs >= 2
				commands.changegroup.Data.ready = true
			end)

			commands.changegroup.Data.Objects.confirmbutton.MouseButton1Click:Connect(function()
				if commands.changegroup.Data.ready == true then
					local request = task.spawn(function()
						storageserver:Send("changegroup", Keyboard_inputs[1], Keyboard_inputs[2])
						local _, returnval = Microcontroller:Receive()

						if returnval == true then
							GuiObjects.Out1.Text = "Success"
							GuiObjects.Out2.Text = "Group converted"
						else
							GuiObjects.Out1.Text = "Failure"
							GuiObjects.Out2.Text = "Convert failed"
						end
					end)
					task.wait(0.5)
					task.cancel(request)
					commands.changegroup.Data.Pressed = false
					commands.changegroup.Data.ready = false
				end
			end)

			commands.changegroup.Data.Objects.dualobject.MouseButton1Click:Connect(function()
				if commands.changegroup.Data.Pressed == true then
					commands.changegroup.Data.Pressed = false
					GuiObjects.Out1.Text = "Canceled"
					GuiObjects.Out2.Text = "Canceled"
				end
			end)
		end,
		Data = {
			Pressed = false,
			ready = false,
			Objects = {},
		},
	},

	movetemp = {
		setup = function()
			commands.movetemp.Data.Objects = newcommandframe("Move to Temp", true)

			commands.movetemp.Data.Objects.commandbutton.MouseButton1Click:Connect(function()
				if commands.movetemp.Data.Pressed == false then
					table.clear(Keyboard_inputs)
					commands.movetemp.Data.Pressed = true
					GuiObjects.Out1.Text = "Enter Resource and group"
					GuiObjects.Out2.Text = "Enter fill or empty"
				else
					return
				end

				-- running loop to get all usuer inputted values before continuing
				repeat
					task.wait(0.1)
					if commands.movetemp.Data.Pressed == false then
						return
					end

					for i, v in Keyboard_inputs do
						local Firstvalue = string.match(v, "%a*")
						local GroupID = tonumber(string.match(v, "%d+"))

						if i == 1 and partdata.Parts[Firstvalue] and resources[Firstvalue].Ports[GroupID] then
							if GuiObjects.Out1.Text ~= string.match(v, "[^\n]*") then
								GuiObjects.Out1.Text = string.match(v, "[^\n]*")
							end
						elseif i == 2 and (string.lower(Firstvalue) == "empty" or "fill") then --test to make sure this condition works
							if GuiObjects.Out2.Text ~= Firstvalue then
								GuiObjects.Out2.Text = Firstvalue
							end
						else
							if i == 1 then
								GuiObjects.Out1.Text = "Invalid entry"
							elseif i == 2 then
								GuiObjects.Out2.Text = "Invalid entry"
							end
							print("Invalid entry")
							Keyboard_inputs[i] = nil
						end
					end

				until #Keyboard_inputs >= 2
				commands.movetemp.Data.ready = true
			end)

			commands.movetemp.Data.Objects.confirmbutton.MouseButton1Click:Connect(function()
				if commands.movetemp.Data.ready == true then
					local request = task.spawn(function()
						local Firstvalue = string.match(Keyboard_inputs[1], "%a*")
						local GroupID = tonumber(string.match(Keyboard_inputs[1], "%d+"))
						local Secondvalue = string.match(Keyboard_inputs[2], "[^\n]*")

						storageserver:Send("Tempmove", Firstvalue, Secondvalue, resources[Firstvalue].Ports[GroupID])

						local _, returnval = Microcontroller:Receive()

						if returnval == true then
							GuiObjects.Out1.Text = "Success"
							GuiObjects.Out2.Text = "Items moved"
						else
							GuiObjects.Out1.Text = "Failure"
							GuiObjects.Out2.Text = returnval
						end
					end)
					task.wait(0.5)
					task.cancel(request)
					commands.movetemp.Data.Pressed = false
					commands.movetemp.Data.ready = false
				end
			end)
		end,
		Data = {
			Pressed = false,
			ready = false,
			Objects = {},
		},
	},
}

--gui creation functions
local function UICorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0, 8)
	corner.Parent = parent
end

local function UIPad(parent, top, left, right, bottom)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = top or UDim.new(0, 5)
	pad.PaddingLeft = left or UDim.new(0, 5)
	pad.PaddingRight = right or UDim.new(0, 5)
	pad.PaddingBottom = bottom or UDim.new(0, 5)
	pad.Parent = parent
end

local function newframe(parent, options: { color: Color3, size: UDim2, position: UDim2, name: string })
	local frame = Instance.new("Frame")
	frame.Size = options.size
	frame.Position = options.position
	frame.BackgroundColor3 = options.color
	frame.BorderSizePixel = 0
	frame.Name = options.name or "Frame"
	frame.Parent = parent
	return frame
end

local function UITextlabel(parent, options: { color: Color3, size: UDim2, position: UDim2, text: string, name: string })
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

function newcommandframe(command_name, cancel: boolean)
	local frame = newframe(GuiObjects.commandframe, {
		color = Colors.Black,
		size = UDim2.new(1, 0, 0, 100),
		position = UDim2.new(0, 0, 0, 0),
		name = command_name,
	})

	UICorner(frame)
	UIPad(frame, UDim.new(0, 3), UDim.new(0, 3), UDim.new(0, 3), UDim.new(0, 3))

	local commandbutton = Instance.new("TextButton")
	commandbutton.BackgroundColor3 = Colors.ButtonBlue
	commandbutton.Position = UDim2.new(0, 0, 0, 0)
	commandbutton.BorderSizePixel = 0
	commandbutton.TextScaled = true
	commandbutton.Size = UDim2.new(1, 0, 0.5, -1)
	commandbutton.Text = command_name
	commandbutton.Name = "commandbutton"
	commandbutton.Parent = frame
	UICorner(commandbutton)

	local dualobject

	if cancel then
		dualobject = Instance.new("TextButton")
		dualobject.BackgroundColor3 = Colors.ButtonRed
		dualobject.Position = UDim2.new(0, 0, 0.5, 1)
		dualobject.BorderSizePixel = 0
		dualobject.TextScaled = true
		dualobject.Size = UDim2.new(0.5, -1, 0.5, -1)
		dualobject.Text = "Cancel?"
		dualobject.Name = "commandbutton"
		dualobject.Parent = frame
		UICorner(dualobject)
	else
		dualobject = UITextlabel(frame, {
			color = Colors.ButtonBlue,
			position = UDim2.new(0, 0, 0.5, 1),
			size = UDim2.new(0.5, -1, 0.5, -1),
			text = "output",
			name = "Out1",
		})
		UICorner(dualobject)
	end

	local confirmbutton = Instance.new("TextButton")
	confirmbutton.BackgroundColor3 = Colors.PercentageGreen
	confirmbutton.Position = UDim2.new(0.5, 1, 0.5, 1)
	confirmbutton.Size = UDim2.new(0.5, -1, 0.5, -1)
	confirmbutton.BorderSizePixel = 0
	confirmbutton.TextScaled = true
	confirmbutton.Text = "Confirm?"
	confirmbutton.Name = "confirmbutton"
	confirmbutton.Parent = frame
	UICorner(confirmbutton)

	return { ["commandbutton"] = commandbutton, ["confirmbutton"] = confirmbutton, ["dualobject"] = dualobject }
end

local function createmainframes(gui)
	gui.mainframe = newframe(canvas, {
		color = Colors.Black,
		size = UDim2.fromScale(1, 1),
		position = UDim2.fromOffset(0, 0),
		name = "MainFrame",
	})
	UIPad(gui.mainframe)

	gui.infoframe = newframe(gui.mainframe, {
		color = Colors.BackgroundGrey,
		size = UDim2.new(0.7, -5, 1, 0),
		position = UDim2.fromOffset(0, 0),
		name = "InfoFrame",
	})
	UICorner(gui.infoframe)

	gui.commandframe = Instance.new("ScrollingFrame")
	gui.commandframe.Size = UDim2.new(0.3, 0, 0.65, 0)
	gui.commandframe.Position = UDim2.new(0.7, 0, 0, 0)
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
	list.Padding = UDim.new(0, 5)
	list.Parent = gui.commandframe

	-- sets up the output frame
	gui.outputframe = newframe(gui.mainframe, {
		color = Colors.BackgroundGrey,
		size = UDim2.new(0.3, 0, 0.35, -5),
		position = UDim2.new(0.7, 0, 0.65, 5),
		name = "OutputFrame",
	})
	UICorner(gui.outputframe)
	UIPad(gui.outputframe)

	gui.Out1 = UITextlabel(gui.outputframe, {
		color = Colors.ButtonBlue,
		size = UDim2.new(1, 0, 0.5, 0),
		position = UDim2.new(0, 0, 0, 0),
		text = "output 1",
		name = nil,
	})
	UICorner(gui.Out1)

	gui.Out2 = UITextlabel(gui.outputframe, {
		color = Colors.ButtonBlue,
		size = UDim2.new(1, 0, 0.5, -5),
		position = UDim2.new(0, 0, 0.5, 5),
		text = "output 2",
		name = nil,
	})
	UICorner(gui.Out2)
	return gui
end

local function NewresourceFrame(parent, resource, data)
	local Resourcepercentage

	if data.Totalresource and data.Maxresource then
		Resourcepercentage = data.Totalresource / data.Maxresource
	else
		Resourcepercentage = 0
	end

	local frame = newframe(parent, {
		color = Colors.Black,
		size = UDim2.new(0, 0, 0, 0),
		position = UDim2.new(0, 0, 0, 0),
		name = resource,
	})

	UICorner(frame)
	UIPad(frame, UDim.new(0, 3), UDim.new(0, 3), UDim.new(0, 3), UDim.new(0, 3))

	local Resourcebutton = Instance.new("TextButton")
	Resourcebutton.BackgroundColor3 = Colors.ButtonBlue
	Resourcebutton.Position = UDim2.new(0, 0, 0, 0)
	Resourcebutton.BorderSizePixel = 0
	Resourcebutton.TextScaled = true
	Resourcebutton.Size = UDim2.new(1, 0, 0.5, -1)
	Resourcebutton.Text = resource
	Resourcebutton.Parent = frame
	UICorner(Resourcebutton)

	Resourcebutton.MouseButton1Click:Connect(function()
		switchpage(resource)
	end)

	local box2 = UITextlabel(frame, {
		color = Colors.ButtonBlue,
		position = UDim2.new(0, 0, 0.5, 1),
		size = UDim2.new(0.5, -1, 0.5, -1),
		text = data.Totalresource or 0,
		name = "Totalresource",
	})
	UICorner(box2)

	local percentageframe = newframe(frame, {
		color = Colors.BackgroundGreen,
		position = UDim2.new(0.5, 1, 0.5, 1),
		size = UDim2.new(0.5, -1, 0.5, -1),
		name = "Percentage",
	})
	UICorner(percentageframe)
	UIPad(percentageframe, UDim.new(0.05, 0), UDim.new(0.05, 0), UDim.new(0.05, 0), UDim.new(0.05, 0))

	local percentbar = newframe(percentageframe, {
		color = Colors.PercentageGreen,
		position = UDim2.new(0, 0, 0, 0),
		size = UDim2.new(Resourcepercentage, 0, 1, 0),
		name = "Percent",
	})
	UICorner(percentbar)

	local percentbox = UITextlabel(percentageframe, {
		color = Colors.White,
		position = UDim2.new(0, 0, 0, 0),
		size = UDim2.new(1, 0, 1, 0),
		text = math.floor(Resourcepercentage * 100) .. "%", --.." Full"
		name = nil,
	})
	percentbox.BackgroundTransparency = 1
	UICorner(percentbox)
end

local function SetupresourceFrames(gui, resources)
	gui.resources = Instance.new("ScrollingFrame")
	gui.resources.Size = UDim2.new(1, 0, 1, 0)
	gui.resources.Position = UDim2.new(0, 0, 0, 0)
	gui.resources.BackgroundColor3 = Colors.BackgroundGrey
	gui.resources.ScrollBarImageColor3 = Colors.ScrollGrey
	gui.resources.ScrollBarThickness = 8
	gui.resources.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	gui.resources.BorderSizePixel = 0
	gui.resources.Name = "Resources"
	gui.resources.Parent = gui.infoframe

	gui.val = gui.resources:SetAttribute("FrameType", "MainResources")

	UICorner(gui.resources)
	UIPad(gui.resources)

	currentpage = gui.resources

	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.new(0.01, 0, 0.01, 0)
	grid.CellSize = UDim2.new(0.325, 0, 0, 115)
	grid.Parent = gui.resources

	-- all code after this line will need to be moved to a function that can update the gui

	-- sorts the list into alphabetical order
	local alphabetical = {}
	for i, v in pairs(resources) do
		table.insert(alphabetical, i)
	end

	table.sort(alphabetical, function(first, second)
		return first:lower() < second:lower()
	end)
	-- create the frames in that new alphabetical order
	for i, v in alphabetical do
		NewresourceFrame(gui.resources, v, resources[v])
		task.wait(0.25)
	end
end

local function Creategraph(parentframe, points)
	local graph = {}
	local screensize = parentframe.AbsoluteSize
	local xspacing = (screensize.X / #points)
	local largestval = 0
	local posvectors = {}

	for i, v in points do
		if v > largestval then
			largestval = v
		end
	end

	graph.mainfrrame = newframe(parentframe, {
		color = Colors.Black,
		size = UDim2.new(1, 0, 1, 0),
		position = UDim2.new(0, 0, 0, 0),
		name = nil,
	})
	UIPad(graph.mainfrrame, UDim.new(0.02, 0), UDim.new(0.02, 0), UDim.new(0.02, 0), UDim.new(0.02, 0))

	local layout = Instance.new("UITableLayout")
	layout.Padding = UDim2.new(0.02, 0, 0.02, 0)
	layout.FillEmptySpaceColumns = true
	layout.FillEmptySpaceRows = true
	layout.Parent = graph.mainfrrame

	-- creates the grid for the graph
	for i = 1, 10 do
		local row = newframe(graph.mainfrrame, {
			color = Colors.BackgroundGrey,
			size = UDim2.new(0, 0, 0, 0),
			position = UDim2.new(0, 0, 0, 0),
			name = nil,
		})

		row.BackgroundTransparency = 1

		for i = 1, 10 do
			local _block = newframe(row, {
				color = Colors.White,
				position = UDim2.new(0, 0, 0, 0),
				size = UDim2.new(0, 0, 0, 0),
				name = nil,
			})
		end
	end

	-- creates all the points

	for i, v in points do
		local percentage = v / largestval

		posvectors[i] =
			Vector2.new((i - 1) * xspacing + 10, screensize.Y - (math.floor(percentage * screensize.Y) - 10))
		if posvectors[i].y > screensize.Y then
			posvectors[i] = Vector2.new(posvectors[i].X, screensize.Y - 5)
		end

		local frame = newframe(parentframe, {
			color = Colors.PercentageGreen,
			size = UDim2.fromOffset(10, 10),
			position = UDim2.new(0, posvectors[i].X, 0, posvectors[i].Y),
			name = nil,
		})
		frame.ZIndex = 5
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		UICorner(frame, UDim.new(1, 0))
	end

	-- make the lines
	for i, v in posvectors do
		if posvectors[i + 1] then
			local magnitude = (posvectors[i + 1] - posvectors[i]).Magnitude
			local angle = math.atan2(posvectors[i + 1].Y - posvectors[i].Y, posvectors[i + 1].X - posvectors[i].X)
				* (180 / math.pi)

			local line = newframe(parentframe, {
				color = Colors.linegreen,
				size = UDim2.fromOffset(magnitude, 5),
				position = UDim2.new(
					0,
					(posvectors[i + 1].X + posvectors[i].X) / 2,
					0,
					(posvectors[i + 1].Y + posvectors[i].Y) / 2
				),
				name = nil,
			})
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Rotation = angle
			line.ZIndex = 4
		end
	end
end

local function populatetable(parent, data, resource)
	for i, v in parent:GetChildren() do
		if v.Name == "group" then
			v:Destroy()
		end
	end

	for i, v in data[resource].ItemsperGroup do
		local guide = newframe(parent, {
			color = Colors.Black,
			size = UDim2.new(0, 0, 0, 0),
			position = UDim2.new(0, 0, 0, 0),
			name = "group",
		})
		UICorner(guide)

		local index = UITextlabel(guide, {
			color = Colors.ButtonBlue,
			size = UDim2.new(0, 0, 0.15, 0),
			position = UDim2.new(0, 0, 0, 0),
			text = i,
			name = "Index",
		})
		UICorner(index)
		index:SetAttribute("Index", i)

		local Val = UITextlabel(guide, {
			color = Colors.ButtonBlue,
			size = UDim2.new(0, 0, 0.15, 0),
			position = UDim2.new(0, 0, 0, 0),
			text = v,
			name = "Value",
		})
		UICorner(Val)
	end
end

local function createresourcepage(resource, data, gui, averagedpoints)
	local page = newframe(gui.infoframe, {
		color = Colors.BackgroundGrey,
		size = UDim2.new(1, 0, 1, 0),
		position = UDim2.new(0, 0, 0, 0),
		name = resource,
	})
	UICorner(page)
	UIPad(page)

	page:SetAttribute("FrameType", "Resourcepage")

	local graphframe = newframe(page, {
		color = Colors.White,
		size = UDim2.new(0.62, 0, 0.62, 0),
		position = UDim2.new(0.41, 0, 0.3, 0),
		name = "Graph",
	})
	UICorner(graphframe)

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = graphframe

	local total = UITextlabel(page, {
		color = Colors.ButtonBlue,
		size = UDim2.new(0.3, 0, 0.08, 0),
		position = UDim2.new(0.45, 0, 0, 0),
		text = "<b>Total Resource:</b>",
		name = "Totalresourcetext",
	})
	total.RichText = true
	UICorner(total)

	local total2 = UITextlabel(page, {
		color = Colors.ButtonBlue,
		size = UDim2.new(0.25, 0, 0.08, 0),
		position = UDim2.new(0.75, 0, 0, 0),
		text = (data[resource].Totalresource or "0"),
		name = "Totalresourcenumber",
	})

	UICorner(total2)

	local resourcedisplay = UITextlabel(page, {
		color = Colors.ButtonBlue,
		size = UDim2.new(1, 0, 0.2, 0),
		position = UDim2.new(0, 0, 0.09, 0),
		text = resource,
		name = "Resourcetype",
	})
	UICorner(resourcedisplay)

	local backbutton = Instance.new("TextButton")
	backbutton.Size = UDim2.new(0.4, 0, 0.08, 0)
	backbutton.Position = UDim2.new(0, 0, 0, 0)
	backbutton.BackgroundColor3 = Colors.ButtonRed
	backbutton.Parent = page
	backbutton.TextScaled = true
	backbutton.Text = "<--"
	UICorner(backbutton, UDim.new(1, 0))

	-- creates the table and the graph of the resource over time
	local tablescrol = Instance.new("ScrollingFrame")
	tablescrol.BackgroundColor3 = Colors.Black
	tablescrol.Position = UDim2.new(0, 0, 0.3, 0)
	tablescrol.Size = UDim2.new(0.4, 0, 0.7, 0)
	tablescrol.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tablescrol.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	tablescrol.ScrollBarThickness = 8
	tablescrol.Parent = page
	tablescrol.Name = "Tableframe"
	tablescrol.AutomaticCanvasSize = Enum.AutomaticSize.Y
	UICorner(tablescrol)
	UIPad(tablescrol)

	if data[resource].ItemsperGroup then
		-- creates the graph and table
		local table_layout = Instance.new("UITableLayout")
		table_layout.Padding = UDim2.new(0, 5, 0, 5)
		table_layout.FillEmptySpaceColumns = true
		table_layout.SortOrder = Enum.SortOrder.LayoutOrder
		table_layout.Parent = tablescrol

		-- creates the tables index
		local guide = newframe(tablescrol, {
			color = Colors.Black,
			size = UDim2.new(0, 0, 0, 0),
			position = UDim2.new(0, 0, 0, 0),
			name = "Index",
		})
		UICorner(guide)

		local group = UITextlabel(guide, {
			color = Colors.ButtonBlue,
			size = UDim2.new(0, 0, 0.15, 0),
			position = UDim2.new(0, 0, 0, 0),
			text = "Group",
			name = "Group",
		})
		UICorner(group)

		local quantity = UITextlabel(guide, {
			color = Colors.ButtonBlue,
			size = UDim2.new(0, 0, 0.15, 0),
			position = UDim2.new(0, 0, 0, 0),
			text = "Quantity",
			name = "Quantity",
		})
		UICorner(quantity)

		populatetable(tablescrol, data, resource)

		--create the graph
		if averagedpoints then
			Creategraph(graphframe, averagedpoints)
		else
			--leaves a message saying no data available
			local _graphtext = UITextlabel(graphframe, {
				color = Colors.BackgroundGreen,
				size = UDim2.new(1, 0, 1, 0),
				position = UDim2.fromScale(0, 0),
				text = "No Data Available for graph",
				name = nil,
			})
		end
	else
		-- lists a error for both saying data not available
		local _groupframe = UITextlabel(tablescrol, {
			color = Colors.BackgroundGreen,
			size = UDim2.new(1, -13, 0.5, 0),
			position = UDim2.fromScale(0, 0),
			text = "No Data Available",
			name = nil,
		})

		local _graphtext = UITextlabel(graphframe, {
			color = Colors.BackgroundGreen,
			size = UDim2.new(1, 0, 1, 0),
			position = UDim2.fromScale(0, 0),
			text = "No Data Available for graph",
			name = nil,
		})
	end

	backbutton.MouseButton1Click:Connect(function()
		switchpage("Resources")
		for i, v in graphframe:GetChildren() do
			if v.ClassName == "Frame" then
				v:Destroy()
			end

			if v.ClassName == "TextLabel" then
				v:Destroy()
			end
		end

		for i, v in tablescrol:GetChildren() do
			if v.Name == "group" then
				v:Destroy()
			end
		end
	end)

	return page
end

local function average(raw, numpoints)
	if not raw then
		return nil
	end

	local pointsperaverage = math.floor(#raw / numpoints)
	local averaged = {}

	if pointsperaverage >= 1 then
		for i = 1, numpoints do
			local startpoint = ((i * pointsperaverage) - pointsperaverage) + 1
			averaged[i] = 0
			local endpoint
			if (i * pointsperaverage) > #raw then
				endpoint = #raw
			else
				endpoint = (i * pointsperaverage)
			end

			for k = startpoint, endpoint do
				averaged[i] += raw[k]
			end

			averaged[i] = averaged[i] / ((endpoint - startpoint) + 1)
		end
	else
		return nil
	end

	return average
end

local function Updateresourceamount()
	storageserver:Send("refresh_resources")

	local listen = task.spawn(function()
		local _, data = Microcontroller:Receive()
		for i, v in data do
			if v.Totalresource then
				if not Raw_resource_data[i] then
					Raw_resource_data[i] = {}
				end
				-- stores an hours worth of data points
				if #Raw_resource_data[i] < raw_data_points then
					table.insert(Raw_resource_data[i], v.Totalresource)
				else
					table.remove(Raw_resource_data[i], 1)
					table.insert(Raw_resource_data[i], v.Totalresource)
				end
			end
		end
		disk:Write("Raw_resource_data", Raw_resource_data)
		resources = data
	end)

	task.wait(0.5)
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
			local averagedpoints = average(Raw_resource_data[page], average_data_points)

			if resources[page].ItemsperGroup then
				populatetable(currentpage.Tableframe, resources, page)
			end

			if averagedpoints then
				Creategraph(currentpage["Graph"], averagedpoints)
			else
				local _graphtext = UITextlabel(currentpage["Graph"], {
					color = Colors.BackgroundGreen,
					size = UDim2.new(1, 0, 1, 0),
					position = UDim2.fromScale(0, 0),
					text = "No Data Available for graph",
					name = nil,
				})
			end
		end
		--GuiObjects.infoframe.resources.Visible = false
	else
		currentpage.Visible = false
		currentpage =
			createresourcepage(page, resources, GuiObjects, average(Raw_resource_data[page], average_data_points))
	end
end

Updateresourceamount()
GuiObjects = createmainframes(GuiObjects)
SetupresourceFrames(GuiObjects, resources)

for i, v in commands do
	v.setup()
end

-- events
keyboard.TextInputted:Connect(function(text, player)
	table.insert(Keyboard_inputs, text)
end)

--storageserver:Send("Tempmove","Copper","Empty",resources.Copper.Ports[1])

-- main running
while task.wait(2) do
	Updateresourceamount()
	local frametype = currentpage:GetAttribute("FrameType")

	if frametype == "MainResources" then
		local alphabetical = {}
		for i, v in pairs(resources) do
			table.insert(alphabetical, i)
		end

		table.sort(alphabetical, function(first, second)
			return first:lower() < second:lower()
		end)
		-- create the frames in that new alphabetical order
		for i, v in alphabetical do
			if not currentpage:FindFirstChild(v) then
				NewresourceFrame(GuiObjects.resources, v, resources[v])
				task.wait(0.25)
			end
		end

		for i, v in currentpage:GetChildren() do
			if v.ClassName == "Frame" and resources[v.Name] then
				local percentage
				if resources[v.Name].Totalresource and resources[v.Name].Maxresource then
					percentage = resources[v.Name].Totalresource / resources[v.Name].Maxresource
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

				if
					percenttxt.Text ~= math.floor(percentage * 100) .. "%"--[[.." Full"]]
				then
					percenttxt.Text = math.floor(percentage * 100) .. "%" --[[.." Full"]]
					percent.Size = UDim2.new(percentage, 0, 1, 0)
				end

				task.wait(0.5)
			elseif v.ClassName == "Frame" and not resources[v.Name] then
				v:Destroy()
				if Raw_resource_data[v.Name] then
					Raw_resource_data[v.Name] = nil
				end
			end
		end
	elseif frametype == "Resourcepage" then
		if resources[currentpage.Name] then
			if currentpage["Totalresourcetext"].Text ~= "<b>Total Resource:</b>" then
				currentpage["Totalresourcetext"].Text = "<b>Total Resource:</b>"
			end

			if currentpage["Totalresourcenumber"].Text ~= (resources[currentpage.Name].Totalresource or 0) then
				currentpage["Totalresourcenumber"].Text = (resources[currentpage.Name].Totalresource or 0)
			end

			if currentpage["Resourcetype"].Text ~= currentpage.Name then
				currentpage["Resourcetype"].Text = currentpage.Name
			end
			-- updates the table frame

			if currentpage["Tableframe"]:FindFirstChild("UITableLayout") then
				if currentpage["Tableframe"]["Index"]["Group"].Text ~= "Group" then
					currentpage["Tableframe"]["Index"]["Group"].Text = "Group"
				end

				if currentpage["Tableframe"]["Index"]["Quantity"].Text ~= "Quantity" then
					currentpage["Tableframe"]["Index"]["Quantity"].Text = "Quantity"
				end

				local indexes = 0
				for i, v in currentpage["Tableframe"]:GetChildren() do
					if v.Name == "group" then
						indexes += 1

						if v["Index"].Text ~= tostring(v["Index"]:GetAttribute("Index")) then
							v["Index"].Text = v["Index"]:GetAttribute("Index")
						end

						if resources[currentpage.Name].ItemsperGroup[v["Index"]:GetAttribute("Index")] then
							if
								v["Value"].Text
								~= tostring(resources[currentpage.Name].ItemsperGroup[v["Index"]:GetAttribute("Index")])
							then
								v["Value"].Text =
									resources[currentpage.Name].ItemsperGroup[v["Index"]:GetAttribute("Index")]
							end
						else
							continue
						end
					end
				end
				-- recreates the table if groups got changed around
				if indexes ~= #resources[currentpage.Name].ItemsperGroup then
					local count = 0
					if #resources[currentpage.Name].ItemsperGroup == 0 then
						for i, v in resources[currentpage.Name].ItemsperGroup do
							count += 1
						end
						if indexes ~= count then
							populatetable(currentpage["Tableframe"], resources, currentpage.Name)
						end
					else
						populatetable(currentpage["Tableframe"], resources, currentpage.Name)
					end
				end
			end
		else
			switchpage("Resources")
		end
	end
end
