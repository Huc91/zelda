this is the UI to implement for the card battle screen is really detailed.
https://www.figma.com/design/7mdgc4Iidxwq38jBYewrd2/Untitled?node-id=3-77&t=
CATue0vT5sq3NUE0-0 this is the first frame but other frames are in the figma
as well. Is pretty easy to undertstand. Do you have question?
I explain the basic.

- Direct attack is disabled, get enabled when is legal to make a direct
  attack
- Log, scrollable all the battle log is registered there, automatically
  scroll to last message so i can see what's going on, always update everytime
  something happens.
- The zoomed card: has all the detail of the card, only place were i can see
  all the text and effect of a card. Everytime i hover a card, the zoomed
  versione appears here.
- The hand, I only see my hand. Enemy hand is numeric.
- I can drag cards into zone to put it into play. Based on the zone i play
  it front or back.
- If i right click a card of mine in hand i pitch it.
- If i drag a card from hand to my status bar(life, mana) i pitch it.
- Arrows. Arrows show what i am attacking.
- To attack I select a card, then the arrow appears, i click the target: i
  can clikc other monsters, or direct attack (if available)
- Cards that enter the battlefield have summoning sickness (zzz) state they
  look disabled with the ZZZ text. Also when a card attacks or exhaust to use
  a exhaust effect goes into that state, from now we call it exhausted.
- When i select a card also a green outline appears, with contextual button
  based on what the card can do. Move appears if can move, Effect appear if
  can use the "Exhaust" effect.
- Exhaust is like tap in magic.
- A damaged card have the life in red.
- The angle on the top right and in the mini the bottom left is the mana
  cost.
- You also have a jewel for rarity, the color match the border: grey common,
  blue rare, purple epic, orange legendary. If a demon has type advanage a
  text appears near the arrow telling how much bonus have (type advantage +1
  damage).
- I can click on grave or deck, a modal appears "checking the grave" with
  all cards. If i check a deck the order is random.
- There is a toast the signal important things "change of turn" start of
  battle, end of battle, win or loss.
- I can drag cards into arsenal but the choice is asked at the end of turn
  so i can also click from hand.
- There is a green circle that is green when is your turn, red when is enemy
  turn.
- demon cards have bg F4E4D9 spell cards have bg A1B467
- the mini card has the name trimmed with ...max chars 8. if the card has an
  effect, just the text "Effect" appears in the mini.
