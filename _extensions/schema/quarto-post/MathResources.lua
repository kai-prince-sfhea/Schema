-- Load Directories
local InputDir = os.getenv("QUARTO_PROJECT_ROOT") or error("QUARTO_PROJECT_ROOT not set")
local OutputDir = os.getenv("QUARTO_PROJECT_OUTPUT_DIR") or error("QUARTO_PROJECT_OUTPUT_DIR not set")
local MathDir = pandoc.path.join({InputDir, "_maths"})

-- Find Filter Directory
local ExtDir = pandoc.path.join({InputDir, "_extensions","kai-prince-sfhea","schema"})
ok, err, code = os.rename(ExtDir.."/", ExtDir.."/")
if not ok then
    ExtDir = pandoc.path.join({InputDir, "_extensions","schema"})
end

-- Load Schema Functions
local schema = dofile(pandoc.path.join({ExtDir, "schema.lua"}))

DirFile = io.open(pandoc.path.join({MathDir,"Directories.json"}),"r"):read("a")
Dir = pandoc.json.decode(DirFile)

for key, value in pairs(Dir) do
    RenderDir = pandoc.path.normalize(pandoc.path.join({OutputDir, key}))
    print("Looking at: "..RenderDir)
    if value.RenderMathJax == true then
        print("Copying resource files")
        MathJax = value.MathJax
        MathJaxFile = schema.pretty_json(pandoc.json.encode(MathJax))
        io.open(pandoc.path.join({RenderDir, "Mathjax.json"}),"w"):write(MathJaxFile):close()
    end
end

print("Maths Resources copied")