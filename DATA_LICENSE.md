# Generated interpretation and audio data

This file applies to published exports of generated interpretations and
chapter audio, not to the application source code. The source code is licensed
under Apache-2.0 in `LICENSE`.

## Intended data license

The generated interpretation text and generated audio are intended to be
released under **CC BY 4.0**:

<https://creativecommons.org/licenses/by/4.0/>

When redistributing the data, credit:

> BibleAIApp generated study data, generated with the model and prompt metadata
> included in each record or release manifest.

Do not claim that this license grants rights to third-party source material.
The license applies only to portions that can legally be licensed by the
publisher.

## Required release metadata

Every dataset or audio release should include:

- source translation and its license;
- model name and exact tag or revision;
- Kokoro model, voice, and dependency licenses for audio;
- prompt version and generation date;
- whether web research was enabled;
- source URLs or research policy, where applicable;
- checksums for audio files;
- a clear statement of any excluded or restricted records.

## Important limitations

KJV is public domain in the United States, but other translations may not be.
Model licenses cover model use and do not automatically determine ownership of
generated output. Research snippets and linked pages remain subject to their
original terms. Review the exact translation, model, voice, and source terms
before publishing each release.

Do not publish MongoDB credentials, `deploy/.env`, private sync records, user
notes, or unreviewed personal data.
