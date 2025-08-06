print("Creating Schema Files")
-- Load Project Directories
local InputDir = pandoc.system.get_working_directory() or error("Working directory not set")
local MathDir = pandoc.path.join({InputDir, "_maths"})

-- Find Filter Directory
local ExtDir = pandoc.path.join({InputDir, "_extensions","kai-prince-sfhea","schema"})
ok, err, code = os.rename(ExtDir.."/", ExtDir.."/")
if not ok then
    ExtDir = pandoc.path.join({InputDir, "_extensions","schema"})
end

-- Load Schema Functions
local schema = dofile(pandoc.path.join({ExtDir, "schema.lua"}))

-- Create new Math Directory if it does not exist
ok, err, code = os.rename(MathDir.."/", MathDir.."/")
if not ok then
    pandoc.system.make_directory(MathDir, true)
end

-- Set Output File Directories
local OutputMathJSONFile = pandoc.path.join({MathDir, "Math.json"})
local OutputDependenciesFile = pandoc.path.join({MathDir, "MathDependencies.json"})
local OutputTermsFile = pandoc.path.join({MathDir, "Terms.json"})
local OutputDocumentContentsFile = pandoc.path.join({MathDir, "Document-contents.json"})

-- Load Input Files as List
local InputFiles = os.getenv("QUARTO_PROJECT_INPUT_FILES") or error("QUARTO_PROJECT_INPUT_FILES not set")
local Files = {}
for file in InputFiles:gmatch("[^\r\n]+") do
    table.insert(Files, file)
end

-- Initialise Output Variables
local MathJSON = {}
local MathJSONCount = {}
MathJSONFile = io.open(OutputMathJSONFile, "r")
if MathJSONFile ~= nil then
    MathJSON = pandoc.json.decode(MathJSONFile:read("a"))
    for k, v in pairs(MathJSON) do
        MathJSONCount[k] = 1  -- Initialize count for each command
        for _, file in ipairs(Files) do
            if v.Source == file then
                MathJSONCount[k] = 0  -- Reset count for files being processed
                break  -- Stop checking once the file is found
            end
        end
    end
end

local TermsJSON = {}
TermsFile = io.open(OutputTermsFile, "r")
if TermsFile ~= nil then
    TermsJSON = pandoc.json.decode(TermsFile:read("a"))
end

local DocJSON = {}
DocFile = io.open(OutputDocumentContentsFile, "r")
if DocFile ~= nil then
    DocJSON = pandoc.json.decode(DocFile:read("a"))
end

-- MathJSON Warning function
local MathJSONWarning = {}
local MathJSONWarningBoolean = false
local function mathjson_warning(cmd, file)
    MathJSONWarningBoolean = true
    if MathJSONWarning[cmd] == nil then
        MathJSONWarning[cmd] = {}
        MathJSONWarning[cmd][MathJSON[cmd].Source] = 1
    end
    if MathJSONWarning[cmd][file] == nil then
        MathJSONWarning[cmd][file] = 1
    else
        MathJSONWarning[cmd][file] = MathJSONWarning[cmd][file] + 1
    end
end

-- Extract Math Macro from metadata and load it into an output table
local function extract_math_macro(value, file)
    -- Load variables
    local cmd = pandoc.utils.stringify(value.command)
    if MathJSON[cmd] == nil then
        MathJSON[cmd] = {}
    end
    local macro = pandoc.utils.stringify(value.macro)
    local variables
    local variablesDefaultString = ""
    local variablesDefaultArray = {}

    if MathJSONCount[cmd] == nil then
        MathJSONCount[cmd] = 1
    else
        MathJSONCount[cmd] = MathJSONCount[cmd] + 1
    end
    if MathJSONCount[cmd] > 1 then
        mathjson_warning(cmd, file)
    end

    TermsJSON["\\"..cmd] = {
        sourceFile = file,
        translation = false,
        type = "math"
    }

    -- Map Math Macro to variables
    if value.variables ~= nil then
        variables = pandoc.utils.stringify(value.variables)
        if value.variablesDefault ~= nil then
            if type(value.variablesDefault) == "table" and value.variablesDefault[2] ~= nil then
                for _, string in ipairs(value.variablesDefault) do
                    table.insert(variablesDefaultArray, "O{"..pandoc.utils.stringify(string).."} ")
                end
                if #variablesDefaultArray < variables + 0 then
                    for i = #variablesDefaultArray + 1, variables + 0 do
                        table.insert(variablesDefaultArray, "m ")
                    end
                end
                MathJSON[cmd] = {
                    MathJax = {
                        macro,
                        tonumber(variables),
                        variablesDefaultArray
                    },
                    LaTeX = "\\NewDocumentCommand{\\".. cmd .."}{" .. pandoc.utils.stringify(variablesDefaultArray) .. "}{" .. macro .. "}"
                }
            else
                variablesDefaultString = pandoc.utils.stringify(value.variablesDefault)
                MathJSON[cmd] = {
                    MathJax = {
                        macro,
                        tonumber(variables),
                        variablesDefaultString
                    },
                    LaTeX = "\\newcommand{\\".. cmd .."}[" .. variables .. "][" .. variablesDefaultString .. "]{" .. macro .. "}"
                }
            end
        else
            MathJSON[cmd] = {
                MathJax = {
                    macro,
                    tonumber(variables)
                },
                LaTeX = "\\newcommand{\\".. cmd .."}[" .. variables .. "]{" .. macro .. "}"
            }
        end
    else
        MathJSON[cmd] = {
            MathJax = macro,
            LaTeX = "\\newcommand{\\".. cmd .."}{" .. macro .. "}"
        }
    end
    if value.description ~= nil then
        MathJSON[cmd].Notation = pandoc.utils.stringify(value.description)
        TermsJSON["\\"..cmd].description = MathJSON[cmd].Notation
    end
    if value.id ~= nil then
        MathJSON[cmd].Ref = pandoc.utils.stringify(value.id)
    end
    MathJSON[cmd].Source = file
end

-- Load and process the metadata of each Input File
for _, file in ipairs(Files) do
    print("-Processing file: " .. file)
    local fileContents = io.open(file, "r"):read("*a")
    local contents = pandoc.read(fileContents, "markdown")
    local body = ""

    if fileContents:match("^%-%-%-") then
        body = fileContents:match("^%-%-%-.+%-%-%-%s*(.*)%s*$")  -- Extract body after YAML metadata
    else
        body = fileContents
    end
    DocJSON[file] = {
        contents = body
    }

    ---@type pandoc.List
    ---@class metadata
    ---@field macros table|nil
    ---@field dependencies table|nil
    ---@field terms table|nil
    local metadata = contents.meta

    -- Pass each Math Macro
    if type(metadata.macros) == "table" then
        for _, value in ipairs(metadata.macros) do
            extract_math_macro(value, file)
        end
    end

    if type(metadata.terms) == "table" then
        for _, term in ipairs(metadata.terms) do
            local termName = pandoc.utils.stringify(term.alias)

            TermsJSON[termName] = {
                sourceFile = file,
                type = "term"
            }

            if term.translate == false then
                TermsJSON[termName].translation = false
            end
            if term.id then
                termRef = pandoc.utils.stringify(term.id)
                TermsJSON[termName].sourceRef = termRef
            end
        end
    end

    for ref, args in body:gmatch("{#([a-zA-Z%-]+)%s?([^}]*)}") do
        TermsJSON["@"..ref] = {
            sourceArgs = args,
            sourceFile = file,
            sourceRef = ref,
            translation = false,
            type = ref:match("^[a-zA-Z]+")
        }
        -- Find the Div block with the matching identifier
        local found_block = nil
        for _, block in ipairs(contents.blocks) do
            if block.identifier == ref then
                found_block = block
                break
            end
        end
        if found_block then
            blockContent = pandoc.write(pandoc.Pandoc({found_block}, contents.meta), "markdown")
            TermsJSON["@"..ref].blockType = found_block.t
            blockTitle, blockBody = blockContent:match("## ([^\n]+)\n\n(.+)\n:::")
            if blockTitle then
                TermsJSON["@"..ref].blockTitle = blockTitle
                TermsJSON["@"..ref].blockBody = blockBody
            else
                TermsJSON["@"..ref].blockBody = blockContent:match("\n(.+)\n:::")
            end
        end
    end

    fileDependencies = {}
    if type(metadata.dependencies) == "table" then
        for _, dep in ipairs(metadata.dependencies) do
            table.insert(fileDependencies, pandoc.utils.stringify(dep))
        end
    end
end

if MathJSONWarningBoolean then
    print("MathJSON Potential Conflicting Definitions: " .. schema.pretty_json(pandoc.json.encode(MathJSONWarning)))
end

-- Create a dependency graph
local dependencyGraph = {}
for key, body in pairs(MathJSON) do
    dependencyGraph[key] = schema.extract_dependencies(body.LaTeX, MathJSON, "\\([a-zA-Z]+)")
end

local sorted_keys = schema.topo_sort(dependencyGraph)

local dependencyData = {
    graph = dependencyGraph,
    sorted_keys = sorted_keys
}

-- Save MathJSON Output to File
MathJSONEncoding = schema.pretty_json(pandoc.json.encode(MathJSON))
io.open(OutputMathJSONFile, "w"):write(MathJSONEncoding)

-- Save TermsJSON Output to File
TermsJSONEncoding = schema.pretty_json(pandoc.json.encode(TermsJSON))
io.open(OutputTermsFile, "w"):write(TermsJSONEncoding)

-- Save DocJSON Output to File
DocJSONEncoding = schema.pretty_json(pandoc.json.encode(DocJSON))
io.open(OutputDocumentContentsFile, "w"):write(DocJSONEncoding)

-- Save Dependencies to File
dependencyJSONEncoding = schema.pretty_json(pandoc.json.encode(dependencyData))
io.open(OutputDependenciesFile, "w"):write(dependencyJSONEncoding)