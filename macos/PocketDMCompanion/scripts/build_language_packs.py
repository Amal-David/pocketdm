#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "Sources" / "PocketDMCompanion" / "Resources" / "language-packs.json"

SPANISH_WORDS = [
    ("Hello", "Hola", "OH-lah"),
    ("Goodbye", "Adiós", "ah-DYOS"),
    ("Yes", "Sí", "SEE"),
    ("No", "No", "noh"),
    ("Please", "Por favor", "por fah-VOR"),
    ("Thank you", "Gracias", "GRAH-syahs"),
    ("Sorry", "Lo siento", "loh SYEN-toh"),
    ("Excuse me", "Perdón", "per-DON"),
    ("Good morning", "Buenos días", "BWEH-nos DEE-ahs"),
    ("Good night", "Buenas noches", "BWEH-nas NOH-ches"),
    ("Water", "Agua", "AH-gwah"),
    ("Coffee", "Café", "kah-FEH"),
    ("Tea", "Té", "teh"),
    ("Food", "Comida", "koh-MEE-dah"),
    ("Rice", "Arroz", "ah-ROS"),
    ("Bread", "Pan", "pahn"),
    ("Fruit", "Fruta", "FROO-tah"),
    ("Apple", "Manzana", "mahn-SAH-nah"),
    ("Banana", "Plátano", "PLAH-tah-noh"),
    ("Soup", "Sopa", "SOH-pah"),
    ("House", "Casa", "KAH-sah"),
    ("Hotel", "Hotel", "oh-TEL"),
    ("Bathroom", "Baño", "BAH-nyoh"),
    ("Station", "Estación", "es-tah-SYON"),
    ("Airport", "Aeropuerto", "ah-eh-roh-PWER-toh"),
    ("Street", "Calle", "KAH-yeh"),
    ("Store", "Tienda", "TYEN-dah"),
    ("Market", "Mercado", "mer-KAH-doh"),
    ("School", "Escuela", "es-KWEH-lah"),
    ("Hospital", "Hospital", "os-pee-TAL"),
    ("Left", "Izquierda", "ees-KYER-dah"),
    ("Right", "Derecha", "deh-REH-chah"),
    ("Straight", "Derecho", "deh-REH-choh"),
    ("Near", "Cerca", "SER-kah"),
    ("Far", "Lejos", "LEH-hos"),
    ("Today", "Hoy", "oy"),
    ("Tomorrow", "Mañana", "mah-NYAH-nah"),
    ("Yesterday", "Ayer", "ah-YER"),
    ("Morning", "Mañana", "mah-NYAH-nah"),
    ("Night", "Noche", "NOH-cheh"),
    ("Now", "Ahora", "ah-OH-rah"),
    ("Later", "Luego", "LWEH-goh"),
    ("I", "Yo", "yoh"),
    ("You", "Tú", "too"),
    ("We", "Nosotros", "noh-SOH-tros"),
    ("They", "Ellos", "EH-yos"),
    ("Friend", "Amigo", "ah-MEE-goh"),
    ("Family", "Familia", "fah-MEE-lyah"),
    ("Teacher", "Maestra", "mah-ES-trah"),
    ("Student", "Estudiante", "es-too-DYAN-teh"),
    ("Child", "Niño", "NEE-nyoh"),
    ("Person", "Persona", "per-SOH-nah"),
    ("Man", "Hombre", "OHM-breh"),
    ("Woman", "Mujer", "moo-HER"),
    ("Name", "Nombre", "NOHM-breh"),
    ("Phone", "Teléfono", "teh-LEH-foh-noh"),
    ("Money", "Dinero", "dee-NEH-roh"),
    ("Ticket", "Boleto", "boh-LEH-toh"),
    ("Bus", "Autobús", "ow-toh-BOOS"),
    ("Train", "Tren", "tren"),
    ("Taxi", "Taxi", "TAHK-see"),
    ("Car", "Coche", "KOH-cheh"),
    ("Bicycle", "Bicicleta", "bee-see-KLEH-tah"),
    ("City", "Ciudad", "syoo-DAHD"),
    ("Country", "País", "pah-EES"),
    ("Language", "Idioma", "ee-DYOH-mah"),
    ("Spanish", "Español", "es-pah-NYOL"),
    ("Chinese", "Chino", "CHEE-noh"),
    ("English", "Inglés", "een-GLES"),
    ("Book", "Libro", "LEE-broh"),
    ("Music", "Música", "MOO-see-kah"),
    ("Movie", "Película", "peh-LEE-koo-lah"),
    ("Work", "Trabajo", "trah-BAH-hoh"),
    ("Help", "Ayuda", "ah-YOO-dah"),
    ("Question", "Pregunta", "preh-GOON-tah"),
    ("Answer", "Respuesta", "res-PWES-tah"),
    ("Problem", "Problema", "proh-BLEH-mah"),
    ("Happy", "Feliz", "feh-LEES"),
    ("Tired", "Cansado", "kahn-SAH-doh"),
    ("Hungry", "Hambriento", "ahm-BRYEN-toh"),
    ("Thirsty", "Sediento", "seh-DYEN-toh"),
    ("Hot", "Caliente", "kah-LYEN-teh"),
    ("Cold", "Frío", "FREE-oh"),
    ("Big", "Grande", "GRAHN-deh"),
    ("Small", "Pequeño", "peh-KEH-nyoh"),
    ("Fast", "Rápido", "RAH-pee-doh"),
    ("Slow", "Lento", "LEN-toh"),
    ("Good", "Bueno", "BWEH-noh"),
    ("Bad", "Malo", "MAH-loh"),
    ("Open", "Abierto", "ah-BYER-toh"),
    ("Closed", "Cerrado", "seh-RAH-doh"),
    ("Here", "Aquí", "ah-KEE"),
    ("There", "Allí", "ah-YEE"),
    ("One", "Uno", "OO-noh"),
    ("Two", "Dos", "dohs"),
    ("Three", "Tres", "trehs"),
    ("Four", "Cuatro", "KWAH-troh"),
    ("Five", "Cinco", "SEEN-koh"),
    ("Ten", "Diez", "dyes"),
    ("Time", "Tiempo", "TYEM-poh"),
]

MANDARIN_WORDS = [
    ("Hello", "你好", "nǐ hǎo"),
    ("Goodbye", "再见", "zài jiàn"),
    ("Yes", "是", "shì"),
    ("No", "不", "bù"),
    ("Please", "请", "qǐng"),
    ("Thank you", "谢谢", "xiè xie"),
    ("Sorry", "对不起", "duì bu qǐ"),
    ("Excuse me", "不好意思", "bù hǎo yì si"),
    ("Good morning", "早上好", "zǎo shang hǎo"),
    ("Good night", "晚安", "wǎn ān"),
    ("Water", "水", "shuǐ"),
    ("Coffee", "咖啡", "kā fēi"),
    ("Tea", "茶", "chá"),
    ("Food", "食物", "shí wù"),
    ("Rice", "米饭", "mǐ fàn"),
    ("Bread", "面包", "miàn bāo"),
    ("Fruit", "水果", "shuǐ guǒ"),
    ("Apple", "苹果", "píng guǒ"),
    ("Banana", "香蕉", "xiāng jiāo"),
    ("Soup", "汤", "tāng"),
    ("House", "房子", "fáng zi"),
    ("Hotel", "酒店", "jiǔ diàn"),
    ("Bathroom", "洗手间", "xǐ shǒu jiān"),
    ("Station", "车站", "chē zhàn"),
    ("Airport", "机场", "jī chǎng"),
    ("Street", "街道", "jiē dào"),
    ("Store", "商店", "shāng diàn"),
    ("Market", "市场", "shì chǎng"),
    ("School", "学校", "xué xiào"),
    ("Hospital", "医院", "yī yuàn"),
    ("Left", "左边", "zuǒ biān"),
    ("Right", "右边", "yòu biān"),
    ("Straight", "一直走", "yì zhí zǒu"),
    ("Near", "近", "jìn"),
    ("Far", "远", "yuǎn"),
    ("Today", "今天", "jīn tiān"),
    ("Tomorrow", "明天", "míng tiān"),
    ("Yesterday", "昨天", "zuó tiān"),
    ("Morning", "早上", "zǎo shang"),
    ("Night", "晚上", "wǎn shang"),
    ("Now", "现在", "xiàn zài"),
    ("Later", "以后", "yǐ hòu"),
    ("I", "我", "wǒ"),
    ("You", "你", "nǐ"),
    ("We", "我们", "wǒ men"),
    ("They", "他们", "tā men"),
    ("Friend", "朋友", "péng you"),
    ("Family", "家人", "jiā rén"),
    ("Teacher", "老师", "lǎo shī"),
    ("Student", "学生", "xué sheng"),
    ("Child", "孩子", "hái zi"),
    ("Person", "人", "rén"),
    ("Man", "男人", "nán rén"),
    ("Woman", "女人", "nǚ rén"),
    ("Name", "名字", "míng zi"),
    ("Phone", "电话", "diàn huà"),
    ("Money", "钱", "qián"),
    ("Ticket", "票", "piào"),
    ("Bus", "公交车", "gōng jiāo chē"),
    ("Train", "火车", "huǒ chē"),
    ("Taxi", "出租车", "chū zū chē"),
    ("Car", "汽车", "qì chē"),
    ("Bicycle", "自行车", "zì xíng chē"),
    ("City", "城市", "chéng shì"),
    ("Country", "国家", "guó jiā"),
    ("Language", "语言", "yǔ yán"),
    ("Spanish", "西班牙语", "xī bān yá yǔ"),
    ("Chinese", "中文", "zhōng wén"),
    ("English", "英语", "yīng yǔ"),
    ("Book", "书", "shū"),
    ("Music", "音乐", "yīn yuè"),
    ("Movie", "电影", "diàn yǐng"),
    ("Work", "工作", "gōng zuò"),
    ("Help", "帮助", "bāng zhù"),
    ("Question", "问题", "wèn tí"),
    ("Answer", "回答", "huí dá"),
    ("Problem", "麻烦", "má fan"),
    ("Happy", "开心", "kāi xīn"),
    ("Tired", "累", "lèi"),
    ("Hungry", "饿", "è"),
    ("Thirsty", "渴", "kě"),
    ("Hot", "热", "rè"),
    ("Cold", "冷", "lěng"),
    ("Big", "大", "dà"),
    ("Small", "小", "xiǎo"),
    ("Fast", "快", "kuài"),
    ("Slow", "慢", "màn"),
    ("Good", "好", "hǎo"),
    ("Bad", "不好", "bù hǎo"),
    ("Open", "开", "kāi"),
    ("Closed", "关", "guān"),
    ("Here", "这里", "zhè lǐ"),
    ("There", "那里", "nà lǐ"),
    ("One", "一", "yī"),
    ("Two", "二", "èr"),
    ("Three", "三", "sān"),
    ("Four", "四", "sì"),
    ("Five", "五", "wǔ"),
    ("Ten", "十", "shí"),
    ("Time", "时间", "shí jiān"),
]

SPANISH_SUBJECTS = [
    ("I", "Yo", "yoh", "necesito", "quiero", "tengo", "hablo", "como", "leo", "voy", "compro", "espero", "escucho"),
    ("You", "Tú", "too", "necesitas", "quieres", "tienes", "hablas", "comes", "lees", "vas", "compras", "esperas", "escuchas"),
    ("We", "Nosotros", "noh-SOH-tros", "necesitamos", "queremos", "tenemos", "hablamos", "comemos", "leemos", "vamos", "compramos", "esperamos", "escuchamos"),
    ("They", "Ellos", "EH-yos", "necesitan", "quieren", "tienen", "hablan", "comen", "leen", "van", "compran", "esperan", "escuchan"),
    ("My friend", "Mi amigo", "mee ah-MEE-goh", "necesita", "quiere", "tiene", "habla", "come", "lee", "va", "compra", "espera", "escucha"),
    ("The teacher", "La maestra", "lah mah-ES-trah", "necesita", "quiere", "tiene", "habla", "come", "lee", "va", "compra", "espera", "escucha"),
    ("The family", "La familia", "lah fah-MEE-lyah", "necesita", "quiere", "tiene", "habla", "come", "lee", "va", "compra", "espera", "escucha"),
    ("The child", "El niño", "el NEE-nyoh", "necesita", "quiere", "tiene", "habla", "come", "lee", "va", "compra", "espera", "escucha"),
    ("The traveler", "El viajero", "el byah-HEH-roh", "necesita", "quiere", "tiene", "habla", "come", "lee", "va", "compra", "espera", "escucha"),
    ("The student", "La estudiante", "lah es-too-DYAN-teh", "necesita", "quiere", "tiene", "habla", "come", "lee", "va", "compra", "espera", "escucha"),
]

SPANISH_ACTIONS = [
    ("need water", "{need} agua", "{need} AH-gwah"),
    ("want coffee", "{want} café", "{want} kah-FEH"),
    ("have a question", "{have} una pregunta", "{have} OO-nah preh-GOON-tah"),
    ("speak Spanish", "{speak} español", "{speak} es-pah-NYOL"),
    ("eat rice", "{eat} arroz", "{eat} ah-ROS"),
    ("read a book", "{read} un libro", "{read} oon LEE-broh"),
    ("go to school", "{go} a la escuela", "{go} ah lah es-KWEH-lah"),
    ("buy bread", "{buy} pan", "{buy} pahn"),
    ("wait for the bus", "{wait} el autobús", "{wait} el ow-toh-BOOS"),
    ("listen to music", "{listen} música", "{listen} MOO-see-kah"),
]

MANDARIN_SUBJECTS = [
    ("I", "我", "wǒ"),
    ("You", "你", "nǐ"),
    ("We", "我们", "wǒ men"),
    ("They", "他们", "tā men"),
    ("My friend", "我的朋友", "wǒ de péng you"),
    ("The teacher", "老师", "lǎo shī"),
    ("The family", "家人", "jiā rén"),
    ("The child", "孩子", "hái zi"),
    ("The traveler", "旅客", "lǚ kè"),
    ("The student", "学生", "xué sheng"),
]

MANDARIN_ACTIONS = [
    ("need water", "需要水", "xū yào shuǐ"),
    ("want coffee", "想要咖啡", "xiǎng yào kā fēi"),
    ("have a question", "有一个问题", "yǒu yí ge wèn tí"),
    ("speak Chinese", "说中文", "shuō zhōng wén"),
    ("eat rice", "吃米饭", "chī mǐ fàn"),
    ("read a book", "读一本书", "dú yì běn shū"),
    ("go to school", "去学校", "qù xué xiào"),
    ("buy bread", "买面包", "mǎi miàn bāo"),
    ("wait for the bus", "等公交车", "děng gōng jiāo chē"),
    ("like music", "喜欢音乐", "xǐ huan yīn yuè"),
]

SPANISH_ROMAN_VERBS = {
    "necesito": "neh-seh-SEE-toh",
    "necesitas": "neh-seh-SEE-tahs",
    "necesitamos": "neh-seh-see-TAH-mos",
    "necesitan": "neh-seh-SEE-tahn",
    "necesita": "neh-seh-SEE-tah",
    "quiero": "KYEH-roh",
    "quieres": "KYEH-rehs",
    "queremos": "keh-REH-mos",
    "quieren": "KYEH-ren",
    "quiere": "KYEH-reh",
    "tengo": "TEN-goh",
    "tienes": "TYEH-nehs",
    "tenemos": "teh-NEH-mos",
    "tienen": "TYEH-nen",
    "tiene": "TYEH-neh",
    "hablo": "AH-bloh",
    "hablas": "AH-blahs",
    "hablamos": "ah-BLAH-mos",
    "hablan": "AH-blahn",
    "habla": "AH-blah",
    "como": "KOH-moh",
    "comes": "KOH-mehs",
    "comemos": "koh-MEH-mos",
    "comen": "KOH-men",
    "come": "KOH-meh",
    "leo": "LEH-oh",
    "lees": "LEH-ehs",
    "leemos": "leh-EH-mos",
    "leen": "LEH-en",
    "lee": "LEH-eh",
    "voy": "voy",
    "vas": "vahs",
    "vamos": "VAH-mos",
    "van": "vahn",
    "va": "vah",
    "compro": "KOHM-proh",
    "compras": "KOHM-prahs",
    "compramos": "kohm-PRAH-mos",
    "compran": "KOHM-prahn",
    "compra": "KOHM-prah",
    "espero": "es-PEH-roh",
    "esperas": "es-PEH-rahs",
    "esperamos": "es-peh-RAH-mos",
    "esperan": "es-PEH-rahn",
    "espera": "es-PEH-rah",
    "escucho": "es-KOO-choh",
    "escuchas": "es-KOO-chahs",
    "escuchamos": "es-koo-CHAH-mos",
    "escuchan": "es-KOO-chahn",
    "escucha": "es-KOO-chah",
}


def make_cards(lang_id, kind, entries, english_pool):
    cards = []
    for idx, (english, target, romanization) in enumerate(entries, start=1):
        distractors = [value for offset in (7, 19, 31) for value in [english_pool[(idx - 1 + offset) % len(english_pool)]]]
        if kind == "word":
            tip = f"Say it as {romanization}. Keep the final sound light."
        else:
            tip = f"Practice the rhythm: {romanization}."
        cards.append(
            {
                "id": f"{lang_id}-{kind}-{idx:03d}",
                "kind": kind,
                "english": english,
                "target": target,
                "romanization": romanization,
                "pronunciationTip": tip,
                "distractors": distractors,
            }
        )
    return cards


def spanish_sentences():
    rows = []
    for subject in SPANISH_SUBJECTS:
        english_subject, target_subject, roman_subject = subject[:3]
        forms = {
            "need": subject[3],
            "want": subject[4],
            "have": subject[5],
            "speak": subject[6],
            "eat": subject[7],
            "read": subject[8],
            "go": subject[9],
            "buy": subject[10],
            "wait": subject[11],
            "listen": subject[12],
        }
        for english_action, target_template, roman_template in SPANISH_ACTIONS:
            target = target_template.format(**forms)
            roman_forms = {key: SPANISH_ROMAN_VERBS[value] for key, value in forms.items()}
            roman = roman_template.format(**roman_forms)
            rows.append((f"{english_subject} {english_action}", f"{target_subject} {target}", f"{roman_subject} {roman}"))
    return rows


def mandarin_sentences():
    rows = []
    for english_subject, target_subject, roman_subject in MANDARIN_SUBJECTS:
        for english_action, target_action, roman_action in MANDARIN_ACTIONS:
            rows.append((f"{english_subject} {english_action}", f"{target_subject}{target_action}", f"{roman_subject} {roman_action}"))
    return rows


def build():
    assert len(SPANISH_WORDS) == 100
    assert len(MANDARIN_WORDS) == 100
    spanish_sentence_rows = spanish_sentences()
    mandarin_sentence_rows = mandarin_sentences()
    assert len(spanish_sentence_rows) == 100
    assert len(mandarin_sentence_rows) == 100

    spanish_pool = [english for english, _, _ in SPANISH_WORDS + spanish_sentence_rows]
    mandarin_pool = [english for english, _, _ in MANDARIN_WORDS + mandarin_sentence_rows]

    packs = [
        {
            "id": "spanish",
            "title": "Spanish",
            "nativeTitle": "Español",
            "subtitle": "100 words + 100 sentences",
            "languageCode": "es-ES",
            "words": make_cards("spanish", "word", SPANISH_WORDS, spanish_pool),
            "sentences": make_cards("spanish", "sentence", spanish_sentence_rows, spanish_pool),
        },
        {
            "id": "mandarin",
            "title": "Mandarin",
            "nativeTitle": "中文",
            "subtitle": "100 words + 100 sentences",
            "languageCode": "zh-CN",
            "words": make_cards("mandarin", "word", MANDARIN_WORDS, mandarin_pool),
            "sentences": make_cards("mandarin", "sentence", mandarin_sentence_rows, mandarin_pool),
        },
    ]
    TARGET.write_text(json.dumps(packs, ensure_ascii=False, indent=2) + "\n")
    print(f"wrote {TARGET}")


if __name__ == "__main__":
    build()
