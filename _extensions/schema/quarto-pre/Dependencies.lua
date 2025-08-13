print("Extracting schema links and notation...")
-- Load Project Directories
local InputDir = pandoc.system.get_working_directory() or error("Working directory not set")
local MathDir = pandoc.path.join({InputDir, "_schema"})

-- Find Filter Directory
local ExtDir = pandoc.path.join({InputDir, "_extensions","kai-prince-sfhea","schema"})
local ok, err, code = os.rename(ExtDir.."/", ExtDir.."/")
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
    DocFile:close()
end

-- Load MathJSON, Math Dependencies and Math Sorted Keys
local MathJSON = {}
local MathDep = {}
local MathSortedKeys = {}
MathFile = io.open(pandoc.path.join({MathDir, "Math.json"}), "r")
if MathFile ~= nil then
    content = pandoc.json.decode(MathFile:read("a"))
    MathJSON = content.MathJSON
    MathDep = content.dependencyGraph
    MathSortedKeys = content.sortedKeys
    MathFile:close()
end

-- Load Terms JSON
local OutputTermsFile = pandoc.path.join({MathDir, "Terms.json"})
local TermsJSON = {}
TermsFile = io.open(OutputTermsFile, "r")
if TermsFile ~= nil then
    TermsJSON = pandoc.json.decode(TermsFile:read("a"))
    TermsFile:close()
end

-- Set Output Links File 
local OutputLinksFile = pandoc.path.join({MathDir, "Links.json"})
local LinkJSON = {}
LinksFile = io.open(OutputLinksFile, "r")
if LinksFile ~= nil then
    LinkJSON = pandoc.json.decode(LinksFile:read("a"))
    LinksFile:close()
end

-- Set Output Directories File 
local OutputDirFile = pandoc.path.join({MathDir, "Directories.json"})
local DirJSON = {}
DirFile = io.open(OutputDirFile, "r")
if DirFile ~= nil then
    DirJSON = pandoc.json.decode(DirFile:read("a"))
    DirFile:close()
    for k, _ in pairs(DirJSON) do
        DirJSON[k].RenderMathJax = false -- Initialize math flag to false
    end
end

-- Get shortcode body and complete nested shortcodes
local function process_shortcode(shortcode, path)
    if shortcode:match('^{{<%s*term%s+ref="([^"]+)"%s+([^>]+)>}}$') then
        local ref, args = shortcode:match('{{<%s*term%s+ref="([^"]+)"%s+([^>]+)>}}')
        local term = "@" .. ref 
        local templateArgs = args:match('templateMap="(%[[^"]+%])"')
        local templateMap = {}
        if templateArgs then
            templateMap = pandoc.json.decode(schema.to_json_array(templateArgs):gsub("\\\\", "\\"))
        end
        local shortcode_body = ""
        local subpath = path or {}
        if subpath["@" .. ref] then
            PathStr = schema.pretty_json(pandoc.json.encode(path))
            print("Warning: Recursive term reference detected for " .. ref .. " in path:\n" .. PathStr)
            return ""
        else
            subpath["@" .. ref] = true
        end
        if TermsJSON[term].blockMD:match('({{<%s*term%s+ref="[^"]+"%s+[^>]*>}})') then
            local uniqueShortcodes = {}
            for shortcode in TermsJSON[term].blockMD:gmatch('({{<%s*term%s+ref="[^"]+"%s+[^>]*>}})') do
                uniqueShortcodes[shortcode] = true
            end
            for shortcode, _ in pairs(uniqueShortcodes) do
                shortcode_body, _ = process_shortcode(shortcode, subpath)
                TermsJSON[term].HTMLMD = TermsJSON[term].HTMLMD:gsub(schema.escape_pattern(shortcode), shortcode_body)
                clean_body = shortcode_body:gsub('%[([^]]+)%]%([^)]+ "[^"]+"%)', '%1')
                TermsJSON[term].divMD = TermsJSON[term].divMD:gsub(schema.escape_pattern(shortcode), clean_body)
                TermsJSON[term].blockMD = TermsJSON[term].blockMD:gsub(schema.escape_pattern(shortcode), clean_body)
            end
        end
        local inline = TermsJSON[term].blockMD:gsub("\n+%-?%s*", " ")
        if args:match('title%s*=%s*true') then
            shortcode_body = "*" .. TermsJSON[term].urlMD .. ":* " .. inline
        else
            shortcode_body = inline
        end
        if #templateMap > 0 and TermsJSON[term].templateMap then
            shortcode_body = schema.MathReplacementMD(shortcode_body, TermsJSON[term].templateMap, templateMap)
        end
        return shortcode_body, term
    else
        return "", ""
    end
end

-- Inline the contents of {{< term ref="..." >}} shortcodes to capture nested references
local function embed_content(body)
    local contents = body
    local uniqueShortcodes = {}
    local terms = {}

    for shortcode, shortcode_code in body:gmatch('({{<%s*(%a+)%s+ref="[^"]+"%s+[^>]*>}})') do
        uniqueShortcodes[shortcode] = shortcode_code
    end

    for shortcode, shortcode_code in pairs(uniqueShortcodes) do
        if shortcode_code == "term" then
            shortcode_body, term_visited= process_shortcode(shortcode, {})
            terms[term_visited] = true
            contents = contents:gsub(schema.escape_pattern(shortcode), shortcode_body)
        end
    end

    local definedCommands = {}

    for key, _ in pairs(terms) do
        term_data = TermsJSON[key]
        if term_data.termRef then
            original_key = term_data.termRef
            original_data = TermsJSON[original_key]
            if original_data.relatedCommands then
                for cmd, value in ipairs(original_data.relatedCommands) do
                    definedCommands[cmd] = value
                end
            end
        end
    end
    
    return contents, terms, definedCommands
end

dependencyGraph = {}
for k, v in pairs(DocJSON) do
    print("-Processing file: " .. k)
    Terms = {}
    dependencyGraph[k] = {}
    FileLinks = {}
    RelLinks = {}
    FileNotation = {}
    FileNotationSet = {}
    RefTerms = {}
    RefMath = {}
    local CurrentTitle = (DocJSON[k] and DocJSON[k].title) or ""

    FileContents, term_visited, FileNotationSet = embed_content(v.contents)

    for term, _ in pairs(term_visited) do
        Terms[term] = true
    end

    local RefTokenSet = {}
    for match in FileContents:gmatch("(@[%w%-_]+)") do
        RefTokenSet[match] = true
    end

    if not DirJSON[pandoc.path.directory(k)] then
        DirJSON[pandoc.path.directory(k)] = {
            RenderMathJax = false,
            MathJax = {}
        }
    end

    for term, termData in pairs(TermsJSON) do
        local standardMatch = FileContents:find(term, 1, true)
        local referenceMatch = false
        if not standardMatch and term:match("@") then
            referenceMatch = RefTokenSet[term] or false
        end
        -- Regex detection for non-math terms (if provided)
        local regexMatch = false
        if not standardMatch and not referenceMatch and termData.regex then
            local pattern = termData.regex
            -- Escape backslashes appropriately in Lua string matcher: pattern is already a Lua string here
            local ok, res = pcall(function() return FileContents:match(pattern) end)
            regexMatch = ok and (res ~= nil)
        end
        -- Check if term is in the file contents
        if standardMatch or referenceMatch or regexMatch then
            Terms[term] = true
            
            -- Check if term is a math command
            if termData.type == "math" then
                cmd = term:match("^\\(.+)$")
                DirJSON[pandoc.path.directory(k)].MathJax[cmd] = MathJSON[cmd].MathJax
                for _, dep in ipairs(MathDep[cmd]) do
                    Terms["\\" .. dep] = true
                end
            end

            -- Cross-page references: record backlinks/outlinks info
            File = termData.sourceFile
            if File ~= k then
                Source = File
                if FileLinks[File] == nil then
                    table.insert(dependencyGraph[k], File)
                    FileLinks[File] = {}
                end

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

                -- Compute relative link to source file
                RelativePath = schema.RelativePath(k, File)
                RelLinks[File] = RelativePath
            end
        end
    end

    local FileLaTeX = "\n"
    for _, term in ipairs(MathSortedKeys) do
        local LaTeXcmd = "\\" .. term
        if Terms[LaTeXcmd] then
            FileLaTeX = FileLaTeX .. MathJSON[term].LaTeX .. "\n"
        end
    end

    -- Build Table of Notation rows for used math macros
    for term, termData in pairs(TermsJSON) do
        if termData.type == "math" and termData.description and Terms[term] and not FileNotationSet[term] then
            local src = termData.sourceFile or ""
            local srcWithRef = src
            if termData.sourceRef then srcWithRef = srcWithRef .. "#" .. termData.sourceRef end
            FileNotation[term] = {
                LaTeX = "$"..term.."$",
                description = termData.description,
                Source = srcWithRef,
                mandatoryVars = termData.mandatoryVars,
                optionalVars = termData.optionalVars
            }
            FileNotationSet[term] = true
        end
    end

    LinkJSON[k] = {
        FileLinks = FileLinks,
        FileNotation = FileNotation,
        LaTeX = FileLaTeX .. "\n",
        RefMath = RefMath,
        RefTerms = RefTerms,
        RelLinks = RelLinks,
        Title = CurrentTitle
    }
end

LinkJSON["dependency_Graph"] = dependencyGraph
LinkJSON["sorted_keys"] = schema.topo_sort(dependencyGraph)

-- Save LinksJSON Output to File
LinksJSONEncoding = schema.pretty_json(pandoc.json.encode(LinkJSON))
do
    local f = io.open(OutputLinksFile, "w")
    if f then
        f:write(LinksJSONEncoding)
        f:close()
    else
        print("Warning: Unable to open Links.json for writing: " .. tostring(OutputLinksFile))
    end
end

-- Save TermsJSON Output to File
TermsJSONEncoding = schema.pretty_json(pandoc.json.encode(TermsJSON))
do
    local f = io.open(OutputTermsFile, "w")
    if f then
        f:write(TermsJSONEncoding)
        f:close()
    else
        print("Warning: Unable to open Terms.json for writing: " .. tostring(OutputTermsFile))
    end
end

-- Save DirJSON Output to File
DirJSONEncoding = schema.pretty_json(pandoc.json.encode(DirJSON))
do
    local f = io.open(OutputDirFile, "w")
    if f then
        f:write(DirJSONEncoding)
        f:close()
    else
        print("Warning: Unable to open Directories.json for writing: " .. tostring(OutputDirFile))
    end
end