local Root = script.Parent.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local UI = Root:WaitForChild 'UI'
local UserInputService = game:GetService 'UserInputService'

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Roact = require(Libraries:WaitForChild 'Roact')
local Janitor = require(Libraries:WaitForChild 'Janitor')

-- Roact
local new = Roact.createElement
local Frame = require(UI:WaitForChild 'Frame')
local ImageLabel = require(UI:WaitForChild 'ImageLabel')
local ImageButton = require(UI:WaitForChild 'ImageButton')
local TextLabel = require(UI:WaitForChild 'TextLabel')
local TextBox = require(UI:WaitForChild 'TextBox')

-- Create component
local ItemRow = Roact.PureComponent:extend 'ItemRow'

function ItemRow:GetParts()
    local Object = self.props.Instance

    -- Return part for parts
    if Object:IsA 'BasePart' then
        return { Object }

    -- Return descendant parts for model
    elseif Object:IsA 'Model' then
        local Parts = {}
        for _, Part in pairs(Object:GetDescendants()) do
            if Part:IsA 'BasePart' then
                Parts[#Parts + 1] = Part
            end
        end
        return Parts
    end
end

function ItemRow:ToggleLock()
    local props = self.props

    -- Create history record
    local Parts = self:GetParts()
    local HistoryRecord = {
        Parts = Parts,
        BeforeLocked = Support.GetListMembers(Parts, 'Locked'),
        AfterLocked = not props.IsLocked
    }

    function HistoryRecord:Unapply()
        props.SyncAPI:Invoke('SetLocked', self.Parts, self.BeforeLocked)
    end

    function HistoryRecord:Apply()
        props.SyncAPI:Invoke('SetLocked', self.Parts, self.AfterLocked)
    end

    -- Send lock toggling request to gameserver
    HistoryRecord:Apply()

    -- Register history record
    props.History.Add(HistoryRecord)

end

function ItemRow:SetName(Name)
    local props = self.props

    -- Create history record
    local HistoryRecord = {
        Items = { props.Instance },
        BeforeName = props.Instance.Name,
        AfterName = Name
    }

    function HistoryRecord:Unapply()
        props.SyncAPI:Invoke('SetName', self.Items, self.BeforeName)
    end

    function HistoryRecord:Apply()
        props.SyncAPI:Invoke('SetName', self.Items, self.AfterName)
    end

    -- Send renaming request to gameserver
    HistoryRecord:Apply()

    -- Register history record
    props.History.Add(HistoryRecord)

end

function ItemRow:HandleSelection()
    local props = self.props
    local Selection = props.Selection

    -- Check if multiselecting
    local PressedKeys = UserInputService:GetKeysPressed()
    local Multiselecting = Support.IsInTable(Support.GetListMembers(PressedKeys, 'KeyCode'), Enum.KeyCode.LeftControl) or
        Support.IsInTable(PressedKeys, Enum.KeyCode.RightControl)

    -- Perform selection
    if Multiselecting then
        if not Selection.IsSelected(props.Instance) then
            Selection.Add({ props.Instance }, true)
        else
            Selection.Remove({ props.Instance }, true)
        end
    else
        Selection.Replace({ props.Instance }, true)
    end
end

function ItemRow:ToggleExpand()
    self.props.ToggleExpand(self.props.Id)
end

ItemRow.ClassIcons = {
    Part = Vector2.new(2, 1),
    MeshPart = Vector2.new(4, 8),
    UnionOperation = Vector2.new(4, 8),
    NegateOperation = Vector2.new(3, 8),
    VehicleSeat = Vector2.new(6, 4),
    Seat = Vector2.new(6, 4),
    TrussPart = Vector2.new(2, 1),
    CornerWedgePart = Vector2.new(2, 1),
    WedgePart = Vector2.new(2, 1),
    SpawnLocation = Vector2.new(6, 3),
    Model = Vector2.new(3, 1),
    Folder = Vector2.new(8, 8)
}

function ItemRow:render()
    local props = self.props
    local state = self.state

    -- Determine icon for class
    local IconPosition = ItemRow.ClassIcons[props.Class] or Vector2.new(1, 1)

    -- Item information
    local Metadata = new(Frame, {
        Layout = 'List',
        LayoutDirection = 'Horizontal',
        VerticalAlignment = 'Center'
    },
    {
        StartSpacer = new(Frame, {
            AspectRatio = (5 + 10 * props.Depth) / 18,
            LayoutOrder = 0
        }),

        -- Class icon
        Icon = new(ImageLabel, {
            AspectRatio = 1,
            Image = 'rbxassetid://2245672825',
            ImageRectOffset = (IconPosition - Vector2.new(1, 1)) * Vector2.new(16, 16),
            ImageRectSize = Vector2.new(16, 16),
            Size = UDim2.new(1, 0, 12/18, 0),
            LayoutOrder = 1
        }),

        IconSpacer = new(Frame, {
            AspectRatio = 5/18,
            LayoutOrder = 2
        }),

        -- Item name
        NameContainer = new(ImageButton, {
            Layout = 'List',
            Size = 'WRAP_CONTENT',
            LayoutOrder = 3,
            [Roact.Event.Activated] = function (rbx)
                local CurrentTime = tick()
                if self.LastNameClick and (CurrentTime - self.LastNameClick) <= 0.25 then
                    self:setState { EditingName = true }
                else
                    self.LastNameClick = CurrentTime
                    self:HandleSelection()
                end
            end
        },
        {
            Name = (not state.EditingName) and new(TextLabel, {
                TextSize = 13,
                TextColor = 'FFFFFF',
                Text = props.Name,
                Size = 'WRAP_CONTENT'
            }),
            NameInput = state.EditingName and new(TextBox, {
                TextSize = 13,
                TextColor = 'FFFFFF',
                Text = props.Name,
                Size = 'WRAP_CONTENT',
                [Roact.Event.FocusLost] = function (rbx, EnterPressed)
                    if EnterPressed then
                        self:SetName(rbx.Text)
                        self:setState { EditingName = Roact.None }
                    end
                end
            })
        })
    })

    -- Item buttons
    local Buttons = new(Frame, {
        Layout = 'List',
        LayoutDirection = 'Horizontal',
        HorizontalAlignment = 'Right',
        VerticalAlignment = 'Center',
        Width = 'WRAP_CONTENT',
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0)
    },
    {
        -- Locking button
        Lock = new(ImageButton, {
            AspectRatio = 1,
            Image = 'rbxassetid://2244452978',
            ImageRectOffset = Vector2.new(14 * (props.IsLocked and 2 or 1), 0) * 2,
            ImageRectSize = Vector2.new(14, 14) * 2,
            Size = UDim2.new(1, 0, 12/18, 0),
            ImageTransparency = 1 - (props.IsLocked and 0.75 or 0.15),
            LayoutOrder = 0,
            [Roact.Event.Activated] = function ()
                self:ToggleLock()
            end
        }),

        Spacer = new(Frame, {
            LayoutOrder = 1,
            AspectRatio = 1/10
        }),

        -- Item expansion arrow
        ArrowWrapper = next(props.Children) and new(Frame, {
            AspectRatio = 1,
            Size = UDim2.new(1, 0, 14/18, 0),
            LayoutOrder = 2
        },
        {
            Arrow = new(ImageButton, {
                Image = 'rbxassetid://2244452978',
                ImageRectOffset = Vector2.new(14 * 3, 0) * 2,
                ImageRectSize = Vector2.new(14, 14) * 2,
                Rotation = props.Expanded and 180 or 90,
                ImageTransparency = 1 - 0.15,
                [Roact.Event.Activated] = function ()
                    self:ToggleExpand()
                end
            })
        }),

        EndSpacer = new(Frame, {
            LayoutOrder = 3,
            AspectRatio = 1/20
        })
    })

    -- Return button with contents
    return new(ImageButton, {
        LayoutOrder = props.Order,
        Size = UDim2.new(1, 0, 0, 18),
        AutoButtonColor = false,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = props.Selected and (1 - 0.15) or 1,
        [Roact.Event.Activated] = function (rbx)
            self:HandleSelection()
        end
    },
    {
        Metadata = Metadata,
        Buttons = Buttons
    })
end

return ItemRow