-- 이 파일은 여러 테이블의 관계를 조금 더 폭넓게 탐색하는 8개 보너스 쿼리다.
-- 모든 조회는 데이터 변경 없이 results의 해당 파일을 덮어쓴다.

\pset expanded off
\pset null '(없음)'

-- 1. GROUP BY가 같은 포지션의 선수를 묶고 COUNT가 서로 다른 선수 행을 센다.
\o :results_dir/bonus_01_player_count_by_position.txt
\echo '보너스 1. 포지션별 선수 수'
SELECT position, COUNT(*) AS player_count
FROM player
GROUP BY position
ORDER BY player_count DESC, position;

-- 2. tournament, championship, team을 INNER JOIN해 우승이 확정된 연도만 조회한다.
\o :results_dir/bonus_02_winners_by_year.txt
\echo '보너스 2. 연도별 우승팀'
SELECT tournament.season_year, tournament.name, team.name AS winner
FROM championship
INNER JOIN tournament ON tournament.id = championship.tournament_id
INNER JOIN team ON team.id = championship.winner_team_id
ORDER BY tournament.season_year, tournament.start_date;

-- 3. 서브쿼리의 MAX가 가장 늦은 종료일을 먼저 계산하고 해당 대회를 찾는다.
\o :results_dir/bonus_03_latest_championship.txt
\echo '보너스 3. 최근 우승 대회'
SELECT tournament.name, tournament.end_date, team.name AS winner
FROM championship
INNER JOIN tournament ON tournament.id = championship.tournament_id
INNER JOIN team ON team.id = championship.winner_team_id
WHERE tournament.end_date = (SELECT MAX(end_date) FROM tournament);

-- 4. 팀별 우승 횟수를 내림차순 정렬하고 LIMIT으로 상위 3개 팀만 남긴다.
\o :results_dir/bonus_04_top_three_championships.txt
\echo '보너스 4. 우승 횟수 TOP 3'
SELECT team.name, COUNT(championship.id) AS championship_count
FROM team
LEFT JOIN championship ON championship.winner_team_id = team.id
GROUP BY team.id, team.name
ORDER BY championship_count DESC, team.name
LIMIT 3;

-- 5. 현재 이력만 팀별로 묶은 뒤 가장 큰 COUNT와 같은 팀을 찾는다.
-- 서브쿼리를 사용하므로 공동 최다 팀도 모두 표시한다.
\o :results_dir/bonus_05_largest_current_roster.txt
\echo '보너스 5. 현재 소속 선수가 가장 많은 팀'
WITH current_counts AS (
    SELECT team.name, COUNT(player_team_history.id) AS player_count
    FROM team
    LEFT JOIN player_team_history
        ON player_team_history.team_id = team.id
       AND player_team_history.left_date IS NULL
    GROUP BY team.id, team.name
)
SELECT name, player_count
FROM current_counts
WHERE player_count = (SELECT MAX(player_count) FROM current_counts)
ORDER BY name;

-- 6. 선수별 서로 다른 대상 팀 수를 세고 HAVING으로 2개 이상인 선수만 남긴다.
-- 기간이 2020년 이후와 한 번이라도 겹치도록 종료일과 입단일 조건을 함께 사용한다.
\o :results_dir/bonus_06_players_on_multiple_teams.txt
\echo '보너스 6. 2020년 이후 두 개 이상의 대상 팀에 소속된 선수'
SELECT player.summoner_name, COUNT(DISTINCT player_team_history.team_id) AS team_count
FROM player
INNER JOIN player_team_history ON player_team_history.player_id = player.id
WHERE player_team_history.joined_date <= DATE '2026-07-19'
  AND (player_team_history.left_date IS NULL OR player_team_history.left_date >= DATE '2020-01-01')
GROUP BY player.id, player.summoner_name
HAVING COUNT(DISTINCT player_team_history.team_id) >= 2
ORDER BY team_count DESC, player.summoner_name;

-- 7. 같은 선수가 재합류해 이력 행이 여러 개여도 한 명으로 세도록 COUNT DISTINCT를 사용한다.
\o :results_dir/bonus_07_historical_player_count_by_team.txt
\echo '보너스 7. 팀별 역대 소속 선수 수'
SELECT team.name, COUNT(DISTINCT player_team_history.player_id) AS historical_player_count
FROM team
LEFT JOIN player_team_history ON player_team_history.team_id = team.id
GROUP BY team.id, team.name
ORDER BY historical_player_count DESC, team.name;

-- 8. generate_series가 2020~2026 연도 목록을 먼저 만들고, 그해와 기간이 겹친 선수를 센다.
-- LEFT JOIN을 사용하므로 등록 선수가 없는 연도도 0명으로 표시할 수 있다.
\o :results_dir/bonus_08_registered_players_by_year.txt
\echo '보너스 8. 연도별 등록 선수 수'
WITH years AS (
    SELECT generate_series(2020, 2026) AS season_year
)
SELECT years.season_year,
       COUNT(DISTINCT player_team_history.player_id) AS registered_player_count
FROM years
LEFT JOIN player_team_history
    ON player_team_history.joined_date <= make_date(years.season_year, 12, 31)
   AND (player_team_history.left_date IS NULL
        OR player_team_history.left_date >= make_date(years.season_year, 1, 1))
GROUP BY years.season_year
ORDER BY years.season_year;

\o
