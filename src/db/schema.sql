--
-- PostgreSQL database dump
--

\restrict sy03SXkwyNl7nyMsAdj68aTW028EneoO8S4EGUUl9wuh9qAZ0CEFXRCKotVB0Vb

-- Dumped from database version 18.4 (Postgres.app)
-- Dumped by pg_dump version 18.4 (Postgres.app)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: booking_demand; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_demand (
    booking_item_id text NOT NULL,
    space_id text NOT NULL,
    period daterange NOT NULL,
    is_pin boolean NOT NULL
);


--
-- Name: booking_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_items (
    id text NOT NULL,
    booking_id text NOT NULL,
    period daterange NOT NULL,
    kind text NOT NULL,
    target_space_id text NOT NULL,
    assigned_space_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT booking_items_period_not_empty CHECK ((NOT isempty(period)))
);


--
-- Name: bookings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bookings (
    id text NOT NULL,
    organization_id text NOT NULL,
    guest_id text,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: guests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guests (
    id text NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id text NOT NULL,
    user_id text
);


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id text NOT NULL,
    organization_id text NOT NULL,
    user_id text NOT NULL,
    role_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id text NOT NULL,
    slug text NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_permissions (
    role_id text NOT NULL,
    permission text NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id text NOT NULL,
    organization_id text NOT NULL,
    name text NOT NULL,
    is_owner boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    token_hash text NOT NULL,
    user_id text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: spaces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spaces (
    id text NOT NULL,
    organization_id text NOT NULL,
    parent_id text,
    is_grouping boolean NOT NULL,
    label text NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    bookable boolean NOT NULL
);


--
-- Name: user_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_credentials (
    user_id text NOT NULL,
    password_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id text NOT NULL,
    email text NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: booking_demand booking_demand_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_demand
    ADD CONSTRAINT booking_demand_no_overlap EXCLUDE USING gist (space_id WITH =, period WITH &&) WHERE (is_pin);


--
-- Name: booking_items booking_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_items
    ADD CONSTRAINT booking_items_pkey PRIMARY KEY (id);


--
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (id);


--
-- Name: guests guests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guests
    ADD CONSTRAINT guests_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (role_id, permission);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (token_hash);


--
-- Name: spaces spaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spaces
    ADD CONSTRAINT spaces_pkey PRIMARY KEY (id);


--
-- Name: user_credentials user_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_credentials
    ADD CONSTRAINT user_credentials_pkey PRIMARY KEY (user_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: booking_demand_space_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX booking_demand_space_id_idx ON public.booking_demand USING btree (space_id);


--
-- Name: booking_items_booking_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX booking_items_booking_id_idx ON public.booking_items USING btree (booking_id);


--
-- Name: bookings_guest_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bookings_guest_id_idx ON public.bookings USING btree (guest_id);


--
-- Name: bookings_organization_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bookings_organization_id_idx ON public.bookings USING btree (organization_id);


--
-- Name: guests_organization_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX guests_organization_id_idx ON public.guests USING btree (organization_id);


--
-- Name: guests_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX guests_user_id_idx ON public.guests USING btree (user_id);


--
-- Name: memberships_org_user_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX memberships_org_user_key ON public.memberships USING btree (organization_id, user_id);


--
-- Name: memberships_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX memberships_user_id_idx ON public.memberships USING btree (user_id);


--
-- Name: organizations_slug_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX organizations_slug_key ON public.organizations USING btree (slug);


--
-- Name: roles_org_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX roles_org_name_key ON public.roles USING btree (organization_id, name);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_user_id_idx ON public.sessions USING btree (user_id);


--
-- Name: spaces_organization_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX spaces_organization_id_idx ON public.spaces USING btree (organization_id);


--
-- Name: spaces_parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX spaces_parent_id_idx ON public.spaces USING btree (parent_id);


--
-- Name: users_email_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_key ON public.users USING btree (email);


--
-- Name: booking_demand booking_demand_booking_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_demand
    ADD CONSTRAINT booking_demand_booking_item_id_fkey FOREIGN KEY (booking_item_id) REFERENCES public.booking_items(id) ON DELETE CASCADE;


--
-- Name: booking_demand booking_demand_space_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_demand
    ADD CONSTRAINT booking_demand_space_id_fkey FOREIGN KEY (space_id) REFERENCES public.spaces(id);


--
-- Name: booking_items booking_items_assigned_space_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_items
    ADD CONSTRAINT booking_items_assigned_space_id_fkey FOREIGN KEY (assigned_space_id) REFERENCES public.spaces(id);


--
-- Name: booking_items booking_items_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_items
    ADD CONSTRAINT booking_items_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;


--
-- Name: booking_items booking_items_target_space_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_items
    ADD CONSTRAINT booking_items_target_space_id_fkey FOREIGN KEY (target_space_id) REFERENCES public.spaces(id);


--
-- Name: bookings bookings_guest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_guest_id_fkey FOREIGN KEY (guest_id) REFERENCES public.guests(id);


--
-- Name: bookings bookings_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: guests guests_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guests
    ADD CONSTRAINT guests_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: guests guests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guests
    ADD CONSTRAINT guests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: memberships memberships_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: memberships memberships_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: memberships memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: roles roles_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: spaces spaces_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spaces
    ADD CONSTRAINT spaces_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: spaces spaces_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spaces
    ADD CONSTRAINT spaces_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.spaces(id);


--
-- Name: user_credentials user_credentials_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_credentials
    ADD CONSTRAINT user_credentials_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

\unrestrict sy03SXkwyNl7nyMsAdj68aTW028EneoO8S4EGUUl9wuh9qAZ0CEFXRCKotVB0Vb

