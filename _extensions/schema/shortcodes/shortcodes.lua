-- Load required libraries
local schema = require("../schema")

-- Load LaTeX and MathJax File Directory
local InputDir = os.getenv("QUARTO_PROJECT_ROOT") or error("QUARTO_PROJECT_ROOT not set")
local MathDir = pandoc.path.join({InputDir, "_maths"})
local File = pandoc.path.make_relative(quarto.doc.input_file,InputDir)
local OutputDir = pandoc.path.directory(File)

-- Read Resources
local TermsJSON = {}
TermsFile = io.open(pandoc.path.join({MathDir, "Terms.json"}), "r")
if TermsFile ~= nil then
    TermsJSON = pandoc.json.decode(TermsFile:read("a"))
end

function getTermBody(term, replacementMap)
    local entry = TermsJSON[term]
    if entry.blockBody ~= nil then
        local doc = pandoc.read(entry.blockBody)
        local blocks = doc.blocks:walk({
            Math = function(math)
                if entry.sourceArgs ~= "" then
                    templateArgs = entry.sourceArgs:match("templateMap=\"(%[[^\"]+%])\""):gsub("\\\\", "\\") 
                    templateMap = quarto.json.decode(schema.to_json_array(templateArgs))
                    return schema.MathReplacement(math, templateMap, replacementMap)
                else
                    return schema.MathVariables(math)
                end
            end
        })
        return blocks
    else
        return nil
    end
end

return {
  ["term"] = function(args, kwargs) 
    if not kwargs["ref"] then
        print("Error: 'ref' argument is required for term shortcode.")
        return pandoc.Null()
    end
    local term = "@"..pandoc.utils.stringify(kwargs["ref"])
    local replacementMap = quarto.json.decode(schema.to_json_array(kwargs["templateMap"])) or {}
    local body = getTermBody(term, replacementMap)
    if body ~= nil and type(body) == "table" then
        return body
    else
        return pandoc.Null()
    end
  end
}