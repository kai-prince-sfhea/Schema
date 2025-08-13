-- Load required libraries
local schema = require("../schema")

-- Resolve paths for project inputs and _schema artifacts
local InputDir = os.getenv("QUARTO_PROJECT_ROOT") or error("QUARTO_PROJECT_ROOT not set")
local MathDir = pandoc.path.join({InputDir, "_schema"})
local File = pandoc.path.make_relative(quarto.doc.input_file,InputDir)
local OutputDir = pandoc.path.directory(File)
print("Rendering file: " .. File)

-- Read Resources
local TermsJSON = {}
TermsFile = io.open(pandoc.path.join({MathDir, "Terms.json"}), "r")
if TermsFile ~= nil then
    TermsJSON = pandoc.json.decode(TermsFile:read("a"))
    TermsFile:close()
end

local LinksJSON = {}
LinksFile = io.open(pandoc.path.join({MathDir, "Links.json"}), "r")
if LinksFile ~= nil then
    LinksJSON = pandoc.json.decode(LinksFile:read("a"))
    LinksFile:close()
end
local FileLinks = LinksJSON[File] or {}
local RefTerms = FileLinks.RefTerms or {}
local RefMath = FileLinks.RefMath or {}

-- Load MathJSON, Math Dependencies and Math Sorted Keys
local MathSortedKeys = {}
MathFile = io.open(pandoc.path.join({MathDir, "Math.json"}), "r")
if MathFile ~= nil then
    content = pandoc.json.decode(MathFile:read("a"))
    MathSortedKeys = content.sortedKeys
    MathFile:close()
end

do
    local fh = io.open(pandoc.path.join({MathDir,"Directories.json"}),"r")
    local data = fh and fh:read("a") or "{}"
    if fh then fh:close() end
    RenderDir = quarto.json.decode(data)
end

local maths_tracked = false

-- Replace dummy math variables and prime math resource copying for HTML
function Math (math)

    -- Make sure math rendering is tracked and document options configured
    if maths_tracked == false then
        print("- Maths detected")
        maths_tracked = true

        if quarto.doc.is_format("html") then
            print(" - HTML File detected")
            if RenderDir[OutputDir].RenderMathJax == false then
                -- Apply MathJax rendering to directory
                RenderDir[OutputDir].RenderMathJax = true
                do
                    local f = io.open(pandoc.path.join({MathDir,"Directories.json"}),"w")
                    if f then f:write(schema.pretty_json(quarto.json.encode(RenderDir))); f:close() end
                end

                -- Ensure MathJax config is included in directory
                quarto.doc.add_format_resource("../resources/mathjax-config.js")
            end
        elseif quarto.doc.is_format("latex") then
            print(" - LaTeX File detected")
            -- Ensure LaTeX macros are included in header
            LaTeX = FileLinks.LaTeX
            quarto.doc.include_text("in-header", LaTeX)
        else
            print(" - Unknown Format detected")
            LaTeX = FileLinks.LaTeX
            quarto.doc.include_text("before-body", "$$"..LaTeX.."$$")
        end
    end

    -- Output Math Variables filter result
    return schema.MathVariables(math)
end

local MentionedTerms = {}

-- Feature toggles/titles from metadata
local enable_backlinks = false
local enable_outlinks = false
local enable_ton = false
local backlinks_title = "Backlinks"
local outlinks_title = "Outlinks"
local ton_title = "Notation"

local function meta_bool(v)
    if v == nil then return false end
    if type(v) == "boolean" then return v end
    if type(v) == "table" and v.t == "MetaBool" then return v.c end
    if type(v) == "string" then return v:lower() == "true" end
    return false
end

function link_terms_in_body(el)
    if not (quarto.doc.is_format("html") and el.t == "Str") then return nil end
    local text = el.text
    -- Separate leading/trailing punctuation so first visible occurrence can be linked
    local leading = text:match("^(%p+)") or ""
    local trailing = text:match("(%p+)$") or ""
    local core = text
    if leading ~= "" then core = core:sub(#leading + 1) end
    if trailing ~= "" then core = core:sub(1, #core - #trailing) end

    if core ~= "" and RefTerms[core] and not MentionedTerms[core] then
        print('Creating link for term: "' .. core .. '"')
        MentionedTerms[core] = true
        local entry = TermsJSON[core]
        if not entry then return nil end
        local sourceFile = entry.sourceFile
        if not (FileLinks and FileLinks.RelLinks and sourceFile and FileLinks.RelLinks[sourceFile]) then return nil end
        local url = ".\\" .. FileLinks.RelLinks[sourceFile]:gsub("%.qmd$", ".html")
        if entry.sourceRef then
            url = url .. "#" .. entry.sourceRef
            print("Adding source reference to URL: " .. url)
        end
        -- Return [leading][Link(core)][trailing]
        local inlines = pandoc.List()
        if leading ~= "" then inlines:insert(pandoc.Str(leading)) end
        inlines:insert(pandoc.Link(pandoc.Inlines{ pandoc.Str(core) }, url))
        if trailing ~= "" then inlines:insert(pandoc.Str(trailing)) end
        return inlines
    end
    return nil
end

function Meta(meta)
    in_header = true
    if meta and meta.schema then
        local s = meta.schema
        enable_backlinks = meta_bool(s.backlinks)
        enable_outlinks = meta_bool(s.outlinks)
        backlinks_title = pandoc.utils.stringify(s["backlinks-title"] or backlinks_title)
        outlinks_title = pandoc.utils.stringify(s["outlinks-title"] or outlinks_title)
    end
    -- ton behaves like toc, configured per format; support html/latex keys or common
    if meta and meta.ton then
        enable_ton = meta_bool(meta.ton)
        ton_title = pandoc.utils.stringify(meta["ton-title"] or ton_title)
    end
    -- Fallback: allow schema.ton as a simple toggle
    if meta and meta.schema and meta.schema.ton ~= nil then
        enable_ton = meta_bool(meta.schema.ton)
    end
    return meta
end

function Pandoc(doc)
    -- Link first visible mention of referenced terms inside the body only
    for i, block in ipairs(doc.blocks) do
        doc.blocks[i] = pandoc.walk_block(block, {
            Str = link_terms_in_body
        })
    end

    -- HTML-only: add backlinks (top) and outlinks (bottom) sections when enabled
    if quarto.doc.is_format("html") then
        -- Helper to prefix relative URLs for Windows-style paths like other links in this extension
        local function to_html_path(rel)
            return ".\\" .. rel:gsub("%.qmd$", ".html")
        end

    -- Backlinks: unique pages this file depends on
        if enable_backlinks then
            local page_set = {}
            local function consider(term)
                local tdata = TermsJSON[term]
                if not tdata then return end
                local src = tdata.sourceFile
                if src and src ~= File then page_set[src] = true end
            end
            for term, _ in pairs(RefTerms or {}) do consider(term) end
            for term, _ in pairs(RefMath or {}) do consider(term) end

            local function title_for(path)
                return (LinksJSON[path] and LinksJSON[path].Title)
                    or (path:gsub("\\", "/"):match("([^/]+)$") or path)
            end
            -- Order pages by dependency order from LinksJSON.sorted_keys, then append any remaining (by title)
            local items = {}
            local sorted_keys = (LinksJSON and LinksJSON.sorted_keys) or {}
            local added = {}
            for _, src in ipairs(sorted_keys) do
                if page_set[src] then
                    local url = schema.RelativePath(File, src)
                    local title = title_for(src)
                    table.insert(items, pandoc.Plain({ pandoc.Link(pandoc.Inlines{ pandoc.Str(title) }, url) }))
                    added[src] = true
                end
            end
            -- Add any pages not present in sorted_keys in a deterministic order (by title)
            local remaining = {}
            for src, _ in pairs(page_set) do
                if not added[src] then table.insert(remaining, src) end
            end
            table.sort(remaining, function(a, b) return title_for(a) < title_for(b) end)
            for _, src in ipairs(remaining) do
                local url = schema.RelativePath(File, src)
                local title = title_for(src)
                table.insert(items, pandoc.Plain({ pandoc.Link(pandoc.Inlines{ pandoc.Str(title) }, url) }))
            end

            if #items > 0 then
                local function sanitize_id(s)
                    s = tostring(s or "")
                    s = s:gsub("%s+", "-")
                    s = s:gsub("[^%w%-_]+", "")
                    return s
                end
                local header = pandoc.Header(2, pandoc.Inlines{ pandoc.Str(backlinks_title) }, pandoc.Attr("sec-"..sanitize_id(backlinks_title), {"unnumbered"}))
                local list = pandoc.BulletList(items)
                local div = pandoc.Div({ header, list }, pandoc.Attr(nil, {"schema-backlinks"}))
                table.insert(doc.blocks, 1, div)
            end
        end

    -- Outlinks: unique pages referencing terms defined here
        if enable_outlinks then
            -- Build set of terms covered in this file (both math and non-math)
            local covered = {}
            for term, tdata in pairs(TermsJSON or {}) do
                if tdata and tdata.sourceFile == File then
                    covered[term] = true
                end
            end

            -- Set of files that reference any covered term
            local page_set = {}
            for otherFile, data in pairs(LinksJSON or {}) do
                if otherFile ~= File then
                    local rterms = (data and data.RefTerms) or {}
                    for term, _ in pairs(rterms) do
                        if covered[term] then
                            page_set[otherFile] = true
                        end
                    end
                    local rmath = (data and data.RefMath) or {}
                    for term, _ in pairs(rmath) do
                        if covered[term] then
                            page_set[otherFile] = true
                        end
                    end
                end
            end

            -- Build list items of pages (unique)
            local function title_for(path)
                return (LinksJSON[path] and LinksJSON[path].Title)
                    or (path:gsub("\\", "/"):match("([^/]+)$") or path)
            end
            -- Order pages by dependency order from LinksJSON.sorted_keys, then append any remaining (by title)
            local items = {}
            local sorted_keys = (LinksJSON and LinksJSON.sorted_keys) or {}
            local added = {}
            for _, f in ipairs(sorted_keys) do
                if page_set[f] then
                    local url = schema.RelativePath(File, f)
                    local title = title_for(f)
                    table.insert(items, pandoc.Plain({ pandoc.Link(pandoc.Inlines{ pandoc.Str(title) }, url) }))
                    added[f] = true
                end
            end
            local remaining = {}
            for f, _ in pairs(page_set) do
                if not added[f] then table.insert(remaining, f) end
            end
            table.sort(remaining, function(a, b) return title_for(a) < title_for(b) end)
            for _, f in ipairs(remaining) do
                local url = schema.RelativePath(File, f)
                local title = title_for(f)
                table.insert(items, pandoc.Plain({ pandoc.Link(pandoc.Inlines{ pandoc.Str(title) }, url) }))
            end

            if #items > 0 then
                local function sanitize_id(s)
                    s = tostring(s or "")
                    s = s:gsub("%s+", "-")
                    s = s:gsub("[^%w%-_]+", "")
                    return s
                end
                local header = pandoc.Header(2, pandoc.Inlines{ pandoc.Str(outlinks_title) }, pandoc.Attr("sec-"..sanitize_id(outlinks_title), {"unnumbered"}))
                local list = pandoc.BulletList(items)
                local div = pandoc.Div({ header, list }, pandoc.Attr(nil, {"schema-outlinks"}))
                table.insert(doc.blocks, div)
            end
        end

    -- Table of Notation (TON): near top; for HTML place after backlinks
        if enable_ton then
            -- Determine if there are notation rows (from Links.json for this file)
            local notations = FileLinks.FileNotation or {}
            if next(notations) ~= nil then
                print(" - External notation detected")
                -- Build a markdown table for portability across Pandoc versions
                local function esc_pipe(s)
                    s = tostring(s or "")
                    s = s:gsub("|", "\\|")
                    return s
                end
                local md = ""
                md = md .. "| Term | Description |\n"
                md = md .. "| --- | --- |\n"
                for _, key in ipairs(MathSortedKeys) do
                    if notations["\\" .. key] then
                        local row = notations["\\" .. key]
                        local term = (row.LaTeX..string.rep("{}", row.mandatoryVars)) or ""
                        local desc = esc_pipe(row.description or "")
                        local src = row.Source or ""
                        if src ~= "" then
                            local url = schema.RelativePath(File, src:gsub("#.*$", ""))
                            if src:match("#") then url = url .. src:match("#.*$") end
                            desc = desc .. " ([Source]("..url.."))"
                        end
                        md = md .. string.format("| %s | %s |\n", esc_pipe(term), desc)
                    end
                end
                local tdoc = pandoc.read(md, "markdown")

                -- Insert near top (after backlinks if present in HTML), with unnumbered header
                local insertIndex = 1
                if quarto.doc.is_format("html") then
                    if #doc.blocks > 0 and doc.blocks[1].t == "Div" and doc.blocks[1].attr and doc.blocks[1].attr.classes then
                        for _, c in ipairs(doc.blocks[1].attr.classes) do
                            if c == "schema-backlinks" then insertIndex = 2 break end
                        end
                    end
                end
                local function sanitize_id(s)
                    s = tostring(s or "")
                    s = s:gsub("%s+", "-")
                    s = s:gsub("[^%w%-_]+", "")
                    return s
                end
                local header = pandoc.Header(2, pandoc.Inlines{ pandoc.Str(ton_title) }, pandoc.Attr("sec-"..sanitize_id(ton_title), {"unnumbered"}))
                table.insert(doc.blocks, insertIndex, header)
                for i = #tdoc.blocks, 1, -1 do
                    table.insert(doc.blocks, insertIndex + 1, tdoc.blocks[i])
                end
            end
        end
    end
    return doc
end

return {
    { Math = Math },
    { Meta = Meta },
    { Pandoc = Pandoc }
}