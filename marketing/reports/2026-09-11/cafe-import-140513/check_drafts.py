import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent
posts = json.loads((root / 'app-drafts.json').read_text())
receipt = json.loads((root / 'crawl4ai-receipt.json').read_text())
assert len(posts) == receipt['sources_processed'] == 3
assert all(n > 0 for n in receipt['paragraph_counts'])
assert len({p['assigned_profile_id'] for p in posts}) == 3
for p in posts:
    saved = (root / (p['content_id'].lower() + '.txt')).read_text()
    assert saved == p['title'] + '\n\n' + p['body'] + '\n'
    assert hashlib.sha256(p['body'].encode()).hexdigest() == p['body_sha256']
    assert p['app_post_id'] is None and p['published_at'] is None
    assert p['photos'] == [] and p['visit_claim'] is False
    assert p['security_role_change'] is False
assert root.joinpath('calendar-before.csv').read_bytes() == root.parents[2].joinpath('social-calendar.csv').read_bytes()
print('PASS: 3 sourced drafts, saved bodies, profiles, no app writes/photos; SNS CSV unchanged')
