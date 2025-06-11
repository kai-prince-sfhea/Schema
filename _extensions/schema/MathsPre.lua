print("=== MathsPre.lua filter loaded ===")

local OutputDir = os.getenv("QUARTO_PROJECT_OUTPUT_DIR") or error("QUARTO_PROJECT_OUTPUT_DIR not set")
pandoc.system.make_directory(OutputDir)
local OutputFile = pandoc.path.join({OutputDir, "math-macros.json"})
print(OutputFile)

local InputFiles = os.getenv("QUARTO_PROJECT_INPUT_FILES") or error("QUARTO_PROJECT_INPUT_FILES not set")
local Files = {}
for file in InputFiles:gmatch("[^\r\n]+") do
    table.insert(Files, file)
end
print(pandoc.utils.stringify(Files))

local outputJSON = {}

for _, file in ipairs(Files) do
    local metadata = pandoc.read(io.open(file, "r"):read("*a"), "markdown").meta
    local outputRow = {
        string = tostring(metadata.title):match('\"(.*)\"'),
        source = file
    }
    table.insert(outputJSON, outputRow)
    print(pandoc.json.decode)

    if type(metadata.macros) == "table" then
        for _, value in ipairs(metadata.macros) do
            print(value.macro)
            local cmd = pandoc.utils.stringify(value.command)
            local macro = pandoc.utils.stringify(value.macro)
            local variables = ""
            local variablesDefaultString = ""
            local variablesDefaultArray = {}
            local outputMacros = {}
            if value.variables ~= nil then
                variables = pandoc.utils.stringify(value.variables)
                if value.variablesDefault ~= nil then
                    if type(value.variablesDefault) == "table" then
                        for _, string in ipairs(value.variablesDefault) do
                            table.insert(variablesDefaultArray, pandoc.utils.stringify(string))
                            outputMacros = {
                                string = "\\" .. cmd,
                                command = cmd,
                                macro = macro,
                                variables = variables,
                                variablesDefault = variablesDefaultArray,
                                source = file,
                                Type = "MathJaxMacro"
                            }
                        end
                    else
                        variablesDefaultString = pandoc.utils.stringify(value.variablesDefault)
                        outputMacros = {
                            string = "\\" .. cmd,
                            command = cmd,
                            macro = macro,
                            variables = variables,
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
                        variables = variables,
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
            print("Macro stored: " .. cmd .. " = " .. macro)
        end
    else
        print("No macros found in file: " .. file)
    end
end
print(pandoc.json.encode(outputJSON, {indent = true}))

io.open(OutputFile, "w"):write(pandoc.json.encode(outputJSON, {indent = true}), "\n")
print("Macros updated from metadata.")