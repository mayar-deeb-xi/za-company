extends RefCounted
## How many players the world is answering: the ONE place the game asks how big
## the party is. ONE today - game.tscn owns a single player as a single child -
## and everything that scales with a crowd reads it from here rather than
## counting the group itself, so the day a second player exists there is one
## line to change and no second definition of "how many of us are there".
##
## ## The rule it exists to keep
##
## **Scale what the world SENDS, never what it is made of.** Enemy HP are exact
## breakpoints on the player's combo (24 / 17 / 36 - four hits, three, six,
## heavy one-shot), so a head multiplier on health would land a party on a last
## swing that does nothing visible. More heads means more BODIES, for the same
## reason no difficulty mode touches health either.
##
## **A BOSS's health is the one exception, and it scales by ADDING rather than
## multiplying.** His adds alone could not cover it - two players are two sets
## of swings on one body, and the fight ends in half the wall-clock whatever
## walks in meanwhile - so each extra head adds his `health_per_head`
## (boss_base.gd), a whole number of 24-damage combos: Ahmed 144 + 48 a head,
## Big Mo 216 + 72, Silverman 288 + 96. A sum of whole combos still dies on a
## whole combo, which is all the rule above was protecting. Everything keyed to
## how hurt he is reads a FRACTION of his max, so it moves with him.
##
## The healing side reads the same number in the other direction: Ivan hands out
## one heart per head (game/npcs/ivan/ivan.gd), because four players sharing one
## heart is the same unfairness as one player facing four times the bodies.
##
## Preloaded by path like every other cross-feature script here - global class
## names live in an editor-written cache a fresh headless checkout does not have.


static func count(tree: SceneTree) -> int:
	return maxi(1, tree.get_nodes_in_group("player").size())
