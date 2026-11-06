-- 새 Supabase 프로젝트의 SQL Editor에서 한 번 실행하세요.
-- 테이블은 직접 접근 불가. 검증된 RPC만 공개합니다.
begin;
create table public.cases (
 id bigint generated always as identity primary key,
 category text not null check(category in ('친구','연애','직장','일상')),
 title text not null check(length(btrim(title)) between 5 and 100),
 body text not null check(length(btrim(body)) between 5 and 600),
 option_a text not null check(length(btrim(option_a)) between 1 and 60),
 option_b text not null check(length(btrim(option_b)) between 1 and 60),
 author_id uuid references auth.users(id) on delete set null,
 status text not null default 'pending' check(status in ('pending','published','hidden')),
 created_at timestamptz not null default now(), check(option_a<>option_b)
);
create table public.votes (
 case_id bigint not null references public.cases(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 choice text not null check(choice in ('a','b')),
 created_at timestamptz not null default now(),primary key(case_id,user_id)
);
create table public.comments (
 id bigint generated always as identity primary key,
 case_id bigint not null references public.cases(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 body text not null check(length(btrim(body)) between 1 and 140),
 hidden boolean not null default false,created_at timestamptz not null default now()
);
create index on public.cases(status,created_at desc);
create index on public.cases(author_id,created_at desc);
create index on public.comments(case_id,created_at desc);
create index on public.comments(user_id,created_at desc);
alter table public.cases enable row level security;
alter table public.votes enable row level security;
alter table public.comments enable row level security;
revoke all on public.cases,public.votes,public.comments from anon,authenticated;
revoke all on sequence public.cases_id_seq,public.comments_id_seq from anon,authenticated;

create function public.get_board() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception '로그인이 필요합니다'; end if;
 return coalesce((select jsonb_agg(row_data order by created_at desc) from (
 select c.created_at,jsonb_build_object('id',c.id,'category',c.category,'title',c.title,'body',c.body,
 'option_a',c.option_a,'option_b',c.option_b,
 'total',(select count(*) from public.votes v where v.case_id=c.id),
 'mine',(select v.choice from public.votes v where v.case_id=c.id and v.user_id=auth.uid()),
 'a',case when exists(select 1 from public.votes v where v.case_id=c.id and v.user_id=auth.uid()) then (select count(*) from public.votes v where v.case_id=c.id and v.choice='a') else null end,
 'b',case when exists(select 1 from public.votes v where v.case_id=c.id and v.user_id=auth.uid()) then (select count(*) from public.votes v where v.case_id=c.id and v.choice='b') else null end,
 'comments',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'body',t.body) order by t.created_at) from (select id,body,created_at from public.comments where case_id=c.id and not hidden order by created_at desc limit 30) t),'[]'::jsonb)) as row_data
 from public.cases c where c.status='published' order by c.created_at desc limit 100
 ) q),'[]'::jsonb);
end $$;

create function public.participate(p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); cid bigint;
begin
 if u is null then raise exception '로그인이 필요합니다'; end if;
 -- 같은 사용자 동시 요청을 직렬화해 속도 제한 우회를 줄입니다.
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 if p_action in ('vote','comment') then
 cid:=(p_payload->>'case_id')::bigint;
 perform 1 from public.cases where id=cid and status='published' for share;
 if not found then raise exception '공개된 논쟁이 아닙니다'; end if;
 end if;
 if p_action='vote' then
 if (p_payload->>'choice') is null or (p_payload->>'choice') not in ('a','b') then raise exception '선택지를 확인해 주세요'; end if;
 insert into public.votes(case_id,user_id,choice) values(cid,u,p_payload->>'choice');
 elsif p_action='comment' then
 if not exists(select 1 from public.votes where case_id=cid and user_id=u) then raise exception '투표한 뒤 변론을 남겨주세요'; end if;
 if exists(select 1 from public.comments where user_id=u and created_at>now()-interval '30 seconds') then raise exception '변론은 30초에 한 번 남길 수 있습니다'; end if;
 insert into public.comments(case_id,user_id,body) values(cid,u,btrim(p_payload->>'body'));
 elsif p_action='case' then
 if (select count(*) from public.cases where author_id=u and created_at>now()-interval '1 day')>=3 then raise exception '사연은 하루에 3개까지 접수할 수 있습니다'; end if;
 insert into public.cases(category,title,body,option_a,option_b,author_id) values(p_payload->>'category',btrim(p_payload->>'title'),btrim(p_payload->>'body'),btrim(p_payload->>'option_a'),btrim(p_payload->>'option_b'),u);
 else raise exception '지원하지 않는 작업입니다'; end if;
 return jsonb_build_object('ok',true);
exception when unique_violation then raise exception '이미 투표한 논쟁입니다';
end $$;
revoke all on function public.get_board() from public,anon;
revoke all on function public.participate(text,jsonb) from public,anon;
grant execute on function public.get_board() to authenticated;
grant execute on function public.participate(text,jsonb) to authenticated;
insert into public.cases(category,title,body,option_a,option_b,status) values
('친구','약속 10분 전에 취소한 친구, 커피 한 잔은 사야 한다?','만나려고 이미 집을 나왔는데 친구가 피곤하다며 취소했어요. 다음에 커피라도 사 달라고 하면 쪼잔한 건가요?','미안하면 커피는 사야지','피곤할 수도 있지','published'),
('일상','단톡방 생일 축하, “고마워” 한 번이면 충분하다?','친구 여섯 명이 축하해 줬어요. “다들 고마워!” 한 번이면 될까요?','한 번이면 충분하다','한 명씩 답장해야지','published'),
('직장','퇴근 5분 전 온 업무 메시지, 내일 답해도 될까?','급한 일이라는 말 없이 내일 회의 자료를 확인해 달라는 메시지가 왔어요.','내일 출근해서 답한다','짧게라도 답장한다','published'),
('연애','애인이 내 사진 50장 찍고, 한 장만 건져도 성공?','여행 사진 50장 중 한 장만 마음에 들었어요. 다시 부탁해도 될까요?','한 장이면 대성공','한 번만 더 찍어줘','published');
commit;
