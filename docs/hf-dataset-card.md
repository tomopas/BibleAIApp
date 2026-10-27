---
license: cc-by-4.0
language:
  - en
pretty_name: Bible AI — King James Version Audio
tags:
  - audio
  - text-to-speech
  - bible
  - kjv
  - kokoro
task_categories:
  - text-to-speech
size_categories:
  - 1K<n<10K
---

# Bible AI — King James Version Audio

Chapter-by-chapter narration of the complete King James Version (KJV) Bible,
generated locally with [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M).

| | |
|---|---|
| Files | 1,189 MP3s (66 books, one file per chapter) |
| Size | About 2.14 GB |
| Format | MP3, 24 kHz mono, about 64 kbps |
| Voice | `af_heart` (American English) |
| TTS model | `hexgrad/Kokoro-82M` (Apache-2.0) |
| Source text | King James Version (public domain in the United States) |
| Generated | 2026-10-26 (UTC) |
| Companion code | [tomopas/BibleAIApp](https://github.com/tomopas/BibleAIApp) |

## Layout

```text
audio/en-kjv/{book}/{chapter}.mp3
```

`book` is a lowercase three-letter book code, and `chapter` is the chapter
number without leading zeros. For example:

```text
audio/en-kjv/gen/1.mp3
audio/en-kjv/psa/119.mp3
audio/en-kjv/jhn/3.mp3
```

`audio/en-kjv/kokoro-progress.json` records generation metadata, including the
model, voice, and per-chapter completion times.

<details>
<summary>Book codes</summary>

| Code | Book |
|---|---|
| `gen` | Genesis |
| `exo` | Exodus |
| `lev` | Leviticus |
| `num` | Numbers |
| `deu` | Deuteronomy |
| `jos` | Joshua |
| `jdg` | Judges |
| `rut` | Ruth |
| `1sa` | 1 Samuel |
| `2sa` | 2 Samuel |
| `1ki` | 1 Kings |
| `2ki` | 2 Kings |
| `1ch` | 1 Chronicles |
| `2ch` | 2 Chronicles |
| `ezr` | Ezra |
| `neh` | Nehemiah |
| `est` | Esther |
| `job` | Job |
| `psa` | Psalms |
| `pro` | Proverbs |
| `ecc` | Ecclesiastes |
| `sng` | Song of Songs |
| `isa` | Isaiah |
| `jer` | Jeremiah |
| `lam` | Lamentations |
| `eze` | Ezekiel |
| `dan` | Daniel |
| `hos` | Hosea |
| `joe` | Joel |
| `amo` | Amos |
| `oba` | Obadiah |
| `jon` | Jonah |
| `mic` | Micah |
| `nah` | Nahum |
| `hab` | Habakkuk |
| `zep` | Zephaniah |
| `hag` | Haggai |
| `zec` | Zechariah |
| `mal` | Malachi |
| `mat` | Matthew |
| `mrk` | Mark |
| `luk` | Luke |
| `jhn` | John |
| `act` | Acts |
| `rom` | Romans |
| `1co` | 1 Corinthians |
| `2co` | 2 Corinthians |
| `gal` | Galatians |
| `eph` | Ephesians |
| `php` | Philippians |
| `col` | Colossians |
| `1th` | 1 Thessalonians |
| `2th` | 2 Thessalonians |
| `1ti` | 1 Timothy |
| `2ti` | 2 Timothy |
| `tit` | Titus |
| `phm` | Philemon |
| `heb` | Hebrews |
| `jas` | James |
| `1pe` | 1 Peter |
| `2pe` | 2 Peter |
| `1jn` | 1 John |
| `2jn` | 2 John |
| `3jn` | 3 John |
| `jud` | Jude |
| `rev` | Revelation |

</details>

## Usage

Download one chapter:

```python
from huggingface_hub import hf_hub_download

path = hf_hub_download(
    repo_id="Tomopas/bibleai-audio",
    filename="audio/en-kjv/gen/1.mp3",
    repo_type="dataset",
)
```

Download the whole dataset:

```bash
hf download Tomopas/bibleai-audio --repo-type dataset --local-dir bibleai-audio
```

## Checksums

`audio-manifest.sha256` lists the SHA-256 of every MP3 using the same paths as
the dataset. From the dataset root, verify a download with:

```bash
sha256sum -c audio-manifest.sha256
```

## Generation

Audio was generated from the KJV text with Kokoro's local TTS pipeline, one MP3
per chapter, and encoded with ffmpeg. No hosted TTS provider or web research
was used. The reproducible command in the companion repository is:

```bash
python worker/generate_kokoro_audio.py --run --translation en-kjv --yes
```

## License and attribution

- The generated narration is released under
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See
  `DATA_LICENSE.md`.
- The KJV source text is public domain in the United States. It is subject to
  perpetual Crown copyright in the United Kingdom; check the law in your
  jurisdiction.
- Kokoro-82M is licensed under Apache-2.0. Model licenses do not automatically
  determine ownership of generated output.

Suggested attribution:

> Bible AI generated KJV narration, generated with Kokoro-82M voice `af_heart`.
> CC BY 4.0.

## Limitations

- Single voice, read in chapter order. There is no verse-level alignment or
  timestamp metadata.
- TTS may mispronounce names, numbers, and archaic terms.
- This is a generated reading aid, not a critical edition or a substitute for a
  verified Bible text. It is not affiliated with or endorsed by any church or
  Bible publisher.
