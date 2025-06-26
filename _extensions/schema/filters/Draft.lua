print("=== Draft.lua filter loaded ===")

local OutputDir = os.getenv("QUARTO_PROJECT_OUTPUT_DIR") or error("QUARTO_PROJECT_OUTPUT_DIR not set")
local InputDir = pandoc.system.get_working_directory() or error("Working directory not set")
pandoc.system.make_directory(OutputDir)
local OutputFile = pandoc.path.join({OutputDir, "schema.json"})
local KnowledgeGraphFile = pandoc.path.join({InputDir, "knowledge/knowledge-graph.json"})

local InputFiles = os.getenv("QUARTO_PROJECT_INPUT_FILES") or error("QUARTO_PROJECT_INPUT_FILES not set")
local Files = {}
for file in InputFiles:gmatch("[^\r\n]+") do
    table.insert(Files, file)
end

local outputJSON = {}
local references = {}

for _, file in ipairs(Files) do
    local fileContent = pandoc.read(io.open(file, "r"):read("*a"), "markdown")
    local fileString = tostring(fileContent.blocks)
    
    ---@type pandoc.List
    ---@class metadata
    ---@field embedMap table|nil
    ---@field title pandoc.RawInline|string|nil
    local metadata = pandoc.read(io.open(file, "r"):read("*a"), "markdown").meta
    local outputRow = {
        string = tostring(metadata.title):match('\"(.*)\"'),
        source = file
    }
    table.insert(outputJSON, outputRow)

    print(fileString .. "\n")

    for class, description in fileString:gmatch("Div %(\"(%a+%-%a+)") do
        print(class .. "\n")
    end

    for definition in fileString:gmatch("#def%-%a+") do
        regex = "def%-" .. definition:match("#def%-(%a+)") .. "}%s?([^:]+)%s?:::"
        subregex = "def%-" .. definition:match("#def%-(%a+)") .. "}%s?:::%s?([^:]+)%s?:::%s?(.*)%s?:::"
        -- print(regex)
        description = fileString:match(regex)
        -- print(pandoc.json.encode(description))
        -- print(subregex)
        subdescription, suffixdescription =  fileString:match(subregex)
        -- print(pandoc.json.encode(subdescription) .. "\n" .. pandoc.json.encode(suffixdescription))
        references[definition] = {
            source = file,
            embedMap = metadata.embedMap
        }
    end

    if type(metadata.macros) == "table" then
        for _, value in ipairs(metadata.macros) do
            local cmd = pandoc.utils.stringify(value.command)
            local macro = pandoc.utils.stringify(value.macro)
            local variables
            local variablesDefaultString = ""
            local variablesDefaultArray = {}
            local outputMacros = {}
            if value.variables ~= nil then
                variables = pandoc.utils.stringify(value.variables)
                if value.variablesDefault ~= nil then
                    if type(value.variablesDefault) == "table" and value.variablesDefault[2] ~= nil then
                        for _, string in ipairs(value.variablesDefault) do
                            table.insert(variablesDefaultArray, pandoc.utils.stringify(string))
                        end
                        outputMacros = {
                            string = "\\" .. cmd,
                            command = cmd,
                            macro = macro,
                            variables = tonumber(variables),
                            variablesDefault = variablesDefaultArray,
                            source = file,
                            Type = "MathJaxMacro"
                        }
                    else
                        variablesDefaultString = pandoc.utils.stringify(value.variablesDefault)
                        outputMacros = {
                            string = "\\" .. cmd,
                            command = cmd,
                            macro = macro,
                            variables = tonumber(variables),
                            variablesDefault = variablesDefaultString,
                            source = file,
                            Type = "MathJaxMacro"
                        }
                    end
                else
                    outputMacros = {
                        string = "\\" .. cmd,
                        command = cmd,
                        macro = macro,
                        variables = tonumber(variables),
                        source = file,
                        Type = "MathJaxMacro"
                    }
                end
            else
                outputMacros = {
                    string = "\\" .. cmd,
                    command = cmd,
                    macro = macro,
                    source = file,
                    Type = "MathJaxMacro"
                }
            end
            table.insert(outputJSON, outputMacros)
        end
    end
end

print(pandoc.json.encode(references))

outputJSONEncoding = pandoc.json.encode(outputJSON):gsub("},{","\n  },\n  {"):gsub(",\"",",\n    \""):gsub("{\"","{\n    \""):gsub(":",": ")
outputJSONEncoding2 = "[\n  {" .. string.sub(outputJSONEncoding, 3,-3) .. "\n  }\n]"
io.open(OutputFile, "w"):write(outputJSONEncoding2, "\n")

print("Macros updated from metadata.")