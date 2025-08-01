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

for k, v in pairs(DocJSON) do
    Terms = schema.extract_dependencies(v.contents,TermsJSON,"(\\?[^\\%s,.\"/]+)")
    FileLinks = {}
    FileNotation = {}
    RefLinks = {}
    RefTerms = {}
    for _, term in ipairs(Terms) do
        Source = TermsJSON[term].source
        File = Source:match("^([^#]+)")
        if File ~= k then
            FileLinks[File] = true
            table.insert(RefTerms, term)
            if Source:match("#") then
                RefLinks[Source] = true
            end
            if TermsJSON[term].description and TermsJSON[term].math then
                notationRow = {
                    LaTeX = term,
                    description = TermsJSON[term].description,
                    Source = Source
                }
                table.insert(FileNotation, notationRow)
            end
        end
    end
    LinkJSON[k] = {
        FileLinks = FileLinks,
        FileNotation = FileNotation,
        RefLinks = RefLinks,
        RefTerms = RefTerms,
        Terms = Terms
    }
end

-- Save LinksJSON Output to File
LinksJSONEncoding = schema.pretty_json(pandoc.json.encode(LinkJSON))
io.open(OutputLinksFile, "w"):write(LinksJSONEncoding)