-- Load Project Directories
local InputDir = pandoc.system.get_working_directory() or error("Working directory not set")
local MathDir = pandoc.path.join({InputDir, "_maths"})

-- Find Filter Directory
local ExtDir = pandoc.path.join({InputDir, "_extensions","kai-prince-sfhea","schema"})
ok, err, code = os.rename(InputDir.."/", InputDir.."/")
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

-- Create Math Directory file
Directories = {}
Directories[os.getenv("QUARTO_PROJECT_OUTPUT_DIR")] = false
io.open(pandoc.path.join({MathDir,"Render-Directories.json"}),"w"):write(schema.pretty_json(pandoc.json.encode(Directories)))

-- Set Output File Directories
local OutputMathJSONFile = pandoc.path.join({MathDir, "MathJSON.json"})
local OutputMathJaxFile = pandoc.path.join({MathDir, "Mathjax.json"})
local OutputLaTexFile = pandoc.path.join({MathDir, "Tex-macros.tex"})
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
local function mathjson_warning(cmd, file)
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
        source = file,
        translation = false,
        math = true
    }

    -- Map Math Macro to variables
    if value.variables ~= nil then
        variables = pandoc.utils.stringify(value.variables)
        if value.variablesDefault ~= nil then
            if type(value.variablesDefault) == "table" and value.variablesDefault[2] ~= nil then
                for _, string in ipairs(value.variablesDefault) do
                    table.insert(variablesDefaultArray, pandoc.utils.stringify(string))
                end
                MathJSON[cmd] = {
                    MathJax = {
                        macro,
                        tonumber(variables),
                        variablesDefaultArray
                    },
                    LaTeX = "[" .. variables .. "]" .. pandoc.utils.stringify(variablesDefaultArray) .. "{" .. macro .. "}"
                }
            else
                variablesDefaultString = pandoc.utils.stringify(value.variablesDefault)
                MathJSON[cmd] = {
                    MathJax = {
                        macro,
                        tonumber(variables),
                        variablesDefaultString
                    },
                    LaTeX = "[" .. variables .. "][" .. variablesDefaultString .. "]{" .. macro .. "}"
                }
            end
        else
            MathJSON[cmd] = {
                MathJax = {
                    macro,
                    tonumber(variables)
                },
                LaTeX = "[" .. variables .. "]{" .. macro .. "}"
            }
        end
    else
        MathJSON[cmd] = {
            MathJax = macro,
            LaTeX = "{" .. macro .. "}"
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
    local contents = pandoc.read(io.open(file, "r"):read("*a"), "markdown")
    local body = contents.blocks

    DocJSON[file] = {
        contents = pandoc.utils.stringify(pandoc.utils.blocks_to_inlines(body,pandoc.Inlines(' ')))
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
            local termTranslation = true

            if term.translate == false then
                termTranslation = false
            end

            local url = file
            if term.id then
                termRef = pandoc.utils.stringify(term.id)
                url = url .. "#" .. termRef
            end
            TermsJSON[termName] = {
                source = url,
                translation = termTranslation,
                math = false
            }
        end
    end

    fileDependencies = {}
    if type(metadata.dependencies) == "table" then
        for _, dep in ipairs(metadata.dependencies) do
            table.insert(fileDependencies, pandoc.utils.stringify(dep))
        end
    end
end

if MathJSONWarning ~= {} then
    print("MathJSON Potential Conflicting Definitions: " .. schema.pretty_json(pandoc.json.encode(MathJSONWarning)))
end

-- Create a dependency graph
local dependencyGraph = {}
for key, body in pairs(MathJSON) do
    dependencyGraph[key] = schema.extract_dependencies(body.LaTeX, MathJSON, "\\([a-zA-Z]+)")
end

local sorted_keys = schema.topo_sort(dependencyGraph)

-- Build dependency-sorted output variables
local MathJaxJSON = {}
local LaTeX = "\n"
for _, key in ipairs(sorted_keys) do
    MathJaxJSON[key] = MathJSON[key].MathJax

    local LaTeXcmd = "\\" .. key
    local LaTeXdef = "\\newcommand{" .. LaTeXcmd .. "}" .. MathJSON[key].LaTeX
    LaTeX = LaTeX .. LaTeXdef .. "\n"

    local url = MathJSON[key].Source
    if MathJSON[key].Ref then
        url = url .. "#" .. MathJSON[key].Ref
    end
end

-- Save MathJSON Output to File
MathJSONEncoding = schema.pretty_json(pandoc.json.encode(MathJSON))
io.open(OutputMathJSONFile, "w"):write(MathJSONEncoding)

-- Save TermsJSON Output to File
TermsJSONEncoding = schema.pretty_json(pandoc.json.encode(TermsJSON))
io.open(OutputTermsFile, "w"):write(TermsJSONEncoding)

-- Save DocJSON Output to File
DocJSONEncoding = schema.pretty_json(pandoc.json.encode(DocJSON))
io.open(OutputDocumentContentsFile, "w"):write(DocJSONEncoding)

-- Convert MathJax Output to indented JSON + Save to File
MathJaxJSONEncoding = schema.pretty_json(pandoc.json.encode(MathJaxJSON))
io.open(OutputMathJaxFile, "w"):write(MathJaxJSONEncoding)

-- Save Tex commands to File
io.open(OutputLaTexFile, "w"):write(LaTeX .. "\n")

-- Save Dependencies to File
dependencyJSONEncoding = schema.pretty_json(pandoc.json.encode(dependencyGraph))
io.open(OutputDependenciesFile, "w"):write(dependencyJSONEncoding)