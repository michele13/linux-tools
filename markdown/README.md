# md2html.sh - A markdown to HTML converter

A markdown to HTML converter written in shell script

## Syntax to implement

- [x] Headers
- [x] Paragraphs
- [x] Bullet Lists **(only one level, for now)**
- [x] Number Lists **(only one level, for now)**
- [x] Bold **(single line only)**
- [x] Italic **(single line only)**
- [x] Code
- [x] Code blocks
- [ ] Quotes
- [ ] Images
- [ ] Links

## TODO

- [x] Add formatting to lists
- Nest HTML inside markdown?
- lists lines problem: when a bullet list item is in two or more lines:

    >  1. Like This
    >     Example Here
    >

    It does not behave

- There's still a problem with how paragraphs are handled!
- The text file inside here is a good "benchmark" for the script: https://daringfireball.net/projects/markdown/index.text