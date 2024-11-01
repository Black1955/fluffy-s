--
-- PostgreSQL database dump
--

-- Dumped from database version 15.2
-- Dumped by pg_dump version 15.2

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
-- Name: posts_with_liked; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.posts_with_liked AS (
	id integer,
	title character varying(25),
	description character varying(255),
	likes integer,
	"time" timestamp without time zone,
	img_url character varying(255),
	user_id integer,
	liked boolean
);


ALTER TYPE public.posts_with_liked OWNER TO postgres;

--
-- Name: blogposts(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.blogposts(us_id integer, my_id integer, lim integer, ofset integer) RETURNS SETOF public.posts_with_liked
    LANGUAGE plpgsql
    AS $$
BEGIN 
RETURN QUERY 
SELECT userPosts.*, 
  EXISTS (SELECT 1 FROM likes WHERE user_id = my_id AND post_id = userPosts.id) AS liked
FROM (
  SELECT * 
  FROM posts 
  WHERE user_id = us_id
  ORDER BY time DESC
) AS userPosts limit lim offset ofset;
END;
$$;


ALTER FUNCTION public.blogposts(us_id integer, my_id integer, lim integer, ofset integer) OWNER TO postgres;

--
-- Name: followsposts(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.followsposts(sub_id integer, lim integer, pag integer) RETURNS SETOF public.posts_with_liked
    LANGUAGE plpgsql
    AS $$
BEGIN 
RETURN QUERY select P.*,
EXISTS (SELECT 1 FROM likes WHERE user_id = sub_id and post_id = P.id) as liked
FROM follows F 
INNER JOIN Posts P ON P.user_id = F.target_user_id
WHERE F.subscriber_id = sub_id limit lim offset pag;
END;
$$;


ALTER FUNCTION public.followsposts(sub_id integer, lim integer, pag integer) OWNER TO postgres;

--
-- Name: likedposts(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.likedposts(us_id integer, my_id integer, lim integer, pag integer) RETURNS SETOF public.posts_with_liked
    LANGUAGE plpgsql
    AS $$
BEGIN
   RETURN QUERY SELECT P.*,
CASE
  WHEN my_id = L.user_id AND P.id = L.post_id THEN true
  ELSE false
END AS liked
 FROM likes L 
    INNER JOIN posts P ON L.post_id = P.id
 WHERE L.user_id = us_id limit lim offset pag;
END;
$$;


ALTER FUNCTION public.likedposts(us_id integer, my_id integer, lim integer, pag integer) OWNER TO postgres;

--
-- Name: newposts(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.newposts(us_id integer, my_id integer, lim integer, ofset integer) RETURNS SETOF public.posts_with_liked
    LANGUAGE plpgsql
    AS $$
BEGIN 
RETURN QUERY 
SELECT userPosts.*, 
  EXISTS (SELECT 1 FROM likes WHERE user_id = my_id AND post_id = userPosts.id) AS liked
FROM (
  SELECT * 
  FROM posts
  ORDER BY time DESC
) AS userPosts limit lim offset ofset;
END;
$$;


ALTER FUNCTION public.newposts(us_id integer, my_id integer, lim integer, ofset integer) OWNER TO postgres;

--
-- Name: popularblog(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.popularblog(my_id integer, lim integer, page integer) RETURNS SETOF public.posts_with_liked
    LANGUAGE plpgsql
    AS $$
BEGIN 
  RETURN QUERY 
  SELECT userPosts.*,
    EXISTS (SELECT 1 FROM likes WHERE user_id = my_id AND post_id = userPosts.id) AS liked
  FROM (SELECT * FROM posts ORDER BY likes DESC) AS userPosts
  LIMIT lim OFFSET page;
END;
$$;


ALTER FUNCTION public.popularblog(my_id integer, lim integer, page integer) OWNER TO postgres;

--
-- Name: profile(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.profile(nic character varying) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
DECLARE
    p_id int;
BEGIN
    SELECT id INTO p_id FROM users WHERE nickname = nic;

    RETURN QUERY SELECT * FROM users WHERE id = p_id;
    RETURN QUERY SELECT * FROM posts WHERE user_id = p_id;
END;
$$;


ALTER FUNCTION public.profile(nic character varying) OWNER TO postgres;

--
-- Name: recomendusers(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.recomendusers(us_id integer) RETURNS TABLE(id integer, nickname character varying, description text, avatar_url character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
RETURN QUERY SELECT U.id,U.nickname,U.description,U.avatar_url
FROM (
    SELECT U.id, COUNT(*) as count
    FROM follows F
    INNER JOIN follows O on O.subscriber_id = F.target_user_id
    INNER JOIN users U on U.id = O.target_user_id
    WHERE O.target_user_id <> us_id AND F.subscriber_id = us_id
    AND U.id NOT IN (
        SELECT target_user_id
        FROM follows
        WHERE subscriber_id = us_id
    )
    GROUP BY U.id
    ORDER BY count DESC
) AS sub
JOIN users U on U.id = sub.id;
END;
$$;


ALTER FUNCTION public.recomendusers(us_id integer) OWNER TO postgres;

--
-- Name: setlikes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.setlikes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF(TG_OP = 'INSERT') THEN 
    UPDATE posts SET likes = likes + 1 where posts.id = NEW.post_id;
    ELSIF (TG_OP = 'DELETE') THEN 
    UPDATE posts SET likes = likes - 1 where posts.id = OLD.post_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.setlikes() OWNER TO postgres;

--
-- Name: update_follow_count(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_follow_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE users SET followers = followers + 1 WHERE id = NEW.target_user_id;
    UPDATE users SET following = following + 1 WHERE id = NEW.subscriber_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE users SET followers = followers - 1 WHERE id = OLD.target_user_id;
    UPDATE users SET following = following - 1 WHERE id = OLD.subscriber_id;
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_follow_count() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.comments (
    id integer NOT NULL,
    massage character varying(255),
    post_id integer,
    user_id integer,
    date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.comments OWNER TO postgres;

--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.comments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.comments_id_seq OWNER TO postgres;

--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;


--
-- Name: follows; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.follows (
    subscriber_id integer,
    target_user_id integer,
    CONSTRAINT follows_check CHECK ((target_user_id <> subscriber_id))
);


ALTER TABLE public.follows OWNER TO postgres;

--
-- Name: likes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.likes (
    user_id integer,
    post_id integer
);


ALTER TABLE public.likes OWNER TO postgres;

--
-- Name: pets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pets (
    id integer NOT NULL,
    name character varying(50),
    img_url character varying(255),
    user_id integer
);


ALTER TABLE public.pets OWNER TO postgres;

--
-- Name: pets_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pets_id_seq OWNER TO postgres;

--
-- Name: pets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pets_id_seq OWNED BY public.pets.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    title character varying(25),
    description character varying(255),
    likes integer DEFAULT 0,
    "time" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    img_url character varying(255),
    user_id integer
);


ALTER TABLE public.posts OWNER TO postgres;

--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.posts_id_seq OWNER TO postgres;

--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    nickname character varying(20),
    name character varying(50),
    description text,
    followers integer DEFAULT 0,
    following integer DEFAULT 0,
    avatar_url character varying(255),
    back_url character varying(255),
    email character varying(100),
    password character varying(255)
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);


--
-- Name: pets id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pets ALTER COLUMN id SET DEFAULT nextval('public.pets_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: pets pets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pets
    ADD CONSTRAINT pets_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_nickname_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_nickname_key UNIQUE (nickname);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: follows follows_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER follows_trigger AFTER INSERT OR DELETE ON public.follows FOR EACH ROW EXECUTE FUNCTION public.update_follow_count();


--
-- Name: likes set_likes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_likes AFTER INSERT OR DELETE ON public.likes FOR EACH ROW EXECUTE FUNCTION public.setlikes();


--
-- Name: comments comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: comments comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: follows follows_subscriber_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_subscriber_id_fkey FOREIGN KEY (subscriber_id) REFERENCES public.users(id);


--
-- Name: follows follows_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id);


--
-- Name: likes likes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: likes likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: pets pets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pets
    ADD CONSTRAINT pets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: posts posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

