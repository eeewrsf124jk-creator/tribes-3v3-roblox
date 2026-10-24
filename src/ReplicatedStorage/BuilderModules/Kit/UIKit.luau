--!strict
-- UIKit: scale-based (UDim2.fromScale) responsive GUI primitives with UICorner, UIStroke,
-- UIGradient, UIListLayout, UIGridLayout, UIAspectRatioConstraint, UIPadding and
-- UITextSizeConstraint applied with explicit values.

local UIKit = {}

local RGB = Color3.fromRGB

UIKit.Theme = {
	Panel = RGB(18, 20, 28),
	PanelLight = RGB(32, 36, 48),
	PanelLighter = RGB(48, 54, 70),
	Stroke = RGB(80, 88, 110),
	Text = RGB(245, 245, 250),
	SubText = RGB(170, 176, 196),
	Gold = RGB(255, 200, 60),
	Alpha = RGB(60, 140, 255),
	Bravo = RGB(255, 70, 60),
	Good = RGB(80, 220, 120),
	Bad = RGB(235, 70, 70),
	Armor = RGB(70, 160, 255),
	Health = RGB(90, 220, 110),
	Black = RGB(0, 0, 0),
	White = RGB(255, 255, 255),
	Fonts = {
		Title = Enum.Font.GothamBlack,
		Bold = Enum.Font.GothamBold,
		Body = Enum.Font.GothamMedium,
		Mono = Enum.Font.RobotoMono,
	},
}

local T = UIKit.Theme

function UIKit.Screen(parent: Instance?, name: string, displayOrder: number, enabled: boolean): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = displayOrder
	g.Enabled = enabled
	g.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	g.Parent = parent
	return g
end

function UIKit.Frame(parent: Instance, name: string, size: UDim2, pos: UDim2, anchor: Vector2?, color: Color3?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = color or T.Panel
	f.BackgroundTransparency = if transparency == nil then 0.1 else transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- Invisible container frame (layout grouping).
function UIKit.Group(parent: Instance, name: string, size: UDim2, pos: UDim2, anchor: Vector2?): Frame
	return UIKit.Frame(parent, name, size, pos, anchor, T.Panel, 1)
end

function UIKit.Corner(inst: GuiObject, scale: number?, offset: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0, offset or 8)
	c.Parent = inst
	return c
end

function UIKit.Stroke(inst: GuiObject, color: Color3?, thickness: number?, transparency: number?, mode: Enum.ApplyStrokeMode?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or T.Stroke
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = inst
	return s
end

function UIKit.Gradient(inst: GuiObject, colors: ColorSequence, rotation: number?, transparency: NumberSequence?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = colors
	g.Rotation = rotation or 90
	if transparency then
		g.Transparency = transparency
	end
	g.Parent = inst
	return g
end

function UIKit.Grad2(a: Color3, b: Color3): ColorSequence
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b) })
end

function UIKit.List(inst: GuiObject, direction: Enum.FillDirection, padding: number, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction
	l.Padding = UDim.new(padding, 0)
	l.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center
	l.VerticalAlignment = vAlign or Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = inst
	return l
end

function UIKit.Grid(inst: GuiObject, cell: UDim2, padding: UDim2, perRow: number?): UIGridLayout
	local g = Instance.new("UIGridLayout")
	g.CellSize = cell
	g.CellPadding = padding
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.FillDirection = Enum.FillDirection.Horizontal
	g.HorizontalAlignment = Enum.HorizontalAlignment.Left
	g.VerticalAlignment = Enum.VerticalAlignment.Top
	if perRow then
		g.FillDirectionMaxCells = perRow
	end
	g.Parent = inst
	return g
end

function UIKit.Aspect(inst: GuiObject, ratio: number, dominant: Enum.DominantAxis?): UIAspectRatioConstraint
	local a = Instance.new("UIAspectRatioConstraint")
	a.AspectRatio = ratio
	a.AspectType = Enum.AspectType.FitWithinMaxSize
	a.DominantAxis = dominant or Enum.DominantAxis.Width
	a.Parent = inst
	return a
end

function UIKit.Padding(inst: GuiObject, scale: number): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(scale, 0)
	p.PaddingBottom = UDim.new(scale, 0)
	p.PaddingLeft = UDim.new(scale, 0)
	p.PaddingRight = UDim.new(scale, 0)
	p.Parent = inst
	return p
end

function UIKit.Text(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2,
	color: Color3?,
	font: Enum.Font?,
	alignX: Enum.TextXAlignment?,
	maxTextSize: number?
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.TextColor3 = color or T.Text
	l.Font = font or T.Fonts.Bold
	l.TextScaled = true
	l.TextWrapped = true
	l.RichText = true
	l.TextXAlignment = alignX or Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxTextSize or 48
	c.MinTextSize = 6
	c.Parent = l
	return l
end

function UIKit.Button(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, color: Color3?, textColor: Color3?, anchor: Vector2?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = pos
	b.AnchorPoint = anchor or Vector2.zero
	b.BackgroundColor3 = color or T.PanelLighter
	b.BackgroundTransparency = 0
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.TextColor3 = textColor or T.Text
	b.Font = T.Fonts.Title
	b.TextScaled = true
	b.RichText = true
	b.Parent = parent
	UIKit.Corner(b, 0.2, 0)
	UIKit.Stroke(b, Color3.new(0, 0, 0), 1.5, 0.4)
	UIKit.Gradient(b, UIKit.Grad2(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 200)), 90)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 30
	c.MinTextSize = 6
	c.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = b
	return b
end

-- Panel with the standard look: corner 0.04, 2px stroke, dark vertical gradient.
function UIKit.Panel(parent: Instance, name: string, size: UDim2, pos: UDim2, anchor: Vector2?, aspect: number?): Frame
	local f = UIKit.Frame(parent, name, size, pos, anchor, T.Panel, 0.08)
	UIKit.Corner(f, 0.04, 0)
	UIKit.Stroke(f, T.Stroke, 2, 0.2)
	UIKit.Gradient(f, UIKit.Grad2(T.PanelLight, T.Panel), 90)
	if aspect then
		UIKit.Aspect(f, aspect)
	end
	return f
end

-- Progress bar: returns background and fill (fill width is driven by Size.X.Scale).
function UIKit.Bar(parent: Instance, name: string, size: UDim2, pos: UDim2, fillColor: Color3, bgColor: Color3?): (Frame, Frame)
	local bg = UIKit.Frame(parent, name, size, pos, nil, bgColor or Color3.fromRGB(10, 10, 14), 0.25)
	UIKit.Corner(bg, 0.5, 0)
	UIKit.Stroke(bg, Color3.new(0, 0, 0), 1.5, 0.3)
	local fill = UIKit.Frame(bg, "Fill", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), nil, fillColor, 0)
	UIKit.Corner(fill, 0.5, 0)
	UIKit.Gradient(fill, UIKit.Grad2(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)), 90)
	return bg, fill
end

function UIKit.TextBox(parent: Instance, name: string, placeholder: string, size: UDim2, pos: UDim2): TextBox
	local t = Instance.new("TextBox")
	t.Name = name
	t.PlaceholderText = placeholder
	t.Text = ""
	t.Size = size
	t.Position = pos
	t.BackgroundColor3 = T.PanelLight
	t.BorderSizePixel = 0
	t.TextColor3 = T.Text
	t.PlaceholderColor3 = T.SubText
	t.Font = T.Fonts.Bold
	t.TextScaled = true
	t.ClearTextOnFocus = false
	t.Parent = parent
	UIKit.Corner(t, 0.2, 0)
	UIKit.Stroke(t, T.Stroke, 1.5, 0.2)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 24
	c.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = t
	return t
end

-- Close "X" button at the top-right of a modal.
function UIKit.CloseButton(parent: Instance): TextButton
	local b = UIKit.Button(parent, "CloseButton", "✕", UDim2.fromScale(0.05, 0.07), UDim2.fromScale(0.985, 0.015), T.Bad, T.White, Vector2.new(1, 0))
	UIKit.Aspect(b, 1)
	return b
end

-- Find a descendant by slash path, erroring with a clear message if the UI tree is malformed.
function UIKit.Get(root: Instance, path: string): Instance
	local node: Instance = root
	for segment in string.gmatch(path, "[^/]+") do
		local child = node:FindFirstChild(segment)
		if child == nil then
			error(string.format("UI element missing: %s/%s (looking for %s)", root:GetFullName(), path, segment))
		end
		node = child
	end
	return node
end

return UIKit
