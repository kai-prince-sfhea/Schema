-- Load required libraries
local schema = require("../schema")

-- Load LaTeX and MathJax File Directory
local InputDir = os.getenv("QUARTO_PROJECT_ROOT") or error("QUARTO_PROJECT_ROOT not set")
local MathDir = pandoc.path.join({InputDir, "_maths"})
local OutputDir = pandoc.path.directory(quarto.doc.output_file)

-- Set Output File Directories
local OutputLinksFile = pandoc.path.join({MathDir, "Links.json"})

-- Initialise Output Variables


-- Read Resources
local LinksJSON = {}
LinksFile = io.open(pandoc.path.join({MathDir, "Links.json"}), "r")
if LinksFile ~= nil then
    LinksJSON = pandoc.json.decode(LinksFile:read("a"))
end

-- Include LaTeX File in Header
if quarto.doc.is_format("latex") then
    print("- LaTeX File detected")

    LaTeXFileDir = pandoc.path.join({MathDir, "Tex-macros.tex"})
    LaTeXFile = io.open(LaTeXFileDir,"r"):read("a")
    quarto.doc.include_text("in-header", LaTeXFile)
end

-- Specify inclusion of required files for HTML in Output Location
if quarto.doc.is_format("html") then
    print("- HTML File detected")

    RenderDirFile = io.open(pandoc.path.join({MathDir,"Render-Directories.json"}),"r"):read("a")
    RenderDir = quarto.json.decode(RenderDirFile)
    RenderDir[OutputDir] = true
    io.open(pandoc.path.join({MathDir,"Render-Directories.json"}),"w"):write(schema.pretty_json(quarto.json.encode(RenderDir)))
    quarto.doc.add_format_resource("../resources/mathjax-config.js")
end

-- Replace dummy variables
function Math (math)
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
    end
end

return {
    { Math = Math }
}