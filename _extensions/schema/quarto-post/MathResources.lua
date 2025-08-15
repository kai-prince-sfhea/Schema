-- Load Directories
local InputDir = os.getenv("QUARTO_PROJECT_ROOT") or error("QUARTO_PROJECT_ROOT not set")
local OutputDir = os.getenv("QUARTO_PROJECT_OUTPUT_DIR") or error("QUARTO_PROJECT_OUTPUT_DIR not set")
local MathDir = pandoc.path.join({InputDir, "_schema"})

-- Find Filter Directory
local ExtDir = pandoc.path.join({InputDir, "_extensions","kai-prince-sfhea","schema"})
ok, err, code = os.rename(ExtDir.."/", ExtDir.."/")
if not ok then
    ExtDir = pandoc.path.join({InputDir, "_extensions","schema"})
end

-- Load Schema Functions
local schema = dofile(pandoc.path.join({ExtDir, "schema.lua"}))

-- Load Directories
do
    local fh = io.open(pandoc.path.join({MathDir,"Directories.json"}),"r")
    local DirFile = fh and fh:read("a") or "{}"
    if fh then fh:close() end
    Dir = pandoc.json.decode(DirFile)
end

-- Load Document Contents
do
    local fh = io.open(pandoc.path.join({MathDir,"Document-contents.json"}),"r")
    local DocFile = fh and fh:read("a") or "{}"
    if fh then fh:close() end
    DocJSON = pandoc.json.decode(DocFile)
end

-- Iterate over directories
for key, value in pairs(Dir) do
    RenderDir = pandoc.path.normalize(pandoc.path.join({OutputDir, key}))

    -- Add MathJax resources where required
    print("Looking at: "..RenderDir)
    if value.RenderMathJax == true then
        print("Copying resource files")
        MathJax = value.MathJax
        MathJaxFile = schema.pretty_json(pandoc.json.encode(MathJax))
        do
            local f = io.open(pandoc.path.join({RenderDir, "Mathjax.json"}),"w")
            if f then f:write(MathJaxFile); f:close() end
        end
    end
end

print("Maths Resources copied")