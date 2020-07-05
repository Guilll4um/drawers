# Minetest Mod Storage Drawers

![](https://github.com/minetest-mods/drawers/workflows/luacheck/badge.svg)

Version 0.6.0, License: MIT

## Description
This mod adds simple item storages showing the item's inventory image in the
front. 
* By left- or right-clicking the image you can take or **add stack**s. 

* If you also hold the sneak-key only **a single item** will be removed/added. 

* when left-clicking holding sneak + aux1 key you inventory will be full-filled
  when right-clicking with your bare hand **all stacks** from the inventory will 
   be added to the drawer.

* to **swap** item between drawers :
	- left-clicking holding aux1 to select the slot to swap
	- right-clicking holding aux1 to swap (or join if same item)

* to **move** your drawers with items you can use the trolley !

There's also a 'Drawer Controller' which can be connected to pipework tube and
which can **insert items automatically** into a network of drawers.
Just place the drawers next to each other, so they are connected 
and the drawer controller will sort the items automatically. 
If you want **to connect** drawers, but you don't want to place another drawer, 
just use the 'Drawer Trim'.

If you want to **take items automatically** from Drawers Controller network , 
sand digiline message to the controller like this :
```lua
	digiline_send("MyChannel","default:stone 99") 
```
this will take a stack with 99 default stone.

Do you have too many cobblestones for one drawer? No problem, just add some
drawer **upgrades** to your drawer! They are available in different sizes and are
crafted by steel, gold, obsidian, diamonds or mithril.

## Notes
This mod requires Minetest 0.4.14 or later. The `default` mod from MTG or the
MineClone 2 mods are only optional dependencies for crafting recipes.

## To-Do
- [x] Add usable 1x1 drawer
- [x] Add a drawer controller for auto-sorting items into a drawer-network
- [ ] Add half-sized drawers
- [x] Add 2x2 and 1x2 drawers
- [ ] Add compacting drawers for auto-crafting blocks/ingots/fragments
- [ ] Add a key (or something similar) for locking the item (so the item is
      also displayed at count 0)
- [x] Support pipeworks
- [ ] Support hoppers (needs hoppers mod change)
- [x] Make drawers upgradable
- [x] Add drawers in all wood types
- [x] Make them digilines compatible
- [x] Add swaping behavior for drawers slots items: AUX1+LBM to select , 
      then  AUX1+RBM to swap or join 
- [x] Add max_stack == 1 (with setting to allow or not) 
      and metadata item support (chest, tools, inventorybag) 
- [x] Add a fullfill inventory shortcut on punch an item : SNEAK+AUX1+LBM
- [x] Add trolley to carry drawers - with settings :
 	  activate, craftalbe, stamina consumption, limit to 1 in player invRef, wear

## Settings
#### Drawers:
* Drawer can hold unstackable items (all metadata are handled) = **true**
#### Trolley:
* Activate the drawer trolley = **true**
* Activate the drawer trolley recipe = **false**
* Drawer carrying stamina consumption (at take and at put ) = **0.75**
* Limit to one drawer with items in player inventory = **true**
               this handle all cases (when picked up on the ground, 
			   when already got a chest or a bag with a drawers with items inside)
               this limit involved 2 global register :
                        - minetest.registered_entities["__builtin:item"].on_punch
                        - minetest.register_allow_player_inventory_action
                        - and tests on metadata in both and in  override wrench 
						   and trolley event
* Times you can use the trolley before it breaks - 0 = infinite= **40**

## Bug reports and suggestions
You can report bugs and suggest ideas on [GitHub](http://github.com/lnj2/drawers/issues/new),
alternatively you can also [email](mailto:git@lnj.li) me.

## Credits
#### Thanks to:
* Justin Aquadro ([@jaquadro](http://github.com/jaquadro)), developer of the
	original Minecraft Mod (also licensed under MIT :smiley:) — Textures and Ideas
* Mango Tango <<mtango688@gmail.com>> ([@mtango688](http://github.com/mtango688)),
	creator of the Minetest Mod ["Caches"](https://github.com/mtango688/caches/)
	— I reused some code by you. :)

## Links
* [Minetest Forums](https://forum.minetest.net/viewtopic.php?f=9&t=17134)
* [Minetest Wiki](http://wiki.minetest.net/Mods/Storage_Drawers)
* [Weblate](https://hosted.weblate.org/projects/minetest/mod-storage-drawers/)
* [GitHub](http://github.com/minetest-mods/drawers/)
