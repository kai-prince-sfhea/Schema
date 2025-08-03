print("Extracting file dependencies...")
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

-- Load Document Contents JSON
local DocJSON = {}
local DocumentContentsFile = pandoc.path.join({MathDir, "Document-contents.json"})
DocFile = io.open(DocumentContentsFile, "r")
if DocFile ~= nil then
    DocJSON = pandoc.json.decode(DocFile:read("a"))
end

-- Load MathDependencies JSON
local MathDepJSON = {}
MathDepFile = io.open(pandoc.path.join({MathDir, "MathDependencies.json"}), "r")
if MathDepFile ~= nil then
    MathDepJSON = pandoc.json.decode(MathDepFile:read("a"))
end

-- Load MathJSON
local MathJSON = {}
MathFile = io.open(pandoc.path.join({MathDir, "Math.json"}), "r")
if MathFile ~= nil then
    MathJSON = pandoc.json.decode(MathFile:read("a"))
end

-- Load Terms JSON
local TermsJSON = {}
TermsFile = io.open(pandoc.path.join({MathDir, "Terms.json"}), "r")
if TermsFile ~= nil then
    TermsJSON = pandoc.json.decode(TermsFile:read("a"))
end

-- Set Output Links File 
local OutputLinksFile = pandoc.path.join({MathDir, "Links.json"})
local LinkJSON = {}
LinksFile = io.open(OutputLinksFile, "r")
if LinksFile ~= nil then
    LinkJSON = pandoc.json.decode(LinksFile:read("a"))
end

-- Set Output Directories File 
local OutputDirFile = pandoc.path.join({MathDir, "Directories.json"})
local DirJSON = {}
DirFile = io.open(OutputDirFile, "r")
if DirFile ~= nil then
    DirJSON = pandoc.json.decode(DirFile:read("a"))
    for k, _ in pairs(DirJSON) do
        DirJSON[k].RenderMathJax = false -- Initialize math flag to false
    end
end

FileDep = {}
for k, v in pairs(DocJSON) do
    Terms = {}
    FileDep[k] = {}
    FileLinks = {}
    RelLinks = {}
    FileNotation = {}
    RefTerms = {}
    RefMath = {}

    if not DirJSON[pandoc.path.directory(k)] then
        DirJSON[pandoc.path.directory(k)] = {
            RenderMathJax = false,
            MathJax = {}
        }
    end

    for term, termData in pairs(TermsJSON) do
        standardMatch = string.lower(v.contents):find(string.lower(term))
        referenceMatch = false
        if not standardMatch and term:match("@") then
            for match in v.contents:gmatch("(@[-a-zA-Z]+)") do
                if match == term then
                    referenceMatch = true
                    break
                end
            end
        end
        -- Check if term is in the file contents
        if standardMatch or referenceMatch then
            Terms[term] = true
            
            -- Check if term is a math command
            if termData.type == "math" then
                cmd = term:match("^\\(.+)$")
                DirJSON[pandoc.path.directory(k)].MathJax[cmd] = MathJSON[cmd].MathJax
            end

            -- Check if term source file is different from current file
            File = termData.sourceFile
            if File ~= k then
                Source = File
                table.insert(FileDep[k], File)
                FileLinks[File] = {}

                -- Check if term is a math command
                if termData.type == "math" then
                    RefMath[term] = true
                else
                    -- If term is not math, add to RefTerms
                    RefTerms[term] = true
                end

                -- Check if term has a relative link
                SourceRef = termData.sourceRef
                if SourceRef then
                    Source = File .. "#" .. SourceRef
                    table.insert(FileLinks[File],SourceRef)
                end

                -- Create relative link if source file is in the same directory
                RelativePath = schema.RelativePath(k, File)
                RelLinks[File] = RelativePath

                if termData.description and termData.type == "math" then
                    notationRow = {
                        LaTeX = term,
                        description = termData.description,
                        Source = Source
                    }
                    table.insert(FileNotation, notationRow)
                end
            end
        end
    end

    local FileLaTeX = "\n"
    for _, term in ipairs(MathDepJSON.sorted_keys) do
        local LaTeXcmd = "\\" .. term
        if Terms[LaTeXcmd] then
            local LaTeXdef = "\\newcommand{" .. LaTeXcmd .. "}" .. MathJSON[term].LaTeX
            FileLaTeX = FileLaTeX .. LaTeXdef .. "\n"
        end
    end

    LinkJSON[k] = {
        FileLinks = FileLinks,
        FileNotation = FileNotation,
        LaTeX = FileLaTeX .. "\n",
        RefMath = RefMath,
        RefTerms = RefTerms,
        RelLinks = RelLinks
    }
end

-- Save LinksJSON Output to File
LinksJSONEncoding = schema.pretty_json(pandoc.json.encode(LinkJSON))
io.open(OutputLinksFile, "w"):write(LinksJSONEncoding)

-- Save DirJSON Output to File
DirJSONEncoding = schema.pretty_json(pandoc.json.encode(DirJSON))
io.open(OutputDirFile, "w"):write(DirJSONEncoding)