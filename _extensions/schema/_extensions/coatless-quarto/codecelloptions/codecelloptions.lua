-- Check if variable missing or an empty string
local function isVariableEmpty(s)
  return s == nil or s == ''
end

-- Copy the top level value and its direct children
-- Details: http://lua-users.org/wiki/CopyTable
local function shallowcopy(original)
  -- Determine if its a table
  if type(original) == 'table' then
    -- Copy the top level to remove references
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = value
    end
    -- Return the copy
    return copy
  else
    -- If original is not a table, return it directly since it's already a copy
    return original
  end
end

-- Custom method for cloning a table with a shallow copy.
function table.clone(original)
  return shallowcopy(original)
end

local function mergeCellOptions(localOptions, defaultOptions)
  -- Copy default options to the mergedOptions table
  local mergedOptions = table.clone(defaultOptions)

  -- Override default options with local options
  for key, value in pairs(localOptions) do
    if type(value) == "string" then
      value = value:gsub("[\"']", "")
    end
    mergedOptions[key] = value
  end

  -- Return the customized options
  return mergedOptions
end

-- Remove lines with only whitespace until the first non-whitespace character is detected.
local function removeEmptyLinesUntilContent(codeText)
  -- Iterate through each line in the codeText table
  for _, value in ipairs(codeText) do
      -- Detect leading whitespace (newline, return character, or empty space)
      local detectedWhitespace = string.match(value, "^%s*$")

      -- Check if the detectedWhitespace is either an empty string or nil
      -- This indicates whitespace was detected
      if isVariableEmpty(detectedWhitespace) then
          -- Delete empty space
          table.remove(codeText, 1)
      else
          -- Stop the loop as we've now have content
          break
      end
  end

  -- Return the modified table
  return codeText
end

-- Extract Quarto code cell options from the block's text
local function extractCodeBlockOptions(block)
  
  -- Access the text aspect of the code block
  local code = block.text

  -- Define two local tables:
  --  the block's attributes
  --  the block's code lines
  local cellOptions = {}
  local newCodeLines = {}

  -- Iterate over each line in the code block 
  for line in code:gmatch("([^\r\n]*)[\r\n]?") do
    -- Check if the line starts with "#|" and extract the key-value pairing
    -- e.g. #| key: value goes to cellOptions[key] -> value
    local key, value = line:match("^#|%s*(.-):%s*(.-)%s*$")

    -- If a special comment is found, then add the key-value pairing to the cellOptions table
    if key and value then
      cellOptions[key] = value
    else
      -- Otherwise, it's not a special comment, keep the code line
      table.insert(newCodeLines, line)
    end
  end

  -- Merge cell options with default options
  cellOptions = mergeCellOptions(cellOptions)

  -- Set the codeblock text to exclude the special comments.
  cellCode = table.concat(newCodeLines, '\n')

  -- Return the code alongside options
  return cellCode, cellOptions
end

return {
  removeEmptyLinesUntilContent = removeEmptyLinesUntilContent,
  extractCodeBlockOptions = extractCodeBlockOptions,
  mergeCellOptions = mergeCellOptions
}