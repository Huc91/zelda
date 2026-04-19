- enemy do not move you need to implement pathfinding. They pathfind from their tile to mine, avoiding obastacle. check this article: https://casraf.dev/2024/09/pathfinding-guide-for-2d-top-view-tiles-in-godot-4-3/, implement everything they need to fucking move so make tests.
- Implement Card Soul System in the inventory. By lore every item I find is imbued from the soul of an old hero, no need to explain. Anyhow you have 3 slots: 1 red, 1 blue, 1 green, Like Castlevania Aria of Sorrow. You can equip sould card there. Soul card can't be found in packages for now, you found them in the overworld or from the soul catching mechanic.
  Red slot: usually Attack item (the sword you find in the cave at the start of the game is red)
  Blue slot: usually Metroidvania power (item that make you swim, push rocks, etc..)
  Green slot: usually Battle buffs (+4 health, +1 initiative, ecc...)
  For now do not add this item, we just have the sword. So change how the sword is handled in the game, the new invetory become the soul system if equipped there i have the sword. From the HUD, scrap the A B slot, we have 3 slot where i see small icon for each equipped soul item (max 3 as we said). I can offcourse access a menu were i can chage equipped item. Start using icon for GUI i added it into GUI_plugin folder.
- Change attack button of the sword to X key button.
- Z key button to iteract.
- New player hidden stat: Luck. Goes from 0 to 42.
  How luck works: if luck is involved, pick a random number from 1 to 42, if player luck is equal or higher of that value, luck success, player is lucky.
  Luck works for:
  .enemy killing money rewards, luck roll, if luck: + 10 money.
  .initiative, luck roll, if luck + 1 initiative (state it in the screen)
  .flower grass cutting, luck determines more possibility to find reward there.
  Luck is determined by items, and number of foil cards found in packs.
- Change how initiative in combat works. If i have attacked with sword i have a +3, if the enemy attack me before me he have + 3 initiave.
  initiative determines who start first. now is just who attacked first. Add a new screen before battle were dice are rolled automatically.
  My dice white, enemy dice black (invert the sprite color).
  Sprite for dice and explanation of how it works: GUI_plugin/die.
  State who won, by showing the die result and the eventual buffs. Keep this screen 2 seconds. In case of a tie, player always wins, the battle can start, winner take the first turn.
- Soul catching system, every tile that has collision or choose a flag "soulable" i wanna see it in the visual editor as well, can be transformed into an item card or a combat card by interacting with Z. for now I can only catch trees rocks and flowers. I can catch just one time, If i already have it the system says i already have this soul.
  .Stone, blue soul item, +1 max HP.
  .Tree, green soul item, +4 HP healed at end of battle in the overworld.
  .Flower, green soul item, +1 Luck.
  Now you can add this items.
  When i catch, the card is added to the soul system collection, the element is not removed from the map.
- Change health system. My battle HP are my overworld HP. If i lose HP in battle that HP are reflect in the number of hearts I have.
  Now player has 12HP, so every hearth in the HUD is 4HP (3 hearts), if i have more than 12HP by items add heart parts accordingly. I can never have more HP than max HP.
  If i end the battle with 4HP, when i come back i have just one hearth.
  I want to show in the hud also when i lose a quarter of the hearth (1HP) like zelda, i can also lose half heart (2HP), like zelda.
  So for example in end the battle with 1HP (i have just a quarter of 1 heart when i come back).
  If i lose a battle, and the enemy was difficulty easy or normal I don't die, i go to 1HP, and heal accordingly if i have stuff that heals me after battle. Against hard enemies and elites, yes i can die. It is showd at the start of battle under i roll the die if is a skirmish battle or lethal battle.
