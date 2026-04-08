## Card art path resolver + texture cache.
## card_art_2x(id, foil) → large texture for pack reveal / binder.
## card_art_1x(id, foil) → small texture for battle mini cards.
class_name CardArt

static var _cache: Dictionary = {}
static var _art_table: Dictionary = {}
static var _table_built: bool = false


static func card_art_2x(card_id: String, foil: bool = false) -> Texture2D:
	return _fetch(_path_2x(card_id, foil), card_id + ":2x:" + str(foil))


static func card_art_1x(card_id: String, foil: bool = false) -> Texture2D:
	return _fetch(_path_1x(card_id, foil), card_id + ":1x:" + str(foil))


static func _fetch(path: String, key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_cache[key] = t
	return t


static func _path_2x(card_id: String, foil: bool) -> String:
	_ensure_table()
	var e: Array = _art_table.get(card_id, [])
	if e.is_empty(): return ""
	return e[1] if foil else e[0]


static func _path_1x(card_id: String, foil: bool) -> String:
	_ensure_table()
	var e: Array = _art_table.get(card_id, [])
	if e.is_empty(): return ""
	return e[3] if foil else e[2]


static func _ensure_table() -> void:
	if _table_built:
		return
	_table_built = true
	var f2: String = "res://assets/monsters/Free Mythic Monsters/Outlined/2x Size/"
	var f1: String = "res://assets/monsters/Free Mythic Monsters/Outlined/1x Size/"
	var p2: String = "res://assets/monsters/Mythic Monsters I/2x/Outlined/"
	var p1: String = "res://assets/monsters/Mythic Monsters I/1x/Outlined/"

	# Each value: [normal_2x, foil_2x, normal_1x, foil_1x]
	# NOTE: Mythic Monsters I 2x variant-1 files have a name suffix (e.g. D_02_1_imp.png)
	#       1x files have no name suffix (e.g. D_02_1.png)
	_art_table = {
		# ── Core demons (001-043) ────────────────────────────────────────────────────
		"demon_001": [p2+"D_02_1_imp.png",                       p2+"D_02_3.png",                   p1+"D_02_1.png",               p1+"D_02_3.png"],
		"demon_002": [p2+"D_17_1_corrupted-dog.png",             p2+"D_17_3.png",                   p1+"D_17_1.png",               p1+"D_17_3.png"],
		"demon_003": [p2+"H_08_1_rat.png",                       p2+"H_08_3.png",                   p1+"H_08_1.png",               p1+"H_08_3.png"],
		"demon_004": [p2+"B_15_1_wolf.png",                      p2+"B_15_3.png",                   p1+"B_15_1.png",               p1+"B_15_3.png"],
		"demon_005": [p2+"U_07_1_skeleton-knight.png",           p2+"U_07_3.png",                   p1+"U_07_1.png",               p1+"U_07_3.png"],
		"demon_006": [p2+"U_15_1_specter.png",                   p2+"U_15_3.png",                   p1+"U_15_1.png",               p1+"U_15_3.png"],
		"demon_007": [p2+"Y_01_1_fallen_goddess.png",            p2+"Y_01_3.png",                   p1+"Y_01_1.png",               p1+"Y_01_3.png"],
		"demon_008": [p2+"D_07_1_flying_winged_imp.png",         p2+"D_07_3.png",                   p1+"D_07_1.png",               p1+"D_07_3.png"],
		"demon_009": [p2+"N_10_1_treant.png",                    p2+"N_10_3.png",                   p1+"N_10_1.png",               p1+"N_10_3.png"],
		"demon_010": [p2+"B_09_1_cerberus-cat.png",              p2+"B_09_3.png",                   p1+"B_09_1.png",               p1+"B_09_3.png"],
		"demon_011": [p2+"U_09_1_banshee.png",                   p2+"U_09_3.png",                   p1+"U_09_1.png",               p1+"U_09_3.png"],
		"demon_012": [p2+"B_08_1_horned-beast.png",              p2+"B_08_3.png",                   p1+"B_08_1.png",               p1+"B_08_3.png"],
		"demon_013": [p2+"D_01_1_ifrit.png",                     p2+"D_01_3.png",                   p1+"D_01_1.png",               p1+"D_01_3.png"],
		"demon_014": [p2+"U_12_1_mummy.png",                     p2+"U_12_3.png",                   p1+"U_12_1.png",               p1+"U_12_3.png"],
		"demon_015": [p2+"D_10_1_ice_insectoid.png",             p2+"D_10_3.png",                   p1+"D_10_1.png",               p1+"D_10_3.png"],
		"demon_016": [f2+"013_1_demon_head.png",                 f2+"013_3.png",                    f1+"013_1.png",                f1+"013_3.png"],
		"demon_017": [p2+"H_11_1_djinn.png",                     p2+"H_11_3.png",                   p1+"H_11_1.png",               p1+"H_11_3.png"],
		"demon_018": [f2+"024_1_fairy.png",                      f2+"024_3.png",                    f1+"024_1.png",                f1+"024_3.png"],
		"demon_019": [p2+"D_08_1_horned_demon.png",              p2+"D_08_3.png",                   p1+"D_08_1.png",               p1+"D_08_3.png"],
		"demon_020": [p2+"W_08_1_psy-medusa.png",                p2+"W_08_3.png",                   p1+"W_08_1.png",               p1+"W_08_3.png"],
		"demon_021": [f2+"020_1_undead_hero.png",                f2+"020_3.png",                    f1+"020_1.png",                f1+"020_3.png"],
		"demon_022": [p2+"N_11_1_Belzebu.png",                   p2+"N_11_3.png",                   p1+"N_11_1.png",               p1+"N_11_3.png"],
		"demon_023": [p2+"D_19_1_baphomet.png",                  p2+"D_19_3.png",                   p1+"D_19_1.png",               p1+"D_19_3.png"],
		"demon_024": [p2+"D_05_1_one-eyed-book.png",             p2+"D_05_3.png",                   p1+"D_05_1.png",               p1+"D_05_3.png"],
		"demon_025": [p2+"D_06_1_strong-one-eyed-book.png",      p2+"D_06_3.png",                   p1+"D_06_1.png",               p1+"D_06_3.png"],
		"demon_026": [p2+"D_04_1_thousand_eyes.png",             p2+"D_04_3.png",                   p1+"D_04_1.png",               p1+"D_04_3.png"],
		"demon_027": [p2+"H_17_1_cultist_leader.png",            p2+"H_17_3.png",                   p1+"H_17_1.png",               p1+"H_17_3.png"],
		"demon_028": [f2+"027_1_komainu.png",                    f2+"027_3.png",                    f1+"027_1.png",                f1+"027_3.png"],
		"demon_029": [p2+"H_01_1_goblin_king.png",               p2+"H_01_3.png",                   p1+"H_01_1.png",               p1+"H_01_3.png"],
		"demon_030": [p2+"U_06_1_thorns_skeleton.png",           p2+"U_06_3.png",                   p1+"U_06_1.png",               p1+"U_06_3.png"],
		"demon_031": [f2+"030_1_one_eyed_angel.png",             f2+"030_3.png",                    f1+"030_1.png",                f1+"030_3.png"],
		"demon_032": [f2+"030_1_one_eyed_angel.png",             f2+"030_3.png",                    f1+"030_1.png",                f1+"030_3.png"],
		"demon_033": [f2+"030_1_one_eyed_angel.png",             f2+"030_3.png",                    f1+"030_1.png",                f1+"030_3.png"],
		"demon_034": [f2+"030_1_one_eyed_angel.png",             f2+"030_3.png",                    f1+"030_1.png",                f1+"030_3.png"],
		"demon_035": [f2+"030_1_one_eyed_angel.png",             f2+"030_3.png",                    f1+"030_1.png",                f1+"030_3.png"],
		"god_card":  [f2+"031_1_karnia.png",                     f2+"031_3.png",                    f1+"031_1.png",                f1+"031_3.png"],
		"demon_036": [p2+"H_04_1_goblin_assasin.png",            p2+"H_04_3.png",                   p1+"H_04_1.png",               p1+"H_04_3.png"],
		"demon_037": [p2+"H_05_1_goblin_mage.png",               p2+"H_05_3.png",                   p1+"H_05_1.png",               p1+"H_05_3.png"],
		"demon_038": [p2+"H_02_1_goblin_soldier.png",            p2+"H_02_3.png",                   p1+"H_02_1.png",               p1+"H_02_3.png"],
		"demon_039": [p2+"D_12_1_mimic.png",                     p2+"D_12_3.png",                   p1+"D_12_1.png",               p1+"D_12_3.png"],
		"demon_040": [f2+"005_2_imp_summoner.png",               f2+"005_3.png",                    f1+"005_2.png",                f1+"005_3.png"],
		"demon_041": [f2+"021_1_chaos_oroborus.png",             f2+"021_3.png",                    f1+"021_1.png",                f1+"021_3.png"],
		"demon_042": [f2+"025_1_demon_lord.png",                 f2+"025_3.png",                    f1+"025_1.png",                f1+"025_3.png"],
		"demon_043": [p2+"D_03_1_chimera.png",                   p2+"D_03_3.png",                   p1+"D_03_1.png",               p1+"D_03_3.png"],
		# ── Obscura expansion (044-061) ──────────────────────────────────────────────
		"demon_044": [p2+"D_09_1_gargoyle_devil.png",            p2+"D_09_3.png",                   p1+"D_09_1.png",               p1+"D_09_3.png"],
		"demon_045": [f2+"026_1_weak_tiger.png",                 f2+"026_3.png",                    f1+"026_1.png",                f1+"026_3.png"],
		"demon_046": [p2+"D_18_1_slime-spawn.png",               p2+"D_18_3.png",                   p1+"D_18_1.png",               p1+"D_18_3.png"],
		"demon_047": [p2+"M_05_1_giant_mosquito.png",            p2+"M_05_3.png",                   p1+"M_05_1.png",               p1+"M_05_3.png"],
		"demon_048": [p2+"H_10_1_dark_mage.png",                 p2+"H_10_3.png",                   p1+"H_10_1.png",               p1+"H_10_3.png"],
		"demon_049": [p2+"H_13_1_samurai_ghost.png",             p2+"H_13_3.png",                   p1+"H_13_1.png",               p1+"H_13_3.png"],
		"demon_050": [f2+"002_1_star_sprawling.png",             f2+"002_3.png",                    f1+"002_1.png",                f1+"002_3.png"],
		"demon_051": [p2+"U_04_1_flying-skull.png",              p2+"U_04_3.png",                   p1+"U_04_1.png",               p1+"U_04_3.png"],
		"demon_052": [p2+"H_03_1_goblin_paesant.png",            p2+"H_03_3.png",                   p1+"H_03_1.png",               p1+"H_03_3.png"],
		"demon_053": [f2+"007_1_spider_queen.png",               f2+"007_3.png",                    f1+"007_1.png",                f1+"007_3.png"],
		"demon_054": [p2+"N_06_1_small_insect.png",              p2+"N_06_3.png",                   p1+"N_06_1.png",               p1+"N_06_3.png"],
		"demon_055": [p2+"N_03_1_poisonus_snail.png",            p2+"N_03_3.png",                   p1+"N_03_1.png",               p1+"N_03_3.png"],
		"demon_056": [f2+"004_1_specter_knight.png",             f2+"004_3.png",                    f1+"004_1.png",                f1+"004_3.png"],
		"demon_057": [f2+"010_1_octopus_mage.png",               f2+"010_3.png",                    f1+"010_1.png",                f1+"010_3.png"],
		"demon_058": [p2+"B_11_1._a-beast.png",                  p2+"B_11_3.png",                   p1+"B_11_1.png",               p1+"B_11_3.png"],
		"demon_059": [p2+"U_08_1_strong-skeleton.png",           p2+"U_08_3.png",                   p1+"U_08_1.png",               p1+"U_08_3.png"],
		"demon_060": [p2+"U_13_1_pirate_skeleton.png",           p2+"U_13_3.png",                   p1+"U_13_1.png",               p1+"U_13_3.png"],
		"demon_061": [p2+"M_01_1_mecha_demon.png",               p2+"M_01_3.png",                   p1+"M_01_1.png",               p1+"M_01_3.png"],
		# ── Regalia expansion (062-082) ──────────────────────────────────────────────
		"demon_062": [f2+"019_1_kappa_samurai.png",              f2+"019_3.png",                    f1+"019_1.png",                f1+"019_3.png"],
		"demon_063": [f2+"017_1_alienic-demon.png",              f2+"017_3.png",                    f1+"017_1.png",                f1+"017_3.png"],
		"demon_064": [p2+"B_04_1_unicorn.png",                   p2+"B_04_3.png",                   p1+"B_04_1.png",               p1+"B_04_3.png"],
		"demon_065": [f2+"011_1_super_aggresive_demon.png",      f2+"011_3.png",                    f1+"011_1.png",                f1+"011_3.png"],
		"demon_066": [p2+"H_18_1_great_warrior_spirit.png",      p2+"H_18_3.png",                   p1+"H_18_1.png",               p1+"H_18_3.png"],
		"demon_067": [p2+"D_13_1_small_fatty_demon.png",         p2+"D_13_3.png",                   p1+"D_13_1.png",               p1+"D_13_3.png"],
		"demon_068": [p2+"B_03_1_chickenman.png",                p2+"B_03_3.png",                   p1+"B_03_1.png",               p1+"B_03_3.png"],
		"demon_069": [p2+"M_04_1_blastoise.png",                 p2+"M_04_3.png",                   p1+"M_04_1.png",               p1+"M_04_3.png"],
		"demon_070": [f2+"022_1_beast_king.png",                 f2+"022_3.png",                    f1+"022_1.png",                f1+"022_3.png"],
		"demon_071": [p2+"D_14_1_small_weak_demon.png",          p2+"D_14_3.png",                   p1+"D_14_1.png",               p1+"D_14_3.png"],
		"demon_072": [p2+"D_15_1_small_medium_demon.png",        p2+"D_15_3.png",                   p1+"D_15_1.png",               p1+"D_15_3.png"],
		"demon_073": [f2+"023_1_troll.png",                      f2+"023_3.png",                    f1+"023_1.png",                f1+"023_3.png"],
		"demon_074": [p2+"B_17_1_small_beast.png",               p2+"B_17_3.png",                   p1+"B_17_1.png",               p1+"B_17_3.png"],
		"demon_075": [f2+"012_1_strong_weird_demon.png",         f2+"012_3.png",                    f1+"012_1.png",                f1+"012_3.png"],
		"demon_076": [p2+"M_02_1_auto_turret.png",               p2+"M_02_3.png",                   p1+"M_02_1.png",               p1+"M_02_3.png"],
		"demon_077": [p2+"D_16_1_4-big-eyes-demon.png",          p2+"D_16_3.png",                   p1+"D_16_1.png",               p1+"D_16_3.png"],
		"demon_078": [p2+"H_06_1_orc.png",                       p2+"H_06_3.png",                   p1+"H_06_1.png",               p1+"H_06_3.png"],
		"demon_079": [p2+"B_05_1_rooster:phoenix.png",           p2+"B_05_3.png",                   p1+"B_05_1.png",               p1+"B_05_3.png"],
		"demon_080": [f2+"009_1_weak_snake.png",                 f2+"009_3.png",                    f1+"009_1.png",                f1+"009_3.png"],
		"demon_081": [f2+"003_1_egged_demon.png",                f2+"003_3.png",                    f1+"003_1.png",                f1+"003_3.png"],
		"demon_082": [f2+"014_1_elephant_demon.png",             f2+"014_3.png",                    f1+"014_1.png",                f1+"014_3.png"],
		# ── Terresta expansion (083-105) ─────────────────────────────────────────────
		"demon_083": [f2+"016_1_big_slime.png",                  f2+"016_3.png",                    f1+"016_1.png",                f1+"016_3.png"],
		"demon_084": [p2+"U_02_1_skeleton_mage.png",             p2+"U_02_3.png",                   p1+"U_02_1.png",               p1+"U_02_3.png"],
		"demon_085": [p2+"U_10_1_door_trap.png",                 p2+"U_10_3.png",                   p1+"U_10_1.png",               p1+"U_10_3.png"],
		"demon_086": [p2+"W_05_1_fish_demon.png",                p2+"W_05_3.png",                   p1+"W_05_1.png",               p1+"W_05_3.png"],
		"demon_087": [f2+"018_1_slug_dugtrio.png",               f2+"018_3.png",                    f1+"018_1.png",                f1+"018_3.png"],
		"demon_088": [p2+"W_02_1_sea_dragon.png",                p2+"W_02_3.png",                   p1+"W_02_1.png",               p1+"W_02_3.png"],
		"demon_089": [p2+"N_01_1_killer_plant.png",              p2+"N_01_3.png",                   p1+"N_01_1.png",               p1+"N_01_3.png"],
		"demon_090": [p2+"B_01_1_snake.png",                     p2+"B_01_3.png",                   p1+"B_01_1.png",               p1+"B_01_3.png"],
		"demon_091": [f2+"001_1_king_crab.png",                  f2+"001_3.png",                    f1+"001_1.png",                f1+"001_3.png"],
		"demon_092": [p2+"W_01_1_undead_piranha.png",            p2+"W_01_3.png",                   p1+"W_01_1.png",               p1+"W_01_3.png"],
		"demon_093": [p2+"N_07_1_corrupted_plant_thorns.png",    p2+"N_07_3.png",                   p1+"N_07_1.png",               p1+"N_07_3.png"],
		"demon_094": [p2+"N_09_1_tree_stump.png",                p2+"N_09_3.png",                   p1+"N_09_1.png",               p1+"N_09_3.png"],
		"demon_095": [p2+"B_06_1_tigerfang.png",                 p2+"B_06_3.png",                   p1+"B_06_1.png",               p1+"B_06_3.png"],
		"demon_096": [f2+"008_1_hornet_queen.png",               f2+"008_3.png",                    f1+"008_1.png",                f1+"008_3.png"],
		"demon_097": [p2+"R_03_1_furry_beast.png",               p2+"R_03_3.png",                   p1+"R_03_1.png",               p1+"R_03_3.png"],
		"demon_098": [p2+"B_16_1_alpha_wolf.png",                p2+"B_16_3.png",                   p1+"B_16_1.png",               p1+"B_16_3.png"],
		"demon_099": [p2+"R_02_1_pterodactyl.png",               p2+"R_02_3.png",                   p1+"R_02_1.png",               p1+"R_02_3.png"],
		"demon_100": [p2+"R_01_1.png",                           p2+"R_01_3.png",                   p1+"R_01_1.png",               p1+"R_01_3.png"],
		"demon_101": [p2+"B_15_1_wolf.png",                      p2+"B_15_3.png",                   p1+"B_15_1.png",               p1+"B_15_3.png"],
		"demon_102": [p2+"B_10_1_turtle.png",                    p2+"B_10_3.png",                   p1+"B_10_1.png",               p1+"B_10_3.png"],
		"demon_103": [p2+"N_12_1_worms_colony.png",              p2+"N_12_3.png",                   p1+"N_12_1.png",               p1+"N_12_3.png"],
		"demon_104": [p2+"N_05_1_armored_insect.png",            p2+"N_05_3.png",                   p1+"N_05_1.png",               p1+"N_05_3.png"],
		"demon_105": [p2+"N_04_1_bee.png",                       p2+"N_04_3.png",                   p1+"N_04_1.png",               p1+"N_04_3.png"],
		# ── Elemental expansion (106-125) ────────────────────────────────────────────
		"demon_106": [p2+"D_02_1_imp.png",                       p2+"D_02_3.png",                   p1+"D_02_1.png",               p1+"D_02_3.png"],
		"demon_107": [p2+"D_17_1_corrupted-dog.png",             p2+"D_17_3.png",                   p1+"D_17_1.png",               p1+"D_17_3.png"],
		"demon_108": [p2+"N_08_1_mushroom_insect.png",           p2+"N_08_3.png",                   p1+"N_08_1.png",               p1+"N_08_3.png"],
		"demon_109": [p2+"U_05_1_four-legged-skeleton.png",      p2+"U_05_3.png",                   p1+"U_05_1.png",               p1+"U_05_3.png"],
		"demon_110": [p2+"B_05_1_rooster:phoenix.png",           p2+"B_05_3.png",                   p1+"B_05_1.png",               p1+"B_05_3.png"],
		"demon_111": [p2+"U_14_1_undead_medusa.png",             p2+"U_14_3.png",                   p1+"U_14_1.png",               p1+"U_14_3.png"],
		"demon_112": [p2+"M_03_1_cyborg_rat.png",                p2+"M_03_3.png",                   p1+"M_03_1.png",               p1+"M_03_3.png"],
		"demon_113": [p2+"N_13_1_mushroom_bros.png",             p2+"N_13_3.png",                   p1+"N_13_1.png",               p1+"N_13_3.png"],
		"demon_114": [f2+"015_1_ice_lizard.png",                 f2+"015_3.png",                    f1+"015_1.png",                f1+"015_3.png"],
		"demon_115": [p2+"U_11_1_skeleton_unicorn.png",          p2+"U_11_3.png",                   p1+"U_11_1.png",               p1+"U_11_3.png"],
		"demon_116": [p2+"W_06_1_kabuto.png",                    p2+"W_06_3.png",                   p1+"W_06_1.png",               p1+"W_06_3.png"],
		"demon_117": [p2+"W_04_1_shark_demon.png",               p2+"W_04_3.png",                   p1+"W_04_1.png",               p1+"W_04_3.png"],
		"demon_118": [p2+"N_02_1_worm.png",                      p2+"N_02_3.png",                   p1+"N_02_1.png",               p1+"N_02_3.png"],
		"demon_119": [p2+"W_07_1_crab.png",                      p2+"W_07_3.png",                   p1+"W_07_1.png",               p1+"W_07_3.png"],
		"demon_120": [f2+"019_1_kappa_samurai.png",              f2+"019_3.png",                    f1+"019_1.png",                f1+"019_3.png"],
		"demon_121": [f2+"017_1_alienic-demon.png",              f2+"017_3.png",                    f1+"017_1.png",                f1+"017_3.png"],
		"demon_122": [p2+"W_11_1_fish.png",                      p2+"W_11_3.png",                   p1+"W_11_1.png",               p1+"W_11_3.png"],
		"demon_123": [f2+"022_1_beast_king.png",                 f2+"022_3.png",                    f1+"022_1.png",                f1+"022_3.png"],
		"demon_124": [p2+"U_03_1_weak_skeleton.png",             p2+"U_03_3.png",                   p1+"U_03_1.png",               p1+"U_03_3.png"],
		"demon_125": [p2+"U_01_1_skeleton_scimitar.png",         p2+"U_01_3.png",                   p1+"U_01_1.png",               p1+"U_01_3.png"],
		# ── Tokens ───────────────────────────────────────────────────────────────────
		"token_zombie":    [f2+"006_1_zombie.png",               f2+"006_3.png",                    f1+"006_1.png",                f1+"006_3.png"],
		"token_ash_wraith":[p2+"U_15_1_specter.png",             p2+"U_15_3.png",                   p1+"U_15_1.png",               p1+"U_15_3.png"],
		"token_imp":       [p2+"D_02_1_imp.png",                 p2+"D_02_3.png",                   p1+"D_02_1.png",               p1+"D_02_3.png"],
		# ── Spells (all reuse 4 art variants by effect category) ─────────────────────
		# fire → 029_1, dark → 029_3, ice → 028_1, general → 028_3
		"spell_001": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_002": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_003": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_004": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_005": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_006": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_007": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_008": [f2+"028_1_ice_spell.png",   f2+"028_3_normal_spell.png",f1+"028_1.png", f1+"028_3.png"],
		"spell_009": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_010": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_011": [f2+"028_1_ice_spell.png",   f2+"028_3_normal_spell.png",f1+"028_1.png", f1+"028_3.png"],
		"spell_012": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_013": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_014": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_015": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_016": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_017": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_018": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_019": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_020": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_021": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_022": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_023": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_024": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_025": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_026": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_027": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_028": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_029": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_030": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_031": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_032": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_033": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_034": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_035": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_036": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_037": [f2+"028_1_ice_spell.png",   f2+"028_3_normal_spell.png",f1+"028_1.png", f1+"028_3.png"],
		"spell_038": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_039": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_040": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_041": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_042": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_043": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_044": [f2+"028_1_ice_spell.png",   f2+"028_3_normal_spell.png",f1+"028_1.png", f1+"028_3.png"],
		"spell_045": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_046": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_047": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_048": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_049": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_050": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_051": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_052": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_053": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_054": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_055": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_056": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_057": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_058": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_059": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_060": [f2+"028_1_ice_spell.png",   f2+"028_3_normal_spell.png",f1+"028_1.png", f1+"028_3.png"],
		"spell_061": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_062": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_063": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_064": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
		"spell_065": [f2+"029_3_dark_spell.png",  f2+"029_1_fire_spell.png",  f1+"029_3.png", f1+"029_1.png"],
		"spell_066": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_067": [f2+"029_1_fire_spell.png",  f2+"029_3_dark_spell.png",  f1+"029_1.png", f1+"029_3.png"],
		"spell_068": [f2+"028_3_normal_spell.png",f2+"028_1_ice_spell.png",   f1+"028_3.png", f1+"028_1.png"],
	}
