extends Control
## The boss's health: a 240 px channel low and centred, his name over the left
## end of it. On screen only while a boss is standing in the room, and gone the
## moment he concedes.
##
## Fed by hud.gd, which is fed by game.gd - the same one-way street the player's
## own bar is on. Nothing here reaches for a boss, so the thing with the health
## can be Ahmed today and whoever is on the top floor later.
##
## **Deliberately not the player's crimson.** Two red bars on one screen is one
## bar the player has to stop and identify first; this one is ember, which is
## the colour Ahmed's axe is already burning in.
##
## ## The chip
##
## A blow leaves a pale block standing where the fill was, which then drains at
## CHIP_SPEED. That is what makes the heavy legible: 24 off Ahmed's 96 is a
## quarter of the bar, and a quarter of the bar visibly going is worth more than
## a number that was different last time you looked. It trails DOWNWARD only -
## there is nothing to show about health coming back.
##
## Sized in design pixels against the 640x360 viewport, and anchored to the
## bottom centre rather than offset from the top-left, so the player's corner
## and the boss's bar cannot drift into each other.

## The channel, in design pixels. Every width here is a share of it.
const FILL_WIDTH := 240.0

## Bar widths per second. The chip would cross the whole bar in a shade under
## three seconds, so it outlasts the hit that made it and is gone well before
## the next one.
const CHIP_SPEED := 0.35

@onready var _name: Label = %BossName
@onready var _chip: ColorRect = %Chip
@onready var _fill: ColorRect = %Fill
@onready var _fill_top: ColorRect = %FillTop
@onready var _fill_low: ColorRect = %FillLow

## Both are shares of FILL_WIDTH, 0..1, and `_chipped` never sits below
## `_ratio` - the chip is ground already lost, never ground still held.
var _ratio := 0.0
var _chipped := 0.0


func _ready() -> void:
	hide_boss()


## A boss has been found in the room. Named and filled in one call, so arriving
## on a floor he has already been hurt on shows what is left rather than a full
## bar that then jumps.
func show_boss(title: String, health: int, max_health: int) -> void:
	_name.text = title
	_ratio = _share(health, max_health)
	_chipped = _ratio
	visible = true
	set_process(false)
	_apply()


## One blow's worth of news. Only a LOSS leaves a chip behind; anything else
## takes the bar straight to where it now is.
func set_health(health: int, max_health: int) -> void:
	var next := _share(health, max_health)
	_chipped = maxf(_chipped, _ratio) if next < _ratio else next
	_ratio = next
	set_process(_chipped > _ratio)
	_apply()


func hide_boss() -> void:
	visible = false
	set_process(false)


## Runs only while there is a chip left to drain - set_health turns it on and
## the drain turns it off, so a room with a boss standing still costs nothing.
func _process(delta: float) -> void:
	_chipped = maxf(_ratio, _chipped - delta * CHIP_SPEED)
	if _chipped <= _ratio:
		set_process(false)
	_apply()


func _share(health: int, max_health: int) -> float:
	return clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)


## Whole pixels only, in both bars: a fill that lands on a half pixel is a fill
## whose lit top row and dark bottom row end in different places.
func _apply() -> void:
	var drawn := roundf(FILL_WIDTH * _ratio)
	_fill.size = Vector2(drawn, _fill.size.y)
	_fill_top.size = Vector2(drawn, _fill_top.size.y)
	_fill_low.size = Vector2(drawn, _fill_low.size.y)

	var chipped := roundf(FILL_WIDTH * _chipped)
	_chip.visible = chipped > drawn
	_chip.position = Vector2(drawn, _chip.position.y)
	# Never thinner than a pixel: the last sliver of a chip is still a chip.
	_chip.size = Vector2(maxf(chipped - drawn, 1.0), _chip.size.y)
