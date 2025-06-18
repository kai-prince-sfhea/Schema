print("=== MathsPre.lua filter loaded ===")

local OutputDir = os.getenv("QUARTO_PROJECT_OUTPUT_DIR") or error("QUARTO_PROJECT_OUTPUT_DIR not set")
local InputDir = pandoc.system.get_working_directory() or error("Working directory not set")
pandoc.system.make_directory(OutputDir)
local OutputFile = pandoc.path.join({OutputDir, "schema.json"})
local OutputMathJaxFile = pandoc.path.join({OutputDir, "mathjax-macros.json"})
local OutputLaTexFile = pandoc.path.join({InputDir, "Tex-macros.tex"})
local OutputNotationFile = pandoc.path.join({OutputDir, "notation.json"})

local InputFiles = os.getenv("QUARTO_PROJECT_INPUT_FILES") or error("QUARTO_PROJECT_INPUT_FILES not set")
local Files = {}
for file in InputFiles:gmatch("[^\r\n]+") do
    table.insert(Files, file)
end

local outputJSON = {}
local MathJaxJSON = {}
local LaTeXJSON = ""
local notationJSON = {}

for _, file in ipairs(Files) do
    local fileContent = pandoc.read(io.open(file, "r"):read("*a"), "Org")
    local definitions = pandoc.utils.stringify(fileContent):gsub("\n",""):gsub("{}",""):gsub("{#?[^#def][^{}]*}",""):gsub("^.-{#def","#def"):gsub("}[^{}]*$",""):gsub("}[^#]*{#","\n#"):gsub("#","")
    print(definitions)
    local metadata = pandoc.read(io.open(file, "r"):read("*a"), "markdown").meta
    local outputRow = {
        string = tostring(metadata.title):match('\"(.*)\"'),
        source = file
    }
    table.insert(outputJSON, outputRow)

    if type(metadata.macros) == "table" then
        for _, value in ipairs(metadata.macros) do
            local cmd = pandoc.utils.stringify(value.command)
            local macro = pandoc.utils.stringify(value.macro)
            local variables = 0
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
                        MathJaxJSON[cmd] = {
                            macro,
                            tonumber(variables),
                            variablesDefaultArray
                        }
                        LaTeXJSON = LaTeXJSON .. "\\newcommand{\\" .. cmd .. "}[" .. variables .. "]" .. pandoc.utils.stringify(variablesDefaultArray) .. "{" .. macro .. "}\n"
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
                        MathJaxJSON[cmd] = {
                            macro,
                            tonumber(variables),
                            variablesDefaultString
                        }
                        LaTeXJSON = LaTeXJSON .. "\\newcommand{\\" .. cmd .. "}[" .. variables .. "][" .. variablesDefaultString .. "]{" .. macro .. "}\n"
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
                    MathJaxJSON[cmd] = {
                        macro,
                        tonumber(variables)
                    }
                    LaTeXJSON = LaTeXJSON .. "\\newcommand{\\" .. cmd .. "}[" .. variables .. "]{" .. macro .. "}\n"
                end
            else
                outputMacros = {
                    string = "\\" .. cmd,
                    command = cmd,
                    macro = macro,
                    source = file,
                    Type = "MathJaxMacro"
                }
                MathJaxJSON[cmd] = macro
                LaTeXJSON = LaTeXJSON .. "\\newcommand{\\" .. cmd .. "}{" .. macro .. "}\n"
            end
            if value.description ~= nil then
                notationJSON["\\" .. cmd] = pandoc.utils.stringify(value.description)
            end
            table.insert(outputJSON, outputMacros)
        end
    end
end

outputJSONEncoding = pandoc.json.encode(outputJSON):gsub("},{","\n  },\n  {"):gsub(",\"",",\n    \""):gsub("{\"","{\n    \""):gsub(":",": ")
outputJSONEncoding2 = "[\n  {" .. string.sub(outputJSONEncoding, 3,-3) .. "\n  }\n]"
io.open(OutputFile, "w"):write(outputJSONEncoding2, "\n")

MathJaxJSONEncoding = pandoc.json.encode(MathJaxJSON):gsub(",",", "):gsub(":",": ")
MathJaxJSONEncoding2 = string.gsub(string.gsub(MathJaxJSONEncoding,"\", \"","\",\n  \""),"], \"","],\n  \"")
MathJaxJSONEncoding3 = "{\n  " .. MathJaxJSONEncoding2:match "^{(.*)}$" .. "\n}"
io.open(OutputMathJaxFile, "w"):write(MathJaxJSONEncoding3)
print(MathJaxJSONEncoding3)

io.open(OutputLaTexFile, "w"):write(LaTeXJSON)

notationJSONEncoding = pandoc.json.encode(notationJSON):gsub("\",","\",\n  "):gsub(":",": ")
notationJSONEncoding2 = "{\n  " .. notationJSONEncoding:match "^{(.*)}$" .. "\n}"
io.open(OutputNotationFile, "w"):write(notationJSONEncoding2)

print("Macros updated from metadata.")