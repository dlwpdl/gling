"""Read-only check of this immutable run and its local calendar readback."""
import csv
import hashlib
import json
import pathlib
from html.parser import HTMLParser
from urllib.parse import urlsplit

d = pathlib.Path(__file__).resolve().parent
load = lambda n: json.loads((d / (n + '.json')).read_text())
r = load('report-working')
before = list(csv.DictReader((d / 'calendar-before.csv').open(encoding='utf-8-sig')))
after = list(csv.DictReader((d / 'calendar-after.csv').open(encoding='utf-8-sig')))
assert len(before) == len(after) == len(r['posts']) == 12
assert sum(a['copy'] != b['copy'] for a, b in zip(before, after)) == 7
assert sum(bool(p['link']) for p in before) == 7
assert all(not p['link'] and p['link_placement'] == 'none' for p in after)
assert all(p['status'] == 'draft' and not p['scheduled_at'] and not p['published_at'] for p in after)
assert r['inbox_checks'] == r['metric_observations'] == []
assert all(v is None for p in r['posts'] for v in p['metrics'].values())
assert r['costs_and_sends'] == dict(paid_actions=0, external_sns_writes=0, replies_sent=0, app_posts_created=0)
assert len(r['local_seven_day_queue']['items']) == 6
for a in r['content_actions']:
    assert a['saved_body_readback'] and a['after']['copy'] == next(p['copy'] for p in after if p['content_id'] == a['content_id'])
    if a['patina']:
        p = a['patina']
        body = (d.parent / p['body']).read_text().rstrip('\n')
        assert body == a['after']['copy']
        assert hashlib.sha256(body.encode()).hexdigest() == p['body_sha256']
        assert '(passed)' in (d.parent / p['log']).read_text()
pilot = r['article_pilot']
assert pilot['app_url'] is None and pilot['app_post_id'] is None
assert (d.parent / pilot['patina']['body']).read_text().rstrip('\n') == pilot['sns_copy']

class Links(HTMLParser):
    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            href = dict(attrs).get('href', '')
            if href and not urlsplit(href).scheme and not href.startswith('#'):
                assert (d.parent / href).exists(), href

Links().feed((d / 'report-working.html').read_text())
dom = load('report-dom-readback')
assert dom['post_bodies'] == {p['content_id']: p['copy'] for p in after}
assert dom['pilot_sns'] == pilot['sns_copy']
assert dom['article_body'] == pilot['article_body']
print('PASS: 12 drafts, 7 copy changes, 8 Patina readbacks, no SNS links/writes; HTML bodies and local links match')
