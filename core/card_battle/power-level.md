i want a function that knows the power level of a deck.
Is made like this. For every card in the deck check:
rarity: each common is 1 point, each rare is 3 point, each epic is 5 point, each legendary is 8 point.
The sum will give me the rarity power.
Take this value and dived it for 20. This will give the average rarity power of card in the deck. Baseline is 1.

Then for each card find how much power a card wield.
a 2/1 no ability is 2 points (2 of attack), a 2/1, taunt is 3 points (2 of attack + 1 for ability). Do not count spells.
Sum all power of all demons in deck: Eg.: 30. that's my raw demon output.
Then sum all demon mana costs: Eg.: 10.
So in this example i have ha 30 of power output with 10 mana cost.
The baseline is 30 power output with 30 mana cost. it's 3 time more efficient, you ust find this coefficient by doing "total_power / mana_cost" and use the P coefficient of 1 as baseline to know how much powerful is.

we will then have two values:

- Rarity power
- Raw power

Final formula to calculate a deck power: rarity_power \* raw_power.
After you done the formula give me some examples.

This will give me the power level of the deck. In dev mode show the power level in the inventory. only dev mode.

ok super strong deck are near 10.
a base deck have 1.
