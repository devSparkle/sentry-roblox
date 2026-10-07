local Table = {}

local function Copy(Value: any, Seen: { [any]: any }): any
	if type(Value) ~= "table" then return Value end

	local Existing = Seen[Value]

	if Existing ~= nil then return Existing end

	local Clone = table.clone(Value)
	Seen[Value] = Clone

	for Key, Item in next, Clone do
		Clone[Key] = Copy(Item, Seen)
	end

	return Clone
end

function Table.DeepCopy<T>(Value: T): T
	return Copy(Value, {}) :: any
end

local function MergeInto(Base: any, Override: any, Seen: { [any]: any }): any
	if type(Base) ~= "table" or type(Override) ~= "table" then return Override end

	local Existing = Seen[Base]

	if Existing ~= nil then return Existing end

	local Result = table.clone(Base)
	Seen[Base] = Result

	for Key, Value in next, Override do
		local Prior = Result[Key]

		if type(Prior) == "table" and type(Value) == "table" then
			Result[Key] = MergeInto(Prior, Value, Seen)
		else
			Result[Key] = Value
		end
	end

	return Result
end

function Table.Merge(Base: { [any]: any }, Override: { [any]: any }): { [any]: any }
	return MergeInto(Base, Override, {})
end

Table.MaximumDepth = 32

local function SanitizeValue(Value: any, Seen: { [any]: any }, Depth: number, MaximumDepth: number): any
	local Kind = type(Value)

	if Kind == "function" or Kind == "thread" or Kind == "userdata" then return nil end

	if Kind ~= "table" then return Value end

	if Depth >= MaximumDepth then return nil end

	if Seen[Value] ~= nil then return nil end

	Seen[Value] = true

	local Out = {}

	for Key, Item in next, Value do
		local KeyKind = type(Key)

		if KeyKind == "string" or KeyKind == "number" then
			local Clean = SanitizeValue(Item, Seen, Depth + 1, MaximumDepth)

			if Clean ~= nil then Out[Key] = Clean end
		end
	end

	Seen[Value] = nil

	return Out
end

function Table.Sanitize<T>(Value: T, MaximumDepth: number?): T
	return SanitizeValue(Value, {}, 0, MaximumDepth or Table.MaximumDepth) :: any
end

return table.freeze(Table)
