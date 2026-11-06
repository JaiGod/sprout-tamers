extends Node
## Sprout Tamers - all game data. Autoloaded as "D". Everything here is original.

const SEASONS = ["Spring", "Summer", "Autumn", "Winter"]
const DAYS_PER_SEASON = 5
const ELEM = ["Leaf", "Dew", "Ember"]
const ELEM_COL = [Color("6fcf5a"), Color("5ab8f0"), Color("f39a3c")]
const JOB_NAME = {"water": "Waterer", "harvest": "Harvester", "guard": "Guardian"}
const JOB_ICON = {"water": "~", "harvest": "+", "guard": "#"}
const SEASON_TINT = [Color("8fd26a"), Color("c6dc55"), Color("d99a45"), Color("dfe9f2")]
const SEASON_SKY = [Color("bfe8ff"), Color("9ad8ff"), Color("f2c98f"), Color("c7d6e6")]

## Crops: n name, s season, d days to ripen, c seed cost, v sell value, e element, col, k produce kind
const CROPS = [
	{"n": "Dewbean", "s": 0, "d": 2, "c": 10, "v": 26, "e": 1, "col": Color("68d0e8"), "k": "pods"},
	{"n": "Sunradish", "s": 0, "d": 3, "c": 15, "v": 40, "e": 2, "col": Color("ee5a6a"), "k": "round"},
	{"n": "Mossleaf", "s": 0, "d": 2, "c": 8, "v": 21, "e": 0, "col": Color("4fbf4a"), "k": "leafy"},
	{"n": "Flarepepper", "s": 1, "d": 3, "c": 20, "v": 50, "e": 2, "col": Color("f2492f"), "k": "pods"},
	{"n": "Bubblemelon", "s": 1, "d": 4, "c": 28, "v": 80, "e": 1, "col": Color("7fe0b6"), "k": "big"},
	{"n": "Vinecorn", "s": 1, "d": 3, "c": 18, "v": 45, "e": 0, "col": Color("f5d34a"), "k": "tall"},
	{"n": "Lanternkin", "s": 2, "d": 4, "c": 30, "v": 84, "e": 2, "col": Color("f08a24"), "k": "big"},
	{"n": "Mistgrape", "s": 2, "d": 3, "c": 22, "v": 54, "e": 1, "col": Color("9a6be0"), "k": "cluster"},
	{"n": "Barkroot", "s": 2, "d": 2, "c": 14, "v": 33, "e": 0, "col": Color("a8703f"), "k": "round"},
	{"n": "Frostbulb", "s": 3, "d": 3, "c": 24, "v": 58, "e": 1, "col": Color("bfefff"), "k": "round"},
	{"n": "Emberleek", "s": 3, "d": 3, "c": 26, "v": 62, "e": 2, "col": Color("ff7a4a"), "k": "tall"},
	{"n": "Pinecress", "s": 3, "d": 2, "c": 16, "v": 37, "e": 0, "col": Color("2f9e6a"), "k": "cluster"},
]

## Sprouts: plant-spirit creatures. b = base [hp, atk, def, spd]. combo = two crop ids grown side by side.
## shape: 0 round 1 bean 2 wide 3 drop. top: 0 leaves 1 flower 2 cap 3 berries 4 flame 5 crystal 6 pine 7 husk 8 curl 9 aurora
const SPROUTS = [
	{"n": "Pipdew", "e": 1, "job": "water", "b": [24, 6, 5, 7], "s": 0, "combo": [0, 0], "shape": 3, "top": 8, "col": Color("7fd8f0"), "col2": Color("4fbf4a"), "desc": "A droplet that hums when it rains."},
	{"n": "Mossling", "e": 0, "job": "harvest", "b": [28, 6, 6, 5], "s": 0, "combo": [2, 2], "shape": 0, "top": 0, "col": Color("88cf5c"), "col2": Color("3d9a3a"), "desc": "Soft as a cushion. Loves tidy rows."},
	{"n": "Radlet", "e": 2, "job": "guard", "b": [26, 8, 6, 5], "s": 0, "combo": [1, 2], "shape": 1, "top": 0, "col": Color("f07a86"), "col2": Color("4fbf4a"), "desc": "Stomps its root-feet at pests."},
	{"n": "Budbun", "e": 0, "job": "water", "b": [25, 6, 5, 8], "s": 0, "combo": [0, 2], "shape": 0, "top": 1, "col": Color("f0e0a8"), "col2": Color("ff9ac8"), "desc": "Hops between beds carrying dew."},
	{"n": "Peppip", "e": 2, "job": "guard", "b": [24, 10, 5, 7], "s": 1, "combo": [3, 3], "shape": 1, "top": 4, "col": Color("f25a3a"), "col2": Color("ffd04a"), "desc": "Small, spicy and very brave."},
	{"n": "Melodrop", "e": 1, "job": "water", "b": [32, 6, 7, 4], "s": 1, "combo": [4, 5], "shape": 2, "top": 8, "col": Color("7fe0b6"), "col2": Color("2f8f5a"), "desc": "Sloshes happily. Sings in thirds."},
	{"n": "Cobbit", "e": 0, "job": "harvest", "b": [27, 8, 6, 6], "s": 1, "combo": [5, 5], "shape": 1, "top": 7, "col": Color("f5d34a"), "col2": Color("5fb84a"), "desc": "Counts every kernel twice."},
	{"n": "Sizzlet", "e": 2, "job": "harvest", "b": [23, 9, 4, 9], "s": 1, "combo": [3, 4], "shape": 3, "top": 4, "col": Color("ff9a5a"), "col2": Color("ffe07a"), "desc": "Warm to hold, quick to vanish."},
	{"n": "Lumpkin", "e": 2, "job": "guard", "b": [34, 7, 8, 3], "s": 2, "combo": [6, 8], "shape": 2, "top": 8, "col": Color("f08a24"), "col2": Color("6a8f2a"), "desc": "Glows from the inside on cold nights."},
	{"n": "Grapewisp", "e": 1, "job": "water", "b": [24, 8, 5, 8], "s": 2, "combo": [7, 7], "shape": 3, "top": 3, "col": Color("b48af0"), "col2": Color("6a3fb0"), "desc": "Leaves a sweet purple mist."},
	{"n": "Burlrook", "e": 0, "job": "guard", "b": [36, 7, 9, 2], "s": 2, "combo": [8, 8], "shape": 1, "top": 2, "col": Color("b07a48"), "col2": Color("d24a3a"), "desc": "Stands like a stump. Never budges."},
	{"n": "Glowcap", "e": 2, "job": "harvest", "b": [26, 9, 6, 6], "s": 2, "combo": [6, 7], "shape": 0, "top": 2, "col": Color("f4e6c0"), "col2": Color("f0a43a"), "desc": "Its cap lights up the night harvest."},
	{"n": "Frostkit", "e": 1, "job": "water", "b": [25, 8, 6, 8], "s": 3, "combo": [9, 11], "shape": 0, "top": 5, "col": Color("d8f4ff"), "col2": Color("7fc8f0"), "desc": "Melts snow into gentle drizzle."},
	{"n": "Leekeen", "e": 2, "job": "harvest", "b": [26, 10, 5, 7], "s": 3, "combo": [10, 10], "shape": 1, "top": 0, "col": Color("ffb08a"), "col2": Color("3fae5a"), "desc": "Sharp-eyed and quick with its leaves."},
	{"n": "Pinepuff", "e": 0, "job": "guard", "b": [33, 7, 9, 4], "s": 3, "combo": [11, 11], "shape": 2, "top": 6, "col": Color("e8f0e0"), "col2": Color("2f8a5a"), "desc": "A snowy puff with a pine crown."},
	{"n": "Aurorabloom", "e": 1, "job": "harvest", "b": [30, 10, 7, 8], "s": 3, "combo": [9, 10], "shape": 3, "top": 9, "col": Color("c8b4ff"), "col2": Color("7fffd0"), "desc": "Seen once a year, when frost meets fire."},
]

## Traits shape both farm work and battle stats.
const TRAITS = {
	"Dewy": "Waters 2 extra plots",
	"Swift": "+3 Speed",
	"Sturdy": "+3 Defense",
	"Fierce": "+3 Attack",
	"Hearty": "+10 HP",
	"Green Thumb": "Nudges a crop to grow",
	"Lucky": "Harvests can double",
	"Watchful": "Better at guarding",
	"Cheery": "Gains friendship faster",
	"Sunny": "Heals the team in battle",
}

## Blight creatures from the wild woods. e = element, b = [hp, atk, def, spd]
const BLIGHTS = [
	{"n": "Rotmite", "e": 0, "b": [16, 5, 3, 5], "col": Color("6b4a8a"), "s": 0},
	{"n": "Thornlet", "e": 2, "b": [20, 6, 4, 4], "col": Color("7a3a5a"), "s": 0},
	{"n": "Scorchgnat", "e": 2, "b": [18, 8, 3, 8], "col": Color("8a3a3a"), "s": 1},
	{"n": "Wiltwing", "e": 1, "b": [22, 7, 4, 6], "col": Color("4a4a7a"), "s": 1},
	{"n": "Mildew Moth", "e": 1, "b": [24, 8, 5, 7], "col": Color("5a6a6a"), "s": 2},
	{"n": "Gloomshroom", "e": 0, "b": [30, 8, 6, 3], "col": Color("5a3a6a"), "s": 2},
	{"n": "Frostblight", "e": 1, "b": [28, 9, 6, 6], "col": Color("3a4a7a"), "s": 3},
	{"n": "Hollow Husk", "e": 2, "b": [32, 10, 6, 5], "col": Color("4a3a3a"), "s": 3},
]

const BOSSES = [
	{"n": "Bramble Maw", "e": 0, "b": [90, 9, 6, 4], "col": Color("4a3a6a"), "line": "The Bramble Maw claws at your fence!"},
	{"n": "Cinder Wilt", "e": 2, "b": [130, 12, 7, 6], "col": Color("6a2a2a"), "line": "A heatwave of rot rolls in: Cinder Wilt!"},
	{"n": "Mire Mother", "e": 1, "b": [170, 14, 9, 5], "col": Color("2a4a5a"), "line": "Fog thickens. The Mire Mother rises."},
	{"n": "The Hollow Rot", "e": -1, "b": [220, 16, 10, 7], "col": Color("2a1a2a"), "line": "The heart of the blight itself: The Hollow Rot!"},
]

const WOODS = [
	{"n": "Mossy Glade", "lv": 0, "cost": 3, "desc": "Gentle trails. 1-2 blights."},
	{"n": "Tangled Hollow", "lv": 2, "cost": 4, "desc": "Thick thorns. 2-3 blights."},
	{"n": "Blightroot Deep", "lv": 4, "cost": 5, "desc": "Dangerous. Rich rewards."},
]

## The four villagers of Willowmere.
const VILLAGERS = [
	{"n": "Mayor Olwen", "role": "Mayor", "hair": Color("e8e8e8"), "shirt": Color("5a6ad0"), "skin": Color("f0c8a0"),
		"lines": ["Willowmere has farmed beside sprouts for a hundred years.", "The blight grows bolder each season. Your farm is our wall.", "Fill my requests and the whole town will help you."]},
	{"n": "Tilly", "role": "Seed Market", "hair": Color("e0703a"), "shirt": Color("4fae5a"), "skin": Color("f4d0b0"),
		"lines": ["Fresh seeds every season! Plant pairs side by side.", "Sprouts love it when two crops share a border.", "Sell me your harvest. I pay fair, I promise."]},
	{"n": "Bram", "role": "Workshop", "hair": Color("3a2a1a"), "shirt": Color("a8603a"), "skin": Color("c89070"),
		"lines": ["I build things. Fences, wards, bigger fields.", "A Lantern Ward keeps the blight mites away at night.", "Got coin? I've got lumber."]},
	{"n": "Juniper", "role": "Sprout Clinic", "hair": Color("6a4ab0"), "shirt": Color("f0f0f0"), "skin": Color("e8b890"),
		"lines": ["Sprouts with high friendship work harder.", "Two happy sprouts can share a seed. That is breeding!", "Traits pass down. Mix them wisely."]},
]

const FESTIVALS = [
	{"n": "Bloom Fair", "col": Color("ff9ac8")},
	{"n": "Sunfire Night", "col": Color("ffb03a")},
	{"n": "Lantern Harvest", "col": Color("f08a24")},
	{"n": "Frostlight Gala", "col": Color("9fe0ff")},
]

const ITEMS = {
	"tonic": {"n": "Dew Tonic", "c": 30, "desc": "Heals a sprout 25 HP in battle."},
	"nectar": {"n": "Sweet Nectar", "c": 25, "desc": "A treat: +2 friendship."},
	"compost": {"n": "Glow Compost", "c": 45, "desc": "All crops grow 1 day."},
}

const UPGRADES = [
	{"id": "row1", "n": "Field Expansion I", "c": 220, "desc": "+1 row of farm plots."},
	{"id": "row2", "n": "Field Expansion II", "c": 420, "desc": "+1 more row of plots.", "need": "row1"},
	{"id": "ward", "n": "Lantern Ward", "c": 260, "desc": "Halves blight-mite attacks."},
	{"id": "can", "n": "Copper Can", "c": 180, "desc": "Watering costs no energy."},
	{"id": "heart", "n": "Heartroot Graft", "c": 350, "desc": "Restore 1 farm heart.", "repeat": true},
]

func combo_for(a: int, b: int, season: int) -> int:
	var lo = mini(a, b)
	var hi = maxi(a, b)
	for i in SPROUTS.size():
		var s = SPROUTS[i]
		if s["s"] != season:
			continue
		if mini(s["combo"][0], s["combo"][1]) == lo and maxi(s["combo"][0], s["combo"][1]) == hi:
			return i
	return -1

func adv(att: int, def: int) -> float:
	if att < 0 or def < 0:
		return 1.0
	if (att == 0 and def == 1) or (att == 1 and def == 2) or (att == 2 and def == 0):
		return 1.5
	if (def == 0 and att == 1) or (def == 1 and att == 2) or (def == 2 and att == 0):
		return 0.67
	return 1.0
