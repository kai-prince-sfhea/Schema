-- Load required libraries
local schema = require("../schema")

-- Directories
local InputDir = os.getenv("QUARTO_PROJECT_ROOT") or error("QUARTO_PROJECT_ROOT not set")
local MathDir = pandoc.path.join({InputDir, "_schema"})
local File = pandoc.path.make_relative(quarto.doc.input_file, InputDir)

-- Read data
local TermsJSON = {}
do
  local fh = io.open(pandoc.path.join({MathDir, "Terms.json"}), "r")
  if fh then
    TermsJSON = pandoc.json.decode(fh:read("a"))
    fh:close()
  end
end

-- Links (for inline fallbacks / URLs)
local LinksJSON, FileLinks = {}, {}
do
  local fh = io.open(pandoc.path.join({MathDir, "Links.json"}), "r")
  if fh then
    LinksJSON = pandoc.json.decode(fh:read("a"))
    fh:close()
  end
  FileLinks = LinksJSON[File] or {}
end

-- Load in Shortcode Title
local function load_title(term_data, removeURLs_option)
  local output = {
    capitalised = "",
    uncapitalised = ""
  }
  if quarto.doc.is_format("html") and removeURLs_option == false then
    -- title is true and HTML format and removeURLs is false
    file = term_data.urlMD:match('%[[^]]+%]%(([^)]+) "[^"]+"%)')
    output.capitalised = term_data.urlMD:gsub(schema.escape_pattern(file), FileLinks.RelLinks[file])
    output.uncapitalised = term_data.urlTitle:gsub(schema.escape_pattern(file), FileLinks.RelLinks[file])
  else
    -- title is true but no links to be included
    output.capitalised = term_data.titleMD
    output.uncapitalised = term_data.title
  end
  return output
end

-- Apply filters to the Pandoc document
local function apply_filters(Doc, meta, templateMap, replacementMap)
  local PandocDoc = pandoc.Pandoc(Doc.blocks, meta)
  if #templateMap > 0 and #replacementMap > 0 then
    quarto.log.debug("Applying templateMap and replacementMap to PandocDoc")
    PandocDoc = PandocDoc:walk({
      Math = function(math)
        return schema.MathReplacement(math, templateMap, replacementMap)
      end
    })
  else
    quarto.log.debug("No templateMap or replacementMap provided; skipping replacement.")
    PandocDoc = PandocDoc:walk({
      Math = function(math)
        return schema.MathVariables(math)
      end
    })
  end
  return PandocDoc
end

-- Output the correct format for the associated context
local function format_shortcode_output(Filtered, context)
  if context == "block" then
    quarto.log.debug("Returning Blocks")
    return Filtered.blocks
  elseif context == "inline" then
    quarto.log.debug("Returning Inlines")
    return pandoc.Inlines(Filtered.blocks[1])
  else
    quarto.log.warning("'text' context not supported for term shortcode; returning empty.")
    return pandoc.text(Filtered.blocks[1]) or pandoc.Str("")
  end
end

return {
  ["term"] = function(args, kwargs, meta, raw_args, context)
    -- kwargs:
      -- ref: "[term]", 
      -- title: true|false,
      -- block: true|false,
      -- templateMap: "[...]"
      -- removeURLs: true|false
    -- context: [block|inline|text]

  -- Check that ref is included as mandatory
    if not kwargs["ref"] then
      quarto.log.warning("Error: 'ref' argument is required for term shortcode.")
      return pandoc.Null()
    end
    quarto.log.info("Processing term shortcode with ref: " .. pandoc.utils.stringify(kwargs["ref"]))
    quarto.log.info("Context: " .. tostring(context or ""))

    -- Construct Replacement Map
    local replacementMap = {}
    if #kwargs["templateMap"] > 0 then
      replacementMap = quarto.json.decode(schema.to_json_array(kwargs["templateMap"]))
    end

    -- Load in Term, Term Data and Template Map
    local term = "@" .. pandoc.utils.stringify(kwargs["ref"])
    local term_data = TermsJSON[term]
    local templateMap = {}
    if term_data.templateMap then
      templateMap = term_data.templateMap
    end

    quarto.log.debug("Template Map:\n" .. schema.pretty_json(quarto.json.encode(templateMap)))
    quarto.log.debug("Replacement Map:\n" .. schema.pretty_json(quarto.json.encode(replacementMap)))

    -- Initialising Options
    local title_option = kwargs["title"] == "true" or kwargs["Title"] == "true"
    local block_option = kwargs["block"] == "true" or kwargs["Block"] == "true"
    local removeURLs_option = kwargs["removeURLs"] == "true" or kwargs["RemoveURLs"] == "true"

    quarto.log.info("Title Option: " .. tostring(title_option))
    quarto.log.info("Block Option: " .. tostring(block_option))
    quarto.log.info("Remove URLs Option: " .. tostring(removeURLs_option))

    -- Load in Shortcode Body
    local body = term_data.blockMD
    if  quarto.doc.is_format("html") and removeURLs_option == false then
      -- Term is nested and HTML format
      body = term_data.HTMLMD
      -- Correct URLs in body
      for file in body:gmatch('%[[^]]+%]%(([^)]+) "[^"]+"%)') do
         body = body:gsub(schema.escape_pattern(file), FileLinks.RelLinks[file])
      end
    end

    if not block_option or context ~= "block" then
      -- Convert to Inlines if not block option or context is not block
      body = body:gsub("\n+%-?%s*", " ")
      if block_option and context ~= "block" then
        -- block option is true but context is not block
        quarto.log.warning("Term shortcode 'block' used in inline/text context; falling back to inline.")
      end
    end

    -- Load in Shortcode Title
    if title_option == true then
      local title = load_title(term_data, removeURLs_option).capitalised
      body = "*" .. title .. ":* " .. body
    end

    -- Apply Filters to body
    local PandocDoc = pandoc.read(body, "markdown")
    local Filtered = apply_filters(PandocDoc, meta, templateMap, replacementMap)

    return format_shortcode_output(Filtered, context)
  end,
  
  ["term-title"] = function(args, kwargs, meta, raw_args, context)
    -- kwargs:
      -- ref: "[term]",
      -- removeURLs: true|false
    -- context: [block|inline|text]

  -- Check that ref is included as mandatory
    if not kwargs["ref"] then
      quarto.log.warning("Error: 'ref' argument is required for term shortcode.")
      return pandoc.Null()
    end
    quarto.log.info("Processing term shortcode with ref: " .. pandoc.utils.stringify(kwargs["ref"]))
    quarto.log.info("Context: " .. tostring(context or ""))

    -- Load in Term, Term Data and Template Map
    local term = "@" .. pandoc.utils.stringify(kwargs["ref"])
    local term_data = TermsJSON[term]

    -- Initialising Options
    local removeURLs_option = kwargs["removeURLs"] == "true" or kwargs["RemoveURLs"] == "true"
    quarto.log.info("Remove URLs Option: " .. tostring(removeURLs_option))

    -- Load in Shortcode Title
    local title = load_title(term_data, removeURLs_option).uncapitalised

    -- Apply Filters to body
    local PandocDoc = pandoc.read(title, "markdown")
    local Filtered = apply_filters(PandocDoc, meta, {}, {})

    return format_shortcode_output(Filtered, context)
  end
}