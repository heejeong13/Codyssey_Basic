-- 이 파일은 2026-07-19까지 확인된 LCK 기록을 학습용 DB에 입력한다.
-- 팀 → 선수 → 소속 이력 → 대회 → 우승 순서로 넣어 외래 키가 항상 부모 행을 찾게 한다.
-- player에는 검색 가능한 소환사명과 실제 이름, 대표 포지션만 저장한다.

-- 먼저 선수 이력을 관리하는 기존 5개 팀을 입력하고, 이어 나머지 LCK 팀을 입력한다.
INSERT INTO team (name, short_name, founded_date, status) VALUES
    ('T1', 'T1', NULL, 'ACTIVE'),
    ('Gen.G', 'GEN', NULL, 'ACTIVE'),
    ('Dplus KIA', 'DK', NULL, 'ACTIVE'),
    ('Hanwha Life Esports', 'HLE', NULL, 'ACTIVE'),
    ('KT Rolster', 'KT', NULL, 'ACTIVE'),
    -- 아래 5개 팀은 2026년 공식 LCK 표기와 약어를 사용한다.
    -- 과제 범위에서는 팀 기본정보만 관리하고 선수 소속 이력은 추가하지 않는다.
    ('BNK FearX', 'BFX', NULL, 'ACTIVE'),
    ('DN SOOPers', 'DNS', NULL, 'ACTIVE'),
    ('Kiwoom DRX', 'KRX', NULL, 'ACTIVE'),
    ('Nongshim RedForce', 'NS', NULL, 'ACTIVE'),
    ('Hanjin BRION', 'BRO', NULL, 'ACTIVE');

-- 선수는 대상 팀 사이에서 이적했더라도 한 번만 입력한다.
-- real_name은 공식 로스터에서 사용하는 로마자 표기로 통일한다.

-- TOP 선수
INSERT INTO player (summoner_name, real_name, position) VALUES
    ('Canna', 'Kim Chang-dong', 'TOP'), ('Roach', 'Kim Kang-hui', 'TOP'),
    ('Zeus', 'Choi Woo-je', 'TOP'), ('Doran', 'Choi Hyeon-joon', 'TOP'),
    ('CuVee', 'Lee Seong-jin', 'TOP'), ('Rascal', 'Kim Kwang-hee', 'TOP'),
    ('Burdol', 'Noh Tae-yoon', 'TOP'), ('Kiin', 'Kim Gi-in', 'TOP'),
    ('Nuguri', 'Jang Ha-gwon', 'TOP'), ('Flame', 'Lee Ho-jong', 'TOP'),
    ('Khan', 'Kim Dong-ha', 'TOP'), ('Hoya', 'Yoon Yong-ho', 'TOP'),
    ('Thanatos', 'Park Seung-gyu', 'TOP'),
    ('Kingen', 'Hwang Seong-hoon', 'TOP'), ('Siwoo', 'Jeon Si-woo', 'TOP'),
    ('DuDu', 'Lee Dong-ju', 'TOP'), ('Morgan', 'Park Gi-tae', 'TOP'),
    ('SoHwan', 'Kim Jun-yeong', 'TOP'), ('Ray', 'Jeon Ji-won', 'TOP'),
    ('Smeb', 'Song Kyung-ho', 'TOP'), ('PerfecT', 'Lee Seung-min', 'TOP');

-- JUNGLE 선수
INSERT INTO player (summoner_name, real_name, position) VALUES
    ('Ellim', 'Choi El-lim', 'JUNGLE'), ('Cuzz', 'Moon Woo-chan', 'JUNGLE'),
    ('Oner', 'Mun Hyeon-jun', 'JUNGLE'), ('Clid', 'Kim Tae-min', 'JUNGLE'),
    ('Flawless', 'Sung Yeon-jun', 'JUNGLE'), ('Peanut', 'Han Wang-ho', 'JUNGLE'),
    ('Canyon', 'Kim Geon-bu', 'JUNGLE'), ('Malrang', 'Kim Geun-seong', 'JUNGLE'),
    ('Lucid', 'Choi Yong-hyeok', 'JUNGLE'), ('Haru', 'Kang Min-seung', 'JUNGLE'),
    ('CaD', 'Jo Seong-yong', 'JUNGLE'), ('Arthur', 'Park Mi-reu', 'JUNGLE'),
    ('yoHan', 'Kim Yo-han', 'JUNGLE'), ('Willer', 'Kim Jeong-hyeon', 'JUNGLE'),
    ('OnFleek', 'Kim Jang-gyeom', 'JUNGLE'), ('Grizzly', 'Jo Seung-hoon', 'JUNGLE'),
    ('Kanavi', 'Seo Jin-hyeok', 'JUNGLE'), ('bonO', 'Kim Gi-beom', 'JUNGLE'),
    ('Blank', 'Kang Sun-gu', 'JUNGLE'), ('GIDEON', 'Kim Min-seong', 'JUNGLE'),
    ('Pyosik', 'Hong Chang-hyeon', 'JUNGLE');

-- MID 선수
INSERT INTO player (summoner_name, real_name, position) VALUES
    ('Faker', 'Lee Sang-hyeok', 'MID'), ('Clozer', 'Lee Ju-hyeon', 'MID'),
    ('Bdd', 'Gwak Bo-seong', 'MID'), ('Karis', 'Kim Hong-jo', 'MID'),
    ('Chovy', 'Jeong Ji-hoon', 'MID'), ('ShowMaker', 'Heo Su', 'MID'),
    ('RangJun', 'Kim Sang-joon', 'MID'), ('Lava', 'Kim Tae-hoon', 'MID'),
    ('Mireu', 'Jeong Jo-bin', 'MID'), ('Tempt', 'Kang Myung-gu', 'MID'),
    ('Zeka', 'Kim Geon-woo', 'MID'), ('Kuro', 'Lee Seo-haeng', 'MID'),
    ('Ucal', 'Son Woo-hyeon', 'MID'), ('Dove', 'Kim Jae-yeon', 'MID'),
    ('VicLa', 'Lee Dae-kwang', 'MID'), ('Aria', 'Lee Ga-eul', 'MID');

-- ADC 선수
INSERT INTO player (summoner_name, real_name, position) VALUES
    ('Teddy', 'Park Jin-seong', 'ADC'), ('Gumayusi', 'Lee Min-hyeong', 'ADC'),
    ('Smash', 'Shin Geum-jae', 'ADC'), ('Peyz', 'Kim Su-hwan', 'ADC'),
    ('Ruler', 'Park Jae-hyuk', 'ADC'), ('Ghost', 'Jang Yong-jun', 'ADC'),
    ('Nuclear', 'Shin Jeong-hyeon', 'ADC'), ('deokdam', 'Seo Dae-gil', 'ADC'),
    ('Deft', 'Kim Hyuk-kyu', 'ADC'), ('Aiming', 'Kim Ha-ram', 'ADC'),
    ('Rahel', 'Cho Min-seong', 'ADC'), ('Zenit', 'Jeon Tae-gwon', 'ADC'),
    ('Viper', 'Park Do-hyeon', 'ADC'), ('SamD', 'Lee Jae-hoon', 'ADC'),
    ('Cheoni', 'Jo Seung-mo', 'ADC'), ('HyBriD', 'Lee Woo-jin', 'ADC'),
    ('Noah', 'Oh Hyeon-taek', 'ADC'), ('5kid', 'Park Jeong-hyeon', 'ADC');

-- SUPPORT 선수
INSERT INTO player (summoner_name, real_name, position) VALUES
    ('Effort', 'Lee Sang-ho', 'SUPPORT'), ('Kuri', 'Choi Won-yeong', 'SUPPORT'),
    ('Keria', 'Ryu Min-seok', 'SUPPORT'), ('Life', 'Kim Jeong-min', 'SUPPORT'),
    ('Kellin', 'Kim Hyeong-gyu', 'SUPPORT'), ('Lehends', 'Son Si-woo', 'SUPPORT'),
    ('Delight', 'Yoo Hwan-joong', 'SUPPORT'), ('Duro', 'Joo Min-kyu', 'SUPPORT'),
    ('BeryL', 'Cho Geon-hee', 'SUPPORT'), ('Hoit', 'Ryu Ho-sung', 'SUPPORT'),
    ('Bible', 'Yoon Seol', 'SUPPORT'), ('Career', 'Oh Hyeong-seok', 'SUPPORT'),
    ('Asper', 'Kim Tae-gi', 'SUPPORT'), ('Vsta', 'Oh Hyo-seong', 'SUPPORT'),
    ('Tusin', 'Park Jong-ik', 'SUPPORT'), ('Zzus', 'Jang Jun-su', 'SUPPORT'),
    ('Harp', 'Lee Ji-yoong', 'SUPPORT'), ('Way', 'Han Gil', 'SUPPORT'),
    ('Pollu', 'Oh Dong-gyu', 'SUPPORT');

-- 소속 기간은 공식 로스터 등록·발표 시점을 기준으로 정리했다.
-- 종료일이 NULL인 행은 2026-07-19 기준 현재 소속이다.
-- VALUES 목록을 선수명과 팀명으로 먼저 읽은 뒤 실제 id와 JOIN하여 저장한다.
WITH history_data (summoner_name, team_name, joined_date, left_date) AS (
    VALUES
        -- T1: 2020년 이후 공식 1군 등록 이력
        ('Canna', 'T1', DATE '2019-11-26', DATE '2021-11-16'),
        ('Roach', 'T1', DATE '2019-11-26', DATE '2020-11-17'),
        ('Ellim', 'T1', DATE '2019-11-26', DATE '2021-11-16'),
        ('Cuzz', 'T1', DATE '2019-11-26', DATE '2021-11-16'),
        ('Faker', 'T1', DATE '2013-02-13', NULL),
        ('Clozer', 'T1', DATE '2020-05-26', DATE '2021-11-16'),
        ('Teddy', 'T1', DATE '2018-11-22', DATE '2021-11-16'),
        ('Gumayusi', 'T1', DATE '2019-11-26', DATE '2025-11-17'),
        ('Effort', 'T1', DATE '2017-11-29', DATE '2020-11-17'),
        ('Kuri', 'T1', DATE '2019-11-26', DATE '2020-11-17'),
        ('Zeus', 'T1', DATE '2020-11-26', DATE '2024-11-19'),
        ('Oner', 'T1', DATE '2020-12-02', NULL),
        ('Keria', 'T1', DATE '2020-11-18', NULL),
        ('Doran', 'T1', DATE '2024-11-19', NULL),
        ('Smash', 'T1', DATE '2025-02-08', DATE '2025-05-04'),
        ('Peyz', 'T1', DATE '2025-11-19', NULL),

        -- Gen.G: 2020년 기존 로스터부터 2026년 현재 로스터까지
        ('CuVee', 'Gen.G', DATE '2017-11-30', DATE '2020-11-17'),
        ('Rascal', 'Gen.G', DATE '2019-11-20', DATE '2021-11-15'),
        ('Clid', 'Gen.G', DATE '2019-11-20', DATE '2021-11-15'),
        ('Flawless', 'Gen.G', DATE '2020-05-29', DATE '2020-11-17'),
        ('Bdd', 'Gen.G', DATE '2019-11-20', DATE '2021-11-15'),
        ('Ruler', 'Gen.G', DATE '2017-11-30', DATE '2022-11-10'),
        ('Ruler', 'Gen.G', DATE '2024-11-20', NULL),
        ('Life', 'Gen.G', DATE '2018-05-08', DATE '2021-11-15'),
        ('Kellin', 'Gen.G', DATE '2019-11-20', DATE '2020-11-17'),
        ('Burdol', 'Gen.G', DATE '2020-05-29', DATE '2021-11-15'),
        ('Karis', 'Gen.G', DATE '2020-05-29', DATE '2021-11-15'),
        ('Doran', 'Gen.G', DATE '2021-11-23', DATE '2023-11-21'),
        ('Peanut', 'Gen.G', DATE '2021-11-23', DATE '2023-11-21'),
        ('Chovy', 'Gen.G', DATE '2021-11-24', NULL),
        ('Lehends', 'Gen.G', DATE '2021-11-24', DATE '2022-11-22'),
        ('Lehends', 'Gen.G', DATE '2023-11-29', DATE '2024-11-19'),
        ('Peyz', 'Gen.G', DATE '2022-11-23', DATE '2024-11-19'),
        ('Delight', 'Gen.G', DATE '2022-11-23', DATE '2023-11-21'),
        ('Kiin', 'Gen.G', DATE '2023-11-29', NULL),
        ('Canyon', 'Gen.G', DATE '2023-11-29', NULL),
        ('Duro', 'Gen.G', DATE '2024-11-20', NULL),

        -- Dplus KIA: DAMWON Gaming과 DWG KIA 시기의 같은 팀 계보를 현재 이름으로 통합
        ('Nuguri', 'Dplus KIA', DATE '2017-05-28', DATE '2020-11-17'),
        ('Nuguri', 'Dplus KIA', DATE '2022-04-20', DATE '2022-11-28'),
        ('Flame', 'Dplus KIA', DATE '2019-02-18', DATE '2020-11-17'),
        ('Canyon', 'Dplus KIA', DATE '2018-09-13', DATE '2023-11-21'),
        ('ShowMaker', 'Dplus KIA', DATE '2017-11-17', NULL),
        ('Ghost', 'Dplus KIA', DATE '2020-02-24', DATE '2021-11-19'),
        ('Nuclear', 'Dplus KIA', DATE '2018-05-05', DATE '2020-11-17'),
        ('BeryL', 'Dplus KIA', DATE '2017-05-28', DATE '2021-11-19'),
        ('BeryL', 'Dplus KIA', DATE '2024-11-20', DATE '2025-11-17'),
        ('Hoit', 'Dplus KIA', DATE '2017-05-28', DATE '2020-11-17'),
        ('Khan', 'Dplus KIA', DATE '2020-11-27', DATE '2021-11-19'),
        ('Malrang', 'Dplus KIA', DATE '2020-12-01', DATE '2021-11-19'),
        ('RangJun', 'Dplus KIA', DATE '2020-12-01', DATE '2021-11-19'),
        ('Burdol', 'Dplus KIA', DATE '2021-12-01', DATE '2022-11-15'),
        ('Hoya', 'Dplus KIA', DATE '2021-12-01', DATE '2022-06-01'),
        ('deokdam', 'Dplus KIA', DATE '2021-12-01', DATE '2022-11-15'),
        ('Kellin', 'Dplus KIA', DATE '2021-12-01', DATE '2024-11-19'),
        ('Canna', 'Dplus KIA', DATE '2022-11-23', DATE '2023-11-21'),
        ('Deft', 'Dplus KIA', DATE '2022-11-23', DATE '2023-11-21'),
        ('Bible', 'Dplus KIA', DATE '2023-02-01', DATE '2023-11-21'),
        ('Thanatos', 'Dplus KIA', DATE '2023-06-01', DATE '2023-11-21'),
        ('Kingen', 'Dplus KIA', DATE '2023-11-23', DATE '2024-11-19'),
        ('Lucid', 'Dplus KIA', DATE '2023-11-23', NULL),
        ('Aiming', 'Dplus KIA', DATE '2023-11-23', DATE '2025-11-17'),
        ('Rahel', 'Dplus KIA', DATE '2024-06-01', DATE '2024-11-19'),
        ('Siwoo', 'Dplus KIA', DATE '2024-11-20', NULL),
        ('Smash', 'Dplus KIA', DATE '2025-11-19', NULL),
        ('Career', 'Dplus KIA', DATE '2025-11-19', NULL),

        -- Hanwha Life Esports: 공식 1군 후보와 시즌 중 콜업을 포함
        ('CuVee', 'Hanwha Life Esports', DATE '2019-11-27', DATE '2020-11-16'),
        ('DuDu', 'Hanwha Life Esports', DATE '2020-05-11', DATE '2022-11-22'),
        ('Haru', 'Hanwha Life Esports', DATE '2019-11-27', DATE '2020-11-16'),
        ('CaD', 'Hanwha Life Esports', DATE '2020-05-11', DATE '2020-11-16'),
        ('Lava', 'Hanwha Life Esports', DATE '2018-04-16', DATE '2020-11-16'),
        ('Mireu', 'Hanwha Life Esports', DATE '2019-11-27', DATE '2020-11-16'),
        ('Tempt', 'Hanwha Life Esports', DATE '2018-04-16', DATE '2020-05-10'),
        ('Zenit', 'Hanwha Life Esports', DATE '2019-11-27', DATE '2020-05-10'),
        ('Viper', 'Hanwha Life Esports', DATE '2020-05-18', DATE '2020-11-16'),
        ('Viper', 'Hanwha Life Esports', DATE '2022-11-22', DATE '2025-11-17'),
        ('Lehends', 'Hanwha Life Esports', DATE '2019-11-27', DATE '2020-11-16'),
        ('Asper', 'Hanwha Life Esports', DATE '2020-05-11', DATE '2020-11-16'),
        ('Morgan', 'Hanwha Life Esports', DATE '2020-11-23', DATE '2021-11-15'),
        ('Arthur', 'Hanwha Life Esports', DATE '2020-11-23', DATE '2021-11-15'),
        ('yoHan', 'Hanwha Life Esports', DATE '2020-11-23', DATE '2021-11-15'),
        ('Chovy', 'Hanwha Life Esports', DATE '2020-11-24', DATE '2021-11-15'),
        ('Deft', 'Hanwha Life Esports', DATE '2020-11-24', DATE '2021-11-15'),
        ('Vsta', 'Hanwha Life Esports', DATE '2020-05-11', DATE '2022-11-22'),
        ('Willer', 'Hanwha Life Esports', DATE '2021-07-01', DATE '2022-11-22'),
        ('OnFleek', 'Hanwha Life Esports', DATE '2021-12-07', DATE '2022-11-22'),
        ('Karis', 'Hanwha Life Esports', DATE '2021-12-07', DATE '2022-11-22'),
        ('SamD', 'Hanwha Life Esports', DATE '2021-12-07', DATE '2022-11-22'),
        ('Cheoni', 'Hanwha Life Esports', DATE '2022-06-01', DATE '2022-11-22'),
        ('Kingen', 'Hanwha Life Esports', DATE '2022-11-22', DATE '2023-11-20'),
        ('Clid', 'Hanwha Life Esports', DATE '2022-11-22', DATE '2023-06-27'),
        ('Grizzly', 'Hanwha Life Esports', DATE '2023-06-27', DATE '2023-11-20'),
        ('Zeka', 'Hanwha Life Esports', DATE '2022-11-22', NULL),
        ('Life', 'Hanwha Life Esports', DATE '2022-11-22', DATE '2023-11-20'),
        ('Doran', 'Hanwha Life Esports', DATE '2023-11-21', DATE '2024-11-19'),
        ('Peanut', 'Hanwha Life Esports', DATE '2023-11-21', DATE '2025-11-17'),
        ('Delight', 'Hanwha Life Esports', DATE '2023-11-21', NULL),
        ('Zeus', 'Hanwha Life Esports', DATE '2024-11-20', NULL),
        ('Kanavi', 'Hanwha Life Esports', DATE '2025-11-19', NULL),
        ('Gumayusi', 'Hanwha Life Esports', DATE '2025-11-19', NULL),

        -- KT Rolster: 2020년부터 2026년 현재까지의 공식 1군 이력
        ('SoHwan', 'KT Rolster', DATE '2019-11-18', DATE '2020-11-16'),
        ('Ray', 'KT Rolster', DATE '2019-11-18', DATE '2020-05-20'),
        ('Smeb', 'KT Rolster', DATE '2020-05-29', DATE '2020-11-16'),
        ('bonO', 'KT Rolster', DATE '2019-11-18', DATE '2020-11-16'),
        ('Malrang', 'KT Rolster', DATE '2019-11-18', DATE '2020-11-16'),
        ('Kuro', 'KT Rolster', DATE '2019-11-18', DATE '2020-11-16'),
        ('Ucal', 'KT Rolster', DATE '2020-05-27', DATE '2021-11-15'),
        ('Aiming', 'KT Rolster', DATE '2019-11-18', DATE '2020-11-16'),
        ('Aiming', 'KT Rolster', DATE '2021-12-01', DATE '2023-11-21'),
        ('Aiming', 'KT Rolster', DATE '2025-11-19', NULL),
        ('Tusin', 'KT Rolster', DATE '2019-11-18', DATE '2020-11-16'),
        ('Doran', 'KT Rolster', DATE '2020-11-27', DATE '2021-11-15'),
        ('Blank', 'KT Rolster', DATE '2020-11-27', DATE '2021-11-15'),
        ('GIDEON', 'KT Rolster', DATE '2020-11-27', DATE '2021-11-15'),
        ('Dove', 'KT Rolster', DATE '2020-11-27', DATE '2021-11-15'),
        ('HyBriD', 'KT Rolster', DATE '2020-11-27', DATE '2021-06-01'),
        ('Noah', 'KT Rolster', DATE '2021-06-01', DATE '2021-11-15'),
        ('5kid', 'KT Rolster', DATE '2021-07-01', DATE '2021-11-15'),
        ('Zzus', 'KT Rolster', DATE '2020-11-27', DATE '2021-06-01'),
        ('Harp', 'KT Rolster', DATE '2021-06-01', DATE '2021-11-15'),
        ('Rascal', 'KT Rolster', DATE '2021-12-01', DATE '2022-11-22'),
        ('Cuzz', 'KT Rolster', DATE '2021-12-01', DATE '2023-11-21'),
        ('Cuzz', 'KT Rolster', DATE '2024-11-20', NULL),
        ('Aria', 'KT Rolster', DATE '2021-12-01', DATE '2022-06-01'),
        ('VicLa', 'KT Rolster', DATE '2022-02-01', DATE '2022-11-22'),
        ('Life', 'KT Rolster', DATE '2021-12-01', DATE '2022-11-22'),
        ('Kiin', 'KT Rolster', DATE '2022-11-23', DATE '2023-11-21'),
        ('Bdd', 'KT Rolster', DATE '2022-11-23', NULL),
        ('Lehends', 'KT Rolster', DATE '2022-11-23', DATE '2023-11-21'),
        ('PerfecT', 'KT Rolster', DATE '2023-11-27', NULL),
        ('Pyosik', 'KT Rolster', DATE '2023-11-30', DATE '2024-11-19'),
        ('Deft', 'KT Rolster', DATE '2023-11-30', DATE '2024-11-19'),
        ('BeryL', 'KT Rolster', DATE '2023-11-30', DATE '2024-11-19'),
        ('deokdam', 'KT Rolster', DATE '2024-11-20', DATE '2025-11-17'),
        ('Way', 'KT Rolster', DATE '2024-11-20', DATE '2025-11-17'),
        ('Pollu', 'KT Rolster', DATE '2025-11-19', NULL)
)
INSERT INTO player_team_history (player_id, team_id, joined_date, left_date)
SELECT player.id, team.id, history_data.joined_date, history_data.left_date
FROM history_data
INNER JOIN player ON player.summoner_name = history_data.summoner_name
INNER JOIN team ON team.name = history_data.team_name;

-- UPDATE와 DELETE 실습 전용 행이다.
-- 2099년의 종료된 가상 이력이므로 실제 현재 소속 조회와 실제 로스터를 훼손하지 않는다.
INSERT INTO player_team_history (player_id, team_id, joined_date, left_date)
SELECT player.id, team.id, DATE '2099-01-01', DATE '2099-01-01'
FROM player
INNER JOIN team ON team.name = 'KT Rolster'
WHERE player.summoner_name = 'Faker';

-- 종료된 공식 LCK 최상위 국내 대회만 입력한다.
-- 2025년부터 연중 단일 Season 체제로 바뀐 대회는 OTHER로 분류한다.
INSERT INTO tournament (name, season_year, split, start_date, end_date) VALUES
    ('2020 LCK Spring', 2020, 'SPRING', DATE '2020-02-05', DATE '2020-04-25'),
    ('2020 LCK Summer', 2020, 'SUMMER', DATE '2020-06-17', DATE '2020-09-05'),
    ('2021 LCK Spring', 2021, 'SPRING', DATE '2021-01-13', DATE '2021-04-10'),
    ('2021 LCK Summer', 2021, 'SUMMER', DATE '2021-06-09', DATE '2021-08-28'),
    ('2022 LCK Spring', 2022, 'SPRING', DATE '2022-01-12', DATE '2022-04-02'),
    ('2022 LCK Summer', 2022, 'SUMMER', DATE '2022-06-15', DATE '2022-08-28'),
    ('2023 LCK Spring', 2023, 'SPRING', DATE '2023-01-18', DATE '2023-04-09'),
    ('2023 LCK Summer', 2023, 'SUMMER', DATE '2023-06-07', DATE '2023-08-20'),
    ('2024 LCK Spring', 2024, 'SPRING', DATE '2024-01-17', DATE '2024-04-14'),
    ('2024 LCK Summer', 2024, 'SUMMER', DATE '2024-06-12', DATE '2024-09-08'),
    ('2025 LCK Cup', 2025, 'CUP', DATE '2025-01-15', DATE '2025-02-23'),
    ('2025 LCK Season', 2025, 'OTHER', DATE '2025-04-02', DATE '2025-09-28'),
    ('2026 LCK Cup', 2026, 'CUP', DATE '2026-01-14', DATE '2026-03-01');

-- 우승이 확정된 대회를 해당 우승팀과 championship으로 연결한다.
-- 2020 Summer의 DAMWON, 2021의 DWG KIA 우승은 현재 대표명 Dplus KIA로 통합한다.
WITH winner_data (season_year, split, team_name) AS (
    VALUES
        (2020, 'SPRING', 'T1'),
        (2020, 'SUMMER', 'Dplus KIA'),
        (2021, 'SPRING', 'Dplus KIA'),
        (2021, 'SUMMER', 'Dplus KIA'),
        (2022, 'SPRING', 'T1'),
        (2022, 'SUMMER', 'Gen.G'),
        (2023, 'SPRING', 'Gen.G'),
        (2023, 'SUMMER', 'Gen.G'),
        (2024, 'SPRING', 'Gen.G'),
        (2024, 'SUMMER', 'Hanwha Life Esports'),
        (2025, 'CUP', 'Hanwha Life Esports'),
        (2025, 'OTHER', 'Gen.G'),
        (2026, 'CUP', 'Gen.G')
)
INSERT INTO championship (tournament_id, winner_team_id)
SELECT tournament.id, team.id
FROM winner_data
INNER JOIN tournament
    ON tournament.season_year = winner_data.season_year
   AND tournament.split = winner_data.split
INNER JOIN team ON team.name = winner_data.team_name;
