# Schema Extension for Quarto

## Overview

Schema is a Quarto extension for building highly structured, math-rich, and knowledge-graph-enabled websites and documents. It provides:
- Custom HTML, PDF, and LaTeX output formats
- Automated math macro and terminology management
- Cross-referencing and knowledge graph generation [Work in Progress]
- Support for custom code blocks (e.g., Rocq) [Planned]
- Personalization and interactivity options for readers [Planned]

## Features

- Pre-render filters collect math macros, terms, and cross-page references.
- Custom HTML template with MathJax config and Bootstrap SCSS.
- Theorems/proofs rendered via sun123zxy's Callouty Theorem extension.
- Term shortcode to embed or link canonical definitions.
- Backlinks/outlinks sections listing unique pages (not terms).
- Optional Table of Notation (TON) built from used macros per page.

## Installation

1. Install [Quarto](https://quarto.org/docs/get-started/).
2. Add the extension to your project:

   ```bash
   quarto add kai-prince-sfhea/schema
   ```

## Usage

1) Configure _quarto.yml

```yaml
format:
  [format]: # Insert the desired output format
    ton: true
    # show Table of Notation near the top
    # (HTML after backlinks)

    #ton-title: Notation

schema:
  backlinks: true
  outlinks: true
  # backlinks-title: Related pages
  # outlinks-title: Referenced by
```

2) Define terms and macros in page YAML

```yaml
terms:
  - term: Natural number
    regex: "[Nn]atural numbers?"
    associatedMacros:
      - command: "N"
        description: "The Natural Numbers: $1,2,...$"
        macro: "\\mathbb{N}"
  - term: associativity
    regex: "associativ[ei]t?y?"
    id: def-associativity
macros:
  - command: Inverse
    macro: '{#1}^{-1}'
    variables: 1
```

3) Use the term shortcode

- Default: ```{{< term ref="def-associativity" >}}```
    - Embeds the definition body, without any line breaks.
- With title: ```{{< term ref="def-associativity" title=true >}}```
    - Prepends the term title with emphasised format and a colon. In HTML, the title is a hyperlink to the source; in non-HTML formats it's plain text.
- Block embed: ```{{< term ref="def-associativity" block=true >}}```
    - Emits block content when used in a block context, including line breaks.
    - To assign an ID or classes to the embedded block, wrap the shortcode in a Div:
        ::: {#def-associativity-recall .definition}
        {{< term ref="def-associativity" block=true >}}
        :::
- Remove URLs: ```{{< term ref="def-associativity" removeURLs=true >}}```
    - Removes any hyperlinks from the embedded body.
- Template Map:
    - In source definitions, you can declare a template map on the canonical Div:
        ```
        ::: {#def-associativity templateMap="[\\Set, \\Operation, \\Identity]"}
        ...
        :::
        ```
    - When embedding, you can supply a replacement map to adapt notation to local context:
        ```
        {{< term ref="def-associativity" templateMap="[\\Group, \\GroupOperation, \\Identity, g, h, j]" >}}
        ```
    - The replacement map and MathRendering filter will fill any template variables of the form #1, #2, ... (default placeholders are #1=a, #2=b, ... if replacement variables are not provided).

Additionally, Familiarise yourself with sun123zxy's Callouty Theorem extension [here](https://github.com/sun123zxy/quarto-callouty-theorem).

## Scripts, Filters and Shortcodes

- MathMacrosConfig.lua (pre-render script):
    - Extracts macros/terms and builds Math.json, Terms.json, Document-contents.json.
- Dependencies.lua (pre-render script):
    - Detects cross-page references, writes Links.json with RefTerms/RefMath, FileNotation, Titles, and per-dir MathJax flags.
- MathRendering.lua (filter):
    - Adds backlinks (top) and outlinks (bottom) sections in HTML using page titles.
    - Inserts a Table of Notation near the top when enabled.
    - Links the first visible mention of referenced terms in HTML body.
- Shortcodes.lua:
    - Renders {{< term ref="..." >}} with title and block options (e.g., title=true, block=true), applies math replacements, and hyperlinks titles in HTML.
    - Supports template maps on source definitions and replacement maps via shortcode for context-aware notation.
- MathResources.lua (post-render script):
    - Creates Mathjax.json in the output folders where Mathjax is required and only with the macros mentioned under each folder.

## Troubleshooting

- **Slow rendering:** LuaLaTeX will be slow on first run due to package installations.
- **No backlinks/outlinks:** ensure the backlinks/outlinks are true in the project or document YAML metadata and that _schema/Links.json has entries generated from your document metadata.
- **Table of Notation missing:** enable ton under the active format, and ensure the page uses at least one custom macro that is defined in an external file.
- **Nested divs** will not work with the 'term' shortcode.

## Goals

The overall goal of this Extension is to maximise the accessibility of Research Output:

1. Starting from the Maths perspective and then generalising, enable webpages to cover individual concepts with configuration, such as notation and abbreviations carrying over to the rest of the website and alternative formats.
    1. It is preferable that the terminology be defined rigorously to enhance knowledge graph building as well as allowing for more accurate automatic translations.
    1. It is preferable that there be an option for definitions to be provided using templates, that can be updated when embedded on other pages.
1. Correct citations and their rendering when in callout block titles.
1. Allow Rocq to be used as an option for code blocks, with compilation options including raw code and/or pretty-printing, for the purpose of allowing website visitors to view and run Rocq code to verify proofs.
1. Embed knowledge graph building within the compilation process to allow for hyperlinked cross-referencing of specific objects and terminology across the website, as well as making the knowledge easily accessible to AI models.
    1. A graphical representation (similar to Obsidian) would be pretty cool!
1. Provide the framework to allow website visitors to personalise their user experience such as editing mathematical notation, terminology, etc.
1. Build options in procedurally generating web interactivity, for example, allowing website visitors to draft and verify their own proofs before looking at the "solutions" or generating quizzes.

## Planned Structure

1. Pre-render:
    1. Process and store maths macros for MathJax and LaTeX.
    1. Process and store terminology and details.
    1. Generate cross-referencing table with sufficient information required to embed template definitions.
1. Render: Apply Filters to each file to ensure the rendered outputs contain all relevant information, are appropriate for each format, and save cross-referenced information in a table.
    1. Filter math elements to replace any dummy variables leftover in template definitions and generate optional "list of notation" tables.
    1. Filter (theorem) environments to render callout blocks using the "callouty theorem" extension.
    1. Filter mention and template embedding to provide hyperlinked cross-referencing and consistency across linked concepts and generate optional "dependency" tables.
    1. Filter code blocks, with the help of the "code cell options" extension, to process Rocq.
1. Post-render:
    1. (Optional) Process data through Graphiti.
    1. Finalise data required for a graphical representation of knowledge graph.