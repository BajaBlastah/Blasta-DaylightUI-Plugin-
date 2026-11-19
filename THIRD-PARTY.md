# Third-party notices

DaylightUI is a separately installed dependency. Its license expressly permits independent plugins that call its functions and change its interface at runtime. Blasta's dungeon filters use the installed DaylightUI widgets, group finder data and window slide at runtime. The filter panel layout and filtering logic are part of Blasta.

The Lua files under `Imported/Packs` are Blasta's runtime integrations for separately installed add-ons. The pack names identify their targets. Other integrations likewise use separately installed add-ons, including Auctionator, DisenchantBuddy, Forever Dungeon Journal and RareScanner.

Blasta's bundled graphics were generated with ChatGPT.

The optional Blasta loot feed uses the installed DaylightUI QoL module's loot parsers and item metadata helpers at runtime. Blasta supplies its own feed layout, history and playback.

## What's Training? recipe data

The files under `Data/Recipes` are the profession recipe data of What's Training? (`Crafting/Recipes/Camelot`), used under the MIT License below. Only their namespace was changed (they fill `extras.TrainerRecipes`) and the faction name lookups were replaced with plain keys. Blasta's learnable recipe list, detail page and their logic are Blasta's own code.

```
MIT License

Copyright (c) 2019

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
