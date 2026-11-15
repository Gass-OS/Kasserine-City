extends Node

const PATH := "user://settings.cfg"
const LANGS := ["en", "fr", "ar"]

var master_volume := 0.8
var quality := 1
var language := "en"
var look_sensitivity := 1.0
var day_length := 240.0
var first_person := false

const STR := {
	"play": {"en": "Play", "fr": "Jouer", "ar": "ابدأ اللعب"},
	"settings": {"en": "Settings", "fr": "Réglages", "ar": "الإعدادات"},
	"quit": {"en": "Quit", "fr": "Quitter", "ar": "خروج"},
	"quit_confirm": {"en": "Quit the game?", "fr": "Quitter le jeu ?", "ar": "الخروج من اللعبة؟"},
	"yes_quit": {"en": "Yes, quit", "fr": "Oui, quitter", "ar": "نعم، خروج"},
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
	"radio": {"en": "Radio", "fr": "Radio", "ar": "الراديو"},
	"prayer_time": {"en": "Prayer time — men are going to the mosque", "fr": "Heure de la prière — les hommes vont à la mosquée", "ar": "وقت الصلاة — الرجال يتوجهون إلى المسجد"},
	"criminal_caught": {"en": "Criminal caught! %d / 3 tonight", "fr": "Criminel arrêté ! %d / 3 cette nuit", "ar": "تم القبض على المجرم! %d / 3 الليلة"},
	"all_criminals_caught": {"en": "All night criminals caught! The city is safe.", "fr": "Tous les criminels de la nuit arrêtés ! La ville est en sécurité.", "ar": "تم القبض على جميع مجرمي الليل! المدينة آمنة."},
	"wanted_caught": {"en": "MOST WANTED caught! +500 dinars", "fr": "LE PLUS RECHERCHÉ arrêté ! +500 dinars", "ar": "تم القبض على المطلوب الأول! +500 دينار"},
	"wanted_hint": {"en": "The fugitive is close — press USE to arrest him!", "fr": "Le fugitif est proche — appuie sur USE pour l'arrêter !", "ar": "الهارب قريب — اضغط USE للقبض عليه!"},
	"prayer_done": {"en": "Prayer finished.", "fr": "Prière terminée.", "ar": "انتهت الصلاة."},
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
	master_volume = c.get_value("main", "master_volume", master_volume)
	quality = c.get_value("main", "quality", quality)
	language = c.get_value("main", "language", language)
	look_sensitivity = c.get_value("main", "look_sensitivity", look_sensitivity)
	day_length = c.get_value("main", "day_length", day_length)
	first_person = bool(c.get_value("main", "first_person", first_person))

func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("main", "master_volume", master_volume)
	c.set_value("main", "quality", quality)
	c.set_value("main", "language", language)
	c.set_value("main", "look_sensitivity", look_sensitivity)
	c.set_value("main", "day_length", day_length)
	c.set_value("main", "first_person", first_person)
	c.save(PATH)

func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	var vp := get_viewport()
	if vp:
		match quality:
			0: vp.msaa_3d = Viewport.MSAA_DISABLED
			1: vp.msaa_3d = Viewport.MSAA_2X
			_: vp.msaa_3d = Viewport.MSAA_4X
