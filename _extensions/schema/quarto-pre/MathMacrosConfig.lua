-- Load Project Directories
local InputDir = pandoc.system.get_working_directory() or error("Working directory not set")
print("Input Directory: " .. InputDir)
local MathDir = pandoc.path.join({InputDir, "_maths"})
print("Math Directory: " .. MathDir)

-- Find Filter Directory
local ExtDir = pandoc.path.join({InputDir, "_extensions","kai-prince-sfhea","schema"})
ok, err, code = os.rename(InputDir.."/", InputDir.."/")
if not ok then
    ExtDir = pandoc.path.join({InputDir, "_extensions","schema"})
end
print("Extension Directory: " .. ExtDir)

-- Load Schema Functions
local schema = dofile(pandoc.path.join({ExtDir, "schema.lua"}))

-- Create new Math Directory if it does not exist
ok, err, code = os.rename(MathDir.."/", MathDir.."/")
if not ok then
    pandoc.system.make_directory(MathDir, true)
end

-- Create Math Directory file
Directories = {}
Directories[os.getenv("QUARTO_PROJECT_OUTPUT_DIR")] = false
io.open(pandoc.path.join({MathDir,"Render-Directories.json"}),"w"):write(schema.pretty_json(pandoc.json.encode(Directories)))

-- Set Output File Directories
local OutputMathJaxFile = pandoc.path.join({MathDir, "Mathjax-macros.json"})
local OutputLaTexFile = pandoc.path.join({MathDir, "Tex-macros.tex"})
local OutputNotationFile = pandoc.path.join({MathDir, "Notation.json"})

-- Load Input Files as List
local InputFiles = os.getenv("QUARTO_PROJECT_INPUT_FILES") or error("QUARTO_PROJECT_INPUT_FILES not set")
local Files = {}
for file in InputFiles:gmatch("[^\r\n]+") do
    table.insert(Files, file)
end

-- Initialise Output Variables
local MathJSON = {}
MathJaxFile = io.open(OutputMathJaxFile, "r")
if MathJaxFile ~= nil then
    MathJaxTable = pandoc.json.decode(MathJaxFile:read("a"))
    for k, v in pairs(MathJaxTable) do
        MathJSON[k] = {}
        MathJSON[k].MathJax = v
    end
end

local LaTeXFile = io.open(OutputLaTexFile, "r")
if LaTeXFile ~= nil then
    for k, v in string.gmatch(LaTeXFile:read("a"),"\\newcommand{\\([^{}]*)}([^\n]*)") do
        if MathJSON[k] == nil then
            MathJSON[k] = {}
        end
        MathJSON[k].LaTeX = v
    end
end

NotationFile = io.open(OutputNotationFile, "r")
if NotationFile ~= nil then
    notationTable = pandoc.json.decode(NotationFile:read("a"))
    if type(notationTable) == "table" then
        for _, v in pairs(notationTable) do
            cmd = v.LaTeXcmd:match("\\([^{}]*)")
            if MathJSON[cmd] == nil then
                MathJSON[cmd] = {}
            end
            MathJSON[cmd].Notation = v.Notation
        end
    end
end

-- Extract Math Macro from metadata and load it into an output table
local function extract_math_macro(value, macro_table)
    -- Load variables
    local cmd = pandoc.utils.stringify(value.command)
    if macro_table[cmd] == nil then
        macro_table[cmd] = {}
    end
    local macro = pandoc.utils.stringify(value.macro)
    local variables
    local variablesDefaultString = ""
    local variablesDefaultArray = {}

    -- Map Math Macro to variables
    if value.variables ~= nil then
        variables = pandoc.utils.stringify(value.variables)
        if value.variablesDefault ~= nil then
            if type(value.variablesDefault) == "table" and value.variablesDefault[2] ~= nil then
                for _, string in ipairs(value.variablesDefault) do
                    table.insert(variablesDefaultArray, pandoc.utils.stringify(string))
                end
                macro_table[cmd] = {
                    MathJax = {
                        macro,
                        tonumber(variables),
                        variablesDefaultArray
                    },
                    LaTeX = "[" .. variables .. "]" .. pandoc.utils.stringify(variablesDefaultArray) .. "{" .. macro .. "}"
                }
            else
                variablesDefaultString = pandoc.utils.stringify(value.variablesDefault)
                macro_table[cmd] = {
                    MathJax = {
                        macro,
                        tonumber(variables),
                        variablesDefaultString
                    },
                    LaTeX = "[" .. variables .. "][" .. variablesDefaultString .. "]{" .. macro .. "}"
                }
            end
        else
            macro_table[cmd] = {
                MathJax = {
                    macro,
                    tonumber(variables)
                },
                LaTeX = "[" .. variables .. "]{" .. macro .. "}"
            }
        end
    else
        macro_table[cmd] = {
            MathJax = macro,
            LaTeX = "{" .. macro .. "}"
        }
    end
    if value.description ~= nil then
        macro_table[cmd].Notation = pandoc.utils.stringify(value.description)
    end
end

-- Load and process the metadata of each Input File
for _, file in ipairs(Files) do
    ---@type pandoc.List
    ---@class metadata
    ---@field macros table|nil
    local metadata = pandoc.read(io.open(file, "r"):read("*a"), "markdown").meta

    -- Pass each Math Macro
    if type(metadata.macros) == "table" then
        for _, value in ipairs(metadata.macros) do
            extract_math_macro(value, MathJSON)
        end
    end
end

print("Extracting dependencies...")
-- Create a dependency graph
local dependencyGraph = {}
for key, body in pairs(MathJSON) do
    dependencyGraph[key] = schema.extract_dependencies(body.LaTeX, MathJSON)
    print("Dependencies for " .. key .. ": " .. table.concat(dependencyGraph[key], ", "))
end
print("Dependency extraction complete.")

local sorted_keys = schema.topo_sort(dependencyGraph)

-- Build dependency-sorted output variables
local MathJaxJSON = {}
local LaTeX = "\n"
local notationJSON = {}
for _, key in ipairs(sorted_keys) do
    MathJaxJSON[key] = MathJSON[key].MathJax
    local LaTeXcmd = "\\" .. key
    local LaTeXdef = "\\newcommand{" .. LaTeXcmd .. "}" .. MathJSON[key].LaTeX
    LaTeX = LaTeX .. LaTeXdef .. "\n"

    if MathJSON[key].Notation then
        notationRow = {
            LaTeXcmd = LaTeXcmd,
            Notation = MathJSON[key].Notation
        }
        table.insert(notationJSON, notationRow)
    end
end

-- Convert MathJax Output to indented JSON + Save to File
MathJaxJSONEncoding = schema.pretty_json(pandoc.json.encode(MathJaxJSON))
io.open(OutputMathJaxFile, "w"):write(MathJaxJSONEncoding)

-- Save Tex commands to File
io.open(OutputLaTexFile, "w"):write(LaTeX .. "\n")
print(LaTeX)

-- Save Notation Descriptions to File
notationJSONEncoding = schema.pretty_json(pandoc.json.encode(notationJSON))
io.open(OutputNotationFile, "w"):write(notationJSONEncoding)