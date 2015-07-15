# FormatScript Module

This is a set of functions for refactoring your script code in different ways with the aim of beautifying and standardizing your code.  Ideally this collection will eventually include the following (some functions have already been created and been minimally tested):

##Functions
Here is a short list of some of the code included in this module.

* <b>Format-ScriptRemoveStatementSeparators</b> - Removes superfluous semicolons at the end of individual lines of code and splits them into their own lines of code.
* <b>Format-ScriptRemoveSuperfluousSpaces</b>
* <b>Format-ScriptPadOperators</b>
* <b>Format-ScriptFormatCodeIndentation</b>
* <b>Format-ScriptRemoveSpacesAfterBackTicks</b> - 
* <b>Format-ScriptReplaceIllegalCharacters</b> - Find and replace goofy characters you may have copied from the web
* <b>Format-ScriptReplaceLineEndings</b> - Fix CRLF inconsistencies
* <b>Format-ScriptFormatHashTables</b> - Splits hash assignments out to their own lines
* <b>Format-ScriptReplaceAliases</b> - Replace aliases with full commands
* <b>Format-ScriptReplaceTypeDefinitions</b> - Replace type definitions with full types
* <b>Format-ScriptReplaceCommandCase</b> - Updates commands with correct casing
* <b>Format-ScriptSplitLongLines</b> - Any lines past 130 characters (or however many characters you like) are broken into newlines at the pipeline characters if possible
* <b>Format-ScriptReplaceOutNull</b> - Replace piped output to out-null with $null = equivalent
* <b>Format-ScriptFormatOperatorSpacing</b> - places a space before and after every operator
* <b>Format-ScriptFormatArraySpacing</b> - places a space after every comma in an array assignment
* <b>Format-ScriptReplaceHereStrings</b> - Finds herestrings and replaces them with equivalent code to eliminate the herestring
* <b>Format-ScriptFormatTypeNames</b>
* <b>Format-ScriptFormatCommandNames</b>
* <b>Format-ScriptExpandTypeAccelerators</b>
* <b>Format-ScriptCondenseEnclosures</b>
* <b>Format-ScriptConvertKeywordsAndOperatorsToLower</b>
* <b>Format-ScriptExpandAliases</b>