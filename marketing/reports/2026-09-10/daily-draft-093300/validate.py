"""Read-only verification of this immutable daily report and its saved evidence."""
import csv, json, pathlib, hashlib
from html.parser import HTMLParser
from urllib.parse import unquote,urlsplit
base=pathlib.Path(__file__).resolve().parent
run=base.name
report=json.loads((base.parent/(run+'.json')).read_text())
rows=list(csv.DictReader((base/'calendar-after.csv').open()))
old={r['content_id']:r for r in csv.DictReader((base/'calendar-before.csv').open())}
assert len(rows)==len(report['posts'])==12
assert all(r['status']=='draft' and not any(r[k] for k in ('scheduled_at','published_at','publish_ref')) for r in rows)
assert [r['copy'] for r in rows]==[r['copy'] for r in report['posts']]
changed={r['content_id'] for r in rows if r['copy']!=old[r['content_id']]['copy']}
assert changed=={'GL-P007','GL-P008'}
for a in report['content_actions']:
 body=(base.parent/a['patina']['final']).read_text().strip()
 assert body==a['after']['copy'] and hashlib.sha256(body.encode()).hexdigest()==a['saved_body_readback']['sha256']
 assert 'MPS 100, fidelity 100 (passed)' in (base.parent/a['patina']['log']).read_text()
assert all(v is None for p in report['posts'] for v in p['metrics'].values())
assert all(report['costs_and_sends'][k]==0 for k in ['paid_actions','external_messages','published_posts','scheduled_posts','rescheduled_posts','external_composer_uploads'])
queue=report['local_seven_day_queue']['items']
assert all(sum(q['platform']==ch for q in queue)==3 for ch in ['instagram','threads'])
assert all(q['scheduled_at'] is None for q in queue)
mail=json.loads((base/'gmail-union-redacted.json').read_text())
assert len({x['threadId'] for x in mail['unique_threads']})==5 and len(mail['new_ids'])==1
body=json.loads(json.loads((base/'report-body-readback.json').read_text())['result']['result'])
assert all(p['copy'] in body['pre'] for p in report['posts'])
class Links(HTMLParser):
 def __init__(self):super().__init__();self.hrefs=[]
 def handle_starttag(self,tag,attrs):
  if tag=='a':self.hrefs.extend(v for k,v in attrs if k=='href')
h=Links();h.feed((base.parent/(run+'.html')).read_text())
missing=[u for u in h.hrefs if not urlsplit(u).scheme and not (base.parent/unquote(urlsplit(u).path)).exists()]
assert not missing,missing
print(f'PASS: {run}; 12 local drafts, 2 Patina/readback matches, 10 preserved, 6 local preparation slots, {len(h.hrefs)} links, no external writes.')
