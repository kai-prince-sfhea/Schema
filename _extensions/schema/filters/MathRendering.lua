-- Load LaTeX and MathJax File Directory
local InputDir = os.getenv("QUARTO_PROJECT_ROOT") or error("QUARTO_PROJECT_ROOT not set")
local MathDir = pandoc.path.join({InputDir, "_maths"})
local OutputDir = pandoc.path.directory(quarto.doc.output_file)

-- Include LaTeX File in Header
if quarto.doc.is_format("latex") then
    LaTeXFileDir = pandoc.path.join({MathDir, "Tex-macros.tex"})
    LaTeXFile = io.open(LaTeXFileDir,"r"):read("a")
    quarto.doc.include_text("in-header", LaTeXFile)
end

-- Include MathJax Macros File in Header
if quarto.doc.is_format("html") then
    RenderDirFile = io.open(pandoc.path.join({MathDir,"Render-Directories.json"}),"r"):read()
    RenderDir = quarto.json.decode(RenderDirFile)
    RenderDir[OutputDir] = true
    io.open(pandoc.path.join({MathDir,"Render-Directories.json"}),"w"):write(quarto.json.encode(RenderDir))
end

-- Replace dummy variables
function Math(math)
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

print("Math Rendered")