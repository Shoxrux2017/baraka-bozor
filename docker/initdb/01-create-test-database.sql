-- Creates the database the test suite uses, so that running tests never
-- touches development data.
--
-- PostgreSQL runs every script in /docker-entrypoint-initdb.d exactly once, on
-- an empty data volume. Changing this file has no effect on a volume that
-- already exists; see "Reset the data" in docker/README.md.
--
-- The owner is the same role Compose creates, so Laravel can create and drop
-- tables here without extra grants.

CREATE DATABASE baraka_bozor_test OWNER baraka;
