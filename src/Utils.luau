local Timer = {}
Timer.__index = Timer

function Timer.new(callback)
    return setmetatable({
        _callback = callback,
        _alive = false,
        _token = 0,
    }, Timer)
end

function Timer:start(delaySeconds)
    self._token += 1
    local token = self._token
    self._alive = true

    task.delay(delaySeconds, function()
        if self._alive and self._token == token then
            self._callback()
            self._alive = false
        end
    end)
end

function Timer:cancel()
    self._alive = false
end



function flattenTable(tbl, prefix, out)
    out = out or {}
    prefix = prefix or ""

    for key, value in pairs(tbl) do
        local fullKey = prefix ~= "" and (prefix .. "." .. key) or key

        if typeof(value) == "table" then
            flattenTable(value, fullKey, out)
        else
            out[fullKey] = value
        end
    end

    return out
end

function valToAttrVal(val)
    local oType = type(val);
	if(oType ~= "string" and oType ~= "number" and oType ~= "boolean") then
		val = tostring(val); -- Force string if it's other than number or bool
		oType = "string";
	end
	if(oType == "number") then
		if val%1 == 0 then oType = "integer"
		else oType = "double" end
	end
    return {
        value = val;
		type = oType;
    }
end

return {
    Timer=Timer;
    flattenTable=flattenTable;
    valToAttrVal=valToAttrVal;
}