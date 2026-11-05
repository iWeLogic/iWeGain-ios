#!/usr/bin/env python3
"""Copies strings (with all their translations) from the Android app into the iOS String Catalog.

Usage, from the repo root:
    python3 ios/scripts/import_android_strings.py tab_home tab_settings error_unknown=team_error_unknown
    python3 ios/scripts/import_android_strings.py --watch next_set set_of

--watch copies from the Wear OS app into the Apple Watch app's catalog.

Each argument is an Android string name, or `plurals:<name>` for a <plurals>; `ios_key=android_key` stores it
under another key (a plurals needs one: `training_exercise_count=plurals:training_exercises`).
Existing catalog entries with the same key are replaced, everything else in the catalog is kept.
Android placeholders become iOS ones (%1$s → %1$@, %1$d → %1$lld) and <plurals> become plural variations.
Strings that exist only on iOS are added to the catalog by hand (in Xcode or in the JSON).
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ANDROID_RES = ROOT / "android/app/src/main/res"
CATALOG = ROOT / "ios/iWeGain/Resources/Localizable.xcstrings"

# Android resource folder suffix → iOS language code.
LANGUAGES = {
    "": "en", "de": "de", "es": "es", "fr": "fr", "in": "id", "it": "it", "ja": "ja", "ko": "ko",
    "nl": "nl", "pl": "pl", "pt-rBR": "pt-BR", "ru": "ru", "tr": "tr", "uk": "uk", "zh-rCN": "zh-Hans",
}


def convert(text: str) -> str:
    """Android string resource text → iOS format string."""
    text = text.strip()
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        text = text[1:-1]
    text = text.replace("\\'", "'").replace('\\"', '"').replace("\\n", "\n").replace("\\@", "@").replace("\\?", "?")
    text = re.sub(r"%(\d+\$)?s", lambda m: f"%{m.group(1) or ''}@", text)
    text = re.sub(r"%(\d+\$)?d", lambda m: f"%{m.group(1) or ''}lld", text)
    return text


def element_text(element: ET.Element) -> str:
    # Keeps inline markup such as <xliff:g> as plain text.
    return "".join(element.itertext())


def load(folder_suffix: str) -> dict:
    folder = ANDROID_RES / ("values" if not folder_suffix else f"values-{folder_suffix}")
    strings = {}
    elements = [element for file in sorted(folder.glob("*.xml")) for element in ET.parse(file).getroot()]
    for element in elements:
        name = element.get("name")
        if element.tag not in ("string", "plurals"):
            continue
        if element.get("translatable") == "false" and folder_suffix:
            continue
        if element.tag == "string":
            strings[name] = convert(element_text(element))
        elif element.tag == "plurals":
            # Android lets a plurals share its name with a string; plurals are named "plurals:<name>" here.
            strings[f"plurals:{name}"] = {item.get("quantity"): convert(element_text(item)) for item in element.findall("item")}
    return strings


def localization(value) -> dict:
    if isinstance(value, str):
        return {"stringUnit": {"state": "translated", "value": value}}
    return {"variations": {"plural": {q: {"stringUnit": {"state": "translated", "value": v}} for q, v in value.items()}}}


def main(arguments: list[str]) -> None:
    global ANDROID_RES, CATALOG
    if arguments[:1] == ["--watch"]:
        arguments = arguments[1:]
        ANDROID_RES = ROOT / "android/wear/src/main/res"
        CATALOG = ROOT / "ios/iWeGainWatch/Resources/Localizable.xcstrings"
    if not arguments:
        sys.exit(__doc__)
    sources = {language: load(suffix) for suffix, language in LANGUAGES.items()}
    catalog = json.loads(CATALOG.read_text()) if CATALOG.exists() else {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
    for argument in arguments:
        ios_key, _, android_key = argument.partition("=")
        android_key = android_key or ios_key
        if android_key not in sources["en"]:
            sys.exit(f"No Android string named {android_key}")
        localizations = {
            language: localization(strings[android_key])
            for language, strings in sources.items()
            if android_key in strings
        }
        catalog["strings"][ios_key] = {"extractionState": "manual", "localizations": localizations}
    catalog["strings"] = dict(sorted(catalog["strings"].items()))
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, separators=(",", " : ")) + "\n")
    print(f"Imported {len(arguments)} strings into {CATALOG.relative_to(ROOT)}")


if __name__ == "__main__":
    main(sys.argv[1:])
