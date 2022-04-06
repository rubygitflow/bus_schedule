--
-- PostgreSQL database dump
--

-- Dumped from database version 12.7 (Ubuntu 12.7-0ubuntu0.20.10.1)
-- Dumped by pg_dump version 12.7 (Ubuntu 12.7-0ubuntu0.20.10.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: full_schedule(); Type: FUNCTION; Schema: public; Owner: dekan
--

CREATE FUNCTION public.full_schedule() RETURNS TABLE(route character varying, departure_city character varying, arrival_city character varying, full_time interval)
    LANGUAGE plpgsql
    AS $$
	BEGIN
		return query (
			-- Написать запрос, получающий список всех рейсов с городом отправления, городом прибытия и общим временем в пути.
			select r.name as route, 
			c_dep.name as departure_city, c_arr.name as arrival_city,
			justify_interval(
				(interval '24 hours' * (s_arr.arrival_day - s_dep.departure_day - 1)) +
				(interval '24 hours' - s_dep.departure_time::interval) + s_arr.arrival_time::interval
			) as full_time
			from routes as r
			join schedules as s_dep
			on s_dep.route_id = r.id
			join schedules as s_arr
			on s_arr.route_id = r.id
			join cities as c_dep
			on c_dep.id = s_dep.city_id 
			join cities as c_arr
			on c_arr.id = s_arr.city_id 
			where s_dep.arrival_day is null
			and s_arr.departure_day is null
		);
	END;
$$;


ALTER FUNCTION public.full_schedule() OWNER TO dekan;

--
-- Name: route_variants(character varying, character varying, date); Type: FUNCTION; Schema: public; Owner: dekan
--

CREATE FUNCTION public.route_variants(departure_city character varying, arrival_city character varying, at_date date) RETURNS TABLE(route character varying, full_time interval, stop_number integer)
    LANGUAGE plpgsql
    AS $$
	begin
		return query (
			-- Написать запрос, который по заданной дате, городу отправления и городу прибытия выведет 
			-- список возможных рейсов, количество остановок и общее время между этими городами.
			select 
			r.name as route, ss.full_time, (count(s.route_id) - 2)::int as stop_number
			from schedules as s
			join (
				select s_dep.route_id,
				s_dep.departure_day, s_dep.departure_time,
				s_arr.arrival_day, s_arr.arrival_time,
				justify_interval(
					(interval '24 hours' * (s_arr.arrival_day - s_dep.departure_day - 1)) +
					(interval '24 hours' - s_dep.departure_time::interval) + s_arr.arrival_time::interval
				) as full_time
				from routes as r
				join schedules as s_dep
				on s_dep.route_id = r.id
				join schedules as s_arr
				on s_arr.route_id = r.id
				join cities as c_dep
				on c_dep.id = s_dep.city_id 
				join cities as c_arr
				on c_arr.id = s_arr.city_id 
				where not s_dep.departure_day is null
				and not s_arr.arrival_day is null
				and c_dep.name = departure_city
				and c_arr.name = arrival_city
			) as ss
			on ss.route_id = s.route_id
			join routes as r
			on s.route_id = r.id
			join cities as c
			on s.city_id = c.id
			where r.season_start <= at_date
			and r.season_end >= at_date
			and (
			(
			    (
					s.departure_day > ss.departure_day 
			    ) or (
					s.departure_day = ss.departure_day 
					and
				    s.departure_time >= ss.departure_time
			    ) or (
			    	s.departure_day is null
			    ) 
			) and (
			    (
				    s.arrival_day < ss.arrival_day 
			    ) or (
				    s.arrival_day = ss.arrival_day 
				    and
				    s.arrival_time <= ss.arrival_time
			    ) or (
			    	s.arrival_day is null
				)
			)
			    )
			GROUP BY route, ss.full_time
		);
	END;
$$;


ALTER FUNCTION public.route_variants(departure_city character varying, arrival_city character varying, at_date date) OWNER TO dekan;

--
-- Name: selected_route(character varying, character varying, date); Type: FUNCTION; Schema: public; Owner: dekan
--

CREATE FUNCTION public.selected_route(departure_city character varying, arrival_city character varying, at_date date) RETURNS TABLE(id bigint, city character varying, arrival_day integer, arrival_time time without time zone, departure_day integer, departure_time time without time zone)
    LANGUAGE plpgsql
    AS $$
	begin
		return query (
			-- Написать запрос, которые по заданной дате, городу отправления и городу прибытия выведет нумерованный список промежуточных городов:
			-- № остановки, город, время прибытия, время отбытия (включая конечную и начальную точки).
			select row_number()  OVER() as id,
			c.name as city,
			s.arrival_day, s.arrival_time,
			s.departure_day, s.departure_time
			from schedules as s
			join (
				select s_dep.route_id
				from routes as r
				join schedules as s_dep
				on s_dep.route_id = r.id
				join schedules as s_arr
				on s_arr.route_id = r.id
				join cities as c_dep
				on c_dep.id = s_dep.city_id 
				join cities as c_arr
				on c_arr.id = s_arr.city_id 
				where s_dep.arrival_day is null
				and s_arr.departure_day is null
				and c_dep.name = departure_city
				and c_arr.name = arrival_city
			) as ss
			on ss.route_id = s.route_id
			join routes as r
			on s.route_id = r.id
			join cities as c
			on s.city_id = c.id
			where r.season_start <= at_date
			and r.season_end >= at_date
			order by s.route_id, s.arrival_day asc NULLS first, 
			s.departure_day asc NULLS LAST, s.arrival_time asc NULLS first
		);
	END;
$$;


ALTER FUNCTION public.selected_route(departure_city character varying, arrival_city character varying, at_date date) OWNER TO dekan;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: cities; Type: TABLE; Schema: public; Owner: dekan
--

CREATE TABLE public.cities (
    id bigint NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE public.cities OWNER TO dekan;

--
-- Name: cities_id_seq; Type: SEQUENCE; Schema: public; Owner: dekan
--

CREATE SEQUENCE public.cities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cities_id_seq OWNER TO dekan;

--
-- Name: cities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dekan
--

ALTER SEQUENCE public.cities_id_seq OWNED BY public.cities.id;


--
-- Name: routes; Type: TABLE; Schema: public; Owner: dekan
--

CREATE TABLE public.routes (
    id bigint NOT NULL,
    name character varying NOT NULL,
    seats_number integer DEFAULT 0,
    season_start date,
    season_end date
);


ALTER TABLE public.routes OWNER TO dekan;

--
-- Name: routes_id_seq; Type: SEQUENCE; Schema: public; Owner: dekan
--

CREATE SEQUENCE public.routes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.routes_id_seq OWNER TO dekan;

--
-- Name: routes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dekan
--

ALTER SEQUENCE public.routes_id_seq OWNED BY public.routes.id;


--
-- Name: schedules; Type: TABLE; Schema: public; Owner: dekan
--

CREATE TABLE public.schedules (
    id bigint NOT NULL,
    city_id bigint NOT NULL,
    route_id bigint NOT NULL,
    arrival_day integer,
    departure_day integer,
    arrival_time time(0) without time zone,
    departure_time time(0) without time zone
);


ALTER TABLE public.schedules OWNER TO dekan;

--
-- Name: schedules_city_id_seq; Type: SEQUENCE; Schema: public; Owner: dekan
--

CREATE SEQUENCE public.schedules_city_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.schedules_city_id_seq OWNER TO dekan;

--
-- Name: schedules_city_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dekan
--

ALTER SEQUENCE public.schedules_city_id_seq OWNED BY public.schedules.city_id;


--
-- Name: schedules_id_seq; Type: SEQUENCE; Schema: public; Owner: dekan
--

CREATE SEQUENCE public.schedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.schedules_id_seq OWNER TO dekan;

--
-- Name: schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dekan
--

ALTER SEQUENCE public.schedules_id_seq OWNED BY public.schedules.id;


--
-- Name: schedules_route_id_seq; Type: SEQUENCE; Schema: public; Owner: dekan
--

CREATE SEQUENCE public.schedules_route_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.schedules_route_id_seq OWNER TO dekan;

--
-- Name: schedules_route_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dekan
--

ALTER SEQUENCE public.schedules_route_id_seq OWNED BY public.schedules.route_id;


--
-- Name: cities id; Type: DEFAULT; Schema: public; Owner: dekan
--

ALTER TABLE ONLY public.cities ALTER COLUMN id SET DEFAULT nextval('public.cities_id_seq'::regclass);


--
-- Name: routes id; Type: DEFAULT; Schema: public; Owner: dekan
--

ALTER TABLE ONLY public.routes ALTER COLUMN id SET DEFAULT nextval('public.routes_id_seq'::regclass);


--
-- Name: schedules id; Type: DEFAULT; Schema: public; Owner: dekan
--

ALTER TABLE ONLY public.schedules ALTER COLUMN id SET DEFAULT nextval('public.schedules_id_seq'::regclass);


--
-- Name: schedules city_id; Type: DEFAULT; Schema: public; Owner: dekan
--

ALTER TABLE ONLY public.schedules ALTER COLUMN city_id SET DEFAULT nextval('public.schedules_city_id_seq'::regclass);


--
-- Name: schedules route_id; Type: DEFAULT; Schema: public; Owner: dekan
--

ALTER TABLE ONLY public.schedules ALTER COLUMN route_id SET DEFAULT nextval('public.schedules_route_id_seq'::regclass);


--
-- Data for Name: cities; Type: TABLE DATA; Schema: public; Owner: dekan
--

COPY public.cities (id, name) FROM stdin;
1	mos
2	spb
3	yar
4	tve
5	vol
6	pzk
7	vnov
8	vor
\.


--
-- Data for Name: routes; Type: TABLE DATA; Schema: public; Owner: dekan
--

COPY public.routes (id, name, seats_number, season_start, season_end) FROM stdin;
1	1 mos - spb	50	2022-01-01	2022-12-31
3	3 mos - vol	65	2022-04-01	2022-09-30
4	4 mos - yar	60	2022-05-31	2022-08-31
5	5 pzk - mos	55	2022-04-15	2022-10-15
2	2 vor - pzk	70	2022-03-31	2022-10-01
\.


--
-- Data for Name: schedules; Type: TABLE DATA; Schema: public; Owner: dekan
--

COPY public.schedules (id, city_id, route_id, arrival_day, departure_day, arrival_time, departure_time) FROM stdin;
1	1	1	\N	0	\N	09:00:00
2	4	1	0	0	11:00:00	11:30:00
3	2	1	0	\N	22:00:00	\N
5	4	2	0	0	12:45:00	13:00:00
6	2	2	1	1	00:15:00	00:30:00
7	1	3	\N	0	\N	23:00:00
8	6	2	1	\N	08:00:00	\N
9	3	3	1	1	07:00:00	07:30:00
10	5	3	1	\N	11:00:00	\N
11	1	4	\N	0	\N	10:00:00
12	3	4	0	\N	17:00:00	\N
13	6	5	\N	0	\N	18:00:00
14	5	5	1	1	10:00:00	11:00:00
15	3	5	1	1	18:00:00	19:00:00
16	1	5	2	\N	00:15:00	\N
17	7	2	0	0	23:00:00	23:30:00
18	8	2	\N	0	\N	01:00:00
4	1	2	0	0	10:00:00	11:00:00
\.


--
-- Name: cities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: dekan
--

SELECT pg_catalog.setval('public.cities_id_seq', 6, true);


--
-- Name: routes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: dekan
--

SELECT pg_catalog.setval('public.routes_id_seq', 6, true);


--
-- Name: schedules_city_id_seq; Type: SEQUENCE SET; Schema: public; Owner: dekan
--

SELECT pg_catalog.setval('public.schedules_city_id_seq', 1, true);


--
-- Name: schedules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: dekan
--

SELECT pg_catalog.setval('public.schedules_id_seq', 11, true);


--
-- Name: schedules_route_id_seq; Type: SEQUENCE SET; Schema: public; Owner: dekan
--

SELECT pg_catalog.setval('public.schedules_route_id_seq', 1, true);


--
-- Name: cities cities_pkey; Type: CONSTRAINT; Schema: public; Owner: dekan
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (id);


--
-- Name: routes routes_pkey; Type: CONSTRAINT; Schema: public; Owner: dekan
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT routes_pkey PRIMARY KEY (id);


--
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: dekan
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (id);


--
-- Name: cities_name_idx; Type: INDEX; Schema: public; Owner: dekan
--

CREATE UNIQUE INDEX cities_name_idx ON public.cities USING btree (name);


--
-- Name: routes_name_idx; Type: INDEX; Schema: public; Owner: dekan
--

CREATE UNIQUE INDEX routes_name_idx ON public.routes USING btree (name);


--
-- Name: schedules schedules_fk_city; Type: FK CONSTRAINT; Schema: public; Owner: dekan
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_fk_city FOREIGN KEY (city_id) REFERENCES public.cities(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: schedules schedules_fk_route; Type: FK CONSTRAINT; Schema: public; Owner: dekan
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_fk_route FOREIGN KEY (route_id) REFERENCES public.routes(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

