import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

const script = new URL('./seed-city-posts.sh', import.meta.url).pathname;

function dryRun(posts, extraEnv = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'gling-city-posts-'));
  const file = join(dir, 'posts.json');
  writeFileSync(file, JSON.stringify({ posts }));
  return execFileSync(script, ['2026-09-22'], {
    env: { ...process.env, POSTS_FILE: file, DRY_RUN: '1', ...extraEnv },
    encoding: 'utf8',
  });
}

test('도시 게시글 SQL은 원고를 그대로 싣고 프로필·시각·조회수 규칙을 포함한다', () => {
  const sql = dryRun([
    { ord: 1, city_id: 'vancouver', author_nickname: '새벽마켓', tag_slug: 'life', title: '테스트 글 하나', body: '첫 줄\n둘째 줄', source: 'https://example.com/a' },
    { ord: 2, city_id: 'montreal', author_nickname: '불어책갈피', tag_slug: 'transport', title: '테스트 글 둘', body: '내용', source: 'https://example.com/b' },
  ]);

  // 원고가 그대로 들어가야 한다. 따옴표 이스케이프는 JSON 달러 인용으로 처리한다.
  assert.ok(sql.includes('테스트 글 하나'));
  assert.ok(sql.includes('첫 줄\\n둘째 줄'));
  assert.match(sql, /from jsonb_to_recordset\(/);
  assert.match(sql, /\$GLING\$\[/);

  // 도시별 기존 프로필을 재사용하고 새 프로필을 만들지 않는다.
  assert.match(sql, /from public\.profiles pr/);
  assert.match(sql, /raise exception 'SEED_AUTHOR_NOT_FOUND'/);
  assert.doesNotMatch(sql, /offset slot\.slot/);
  assert.doesNotMatch(sql, /insert into public\.profiles/);

  // 실제 계정(운영자·테스터)에는 대신 쓰지 않는다. 시드 계정만 쓴다.
  assert.match(sql, /join auth\.users u on u\.id = pr\.id/);
  assert.match(sql, /and u\.email like '%@seed\.gling\.invalid'/);
  assert.match(sql, /pr\.nickname = slot\.author_nickname/);
  assert.doesNotMatch(sql, /오 이거 궁금했는데|맞아 나도 그랬음/);
  assert.doesNotMatch(sql, /insert into public\.comments/);

  // 재실행 안전, 시각 흩뜨림, 조회 기록.
  assert.match(sql, /where not exists \(\n  select 1 from public\.posts existing/);
  // 작성자 성향(아침·점심·저녁·밤)에 맞춰 시각을 잡고, 아직 안 온 시간대면 어제로 보낸다.
  assert.match(sql, /hashtext\(a\.author_id::text \|\| '-w'\)::bigint\) % 4\)/);
  assert.match(sql, /interval '1 day' end\) at time zone city\.timezone/);
  assert.match(sql, /posted_on = \(post\.created_at at time zone city\.timezone\)::date/);
  assert.match(sql, /private\.post_view_pulse/);
  assert.match(sql, /join public\.tags tag on tag\.slug = seed\.tag_slug/);
});

test('원고 파일이 없으면 아무것도 하지 않고 정상 종료한다', () => {
  const out = execFileSync(script, ['1999-01-01'], {
    env: { ...process.env, POSTS_FILE: '/nonexistent/posts.json', DRY_RUN: '1' },
    encoding: 'utf8',
  });
  assert.match(out, /SKIP/);
  assert.doesNotMatch(out, /jsonb_to_recordset/);
});

test('조회수는 0에서 시작하고 GROW=1일 때만 나이 기준으로 오르며 당일도 반영된다', () => {
  const posts = [
    { ord: 1, city_id: 'calgary', author_nickname: '17에비뉴커피', tag_slug: 'life', title: '테스트 글', body: '내용', source: 'https://example.com/c' },
  ];

  // 새 글은 조회수 0으로 들어간다.
  assert.match(dryRun(posts), /'published',\n       0,/);
  assert.doesNotMatch(dryRun(posts), /generate_series/);

  const grown = dryRun(posts, { GROW: '1' });
  // 1~14일차 하루 1~30, 15~30일차 하루 1~8, 30일에서 멈춤.
  assert.match(grown, /case when day\.i <= 13 then 30 else 8 end/);
  assert.match(grown, /least\(30, base\.elapsed\)/);
  // 올린 당일은 경과 시간 비율로 반영한다.
  assert.match(grown, /base\.age_seconds - least\(30, base\.elapsed\) \* 86400/);
  // 나이로 목표값을 계산하므로 재실행해도 같은 값이 된다.
  assert.match(grown, /where post\.id = target\.id and post\.view_count < target\.views/);
  assert.match(grown, /update private\.post_view_pulse pulse/);
});

test('작성자를 고르지 않은 원고는 등록하지 않는다', () => {
  assert.throws(() => dryRun([
    { ord: 1, city_id: 'vancouver', tag_slug: 'life', title: '누가 썼지', body: '내용' },
  ]), /author_nickname/);
});

test('실제 HTTP 전송 JSON에서도 긴 한글 원고와 유니코드를 손상 없이 보존한다', () => {
  const dir = mkdtempSync(join(tmpdir(), 'gling-city-transport-'));
  const day = `transport-test-${process.pid}`;
  const file = join(dir, 'posts.json');
  const capture = join(dir, 'request.json');
  const bashEnv = join(dir, 'bash-env');
  const posts = [{
    ord: 1, city_id: 'toronto', author_nickname: '서비스온타리오', tag_slug: 'life',
    title: '한글·Montréal·☕ 원고', body: '가나다라마바사 Montréal ☕ "인용"\n'.repeat(1200),
    source: 'https://example.com/transport',
  }];
  writeFileSync(file, JSON.stringify({ posts }));
  // 실제 직렬화는 실행하고 키체인·외부 HTTP 경계만 차단한다.
  writeFileSync(bashEnv, 'security() { printf fixture-token; }\ncurl() { cat > "$CAPTURE_FILE"; printf "[]\\n"; }\n');
  try {
    execFileSync(script, [day], {
      env: { ...process.env, POSTS_FILE: file, DRY_RUN: '0', GROW: '0', BASH_ENV: bashEnv, CAPTURE_FILE: capture },
      encoding: 'utf8',
    });
    const { query } = JSON.parse(readFileSync(capture, 'utf8'));
    const payload = query.split('$GLING$')[1];
    assert.deepEqual(JSON.parse(payload), posts);
  } finally {
    rmSync(dir, { recursive: true, force: true });
    rmSync(join(homedir(), 'Library/Application Support/gling/city-posts', `${day}.log`), { force: true });
  }
});
