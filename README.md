## _Latest version (with dependencies) here: [Releases: 0.0.6b](https://github.com/Nihilianth/REToolbox/releases/tag/v0.0.6b)_

# REToolbox
An addon for Ascension Classless realms. Allows you to see if characters on your account or your guildies have a particular Mystic Enchant in their collection.

## Download

ZIP files found in [Latest Releases (0.0.6b)](https://github.com/Nihilianth/REToolbox/releases/tag/v0.0.6b) already contain the required libraries . If you already have DataStore ``r26`` and DataStore_AscensionRE you don't have to replace them.

## New in version 0.0.6b: New API adaptation, reforge looping, build (+RE) linking
This version adds compatibility with Ascension after API changes last year.
- All original functions are working again
- ``/re show <name>`` now also checks for guildies.
- Reforge looping allows you to gather Mystic Enchants without intervention.

![ref_loop](https://user-images.githubusercontent.com/6731717/154855722-5b50d1ea-ff92-4f01-8879-06f2399a4059.png)
- You can export your current build including equipped REs as Builder URL from Character Advancement frame
![exporturl](https://user-images.githubusercontent.com/6731717/154855728-bf276aaa-8b45-4939-b018-49979f19da1c.png)
- You can import builds using Ascension builder URL
![builder_import](https://user-images.githubusercontent.com/6731717/154855747-0162406f-b60b-47ac-b7b2-5a09f2114e99.png)
- Many other small fixes and changes

## New in version 0.0.4b: Reforging / Extracting and Application of REs

It is now possible to Reforge items aswell as apply and extract REs within the addon. Tokens used for those functions are now displayed aswell.
Toggle Buttons function can be used to perform application / extraction on multiple items.

![image](https://user-images.githubusercontent.com/6731717/116002479-38e6f800-a5fa-11eb-8a81-89a06ac8482b.png)

## New in version 0.0.3b: Character Pane Highlights, RE Collection Linking / UI, colored spell names

### GUI / RE Collection linking
This update introduces a new UI for REToolbox (``/re``). It allows you to view and search through RE collections. Following collections can be accessed:

- Your RE Collection
- RE Collection of alts on the same account
- All REs available ingame
- RE Collections shared via chat link

![re_toolbox_gui](images/cut.jpg)

Using the UI or console command you can create a chat link that allows other users of this addon to inspect your RE collection. 
_Note: Chat links expire after 5 minutes. If you wish to create a spammable macro, see below._

### Character pane highlights
Hovering over RE icons in character panel will now highlight equipped items with this RE applied.

![re_toolbox_chars](images/image_char_highlight.png)

### Colored RE Names in tooltips
RE Spell Names in tooltips (e.g. within Build viewer) will now be colored based on their quality.

![re_toolbox_color](images/image_re_tooltip_color.png)

### Creating a macro link
The generated RE Collection links have an expiration timer, so to create an advertisement macro containing a link to your collection requires some modification. To create a macro for broadcasting, you can use one of thefollowing commands:

- _Has to be called from a macro, not from chat paste._ This opens an edit frame and inserts the link, leaving it editable. Current channel is used (whisper / world / say).

    ``/run RETBLinkPrint("WTS REs %s (1337 total) 50g ")``
    ![example_macro_1](images/re_macro_1.png)
- Posts a message to a pre-set channel. Replace ``<channel number>`` with the desired one and change COMMON to ORCISH if needed.
  
    ``/script SendChatMessage(format("WTS %s 50g", RETBGetNewLink()), "CHANNEL", "COMMON", "<channel number>")``
    ![example_macro_1](images/re_macro_2.png)

_``%s`` will be replaced with Collection link_

## New in Version 0.0.2b: Item tooltips

You can now see RE information while browsing Auction House items and viewing bags / item links.


![ah_item_tooltip](https://user-images.githubusercontent.com/6731717/113595889-e2f5e480-9639-11eb-8c06-019914d3b61f.png)


### Addon description
Based around [DataStore r26](https://www.curseforge.com/wow/addons/datastore/files/437591) aswell as the custom module [DataStore_AscensionRE](https://github.com/Nihilianth/DataStore_AscensionRE)


After installing this addon the RE tooltips will reflect if your alts or your guildies (using this addon) have this certain RE in their collection.


![known_guild_demo](https://user-images.githubusercontent.com/6731717/113483263-d2f7cc80-94a2-11eb-991a-5077097ade52.png)

This addon will provide you a link to the new RE after adding it to your collection. You are also be able to check if your current character has an enchant before attempting to extract it.


![enchant_unknown](https://user-images.githubusercontent.com/6731717/113483252-c96e6480-94a2-11eb-9809-59cfa56a9fea.png)

This addon is still under development, with new features planned for the future. Feel free to spread the word around Ascension and notify me about any issues you encounter. Message Nihilianth on Ascension Discord if you have further questions.
