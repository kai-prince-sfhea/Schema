# My Schema Extension for Quarto

## Installing

Install Quarto if you haven't already. You can find instructions on the [Quarto website](https://quarto.org/docs/get-started/).

Add the extension to your Quarto project by running the following command in your terminal:

```bash
quarto add kai-prince-sfhea/Schema
```

You will also need to install: 

* Neo4j (which you can download on the [Neo4j website](https://neo4j.com/download/)),
* and the `graphiti-core` package, which is used for compiling the knowledge graph. You can do this by running:

```bash
py -m pip install graphiti-core
```

## Using

*TODO*: Describe how to use your format.

## Format Options

*TODO*: If your format has options that can be set via document metadata, describe them.

## Example

Here is the source code for a minimal sample document: [example.qmd](example.qmd).

## Troubleshooting

If your math macros are not applying, check that you're using "\\\\" (double-backslashes) instead of "\\" (single-backslahes).

## Goals
The overall goal of this Extension is to maximise the accessibility of Research Output:

1. Starting from the Maths perspective and then generalising, enable webpages to cover individual concepts with configuration, such as notation and abbreviations carrying over to the rest of the website and alternative formats.

    1. It is preferable that the terminology be defined rigorously to enhance knowledge graph building as well as allowing for more accurate automatic translations.
    1. It is preferable that there be an option for definitions to be provided using templates, that can be updated when embedded on other pages.

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

    1. Filter math elements to replace any dummy variables leftover in template definitions and generate optional "list of notation" tables.`
    1. Filter (theorem) environments to render callout blocks using the "callouty theorem" extension.
    1. Filter mention and template embedding to provide hyperlinked cross-referencing and consistency across linked concepts and generate optional "dependency" tables.
    1. Filter code blocks, with the help of the "code cell options" extension, to process Rocq.

1. Post-render:

    1. (Optional) Process data through Graphiti.
    1. Finalise data required for a graphical representation of knowledge graph.