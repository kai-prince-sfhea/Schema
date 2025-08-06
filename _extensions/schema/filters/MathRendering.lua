-- Load required libraries
local schema = require("../schema")

-- Load LaTeX and MathJax File Directory
local InputDir = os.getenv("QUARTO_PROJECT_ROOT") or error("QUARTO_PROJECT_ROOT not set")
local MathDir = pandoc.path.join({InputDir, "_maths"})
local File = pandoc.path.make_relative(quarto.doc.input_file,InputDir)
local OutputDir = pandoc.path.directory(File)
print("Rendering file: " .. File)

-- Read Resources
local TermsJSON = {}
TermsFile = io.open(pandoc.path.join({MathDir, "Terms.json"}), "r")
if TermsFile ~= nil then
    TermsJSON = pandoc.json.decode(TermsFile:read("a"))
end

local LinksJSON = {}
LinksFile = io.open(pandoc.path.join({MathDir, "Links.json"}), "r")
if LinksFile ~= nil then
    LinksJSON = pandoc.json.decode(LinksFile:read("a"))
end
local FileLinks = LinksJSON[File] or {}
local RefTerms = FileLinks.RefTerms or {}

RenderDirFile = io.open(pandoc.path.join({MathDir,"Directories.json"}),"r"):read("a")
RenderDir = quarto.json.decode(RenderDirFile)

-- Specify inclusion of required files for different formats
if quarto.doc.is_format("html") then
    print("- HTML File detected")
    
    quarto.doc.add_format_resource("../resources/mathjax-config.js")
elseif quarto.doc.is_format("latex") then
    print("- LaTeX File detected")
    LaTeX = FileLinks.LaTeX
    quarto.doc.include_text("in-header", LaTeX)
else
    print("- Unknown Format detected")
    LaTeX = FileLinks.LaTeX
    quarto.doc.include_text("before-body", "$$"..LaTeX.."$$")
end

-- Replace dummy variables
function Math (math)
    if quarto.doc.is_format("html") and RenderDir[OutputDir].RenderMathJax == false then
        print(" - Maths detected")
        
        RenderDir[OutputDir].RenderMathJax = true
        io.open(pandoc.path.join({MathDir,"Directories.json"}),"w"):write(schema.pretty_json(quarto.json.encode(RenderDir)))
    end
    return schema.MathVariables(math)
end

local MentionedTerms = {}

function link_terms_in_body(el)
    if el.t == "Str" and RefTerms[el.text] and not MentionedTerms[el.text] and quarto.doc.is_format("html") then
        local str = el.text
        print('Creating link for term: "' .. str .. '"')
        MentionedTerms[str] = true
        local SourceFile = TermsJSON[str].sourceFile
        local URL = ".\\"..FileLinks.RelLinks[SourceFile]:gsub(".qmd", ".html")
        if TermsJSON[str].sourceRef then
            URL = URL .. "#" .. TermsJSON[str].sourceRef
            print("Adding source reference to URL: " .. URL)
        end
        print("Creating link for term: " .. str .. " with URL: " .. URL)
        return pandoc.Link(str, URL)
    end
end

function Meta(meta)
    in_header = true
    return meta
end

function Pandoc(doc)
    -- Only walk the main document body, not metadata
    for i, block in ipairs(doc.blocks) do
        doc.blocks[i] = pandoc.walk_block(block, {
            Str = link_terms_in_body
        })
    end
    return doc
end

return {
    { Math = Math },
    { Meta = Meta },
    { Pandoc = Pandoc }
}