"""Canonical book metadata shared by the build tools.

The app and the server both speak the same compact "translation bundle" format:

{
  "id": "en-kjv", "name": "...", "abbreviation": "KJV",
  "language": "English", "languageCode": "en",
  "license": "Public Domain", "source": "...",
  "books": [
    {"id": "gen", "name": "Genesis", "abbreviation": "Gen",
     "testament": "OT", "order": 1,
     "chapters": [["verse one", "verse two"], ["..."]]
    }
  ]
}

`chapters` is a list of chapters, each a list of verse strings (verse 1 first).
"""

BOOKS = [
    # id, display name, abbreviation, testament, scrollmapper name, wldeh slug, chapter count
    ("gen", "Genesis", "Gen", "OT", "Genesis", "genesis", 50),
    ("exo", "Exodus", "Exo", "OT", "Exodus", "exodus", 40),
    ("lev", "Leviticus", "Lev", "OT", "Leviticus", "leviticus", 27),
    ("num", "Numbers", "Num", "OT", "Numbers", "numbers", 36),
    ("deu", "Deuteronomy", "Deut", "OT", "Deuteronomy", "deuteronomy", 34),
    ("jos", "Joshua", "Josh", "OT", "Joshua", "joshua", 24),
    ("jdg", "Judges", "Judg", "OT", "Judges", "judges", 21),
    ("rut", "Ruth", "Ruth", "OT", "Ruth", "ruth", 4),
    ("1sa", "1 Samuel", "1Sam", "OT", "I Samuel", "1samuel", 31),
    ("2sa", "2 Samuel", "2Sam", "OT", "II Samuel", "2samuel", 24),
    ("1ki", "1 Kings", "1Kgs", "OT", "I Kings", "1kings", 22),
    ("2ki", "2 Kings", "2Kgs", "OT", "II Kings", "2kings", 25),
    ("1ch", "1 Chronicles", "1Chr", "OT", "I Chronicles", "1chronicles", 29),
    ("2ch", "2 Chronicles", "2Chr", "OT", "II Chronicles", "2chronicles", 36),
    ("ezr", "Ezra", "Ezra", "OT", "Ezra", "ezra", 10),
    ("neh", "Nehemiah", "Neh", "OT", "Nehemiah", "nehemiah", 13),
    ("est", "Esther", "Esth", "OT", "Esther", "esther", 10),
    ("job", "Job", "Job", "OT", "Job", "job", 42),
    ("psa", "Psalms", "Ps", "OT", "Psalms", "psalms", 150),
    ("pro", "Proverbs", "Prov", "OT", "Proverbs", "proverbs", 31),
    ("ecc", "Ecclesiastes", "Eccl", "OT", "Ecclesiastes", "ecclesiastes", 12),
    ("sng", "Song of Songs", "Song", "OT", "Song of Solomon", "songofsolomon", 8),
    ("isa", "Isaiah", "Isa", "OT", "Isaiah", "isaiah", 66),
    ("jer", "Jeremiah", "Jer", "OT", "Jeremiah", "jeremiah", 52),
    ("lam", "Lamentations", "Lam", "OT", "Lamentations", "lamentations", 5),
    ("eze", "Ezekiel", "Ezek", "OT", "Ezekiel", "ezekiel", 48),
    ("dan", "Daniel", "Dan", "OT", "Daniel", "daniel", 12),
    ("hos", "Hosea", "Hos", "OT", "Hosea", "hosea", 14),
    ("joe", "Joel", "Joel", "OT", "Joel", "joel", 3),
    ("amo", "Amos", "Amos", "OT", "Amos", "amos", 9),
    ("oba", "Obadiah", "Obad", "OT", "Obadiah", "obadiah", 1),
    ("jon", "Jonah", "Jonah", "OT", "Jonah", "jonah", 4),
    ("mic", "Micah", "Mic", "OT", "Micah", "micah", 7),
    ("nah", "Nahum", "Nah", "OT", "Nahum", "nahum", 3),
    ("hab", "Habakkuk", "Hab", "OT", "Habakkuk", "habakkuk", 3),
    ("zep", "Zephaniah", "Zeph", "OT", "Zephaniah", "zephaniah", 3),
    ("hag", "Haggai", "Hag", "OT", "Haggai", "haggai", 2),
    ("zec", "Zechariah", "Zech", "OT", "Zechariah", "zechariah", 14),
    ("mal", "Malachi", "Mal", "OT", "Malachi", "malachi", 4),
    ("mat", "Matthew", "Matt", "NT", "Matthew", "matthew", 28),
    ("mrk", "Mark", "Mark", "NT", "Mark", "mark", 16),
    ("luk", "Luke", "Luke", "NT", "Luke", "luke", 24),
    ("jhn", "John", "John", "NT", "John", "john", 21),
    ("act", "Acts", "Acts", "NT", "Acts", "acts", 28),
    ("rom", "Romans", "Rom", "NT", "Romans", "romans", 16),
    ("1co", "1 Corinthians", "1Cor", "NT", "I Corinthians", "1corinthians", 16),
    ("2co", "2 Corinthians", "2Cor", "NT", "II Corinthians", "2corinthians", 13),
    ("gal", "Galatians", "Gal", "NT", "Galatians", "galatians", 6),
    ("eph", "Ephesians", "Eph", "NT", "Ephesians", "ephesians", 6),
    ("php", "Philippians", "Phil", "NT", "Philippians", "philippians", 4),
    ("col", "Colossians", "Col", "NT", "Colossians", "colossians", 4),
    ("1th", "1 Thessalonians", "1Thess", "NT", "I Thessalonians", "1thessalonians", 5),
    ("2th", "2 Thessalonians", "2Thess", "NT", "II Thessalonians", "2thessalonians", 3),
    ("1ti", "1 Timothy", "1Tim", "NT", "I Timothy", "1timothy", 6),
    ("2ti", "2 Timothy", "2Tim", "NT", "II Timothy", "2timothy", 4),
    ("tit", "Titus", "Titus", "NT", "Titus", "titus", 3),
    ("phm", "Philemon", "Phlm", "NT", "Philemon", "philemon", 1),
    ("heb", "Hebrews", "Heb", "NT", "Hebrews", "hebrews", 13),
    ("jas", "James", "Jas", "NT", "James", "james", 5),
    ("1pe", "1 Peter", "1Pet", "NT", "I Peter", "1peter", 5),
    ("2pe", "2 Peter", "2Pet", "NT", "II Peter", "2peter", 3),
    ("1jn", "1 John", "1John", "NT", "I John", "1john", 5),
    ("2jn", "2 John", "2John", "NT", "II John", "2john", 1),
    ("3jn", "3 John", "3John", "NT", "III John", "3john", 1),
    ("jud", "Jude", "Jude", "NT", "Jude", "jude", 1),
    ("rev", "Revelation", "Rev", "NT", "Revelation of John", "revelation", 22),
    # Deuterocanonical / additional books (used by Catholic and Orthodox Bibles)
    ("tob", "Tobit", "Tob", "DC", "Tobit", "tobit", 14),
    ("jdt", "Judith", "Jdt", "DC", "Judith", "judith", 16),
    ("wis", "Wisdom", "Wis", "DC", "Wisdom", "wisdom", 19),
    ("sir", "Sirach", "Sir", "DC", "Sirach", "ecclesiasticus", 51),
    ("bar", "Baruch", "Bar", "DC", "Baruch", "baruch", 6),
    ("1ma", "1 Maccabees", "1Macc", "DC", "I Maccabees", "1maccabees", 16),
    ("2ma", "2 Maccabees", "2Macc", "DC", "II Maccabees", "2maccabees", 15),
    ("1es", "1 Esdras", "1Esd", "DC", "I Esdras", "1esdras", 9),
    ("2es", "2 Esdras", "2Esd", "DC", "II Esdras", "2esdras", 16),
    ("man", "Prayer of Manasseh", "Man", "DC", "Prayer of Manasses", "manasseh", 1),
    ("addest", "Additions to Esther", "AddEsth", "DC", "Additions to Esther", "esther(greek)", 16),
    ("sus", "Susanna", "Sus", "DC", "Susanna", "susanna", 1),
    ("bel", "Bel and the Dragon", "Bel", "DC", "Bel and the Dragon", "belandthedragon", 1),
    ("s3y", "Song of the Three", "S3Y", "DC", "Song of the Three Children", "songofthethree", 1),
]

BY_ID = {b[0]: b for b in BOOKS}
BY_SCROLLMAPPER = {b[4]: b for b in BOOKS}
BY_WLDEH = {b[5]: b for b in BOOKS}

PROTESTANT = [b for b in BOOKS if b[3] in ("OT", "NT")]
CATHOLIC = [b for b in BOOKS if b[0] not in ("1es", "2es", "man", "addest", "sus", "bel", "s3y")]
ALL = BOOKS


def book_meta(book, order):
    return {
        "id": book[0],
        "name": book[1],
        "abbreviation": book[2],
        "testament": book[3],
        "order": order,
    }
