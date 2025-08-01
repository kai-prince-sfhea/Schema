-- Load Directories
local InputDir = os.getenv("QUARTO_PROJECT_ROOT") or error("QUARTO_PROJECT_ROOT not set")
local MathDir = pandoc.path.join({InputDir, "_maths"})

RenderDirFile = io.open(pandoc.path.join({MathDir,"Render-Directories.json"}),"r"):read("a")
RenderDir = pandoc.json.decode(RenderDirFile)

for key, value in pairs(RenderDir) do
    OutputDir = key
    print("Looking at: "..OutputDir)
    if value == true then
        print("Copying resource files")
        MathJaxFile = io.open(pandoc.path.join({MathDir, "Mathjax.json"}),"r"):read("a")
        io.open(pandoc.path.join({OutputDir, "Mathjax.json"}),"w"):write(MathJaxFile):close()
    end
end

print("Maths Resources copied")