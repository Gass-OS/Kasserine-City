extends Node

const PATH := "user://settings.cfg"
const LANGS := ["en", "fr", "ar"]

var master_volume := 0.8
var quality := 1
var language := "en"
var look_sensitivity := 1.0
var day_length := 240.0

const STR := {
	"play": {"en": "Play", "fr": "Jouer", "ar": "ابدأ اللعب"},
	"settings": {"en": "Settings", "fr": "Réglages", "ar": "الإعدادات"},
	"quit": {"en": "Quit", "fr": "Quitter", "ar": "خروج"},
	"subtitle": {"en": "Open world · Tunisia", "fr": "Monde ouvert · Tunisie", "ar": "عالم مفتوح · تونس"},
	"volume": {"en": "Volume", "fr": "Volume", "ar": "الصوت"},
	"quality": {"en": "Graphics", "fr": "Graphismes", "ar": "الجودة"},
	"language": {"en": "Language", "fr": "Langue", "ar": "اللغة"},
	"sensitivity": {"en": "Touch sensitivity", "fr": "Sensibilité tactile", "ar": "حساسية اللمس"},
	"day_length": {"en": "Day length (sec)", "fr": "Durée du jour (s)", "ar": "مدة اليوم (ثانية)"},
	"back": {"en": "Back", "fr": "Retour", "ar": "رجوع"},
	"low": {"en": "Low", "fr": "Bas", "ar": "منخفضة"},
	"medium": {"en": "Medium", "fr": "Moyen", "ar": "متوسطة"},
	"high": {"en": "High", "fr": "Élevé", "ar": "عالية"},
}

func _ready() -> void:
	load_settings()
	apply()

func t(key: String) -> String:
	var d: Dictionary = STR.get(key, {})
	return d.get(language, d.get("en", key))

func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return

	var saved_volume = c.get_value("main", "master_volume", master_volume)
	if typeof(saved_volume) == TYPE_INT or typeof(saved_volume) == TYPE_FLOAT:
		master_volume = clampf(float(saved_volume), 0.0, 1.0)

	var saved_quality = c.get_value("main", "quality", quality)
	if typeof(saved_quality) == TYPE_INT:
		quality = clampi(saved_quality, 0, 2)

	var saved_language = c.get_value("main", "language", language)
	if saved_language is String and saved_language in LANGS:
		language = saved_language

	var saved_sensitivity = c.get_value("main", "look_sensitivity", look_sensitivity)
	if typeof(saved_sensitivity) == TYPE_INT or typeof(saved_sensitivity) == TYPE_FLOAT:
		look_sensitivity = clampf(float(saved_sensitivity), 0.3, 2.5)

	var saved_day_length = c.get_value("main", "day_length", day_length)
	if typeof(saved_day_length) == TYPE_INT or typeof(saved_day_length) == TYPE_FLOAT:
		day_length = clampf(float(saved_day_length), 60.0, 600.0)

func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("main", "master_volume", master_volume)
	c.set_value("main", "quality", quality)
	c.set_value("main", "language", language)
	c.set_value("main", "look_sensitivity", look_sensitivity)
	c.set_value("main", "day_length", day_length)
	c.save(PATH)

func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	var vp := get_viewport()
	if vp:
		match quality:
			0: vp.msaa_3d = Viewport.MSAA_DISABLED
			1: vp.msaa_3d = Viewport.MSAA_2X
			_: vp.msaa_3d = Viewport.MSAA_4X
