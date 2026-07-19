-- 이 파일은 SELECT, JOIN, 집계, 서브쿼리, UPDATE, DELETE를 단계별로 연습한다.
-- psql의 \o 명령은 화면 출력을 각 results 파일로 전환하며 SQL 문장 자체는 저장하지 않는다.
-- make all이 먼저 DB를 초기화하므로 UPDATE와 DELETE까지 실행해도 다음 실행 결과는 같다.

-- 표가 읽기 좋은 너비로 출력되도록 psql의 확장 출력은 끄고 NULL 표시를 통일한다.
\pset expanded off
\pset null '(없음)'

-- 1. 전체 10개 팀의 이름, 약어, 상태를 이름순으로 조회하는 기본 SELECT다.
-- LIMIT은 최대 10행까지만 반환하며 현재 팀 수와 같으므로 전체 팀을 보여준다.
\o :results_dir/01_all_teams.txt
\echo '1. 전체 대상 팀'
SELECT id, name, short_name, status
FROM team
ORDER BY name
LIMIT 10;

-- 2. WHERE는 다섯 포지션 중 ADC인 선수만 고른다.
\o :results_dir/02_players_by_position.txt
\echo '2. ADC 포지션 선수'
SELECT summoner_name, real_name, position
FROM player
WHERE position = 'ADC'
ORDER BY summoner_name;

-- 3. 현재 소속이 반드시 있는 선수만 보므로 INNER JOIN을 사용한다.
-- player_team_history가 player와 team의 id를 연결하고, NULL 종료일이 현재 소속을 뜻한다.
\o :results_dir/03_current_players_and_teams.txt
\echo '3. 현재 소속팀이 있는 선수와 팀'
SELECT player.summoner_name, player.real_name, player.position, team.name AS team_name
FROM player_team_history
INNER JOIN player ON player.id = player_team_history.player_id
INNER JOIN team ON team.id = player_team_history.team_id
WHERE player_team_history.left_date IS NULL
ORDER BY team.name, player.position, player.summoner_name;

-- 4. LEFT JOIN은 현재 선수가 0명인 팀도 결과에서 빠지지 않게 한다.
-- GROUP BY는 팀 하나를 한 묶음으로 만들고 COUNT는 각 묶음의 선수 id를 센다.
\o :results_dir/04_current_player_count_by_team.txt
\echo '4. 팀별 현재 선수 수'
SELECT team.name, COUNT(player_team_history.player_id) AS current_player_count
FROM team
LEFT JOIN player_team_history
    ON player_team_history.team_id = team.id
   AND player_team_history.left_date IS NULL
GROUP BY team.id, team.name
ORDER BY current_player_count DESC, team.name;

-- 5. 세 테이블을 INNER JOIN하고 WHERE로 T1의 현재 행만 선택한다.
\o :results_dir/05_t1_current_roster.txt
\echo '5. T1 현재 선수 명단'
SELECT player.position, player.summoner_name, player.real_name, player_team_history.joined_date
FROM player_team_history
INNER JOIN player ON player.id = player_team_history.player_id
INNER JOIN team ON team.id = player_team_history.team_id
WHERE team.name = 'T1'
  AND player_team_history.left_date IS NULL
ORDER BY player.position, player.summoner_name;

-- 6. Faker의 모든 소속 이력을 날짜순으로 조회한다.
-- 실습용 2099년 행도 실제 데이터와 구분할 수 있도록 함께 나타난다.
\o :results_dir/06_faker_team_history.txt
\echo '6. Faker의 전체 소속 이력'
SELECT team.name, player_team_history.joined_date, player_team_history.left_date
FROM player_team_history
INNER JOIN player ON player.id = player_team_history.player_id
INNER JOIN team ON team.id = player_team_history.team_id
WHERE player.summoner_name = 'Faker'
ORDER BY player_team_history.joined_date;

-- 7. WHERE로 2024년에 열린 대회만 선택한다.
\o :results_dir/07_tournaments_in_2024.txt
\echo '7. 2024년 LCK 대회 목록'
SELECT name, split, start_date, end_date
FROM tournament
WHERE season_year = 2024
ORDER BY start_date;

-- 8. 대상 밖 팀 우승이나 미확정 우승도 대회 목록에서 보이도록 LEFT JOIN을 사용한다.
\o :results_dir/08_winner_by_tournament.txt
\echo '8. 대회별 대상 팀 우승 기록'
SELECT tournament.name, COALESCE(team.name, '대상 팀 우승 기록 없음') AS winner
FROM tournament
LEFT JOIN championship ON championship.tournament_id = tournament.id
LEFT JOIN team ON team.id = championship.winner_team_id
ORDER BY tournament.start_date;

-- 9. team을 기준으로 LEFT JOIN하므로 우승이 없는 팀도 0회로 집계된다.
-- GROUP BY는 팀별 묶음을 만들고 COUNT는 우승 행 수를 센다.
\o :results_dir/09_championship_count_by_team.txt
\echo '9. 팀별 우승 횟수'
SELECT team.name, COUNT(championship.id) AS championship_count
FROM team
LEFT JOIN championship ON championship.winner_team_id = team.id
GROUP BY team.id, team.name
ORDER BY championship_count DESC, team.name;

-- 10. 안쪽 서브쿼리는 팀별 우승 횟수를 먼저 계산한다.
-- 바깥 WHERE는 MAX와 같은 최다 횟수인 팀을 모두 반환해 공동 1위도 처리한다.
\o :results_dir/10_most_championships.txt
\echo '10. 가장 많이 우승한 팀'
WITH team_counts AS (
    SELECT team.name, COUNT(championship.id) AS championship_count
    FROM team
    LEFT JOIN championship ON championship.winner_team_id = team.id
    GROUP BY team.id, team.name
)
SELECT name, championship_count
FROM team_counts
WHERE championship_count = (SELECT MAX(championship_count) FROM team_counts)
ORDER BY name;

-- 11. LEFT JOIN 후 championship.id가 NULL인 행은 한 번도 우승팀으로 연결되지 않은 팀이다.
\o :results_dir/11_teams_without_championship.txt
\echo '11. 우승 이력이 없는 대상 팀'
SELECT team.name
FROM team
LEFT JOIN championship ON championship.winner_team_id = team.id
WHERE championship.id IS NULL
ORDER BY team.name;

-- 12. 연도와 split이라는 두 조건으로 특정 대회의 우승팀을 찾는다.
\o :results_dir/12_2024_summer_winner.txt
\echo '12. 2024년 SUMMER 우승팀'
SELECT tournament.name, team.name AS winner
FROM championship
INNER JOIN tournament ON tournament.id = championship.tournament_id
INNER JOIN team ON team.id = championship.winner_team_id
WHERE tournament.season_year = 2024
  AND tournament.split = 'SUMMER';

-- 13. 첫 서브쿼리는 팀별 우승 횟수를 만들고 두 번째는 그 평균을 계산한다.
-- HAVING은 GROUP BY 결과 중 평균보다 우승 횟수가 많은 팀만 남긴다.
\o :results_dir/13_above_average_championships.txt
\echo '13. 평균보다 많이 우승한 팀'
WITH team_counts AS (
    SELECT team.id, team.name, COUNT(championship.id) AS championship_count
    FROM team
    LEFT JOIN championship ON championship.winner_team_id = team.id
    GROUP BY team.id, team.name
)
SELECT name, championship_count
FROM team_counts
GROUP BY id, name, championship_count
HAVING championship_count > (SELECT AVG(championship_count) FROM team_counts)
ORDER BY championship_count DESC, name;

-- 14. 02_seed.sql에서 명확히 표시한 2099년 실습용 행만 UPDATE한다.
-- 실제 선수의 핵심 소속 이력에는 같은 날짜가 없으므로 조건이 안전하게 한 행을 가리킨다.
\o :results_dir/14_update_practice_history.txt
\echo '14. 실습용 소속 이력 UPDATE 결과'
UPDATE player_team_history
SET left_date = DATE '2099-01-02'
WHERE joined_date = DATE '2099-01-01'
  AND player_id = (SELECT id FROM player WHERE summoner_name = 'Faker')
RETURNING id, player_id, team_id, joined_date, left_date;

-- 15. UPDATE로 확인한 같은 실습용 행만 실제 DELETE하고 RETURNING으로 삭제 내용을 확인한다.
-- make all의 다음 실행은 DB를 reset하므로 실습 행이 다시 만들어져 결과가 동일하다.
\o :results_dir/15_delete_practice_history.txt
\echo '15. 실습용 소속 이력 DELETE 결과'
DELETE FROM player_team_history
WHERE joined_date = DATE '2099-01-01'
  AND player_id = (SELECT id FROM player WHERE summoner_name = 'Faker')
RETURNING id, player_id, team_id, joined_date, left_date;

-- 16. player 한 테이블만 사용하는 네 번째 기본 조회다.
-- WHERE로 실제 이름이 Kim으로 시작하는 선수를 고르고 ORDER BY 후 LIMIT 10을 적용한다.
\o :results_dir/16_players_whose_name_starts_with_kim.txt
\echo '16. 실제 이름이 Kim으로 시작하는 선수 중 10명'
SELECT summoner_name, real_name, position
FROM player
WHERE real_name LIKE 'Kim %'
ORDER BY real_name, summoner_name
LIMIT 10;

-- 마지막에는 출력을 다시 터미널로 돌려 이후 psql 메시지가 결과 파일에 섞이지 않게 한다.
\o
