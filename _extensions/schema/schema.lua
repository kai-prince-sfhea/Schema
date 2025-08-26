local M = {}

local pandoc = require("pandoc")

-- Escape Pattern Function (found on Reddit)
M.escape_pattern = function(str)
    return str:gsub('([%^%$%(%)%%%.%[%]%*%+%-%q?])', '%%%1')
end

-- Meta Boolean Function
M.meta_bool = function(v)
    if v == nil then return false end
    if type(v) == "boolean" then return v end
    if type(v) == "table" and v.t == "MetaBool" then return v.c end
    if type(v) == "string" then return v:lower() == "true" end
    return false
end

-- Pretty Print JSON
M.pretty_json = function(json_str)
    indent = "  "
    local level = 0
    local formatted = ""
    local in_str = false
    local char = ""
    local prev_char = ""

    for i = 1, #json_str do
        char = json_str:sub(i, i)
        if char == '"' and prev_char ~= '\\' then
            in_str = not in_str
        end
        if not in_str then
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

M.json_encode = function(table)
    local output_string = ""
    if quarto and quarto.json then
        output_string = quarto.json.encode(table)
    else
        output_string = pandoc.json.encode(table)
    end
    output_string = M.pretty_json(output_string)
    return output_string
end

-- Count Keys
M.count_keys = function(graph)
    local count = 0
    for k,_ in pairs(graph) do
        count = count + 1
    end
    return count
end

-- Graph Key Value Switch
M.key_value_switch = function(graph)
    local output_keys = {}
    for k,v in pairs(graph) do
        output_keys[v] = k
    end
    return output_keys
end

-- Graph Index Isolate
M.index_isolate = function(graph)
    local output_indices = {}
    local index_values = {}
    for k,_ in ipairs(graph) do
        table.insert(output_indices, graph[k])
        index_values[k] = true
    end
    return output_indices, index_values
end

-- Graph Key Isolate
M.key_isolate = function(graph)
    local output_keys = {}
    local _, index_values = M.index_isolate(graph)
    for k,_ in pairs(graph) do
        if not index_values[k] then
            table.insert(output_keys, k)
        end
    end
    return output_keys
end

-- Graph Key Standardise
M.key_standardise = function(keys)
    local output_keys = {}
    for _, k in ipairs(keys) do
        output_keys[string.lower(k:gsub("[^%w]", ""))] = k
    end
    return output_keys
end

-- Graph Key Replace
M.key_replace = function(ordered_keys, key_replacements)
    local output_keys = {}
    for _, k in ipairs(ordered_keys) do
        table.insert(output_keys, key_replacements[k] or k)
    end
    return output_keys
end

-- Graph Index Alphabetical Sort
M.index_sort = function(graph)
    local indices = M.index_isolate(graph)
    local output = {}
    local table_values = {}
    for _, index in ipairs(indices) do
        if type(graph[index]) == "table" then
            table.insert(table_values, graph[index])
        else
            table.insert(output, graph[index])
        end
    end
    table.sort(output)
    return output, table_values
end

-- Graph Key Alphabetical Sort
M.key_sort = function(graph)
    local keys = M.key_isolate(graph)
    local standard_keys = M.key_standardise(keys)
    local sorted_keys = M.key_isolate(standard_keys)
    table.sort(sorted_keys)
    sorted_keys = M.key_replace(sorted_keys, standard_keys)
    return sorted_keys
end

-- Graph Key Weighted Sort
M.weighted_key_sort = function(graph)
    local keys = M.key_sort(graph)
    local key_count = M.count_keys(graph)
    local sorted_keys = {}
    local key_values = {}
    for i, key in ipairs(keys) do
        new_key = i + #graph[key] * key_count
        table.insert(sorted_keys, new_key)
        key_values[new_key] = key
    end
    table.sort(sorted_keys)
    local output_keys = {}
    for _, i in ipairs(sorted_keys) do
        table.insert(output_keys, key_values[i])
    end
    return output_keys
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
    local sorted_keys = M.weighted_key_sort(graph)
    local visited = {}
    local result = {}

    local function visit(node)
        if not visited[node] then
            visited[node] = true
            if graph[node] and #graph[node] > 0 then
                local node_keys = graph[node]
                table.sort(node_keys)
                for _, dep in ipairs(node_keys) do
                    if graph[dep] and dep ~= node then
                        visit(dep)
                    end
                end
            end
            table.insert(result, node)
        end
    end

    for _, node in ipairs(sorted_keys) do
        visit(node)
    end
    return result
end

M.RelativePath = function(CurrentPath, TargetPath)
    -- Function to create a relative path from CurrentPath to TargetPath assuming they're both relative to the Project Root
    local CurrentVector = pandoc.path.split(CurrentPath)
    local TargetVector = pandoc.path.split(TargetPath)
    SharedRootIndex = 0
    local RelativeVector = {}
    for i = 1, #CurrentVector do
        for j = 1, #TargetVector do
            if CurrentVector[i] == TargetVector[j] then
                if i > SharedRootIndex then
                    SharedRootIndex = i
                end
            else
                break
            end
        end
    end
    UpIndex = #CurrentVector - SharedRootIndex - 1
    if UpIndex > 0 then
        for i = 1, UpIndex do
            table.insert(RelativeVector, "..")
        end
    end
    for i = SharedRootIndex + 1, #TargetVector do
        table.insert(RelativeVector, TargetVector[i])
    end
    RelativePath = pandoc.path.join(RelativeVector)
    if RelativePath == "" then
        RelativePath = "."
    end
    RelativePath = RelativePath:gsub("%.qmd$", ".html")
    return RelativePath
end

M.MathVariables = function(math)
    local matchRegex = math.text:match '(.?#[0-9]+)'
    if matchRegex ~= nil then
        local output = math.text
        repeat
            Term = matchRegex:match '.?#([0-9]+)'
            FirstChar = matchRegex:match '^(.?)#[0-9]+' or ""
            if FirstChar ~= "\\" then
                newTerm = string.char(96+tonumber(Term))
                replacement = FirstChar .. newTerm
                output = output:gsub(matchRegex, replacement)
            end
            matchRegex = output:match '(.?#[0-9]+)'
        until matchRegex == nil
        quarto.log.info("Math: " .. output .. "\nFinal Math: " .. output)
        return pandoc.Math(math.mathtype, output)
    else
        return math
    end
end

M.MathReplacement = function(math, templateMap, replacementMap)
    local output = math.text
    local TemplateArray = {}
    for v,k in ipairs(templateMap) do
        if math.text:match(k) ~= nil then
            TemplateArray[v] = k
        end
    end
    for v,k in ipairs(replacementMap) do
        if v <= #templateMap and TemplateArray[v] ~= nil then
            output = output:gsub(TemplateArray[v], k)
        elseif v > #templateMap then
            variable = "#" .. tostring(v-#templateMap)
            output = output:gsub(variable, k)
        end
    end
    return M.MathVariables(pandoc.Math(math.mathtype, output))
end

M.MathReplacementMD = function(md, templateMap, replacementMap)
    local output = md
    local TemplateArray = {}
    for v,k in ipairs(templateMap) do
        if md:match(k) ~= nil then
            TemplateArray[v] = k
        end
    end
    for v,k in ipairs(replacementMap) do
        if v <= #templateMap and TemplateArray[v] ~= nil then
            output = output:gsub(TemplateArray[v], k)
        elseif v > #templateMap then
            variable = "#" .. tostring(v-#templateMap)
            output = output:gsub(variable, k)
        end
    end
    return output
end

M.to_json_array = function(str)
    -- Remove brackets
    body = str:match("^%[(.*)%]$")

    if body then
        -- Split by comma, trim, add quotes, escape backslashes
        local arr = {}
        for item in body:gmatch("[^,]+") do
            item = item:gsub("^%s*", ""):gsub("%s*$", "") -- trim
            item = item:gsub("\\", "\\\\")                -- escape backslash
            table.insert(arr, '"' .. item .. '"')
        end
        return "[" .. table.concat(arr, ",") .. "]"
    else
        body = str:match("^\\%[(.*)\\%]$")
        if body then
            -- Split by comma, trim, add quotes, escape backslashes
            local arr = {}
            for item in body:gmatch("[^,]+") do
                item = item:gsub("^%s*", ""):gsub("%s*$", "") -- trim
                table.insert(arr, '"' .. item .. '"')
            end
            return "[" .. table.concat(arr, ",") .. "]"
        else
            return "[]"
        end
    end
end

M.LoadDiv = function(Div)
    if not Div then
        return nil
    end

    local doc = pandoc.Pandoc(pandoc.Blocks({}))
    if Div.t and Div.t == "Div" then
        -- If Div is already a Div, we can use it directly
        doc = pandoc.Pandoc({Div}, doc.meta)
    else
        doc = pandoc.read(Div, "markdown")
    end

    -- Define DivContent and Div_blocks
    local DivContent = doc.blocks[1]
    local Div_blocks = DivContent.content
    if Div_blocks[1] == nil then
        return nil
    end

    -- Initialise output table
    local output = {
        pandoc = doc,
        Div = DivContent,
        block = Div_blocks,
        identifier = DivContent.identifier,
        classes = DivContent.classes,
        attributes = DivContent.attributes
    }

    -- Remove Header and create Inlines
    if Div_blocks[1].t == "Header" then
      i = 2
      output.title = Div_blocks[1].content
      output.block:remove(1)
    end

    -- Be defensive: attributes table may be absent
    if DivContent.attributes.templateMap then
        FormattedString = M.to_json_array(DivContent.attributes.templateMap)
        if quarto and quarto.json then
            output.templateMap = quarto.json.decode(FormattedString)
        else
            output.templateMap = pandoc.json.decode(FormattedString)
        end
    end
    return output
end

-- Convert inline to markdown
M.convert_md = function(inlines, metadata)
    local md = pandoc.write(pandoc.Pandoc(inlines, metadata), "markdown", pandoc.WriterOptions({
        wrap_text = "wrap-none"
    }))
    local replacementArray = {
        ["\\<"] = "<",
        ["\\>"] = ">",
        ["\\%["] = "[",
        ["\\%]"] = "]",
        ["\\%("] = "(",
        ["\\%)"] = ")",
        ["\\{"] = "{",
        ["\\}"] = "}",
        ["\\$"] = "$"
    }
    for k, v in pairs(replacementArray) do
        md = md:gsub(k, v)
    end
    return md:match("^%s*([^%s].*[^%s])%s*$")
end

return M