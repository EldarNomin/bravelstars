class_name SimFixtures
extends RefCounted
## Общие заготовки для тестов симуляции.


static func open_map(w: int = 20, h: int = 20) -> SimMap:
	var lines := PackedStringArray()
	for _y in h:
		lines.append(".".repeat(w))
	return SimMap.from_lines(lines)


static func straight_attack(dmg: int = 1000, rng: float = 6.0) -> AttackData:
	var a := AttackData.new()
	a.kind = AttackData.Kind.STRAIGHT
	a.damage = dmg
	a.range_tiles = rng
	a.speed = 15.0
	a.super_charge_per_hit = 250
	return a


static func brawler(hp: int = 3000) -> BrawlerData:
	var d := BrawlerData.new()
	d.id = &"test"
	d.max_hp = hp
	d.move_speed = 3.0
	d.attack = straight_attack()
	d.super_attack = straight_attack(2000, 8.0)
	return d


## Прогоняет n тиков, подавая одну и ту же команду (или без команды).
static func run(world: SimWorld, n: int, who: SimBrawler = null, cmd: InputCommand = null) -> void:
	for _i in n:
		if who != null and cmd != null:
			world.set_input(who.id, cmd)
		world.step()
