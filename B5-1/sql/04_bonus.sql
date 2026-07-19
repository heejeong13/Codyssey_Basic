-- 이 파일은 과제에서 지정한 공식 보너스 3개만 실행한다.
-- 각 PART의 목적, 실행 방법, 결과 해석을 초보자가 이해할 수 있도록 주석으로 설명한다.

\pset expanded off
\pset null '(없음)'

-- ============================================================================
-- PART 1. 같은 요구사항을 JOIN과 서브쿼리 두 방식으로 풀기
-- ============================================================================
-- 요구사항: 대상 10개 팀 중 LCK 우승 이력이 없는 팀을 찾는다.
--
-- LEFT JOIN 방식:
-- team의 모든 행을 남긴 채 championship을 연결한 후, 연결되지 않은 NULL 행을 찾는다.
-- 연결 결과의 다른 컬럼도 함께 조회해야 할 때 확장하기 쉬운 방식이다.
--
-- NOT EXISTS 서브쿼리 방식:
-- 각 team 행마다 championship 행이 존재하는지만 확인하고, 존재하지 않을 때 반환한다.
-- 단순히 관련 행의 존재 여부만 묻는 요구에는 의도가 더 직접적으로 드러난다.
--
-- 두 쿼리는 작성 방법만 다르고 같은 팀 목록을 반환해야 한다.
\o :results_dir/bonus_01_join_vs_subquery.txt
\echo '공식 보너스 1. 우승 이력이 없는 팀을 JOIN과 서브쿼리로 비교'
\echo '[LEFT JOIN 방식]'
SELECT team.name
FROM team
LEFT JOIN championship ON championship.winner_team_id = team.id
WHERE championship.id IS NULL
ORDER BY team.name;

\echo '[NOT EXISTS 서브쿼리 방식]'
SELECT team.name
FROM team
WHERE NOT EXISTS (
    SELECT 1
    FROM championship
    WHERE championship.winner_team_id = team.id
)
ORDER BY team.name;

\echo '[비교 결론] LEFT JOIN은 연결 후 NULL을 찾고, NOT EXISTS는 연결 행의 존재 여부만 검사한다.'

-- ============================================================================
-- PART 2. FK 오류를 발생시켜 데이터 정합성 확인하기
-- ============================================================================
-- player_team_history.player_id는 player.id를 참조하는 FK다.
-- 존재하지 않는 player_id 999999를 입력하면 부모 선수 행이 없으므로 PostgreSQL이 거부해야 한다.
-- 이 오류 덕분에 소속 이력이 실제로 존재하는 선수만 참조한다는 데이터 정합성이 유지된다.
--
-- 올바른 해결 방법:
-- 1. 이미 player에 존재하는 선수의 id를 사용한다.
-- 2. 새 선수라면 player에 부모 행을 먼저 INSERT한 후 그 id로 소속 이력을 INSERT한다.
-- FK를 삭제하거나 검사를 끄는 것은 관계를 깨뜨리므로 해결 방법으로 사용하지 않는다.
--
-- 아래 오류는 의도한 결과이므로 이 구간에서만 ON_ERROR_STOP을 끈다.
-- 실제 오류 메시지는 run_all.sh가 results/bonus_02_fk_error.txt에 저장한다.
\set ON_ERROR_STOP off
INSERT INTO player_team_history (player_id, team_id, joined_date, left_date)
SELECT 999999, team.id, DATE '2026-07-20', NULL
FROM team
WHERE team.name = 'T1';
\set ON_ERROR_STOP on

-- FK가 정상 작동했다면 위 행은 저장되지 않아 COUNT 결과가 0이어야 한다.
\o :results_dir/bonus_02_fk_verification.txt
\echo '공식 보너스 2. FK 오류 후 잘못된 행이 저장되지 않았는지 확인'
SELECT COUNT(*) AS invalid_history_count
FROM player_team_history
WHERE player_id = 999999;

\echo '[해결 방법] 존재하는 player.id를 사용하거나, 부모 player 행을 먼저 INSERT해야 한다.'

-- ============================================================================
-- PART 3. LCK 데이터베이스 핵심 지표 3개 미니 리포트
-- ============================================================================
-- 지표 1: 팀별 LCK 우승 횟수 TOP 3
-- championship을 팀별로 묶어 대상 기간에 가장 많이 우승한 팀을 찾는다.
--
-- 지표 2: 선수별 LCK 우승 횟수 TOP 5
-- 이 DB는 우승 당시 별도 로스터 테이블을 만들지 않았으므로 소속 기간으로 계산한다.
-- 대회 종료일에 선수가 우승팀에 소속되어 있었다면 해당 대회의 우승 선수로 간주한다.
-- joined_date는 대회 종료일 이전이고, left_date는 NULL이거나 종료일 이후여야 한다.
--
-- 지표 3: 2020년 이후 두 개 이상의 대상 팀에 소속된 선수
-- 같은 팀 재합류는 한 팀으로 세고, 서로 다른 team_id가 2개 이상인 선수만 찾는다.
\o :results_dir/bonus_03_mini_report.txt
\echo '공식 보너스 3. LCK 데이터베이스 핵심 지표 3개'

\echo '[지표 1] 팀별 LCK 우승 횟수 TOP 3'
SELECT team.name, COUNT(championship.id) AS championship_count
FROM team
LEFT JOIN championship ON championship.winner_team_id = team.id
GROUP BY team.id, team.name
ORDER BY championship_count DESC, team.name
LIMIT 3;

\echo '[지표 2] 선수별 LCK 우승 횟수 TOP 5'
SELECT player.summoner_name,
       player.real_name,
       COUNT(DISTINCT championship.id) AS championship_count
FROM player
INNER JOIN player_team_history
    ON player_team_history.player_id = player.id
INNER JOIN championship
    ON championship.winner_team_id = player_team_history.team_id
INNER JOIN tournament
    ON tournament.id = championship.tournament_id
   AND player_team_history.joined_date <= tournament.end_date
   AND (player_team_history.left_date IS NULL
        OR player_team_history.left_date >= tournament.end_date)
GROUP BY player.id, player.summoner_name, player.real_name
ORDER BY championship_count DESC, player.summoner_name
LIMIT 5;

\echo '[지표 3] 2020년 이후 두 개 이상의 대상 팀에 소속된 선수'
SELECT player.summoner_name,
       player.real_name,
       COUNT(DISTINCT player_team_history.team_id) AS team_count
FROM player
INNER JOIN player_team_history ON player_team_history.player_id = player.id
WHERE player_team_history.joined_date <= DATE '2026-07-20'
  AND (player_team_history.left_date IS NULL
       OR player_team_history.left_date >= DATE '2020-01-01')
GROUP BY player.id, player.summoner_name, player.real_name
HAVING COUNT(DISTINCT player_team_history.team_id) >= 2
ORDER BY team_count DESC, player.summoner_name;

\o
