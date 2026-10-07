#!/bin/bash
# 도시 게시글 자동 등록. content/<날짜>/posts.json 을 읽어 운영 DB에 넣는다.
#
# 원고는 사람이나 에이전트가 미리 쓴다. 이 스크립트는 넣는 일만 한다.
#   - 원고에서 먼저 지정한 도시별 기존 프로필을 재사용한다 (새 프로필을 만들지 않는다)
#   - 시드 계정만 쓴다. 운영자·테스터 같은 실제 계정에는 대신 쓰지 않는다
#   - 프로필 도시와 글 도시를 섞지 않는다
#   - 등록 시각을 지금으로부터 25~275분 전 사이로 흩뜨린다
#   - 조회수를 5~120 사이 값으로 주고 주간 랭킹용 조회 기록도 함께 넣는다
#   - 같은 도시에 같은 제목이 이미 있으면 그 줄은 건너뛴다 (재실행 안전)
#
# 사용법:
#   scripts/seed-city-posts.sh            # 오늘 날짜로 등록
#   scripts/seed-city-posts.sh 2026-09-22 # 날짜 지정
#   DRY_RUN=1 scripts/seed-city-posts.sh  # SQL만 출력
#   STAGE=1 scripts/seed-city-posts.sh    # 원고를 launchd가 읽을 수 있는 위치로 복사
#
# launchd는 macOS 권한 때문에 ~/Desktop을 읽지 못한다. 그래서 예약 실행은
# ~/Library/Application Support/gling/city-posts/ 아래에 복사된 스크립트와 원고를 쓴다.
set -uo pipefail

export PATH="/Users/ash/.nvm/versions/node/v22.23.1/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

REPO="$HOME/Desktop/Git/unknown/mobile"
PROJECT_REF="wjvahbdwmctzpkndqaxa"
DAY="${1:-$(TZ=America/Vancouver date +%F)}"
LOG_DIR="$HOME/Library/Application Support/gling/city-posts"
PAYLOAD_DIR="$LOG_DIR/payload"
REPO_FILE="$REPO/content/$DAY/posts.json"
STAGED_FILE="$PAYLOAD_DIR/$DAY.json"

mkdir -p "$PAYLOAD_DIR"

# 원고를 예약 실행이 읽을 수 있는 위치로 복사한다. 원고를 쓴 직후 한 번 돌린다.
if [ "${STAGE:-0}" = "1" ]; then
  if [ ! -f "$REPO_FILE" ]; then echo "SKIP $REPO_FILE 없음"; exit 1; fi
  cp "$REPO_FILE" "$STAGED_FILE" || exit 1
  echo "STAGED $STAGED_FILE"
  exit 0
fi

FILE="${POSTS_FILE:-}"
# launchd는 ~/Desktop 파일을 stat은 하되 열지는 못한다. 권한 비트(-r)로는 구분되지 않으므로
# 실제로 한 바이트를 열어보고, 열리지 않으면 예약 실행용 사본을 쓴다.
if [ -z "$FILE" ] && [ -f "$REPO_FILE" ] && head -c 1 "$REPO_FILE" >/dev/null 2>&1; then
  FILE="$REPO_FILE"
fi
[ -n "$FILE" ] || FILE="$STAGED_FILE"

if [ "${DRY_RUN:-0}" != "1" ]; then exec >>"$LOG_DIR/$DAY.log" 2>&1; fi
echo "=== $(date) 도시 게시글 등록 시작 ($DAY)"

if [ ! -f "$FILE" ]; then
  echo "SKIP $FILE 없음. 오늘 원고가 아직 없어 등록하지 않는다."
  exit 0
fi

PAYLOAD="$(jq -c '.posts' "$FILE")"
COUNT="$(jq '.posts | length' "$FILE" 2>/dev/null || echo 0)"
if [ -z "$PAYLOAD" ] || [ "${COUNT:-0}" = "0" ]; then
  echo "FAIL $FILE 를 읽지 못했거나 원고가 비었다."
  exit 1
fi
if [ "$COUNT" -lt 1 ]; then
  echo "SKIP 원고 0건."
  exit 0
fi
if ! jq -e '.posts | all(.[]; (.author_nickname | type) == "string" and (.author_nickname | length) > 0)' "$FILE" >/dev/null; then
  echo "FAIL 각 글에 author_nickname을 지정해야 한다." >&2
  exit 1
fi

SQL_FILE="$(mktemp -t gling-city-posts)"
{
  cat <<'HEAD'
begin;
create temporary table gling_today (
  ord integer, city_id text, author_nickname text, tag_slug text, title text, body text, source text
) on commit drop;
insert into gling_today (ord, city_id, author_nickname, tag_slug, title, body, source)
select item.ord, item.city_id, item.author_nickname, item.tag_slug, item.title, item.body, item.source
from jsonb_to_recordset(
HEAD
  printf '$GLING$%s$GLING$::jsonb' "$PAYLOAD"
  cat <<'TAIL'
) as item(ord int, city_id text, author_nickname text, tag_slug text, title text, body text, source text);
create temporary table gling_today_author on commit drop as
select slot.city_id, slot.author_nickname,
       (select pr.id
        from public.profiles pr
        join auth.users u on u.id = pr.id
        where pr.city_id = slot.city_id
          and pr.nickname = slot.author_nickname
          and pr.account_status = 'active'
          and u.email like '%@seed.gling.invalid') as author_id
from (select distinct city_id, author_nickname from gling_today) slot;
do $$ begin
  if exists (select 1 from gling_today_author where author_id is null) then
    raise exception 'SEED_AUTHOR_NOT_FOUND';
  end if;
end $$;
insert into public.posts (author_id, city_id, tag_id, title, body, status, view_count, created_at)
select a.author_id, seed.city_id, tag.id, seed.title,
       seed.body,
       'published',
       0,
       (case when window_slot.local_time <= city_now.local_now
             then window_slot.local_time
             else window_slot.local_time - interval '1 day' end) at time zone city.timezone
from gling_today seed
join gling_today_author a on a.city_id = seed.city_id and a.author_nickname = seed.author_nickname
join public.tags tag on tag.slug = seed.tag_slug
join public.cities city on city.id = seed.city_id
cross join lateral (select now() at time zone city.timezone as local_now) city_now
cross join lateral (
  select date_trunc('day', city_now.local_now)
         + make_interval(hours => case (abs(hashtext(a.author_id::text || '-w')::bigint) % 4)
                                     when 0 then 7 when 1 then 12 when 2 then 18 else 22 end)
         + make_interval(mins => ((abs(hashtext(seed.title || '-m')::bigint) % 110) + seed.ord * 7)::int % 120)
         as local_time
) window_slot
where not exists (
  select 1 from public.posts existing
  where existing.city_id = seed.city_id and existing.title = seed.title and existing.status = 'published');

-- 작성자 성향에 맞춘 시간대는 어제가 될 수도 있다. posted_on을 그 현지 날짜로 맞춘다.
update public.posts post
set posted_on = (post.created_at at time zone city.timezone)::date
from public.cities city, gling_today seed, gling_today_author author
where city.id = post.city_id
  and seed.city_id = post.city_id
  and seed.title = post.title
  and author.city_id = seed.city_id
  and author.author_nickname = seed.author_nickname
  and post.author_id = author.author_id
  and post.posted_on <> (post.created_at at time zone city.timezone)::date;

TAIL
} > "$SQL_FILE"

# 조회수는 넣기만 하면 그날 숫자로 멈춘다. 하루 한 번만 부르는 실행에서 오래된 글 조회수를 조금씩 올린다.
if [ "${GROW:-0}" = "1" ]; then
  cat >> "$SQL_FILE" <<'GROW'
-- 조회수는 올린 날부터 30일 동안 오른다. 1~14일차는 하루 1~30, 15~30일차는 하루 1~8. 30일이 지나면 멈춘다.
-- 올린 당일은 하루치를 경과 시간 비율로 반영한다. 나이로 목표값을 계산하므로 다시 돌려도 값이 같다.
update public.posts post
set view_count = target.views
from (
  select base.id,
         round(
           coalesce((
             select sum(1 + (abs(hashtext(base.id::text || '-' || day.i)::bigint)
                             % (case when day.i <= 13 then 30 else 8 end))::int)
             from generate_series(0, least(30, base.elapsed) - 1) as day(i)
           ), 0)
           + case when base.elapsed < 30 then
               (1 + (abs(hashtext(base.id::text || '-' || least(30, base.elapsed))::bigint)
                     % (case when base.elapsed <= 13 then 30 else 8 end))::int)
               * ((base.age_seconds - least(30, base.elapsed) * 86400) / 86400.0)
             else 0 end
         )::int as views
  from (
    select p.id,
           floor(extract(epoch from (now() - p.created_at)) / 86400)::int as elapsed,
           extract(epoch from (now() - p.created_at)) as age_seconds
    from public.posts p
    where p.status = 'published'
      and p.city_id in (select distinct city_id from gling_today)
      and p.created_at <= now()
  ) base
) target
where post.id = target.id and post.view_count < target.views;

update private.post_view_pulse pulse
set views = greatest(0, post.view_count - (select count(*) from public.post_views v where v.post_id = post.id))
from public.posts post
where pulse.post_id = post.id
  and post.city_id in (select distinct city_id from gling_today);

-- 조회 기록이 아예 없는 옛 글은 주간 랭킹에서 0으로 잡힌다. 조회수와 맞는 기록을 채운다.
insert into private.post_view_pulse (post_id, bucket, views)
select post.id, date_bin(interval '10 minutes', post.created_at, '2000-01-01'::timestamptz),
       greatest(0, post.view_count - (select count(*) from public.post_views v where v.post_id = post.id))
from public.posts post
where post.status = 'published'
  and post.city_id in (select distinct city_id from gling_today)
  and not exists (select 1 from private.post_view_pulse x where x.post_id = post.id)
  and greatest(0, post.view_count - (select count(*) from public.post_views v where v.post_id = post.id)) > 0;
GROW
fi

cat >> "$SQL_FILE" <<'PULSE'
insert into private.post_view_pulse (post_id, bucket, views)
select p.id, date_bin(interval '10 minutes', p.created_at, '2000-01-01'::timestamptz), p.view_count
from public.posts p
join gling_today seed on seed.title = p.title and seed.city_id = p.city_id
join gling_today_author author on author.city_id = seed.city_id
  and author.author_nickname = seed.author_nickname and author.author_id = p.author_id
where p.status = 'published'
  and not exists (select 1 from private.post_view_pulse x where x.post_id = p.id);
commit;
PULSE

if [ "${DRY_RUN:-0}" = "1" ]; then cat "$SQL_FILE"; exit 0; fi

# 연결은 Supabase Management API로 한다. 키체인의 CLI 토큰을 그대로 쓴다.
TOKEN="$(security find-generic-password -s 'Supabase CLI' -w 2>/dev/null)"
if [ -z "$TOKEN" ]; then
  echo "FAIL Supabase CLI 토큰을 키체인에서 읽지 못했다."
  exit 1
fi

RESULT="$(jq -Rs '{query: .}' "$SQL_FILE" | curl -s -X POST \
  "https://api.supabase.com/v1/projects/$PROJECT_REF/database/query" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data-binary @-)"

if printf '%s' "$RESULT" | grep -q '"message"'; then
  echo "FAIL $RESULT"
  exit 1
fi
echo "OK ${COUNT}건 처리 $RESULT"
