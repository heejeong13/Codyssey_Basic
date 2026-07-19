-- 이 파일은 LCK 팀, 선수, 소속 이력, 대회, 우승을 관리할 5개 테이블을 만든다.
-- 테이블은 참조되는 부모 테이블부터 생성해 외래 키가 올바르게 연결되게 한다.
-- PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK는 잘못된 데이터가 들어오는 것을 DB가 막도록 한다.

-- team은 2026년 LCK 10개 팀의 현재 대표 이름과 상태를 저장한다.
-- GENERATED ALWAYS AS IDENTITY는 PostgreSQL이 1부터 증가하는 id를 자동으로 발급한다.
CREATE TABLE team (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name varchar(100) NOT NULL UNIQUE,
    short_name varchar(10) NOT NULL UNIQUE,
    founded_date date,
    status varchar(10) NOT NULL,
    -- 현재 과제에서는 모두 ACTIVE지만 허용되지 않은 오타가 들어가지 않도록 제한한다.
    CONSTRAINT team_status_check CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

-- player는 선수를 팀과 분리해 한 번만 저장한다.
-- 선수가 이적해도 개인 행을 복제하지 않고 player_team_history에 새 기간을 추가한다.
CREATE TABLE player (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    summoner_name varchar(50) NOT NULL UNIQUE,
    real_name varchar(100) NOT NULL,
    position varchar(10) NOT NULL,
    -- LoL의 공식 다섯 포지션 이외의 값이 입력되는 것을 막는다.
    CONSTRAINT player_position_check
        CHECK (position IN ('TOP', 'JUNGLE', 'MID', 'ADC', 'SUPPORT'))
);

-- tournament는 2020년 이후 열린 LCK 최상위 국내 대회를 저장한다.
-- 아직 종료되지 않은 대회는 이 프로젝트에 넣지 않으므로 end_date도 필수다.
CREATE TABLE tournament (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name varchar(100) NOT NULL,
    season_year integer NOT NULL,
    split varchar(10) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    -- 같은 연도에 같은 split 대회가 두 번 입력되는 중복을 막는다.
    CONSTRAINT tournament_year_split_unique UNIQUE (season_year, split),
    CONSTRAINT tournament_split_check CHECK (split IN ('SPRING', 'SUMMER', 'CUP', 'OTHER')),
    CONSTRAINT tournament_year_check CHECK (season_year BETWEEN 2020 AND 2100),
    -- 대회 종료일이 시작일보다 앞서는 잘못된 기간을 막는다.
    CONSTRAINT tournament_dates_check CHECK (end_date >= start_date)
);

-- player_team_history는 선수와 팀을 연결하고 각 소속 기간을 저장한다.
-- 한 선수는 여러 팀 이력을, 한 팀은 여러 선수 이력을 가질 수 있으므로 두 1:N 관계를 만든다.
CREATE TABLE player_team_history (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    player_id integer NOT NULL,
    team_id integer NOT NULL,
    joined_date date NOT NULL,
    left_date date,
    CONSTRAINT history_player_fk
        FOREIGN KEY (player_id) REFERENCES player (id),
    CONSTRAINT history_team_fk
        FOREIGN KEY (team_id) REFERENCES team (id),
    -- 같은 선수, 팀, 입단일의 동일 기간이 두 번 입력되는 것을 막는다.
    -- 재합류했다면 joined_date가 다르므로 별도의 행으로 저장할 수 있다.
    CONSTRAINT history_period_unique UNIQUE (player_id, team_id, joined_date),
    -- left_date가 NULL이면 현재 소속이고, 값이 있으면 입단일보다 빠를 수 없다.
    CONSTRAINT history_dates_check CHECK (left_date IS NULL OR left_date >= joined_date)
);

-- championship은 한 대회의 우승팀만 저장한다.
-- 우승이 확정되지 않은 대회에는 행이 없으며, 확정된 대회는 한 팀만 연결된다.
CREATE TABLE championship (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tournament_id integer NOT NULL UNIQUE,
    winner_team_id integer NOT NULL,
    CONSTRAINT championship_tournament_fk
        FOREIGN KEY (tournament_id) REFERENCES tournament (id),
    CONSTRAINT championship_team_fk
        FOREIGN KEY (winner_team_id) REFERENCES team (id)
);

-- UNIQUE 컬럼과 PRIMARY KEY에는 PostgreSQL이 인덱스를 자동 생성한다.
-- 아래 인덱스는 그와 중복되지 않으며 실제 필터, JOIN, 정렬에 사용하는 열을 보완한다.

-- 포지션별 선수 검색에 사용한다.
CREATE INDEX idx_player_position ON player (position);

-- PostgreSQL은 FOREIGN KEY에 인덱스를 자동 생성하지 않으므로 양쪽 JOIN 열에 만든다.
-- joined_date를 함께 두어 한 선수의 소속 이력을 시간순으로 찾는 데도 사용한다.
CREATE INDEX idx_history_player_joined
    ON player_team_history (player_id, joined_date);

-- 팀별 현재/역대 선수 조회에서 team_id로 이력을 찾는 데 사용한다.
CREATE INDEX idx_history_team
    ON player_team_history (team_id);

-- 현재 소속은 left_date IS NULL인 일부 행만 자주 조회하므로 작은 부분 인덱스를 만든다.
CREATE INDEX idx_history_current
    ON player_team_history (team_id, player_id)
    WHERE left_date IS NULL;

-- 우승팀을 기준으로 우승 횟수를 집계하거나 대회와 연결할 때 사용한다.
CREATE INDEX idx_championship_winner
    ON championship (winner_team_id);

-- 연도별 대회 조회는 UNIQUE 인덱스의 첫 열을 활용할 수 있다.
-- split 단독 검색도 지원하기 위해 split 인덱스만 별도로 추가한다.
CREATE INDEX idx_tournament_split ON tournament (split);
