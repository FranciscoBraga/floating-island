extends RefCounted
## Tobé ou um monstro andando pela grade da ilha (posições em células).

var kind := "tobe"
var cpos := Vector2.ZERO
var path: Array[Vector2i] = []
var target := Vector2i(9999, 9999)
var speed := 2.6
var weak := 0
var stun := 0.0
var invuln := 0.0
var replan := 0.0
var dash_cd := 4.0
var dash_t := 0.0
var pause_t := 0.0
var facing := 1.0
var moving := false
var anim := 0.0
var fleeing := false
var food_t := 0.0
var has_manual := false        # o jogador tocou num lugar da ilha
var manual := Vector2i.ZERO    # célula tocada
var manual_t := 0.0            # quanto tempo o Tobé espera lá antes de voltar a andar sozinho


func cell() -> Vector2i:
	return Vector2i(roundi(cpos.x), roundi(cpos.y))
