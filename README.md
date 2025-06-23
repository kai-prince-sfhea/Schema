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

## Troubleshooting

If your math macros are not applying, check that you're using "\\\\" (double-backslashes) instead of "\\" (single-backslahes).

## Structure
1. Pre-render data from files and create master json file.
2. Filter applied to each file to create a filtered json file only containing relevant data for each file.
3. Post-render data for each file to create a json file of files that mention it.

## Format Options

*TODO*: If your format has options that can be set via document metadata, describe them.

## Example

Here is the source code for a minimal sample document: [example.qmd](example.qmd).

## Future
Set up a system for LEAN verification of proofs.