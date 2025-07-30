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
                if i == 1 or prev_char == '{' or prev_char == '[' then
                    formatted = formatted .. char
                elseif prev_char == ',' then
                    level = level + 1
                    formatted = formatted .. indent .. char
                else
                    level = level + 1
                    formatted = formatted .. "\n" .. string.rep(indent, level) .. char
                end
                level = level + 1
                formatted = formatted .. "\n" .. string.rep(indent, level)
            elseif char == '}' or char == ']' then
                level = level - 1
                formatted = formatted .. "\n" .. string.rep(indent, level) .. char
            elseif char == ',' then
                if prev_char == '}' or prev_char == ']' then
                    level = level - 1
                end
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
    print("Formatted JSON:\n" .. formatted)
    return formatted
end

-- Build dependencies
M.extract_dependencies = function(body, key_table)
    local deps = {}
    for dep in body:gmatch("\\([a-zA-Z]+)") do
        if key_table[dep] then
            -- If the command is in the key table, add the dependency
            table.insert(deps, dep)
        end
    end
    return deps
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