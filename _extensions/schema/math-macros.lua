-- Create new JSON file with math-macros from metadata
quarto.log.info("=== math-macros.lua filter loaded ===")
local mathMacrosDir = pandoc.path.join({quarto.project.output_directory, "mathjax-macros.json"})
quarto.log.info(mathMacrosDir)

function Math(math)
    local matchRegex = math.text:match '(.?#[0-9]+)'
    if matchRegex ~= nil then
        local output = math.text
        quarto.log.info("Math: " .. output)
        repeat
            Term = matchRegex:match '.?#([0-9]+)'
            FirstChar = matchRegex:match '^(.?)#[0-9]+' or ""
            quarto.log.info("Match Regex: \"" .. matchRegex .. "\", FirstChar: " .. FirstChar .. "\", Term: \"#" .. Term .. "\"")
            if FirstChar ~= "\\" then
                newTerm = string.char(96+tonumber(Term))
                quarto.log.info("No Slash: Yes, newTerm: " .. newTerm)
                replacement = FirstChar .. newTerm
                output = output:gsub(matchRegex, replacement)
            end
            matchRegex = output:match '(.?#[0-9]+)'
        until matchRegex == nil
        quarto.log.info("Final Math: " .. output)
        return pandoc.Math(math.mathtype, output)
    end
end