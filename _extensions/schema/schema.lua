print("Schema Functions Loaded")
local M = {}

-- Pretty Print JSON
M.pretty_json = function(json_str)
    indent = "  "
    local level = 0
    local formatted = ""
    local in_string = false
    local char = ""
    local prev_char = ""

    for i = 1, #json_str do
        char = json_str:sub(i, i)
        if char == '"' and prev_char ~= '\\' then
            in_string = not in_string
        end
        if not in_string then
            if char == '{' or char == '[' then
                level = level + 1
                formatted = formatted .. char .. "\n" .. string.rep(indent, level)
            elseif char == '}' or char == ']' then
                level = level - 1
                formatted = formatted .. "\n" .. string.rep(indent, level) .. char
            elseif char == ',' then
                formatted = formatted .. char .. "\n" .. string.rep(indent, level)
            elseif char == ':' then
                formatted = formatted .. ": "
            else
                formatted = formatted .. char
            end
        else
            formatted = formatted .. char
        end
        prev_char = char
    end
    return formatted
end

-- Build dependencies
M.extract_dependencies = function(body, key_table, regex)
    local deps = {}
    for dep in body:gmatch(regex) do
        if key_table[dep] then
            -- If the command is in the key table, add the dependency
            deps[dep] = true
        end
    end
    local output = {}
    for k, v in pairs(deps) do
        table.insert(output, k)
    end
    return output
end

-- Topological sort
M.topo_sort = function(graph)
    local visited = {}
    local result = {}

    local function visit(node)
        if not visited[node] then
            visited[node] = true
            if graph[node] then
                for _, dep in ipairs(graph[node]) do
                    if graph[dep] then
                        visit(dep)
                    end
                end
            end
            table.insert(result, node)
        end
    end

    for node, _ in pairs(graph) do
        visit(node)
    end
    return result
end

return M