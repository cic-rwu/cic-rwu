```
cic-rwu/static/man/README.md
```
___
# Overview
This directory contains manual pages for shared CIC programs stored in `bin/`

In general, formatting should follow the same format as [linux man-pages](https://man7.org/linux/man-pages/man7/man-pages.7.html), but this ***does NOT mean*** *all manuals listed here are related to linux/UNIX-only programs*. This is simply because I think the formatting conventions are intuitive. 

Ultimately, **formatting remains up to the discretion of the author**.\
As much as I would like to attempt to standardize everything, I also realize that not everybody will come to the same conclusion as me.

That being said, some things **must still be standardized**, for the sake of organization.
**At minimum**, every manual page should:
- **Contain an *equivalent to* the NAME, SYNOPSIS/DESCRIPTION, and AUTHOR sections** described in **man-pages**([7](https://man7.org/linux/man-pages/man7/man-pages.7.html))

- **Follow the section conventions** described in man-pages(7)


Of course, *more detail is always encouraged*, but I also recognize that not all programs here may be complex scripts that take five-hundred different arguments and produce thirty different results. These standards are defined to avoid having to ask someone what any/every single script here does. 
___

# Pandoc
If you are unfamiliar, (pandoc)[https://pandoc.org/] is a package that is a "swiss-army knife" for converting files from one markup format to another. Manual pages in the [root directory](static/man) should be *.md* files, and OS-specific manual pages (like *groff* for linux man-pages) should be in their respective category folder.

If you are on Linux and using VS Code, you can add this to your *tasks.json* to help automate building to whatever `<FORMAT>` you need:
```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Build Man Page",
            "type": "shell",
            "command": "pandoc --standalone --to <FORMAT> ${file} -o ${fileDirname}/${fileBasenameNoExtension}",
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "problemMatcher": [],
            "detail": "Compiles the active Markdown file into a manual page using Pandoc."
        }
    ]
}
```

For example, when I'm writing groff manual pages, my Build Man Page task looks like:
```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "build-mp",
            "type": "shell",
            "command": "pandoc --standalone --to man ${file} -o ${fileDirname}/${fileBasenameNoExtension} && tar -cvf ${fileDirname}/${fileBasenameNoExtension}.gz ${fileDirname}/${fileBasenameNoExtension}",
            "group": {
                "kind": "build",
                "isDefault": false
            },
            "problemMatcher": [],
            "detail": "Compile the active Markdown file into a Linux groff man page with pandoc(1) and compress it with tar(1)."
        }
    ]
}
```

Furthermore, you can automate this task with the [tasks on save extension](https://marketplace.visualstudio.com/items?itemName=Gruntfuggly.triggertaskonsave) for VS Code:
```json
    "triggerTaskOnSave.tasks": {
        "Build Man Page": [
            "static/man/**.md",
        ]
    },
```