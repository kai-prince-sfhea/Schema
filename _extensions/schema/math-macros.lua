-- Create new JSON file with math-macros from metadata
quarto.log.info("=== math-macros.lua filter loaded ===")
local mathMacrosDir = quarto.project.output_directory .. "/math-macros.json"
local mathMacrosFile = quarto.json.decode(io.open(mathMacrosDir, "r"):read("*a"))
quarto.log.info(mathMacrosFile)

