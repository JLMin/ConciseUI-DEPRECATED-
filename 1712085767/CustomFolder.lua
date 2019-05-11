--[[
          ┌──────────────────────────────────────────────────────────┐
          │                                                          │
          │        Concise Mod Manager - Configuration File          │
          │                 eudaimonia - April 2019                  │
          │                                                          │
          └──────────────────────────────────────────────────────────┘

          ┌──────────────────────────────────────────────────────────┐
          │                                                          │
          │                      * IMPORTANT *                       │
          │     This file will be overwritten when it's updated!     │
          │    Please *BACKUP* this file when you finish editing!    │
          │                                                          │
          └──────────────────────────────────────────────────────────┘



]]C={---------------------  ↓ Custom Folder Start ↓  ---------------------------


      { -- Example 1
        FolderName = "Custom Folder",
        ModList = {
          "1671978687",  -- Concise UI - [ Core ]
        }
      },

      { -- Example 2
        FolderName = "\"Special\" Folder",
        ModList = {
          "1681714708",  -- Concise UI - Civ Assistant
          "1671982095",  -- Concise UI - Deal Panel
          "1671984106",  -- Concise UI - Great Works Screen
          "1671985335",  -- Concise UI - Leader Icon
          "1671994053",  -- Concise UI - Unit List
        }
      },


};--[[---------------------  ↑ Custom Folder End ↑  ----------------------------



          ┌──────────────────────────────────────────────────────────┐
          │                                                          │
┌─────────┤                Custom Folder Instruction                 ├─────────┐
│         │                                                          │         │
│         └──────────────────────────────────────────────────────────┘         │
│                                                                              │
│                                                                              │
│   > What editor to use?                                                      │
│     - Any text editor will do.                                               │
│     - Notepad++ is recommended, it's a free source code editor.              │
│       It'll color code the file to make it easier to read and edit.          │
│       Download: https://notepad-plus-plus.org                                │
│                                                                              │
│                                                                              │
│   > How to create a folder?                                                  │
│     - You can copy the existing folder directly and modify it.               │
│     - Make sure your code is in the same format as the examples.             │
│                                                                              │
│                                                                              │
│   > How to name a folder?                                                    │
│     - Custom folder name goes between the double quotation marks.            │
│     - eg: FolderName = "Custom Folder",                                      │
│           The name of this folder is: Custom Folder                          │
│     * If you want to have (") or (\) in the folder name, use (\") or (\\).   │
│     * eg: FolderName = "\"Special\" Folder",                                 │
│           The name of this folder is: "Special" Folder                       │
│                                                                              │
│                                                                              │
│   > How to add a mod to a folder?                                            │
│     - in the game                                                            │
│       1. Click the 'Generate Mod ID' button.                                 │
│       2. Select the code it generates.             -- Ctrl+A (Select All)    │
│       3. Copy the code.                            -- Ctrl+C (Copy)          │
│     - in this file                                                           │
│       4. Paste it under the 'ModList' of a folder. -- Ctrl+V (Paste)         │
│                                                                              │
│                                                                              │
│   > Few other things you should be aware of.                                 │
│     - Changes you made in this file will not take effect until you:          │
│       'restart the game' or 'load a game and exit to main menu'.             │
│     - There is no limit on the number of folders and mods.                   │
│     - The same mod can be added to different folders.                        │
│                                                                              │
│                                                                              │
│   > A more detailed guide is pinned in the discussion section of             │
│     Concise Mod Manager's Steam Workshop webpage.                            │
│                                                                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────]]