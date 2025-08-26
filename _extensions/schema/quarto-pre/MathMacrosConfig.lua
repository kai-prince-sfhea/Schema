print("Creating Schema Files")
-- Load Project Directories
local InputDir = pandoc.system.get_working_directory() or error("Working directory not set")
local MathDir = pandoc.path.join({InputDir, "_schema"})

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
    MathJSON = pandoc.json.decode(MathJSONFile:read("a")).MathJSON
    MathJSONFile:close()
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
    TermsFile:close()
end

local DocJSON = {}
DocFile = io.open(OutputDocumentContentsFile, "r")
if DocFile ~= nil then
    DocJSON = pandoc.json.decode(DocFile:read("a"))
    DocFile:close()
end

-- Create URL formatted Title
local function create_url_title(inlines, url, capitalize)
    local OutputInlines = pandoc.Inlines("")
    local citations = false
    local uncited_title = pandoc.Inlines("")
    local cited_title = pandoc.Inlines("")
    for _, inl in ipairs(inlines) do
    if inl.t == "Cite" or citations == true then
        citations = true
        local outl = inl
        if inl.t == "Str" and capitalize then
            outl.text = inl.text:gsub("^%l", string.upper)
        end
        cited_title:insert(outl)
    else
        local outl = inl
        if inl.t == "Str" and capitalize then
            outl.text = inl.text:gsub("^%l", string.upper)
        end
        uncited_title:insert(outl)
    end
    end
    if citations == true then
        title_url = pandoc.Link(uncited_title, url, "Link to source page")
        OutputInlines:insert(title_url)
        for _, inl in ipairs(cited_title) do
            outl = inl
            if inl.t == "Str" and capitalize then
                outl.text = inl.text:gsub("^%l", string.upper)
            end
            OutputInlines:insert(outl)
        end
    else
        title_url = pandoc.Link(inlines, url, "Link to source page")
        OutputInlines:insert(title_url)
    end
    return OutputInlines
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
    local variablesDefaultArrayPlain = {}

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
                OptionalVariables = 0
                MandatoryVariables = 0
                for _, string in ipairs(value.variablesDefault) do
                    table.insert(variablesDefaultArray, "O{"..pandoc.utils.stringify(string).."} ")
                    table.insert(variablesDefaultArrayPlain, pandoc.utils.stringify(string))
                    OptionalVariables = OptionalVariables + 1
                end
                if #variablesDefaultArray < variables + 0 then
                    MandatoryVariables = variables - OptionalVariables
                    for i = #variablesDefaultArray + 1, variables + 0 do
                        table.insert(variablesDefaultArray, "m ")
                    end
                end
                MathJSON[cmd] = {
                    MathJax = {
                        macro,
                        tonumber(variables),
                        variablesDefaultArrayPlain
                    },
                    LaTeX = "\\NewDocumentCommand{\\".. cmd .."}{" .. pandoc.utils.stringify(variablesDefaultArray) .. "}{" .. macro .. "}"
                }
                TermsJSON["\\"..cmd].optionalVars = OptionalVariables
                TermsJSON["\\"..cmd].mandatoryVars = MandatoryVariables
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
                TermsJSON["\\"..cmd].optionalVars = 1
                TermsJSON["\\"..cmd].mandatoryVars = variables - 1
            end
        else
            MathJSON[cmd] = {
                MathJax = {
                    macro,
                    tonumber(variables)
                },
                LaTeX = "\\newcommand{\\".. cmd .."}[" .. variables .. "]{" .. macro .. "}"
            }
            TermsJSON["\\"..cmd].optionalVars = 0
            TermsJSON["\\"..cmd].mandatoryVars = variables + 0
        end
    else
        MathJSON[cmd] = {
            MathJax = macro,
            LaTeX = "\\newcommand{\\".. cmd .."}{" .. macro .. "}"
        }
        TermsJSON["\\"..cmd].optionalVars = 0
        TermsJSON["\\"..cmd].mandatoryVars = 0
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

-- Parse each input file's metadata/body; extract macros, terms, anchors
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
        contents = body,
        title = pandoc.utils.stringify(contents.meta.title or "")
    }

    ---@type pandoc.List
    ---@class metadata
    ---@field macros table|nil
    ---@field dependencies table|nil
    ---@field terms table|nil
    ---@field schema table|nil
    local metadata = contents.meta

    -- Pass each Math Macro
    if type(metadata.macros) == "table" then
        for _, value in ipairs(metadata.macros) do
            extract_math_macro(value, file)
        end
    end

    -- Pass each term reference
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
            -- Preserve full block AST to conserve Div/classes/IDs when reusing via shortcodes
            TermsJSON["@"..ref].divMD = schema.convert_md(found_block, metadata)
            TermsJSON["@"..ref].blockType = found_block.t
            local Div_data = schema.LoadDiv(TermsJSON["@"..ref].divMD)
            if Div_data ~= nil then 
                TermsJSON["@"..ref].blockMD = schema.convert_md(Div_data.block, metadata)
                TermsJSON["@"..ref].HTMLMD = TermsJSON["@"..ref].blockMD
                if Div_data.title then
                    TermsJSON["@"..ref].title = schema.convert_md(Div_data.title, metadata):gsub("%s+", " ")
                    TermsJSON["@"..ref].titleMD = schema.convert_md(Div_data.title, metadata):gsub("%s+", " "):gsub("(%a)(%a*)", function(a,b) return string.upper(a)..b end)
                    TermsJSON["@"..ref].urlTitle = schema.convert_md(create_url_title(Div_data.title,file, false), metadata):gsub("%s+", " ")
                    TermsJSON["@"..ref].urlMD = schema.convert_md(create_url_title(Div_data.title,file, true), metadata):gsub("%s+", " ")
                end
                if Div_data.templateMap then
                    TermsJSON["@"..ref].templateMap = Div_data.templateMap
                end
                if Div_data.classes and #Div_data.classes > 0 then
                    TermsJSON["@"..ref].classes = Div_data.classes
                end
            end
        end
    end

    if type(metadata.terms) == "table" then
        for _, term in ipairs(metadata.terms) do
            -- YAML schema: term, regex, prefixes, associatedMacros
            local baseName = pandoc.utils.stringify(term.term)
            if baseName and baseName ~= "" then
                TermsJSON[baseName] = {
                    sourceFile = file,
                    type = "term"
                }
                if term.translate == false then
                    TermsJSON[baseName].translation = false
                end
                if term.id then
                    local termRef = pandoc.utils.stringify(term.id)
                    TermsJSON[baseName].sourceRef = termRef
                    if TermsJSON["@" .. termRef] then
                        TermsJSON["@" .. termRef].termRef = baseName
                    end
                end
                if term.regex then
                    TermsJSON[baseName].regex = pandoc.utils.stringify(term.regex)
                end

                -- Generate prefixed term aliases if provided
                if type(term.prefixes) == "table" then
                    for _, p in ipairs(term.prefixes) do
                        local pref = pandoc.utils.stringify(p.prefix or "")
                        if pref ~= "" then
                            local name = pref .. baseName
                            TermsJSON[name] = {
                                sourceFile = file,
                                type = "term",
                                termRef = baseName
                            }
                            if p.id then
                                prefixRef = pandoc.utils.stringify(p.id)
                                TermsJSON[name].sourceRef = prefixRef
                                if TermsJSON["@" .. prefixRef] then
                                    TermsJSON["@" .. prefixRef].termRef = baseName
                                end
                            end
                            if term.translate == false then
                                TermsJSON[name].translation = false
                            end
                            if term.regex then
                                TermsJSON[name].regex = pref .. pandoc.utils.stringify(term.regex)
                            end
                        end
                    end
                end

                -- Associated macros defined inside a term
                if type(term.associatedMacros) == "table" then
                    TermsJSON[baseName].relatedCommands = {}
                    for _, macroDef in ipairs(term.associatedMacros) do
                        extract_math_macro(macroDef, file)
                        local latex = "\\" .. pandoc.utils.stringify(macroDef.command)
                        TermsJSON[baseName].relatedCommands[latex] = true
                    end
                end
            end
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

Math = {
    MathJSON = MathJSON,
    dependencyGraph = dependencyGraph,
    sortedKeys = schema.topo_sort(dependencyGraph)
}

-- Save MathJSON Output to File
MathJSONEncoding = schema.json_encode(Math)
do
    local f = io.open(OutputMathJSONFile, "w")
    if f then f:write(MathJSONEncoding); f:close() end
end

-- Save TermsJSON Output to File
TermsJSONEncoding = schema.json_encode(TermsJSON)
do
    local f = io.open(OutputTermsFile, "w")
    if f then f:write(TermsJSONEncoding); f:close() end
end

-- Save DocJSON Output to File
DocJSONEncoding = schema.json_encode(DocJSON)
do
    local f = io.open(OutputDocumentContentsFile, "w")
    if f then f:write(DocJSONEncoding); f:close() end
end