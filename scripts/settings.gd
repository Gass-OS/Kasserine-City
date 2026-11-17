extends Node

const PATH := "user://settings.cfg"
const LANGS := ["en", "fr", "ar"]

var master_volume := 0.8
var quality := 1
var language := "en"
var look_sensitivity := 1.0
# v0.3.1: 2400 s = a full 24 h game day in 40 real minutes — day 20 min
# + night 20 min (is_night splits the cycle exactly in half). Was 240 s.
var day_length := 2400.0
var first_person := false
var intro_seen := false
# v0.4.4: menu start-time choice — 0 = Day (t 0.4, 09:36), 1 = Night
# (t 0.85, 20:24), 2 = Prayer (t 0.521, 12:30 Dhuhr, so the adhan
# plays right at the start). Persisted like the other settings.
var start_time_mode := 0

const STR := {
	"play": {"en": "Play", "fr": "Jouer", "ar": "ابدأ اللعب"},
	"start_at": {"en": "Start at:", "fr": "Commencer :", "ar": "ابدأ في:"},
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
	# v0.4: story chapters (a new officer's first week in Kasserine).
	"story_ch1_title": {"en": "Chapter 1 — First Patrol", "fr": "Chapitre 1 — Première patrouille", "ar": "الفصل ١ — أول دورية"},
	"story_ch1_body": {"en": "You are a new police officer in Kasserine. It is your first day. Meet Amine at the square — he will show you the city, the market and the garage.", "fr": "Tu es un nouvel officier de police à Kasserine. C'est ton premier jour. Retrouve Amine sur la place — il va te montrer la ville, le marché et le garage.", "ar": "أنت ضابط شرطة جديد في القصرين. إنه يومك الأول. قابل أمين في الساحة — سيريك المدينة والسوق والمرآب."},
	"story_ch2_title": {"en": "Chapter 2 — The Souk Robbery", "fr": "Chapitre 2 — Le braquage du souk", "ar": "الفصل ٢ — سرقة السوق"},
	"story_ch2_body": {"en": "A robbery at the souk! Someone stole from the market stalls. Head to the market, look around, and find what happened.", "fr": "Un braquage au souk ! Quelqu'un a volé dans les étals du marché. Va au marché, regarde autour de toi et découvre ce qui s'est passé.", "ar": "سرقة في السوق! سرق أحدهم من أكشاك السوق. توجه إلى السوق، وانظر حولك، واكتشف ما حدث."},
	"story_ch3_title": {"en": "Chapter 3 — Night Shift", "fr": "Chapitre 3 — Service de nuit", "ar": "الفصل ٣ — مناوبة الليل"},
	"story_ch3_body": {"en": "Night falls on Kasserine. Criminals come out after dark — look for the red marks. Press USE near one to arrest him. Catch all three before dawn.", "fr": "La nuit tombe sur Kasserine. Les criminels sortent après la tombée du jour — cherche les marques rouges. Appuie sur USE près d'un criminel pour l'arrêter. Attrape-les tous les trois avant l'aube.", "ar": "يحل الليل على القصرين. يخرج المجرمون بعد حلول الظلام — ابحث عن العلامات الحمراء. اضغط USE قرب أحدهم للقبض عليه. اقبض عليهم جميعًا قبل الفجر."},
	"story_ch4_title": {"en": "Chapter 4 — The Most Wanted", "fr": "Chapitre 4 — Le plus recherché", "ar": "الفصل ٤ — المطلوب الأول"},
	"story_ch4_body": {"en": "The fugitive is hiding somewhere in the city. Follow the golden beam, get close, and press USE to arrest him. +500 dinars. This is your final test, officer.", "fr": "Le fugitif se cache quelque part dans la ville. Suis le faisceau doré, approche-toi et appuie sur USE pour l'arrêter. +500 dinars. C'est ton épreuve finale, officier.", "ar": "الهارب مختبئ في مكان ما في المدينة. اتبع الشعاع الذهبي، واقترب، واضغط USE للقبض عليه. +500 دينار. هذا اختبارك الأخير أيها الضابط."},
	"story_end_title": {"en": "Kasserine is safe — for now", "fr": "Kasserine est en sécurité — pour l'instant", "ar": "القصرين آمنة — في الوقت الحالي"},
	"story_end_body": {"en": "You caught the most wanted fugitive and finished your first week. The city trusts you, officer. Keep patrolling — Kasserine is yours to protect.", "fr": "Tu as arrêté le fugitif le plus recherché et terminé ta première semaine. La ville te fait confiance, officier. Continue tes patrouilles — Kasserine est à toi de protéger.", "ar": "لقد قبضت على الهارب المطلوب الأول وأنهيت أسبوعك الأول. المدينة تثق بك أيها الضابط. واصل دورياتك — القصرين أمانة في عهدتك."},
	"continue": {"en": "Continue", "fr": "Continuer", "ar": "متابعة"},
	"skip": {"en": "Skip", "fr": "Passer", "ar": "تخطي"},
	"tap_to_start": {"en": "Tap to start", "fr": "Touche pour commencer", "ar": "المس للبدء"},
	"loading": {"en": "Loading the city…", "fr": "Chargement de la ville…", "ar": "جارٍ تحميل المدينة…"},
	"intro_card1": {"en": "KASSERINE CITY", "fr": "KASSERINE CITY", "ar": "مدينة القصرين"},
	"intro_card2": {"en": "A new officer arrives in town.", "fr": "Un nouvel officier arrive en ville.", "ar": "ضابط جديد يصل إلى المدينة."},
	"intro_card3": {"en": "His first week on patrol starts now.", "fr": "Sa première semaine de patrouille commence.", "ar": "يبدأ أسبوعه الأول في الدورية الآن."},
	"radio_on": {"en": "RADIO ON", "fr": "RADIO ON", "ar": "الراديو يعمل"},
	"radio_off": {"en": "RADIO OFF", "fr": "RADIO OFF", "ar": "الراديو متوقف"},
	"radio_stopped": {"en": "Radio off.", "fr": "Radio éteinte.", "ar": "الراديو متوقف."},
	"radio_started": {"en": "Radio on — police channel open.", "fr": "Radio allumée — canal police ouvert.", "ar": "الراديو يعمل — قناة الشرطة مفتوحة."},
	"test_adhan": {"en": "TEST ADHAN", "fr": "TEST ADHAN", "ar": "اختبار الأذان"},
	"test_radio": {"en": "TEST RADIO", "fr": "TEST RADIO", "ar": "اختبار الراديو"},
	"adhan_ok": {"en": "Adhan: OK — file found, playing now.", "fr": "Adhan : OK — fichier trouvé, en cours de lecture.", "ar": "الأذان: يعمل — تم العثور على الملف، يتم تشغيله الآن."},
	"adhan_missing": {"en": "Adhan: file missing — no adhan.mp3 found.", "fr": "Adhan : fichier manquant — adhan.mp3 introuvable.", "ar": "الأذان: الملف مفقود — لم يتم العثور على adhan.mp3."},
	"radio_ok": {"en": "Radio: OK — file found, playing now.", "fr": "Radio : OK — fichier trouvé, en cours de lecture.", "ar": "الراديو: يعمل — تم العثور على الملف، يتم تشغيله الآن."},
	"radio_missing": {"en": "Radio: file missing — using the blip.", "fr": "Radio : fichier manquant — bip utilisé.", "ar": "الراديو: الملف مفقود — يتم استخدام الصوت البديل."},
	# v0.4.2: drivable police car.
	"drive_enter": {"en": "Driving the police car — joystick to drive, RUN to boost, USE to get out, SIREN for lights + sound.", "fr": "Tu conduis la voiture de police — joystick pour rouler, RUN pour accélérer, USE pour sortir, SIREN pour gyrophares + sirène.", "ar": "أنت تقود سيارة الشرطة — استخدم عصا التحكم للقيادة، RUN للسرعة، USE للخروج، SIREN للأضواء والصوت."},
	"drive_exit": {"en": "Out of the car — on foot again.", "fr": "Sorti de la voiture — à pied de nouveau.", "ar": "خرجت من السيارة — عدت إلى المشي."},
	"drive_hint": {"en": "Police car — press USE to drive it!", "fr": "Voiture de police — appuie sur USE pour la conduire !", "ar": "سيارة الشرطة — اضغط USE لقيادتها!"},
	"siren_on": {"en": "Siren on!", "fr": "Sirène allumée !", "ar": "الصفارة تعمل!"},
	"siren_off": {"en": "Siren off.", "fr": "Sirène éteinte.", "ar": "الصفارة متوقفة."},
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
	intro_seen = bool(c.get_value("main", "intro_seen", intro_seen))
	start_time_mode = int(c.get_value("main", "start_time_mode", start_time_mode))

func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("main", "master_volume", master_volume)
	c.set_value("main", "quality", quality)
	c.set_value("main", "language", language)
	c.set_value("main", "look_sensitivity", look_sensitivity)
	c.set_value("main", "day_length", day_length)
	c.set_value("main", "first_person", first_person)
	c.set_value("main", "intro_seen", intro_seen)
	c.set_value("main", "start_time_mode", start_time_mode)
	c.save(PATH)

func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	var vp := get_viewport()
	if vp:
		match quality:
			0: vp.msaa_3d = Viewport.MSAA_DISABLED
			1: vp.msaa_3d = Viewport.MSAA_2X
			_: vp.msaa_3d = Viewport.MSAA_4X
