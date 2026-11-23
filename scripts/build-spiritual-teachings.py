"""Build original teaching lessons with checked KJV reference ranges."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
rows = (ROOT / 'source/spiritual-teachings.txt').read_text().splitlines()
assert len(rows) == 13, 'Expected thirteen complete lessons'
lessons = []
for number, row in enumerate(rows):
    title, subtitle, refs, body, boundary, question, action, prayer, memory = row.split('|')
    references = json.loads(refs)
    paragraphs = body.split('~')
    assert len(paragraphs) == 4 and len(body.split()) >= 300, title
    assert all(x.strip() for x in [title, subtitle, *paragraphs, boundary, question, action, prayer, memory])
    for book, chapter, start, end in references:
        data = json.loads((ROOT / f'public/data/{book:02}.json').read_text())
        assert 1 <= start <= end <= len(data['chapters'][chapter - 1]['verses']), (title, book, chapter, start, end)
    lessons.append(dict(id=96000 + number, kind='teaching', title=title, subtitle=subtitle,
                        references=references, story=paragraphs, boundary=boundary,
                        questions=[question, 'Which statement in this lesson is directly supported by the reading? Cite the verse and explain its context.', 'What practical response will you make, and when will you review it?'],
                        action=action, prayer=prayer, memory=memory))
lessons[-1]['comparison'] = json.loads((ROOT / 'source/spiritual-claims.json').read_text())
(ROOT / 'public/spiritual-teachings.js').write_text('/* Original teaching. Built by scripts/build-spiritual-teachings.py. */\nconst spiritualTeachings = ' + json.dumps(lessons, ensure_ascii=False) + ';\n')
print(f'{len(lessons)} original lessons, {sum(len(l["story"]) for l in lessons)} complete teaching sections')
