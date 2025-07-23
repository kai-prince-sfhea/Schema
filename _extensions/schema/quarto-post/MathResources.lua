-- Load Directories
local InputDir = os.getenv("QUARTO_PROJECT_ROOT") or error("QUARTO_PROJECT_ROOT not set")
local MathDir = pandoc.path.join({InputDir, "_maths"})

RenderDirFile = io.open(pandoc.path.join({MathDir,"Render-Directories.json"}),"r"):read()
RenderDir = pandoc.json.decode(RenderDirFile)

for key, value in pairs(RenderDir) do
    OutputDir = key
    print("Looking at: "..OutputDir)
    if value == true then
        print("Copying resource files")
        MathJaxFile = io.open(pandoc.path.join({MathDir, "Mathjax-macros.json"}),"r"):read("a")
        io.open(pandoc.path.join({OutputDir, "Mathjax-macros.json"}),"w"):write(MathJaxFile):close()
        NotationFile = io.open(pandoc.path.join({MathDir, "Notation.json"}),"r"):read("a")
        io.open(pandoc.path.join({OutputDir, "Notation.json"}),"w"):write(NotationFile):close()
    end
end

print("Maths Resources copied")