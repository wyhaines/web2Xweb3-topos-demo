-- Create the blockchain schema, and all associated triggers and functions.
-- Cleanup any old schema
DROP TABLE IF EXISTS transactions CASCADE;

DROP TABLE IF EXISTS blocks CASCADE;

DROP TABLE IF EXISTS vessel_medical_supplies CASCADE;

DROP TABLE IF EXISTS certificates CASCADE;

DROP TABLE IF EXISTS vessels CASCADE;

DROP TABLE IF EXISTS medical_supplies CASCADE;

DROP FUNCTION IF EXISTS generate_hash;

DROP FUNCTION IF EXISTS log_transaction;

DROP FUNCTION IF EXISTS create_block;

DROP FUNCTION IF EXISTS create_genesis_block;

-- Create tables
-- Create the table for storing individual transactions.
CREATE TABLE transactions (
    id uuid DEFAULT uuid_generate_v1mc () NOT NULL PRIMARY KEY,
    seq serial UNIQUE,
    operation_type varchar(10),
    table_name varchar(255),
    transaction_data jsonb,
    transaction_hash varchar(255),
    block_id uuid,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP
);

-- Create the table for storing each block in the chain.
CREATE TABLE blocks (
    id uuid DEFAULT uuid_generate_v1mc () NOT NULL PRIMARY KEY,
    seq serial UNIQUE,
    parent_hash varchar(255),
    parent_id uuid UNIQUE,
    block_data jsonb,
    block_hash varchar(255),
    transactions uuid[],
    created_at timestamp DEFAULT CURRENT_TIMESTAMP
);

-- Create table for storing vessel information.
CREATE TABLE vessels (
    vessel_id serial PRIMARY KEY,
    name varchar(255) NOT NULL,
    imo_number varchar(255) NOT NULL UNIQUE, -- International Maritime Organization number
    flag_country varchar(255) NOT NULL,
    owner_company varchar(255)
);

-- Create table for storing medical supplies information.
CREATE TABLE medical_supplies (
    supply_id serial PRIMARY KEY,
    name varchar(255) NOT NULL,
    description text,
    quantity int DEFAULT 0,
    expiration_date date
);

-- Create table for storing the relationship between vessels and medical supplies.
CREATE TABLE vessel_medical_supplies (
    vessel_id int NOT NULL,
    supply_id int NOT NULL,
    quantity int NOT NULL,
    last_restocked date NOT NULL,
    PRIMARY KEY (vessel_id, supply_id),
    FOREIGN KEY (vessel_id) REFERENCES vessels (vessel_id) ON DELETE CASCADE,
    FOREIGN KEY (supply_id) REFERENCES medical_supplies (supply_id) ON DELETE RESTRICT
);

-- Create table for storing certificates information.
CREATE TABLE certificates (
    certificate_id serial PRIMARY KEY,
    vessel_id int NOT NULL,
    certificate_type varchar(255) NOT NULL,
    issue_date date NOT NULL,
    expiration_date date NOT NULL,
    issuing_authority varchar(255) NOT NULL,
    certificate_details text,
    FOREIGN KEY (vessel_id) REFERENCES vessels (vessel_id) ON DELETE CASCADE
);

-- Function for calculating the hash of a given body of data.
CREATE OR REPLACE FUNCTION generate_hash (data bytea)
    RETURNS text
    AS $$
BEGIN
    RETURN encode(digest(data, 'blake2b512'), 'hex');
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_transaction ()
    RETURNS TRIGGER
    AS $$
DECLARE
    new_id uuid;
    row_data text;
BEGIN
    -- Convert the row data to a JSON string
    row_data := row_to_json(NEW)::text;

    -- Insert the transaction record
    INSERT INTO transactions (operation_type, table_name, transaction_data, transaction_hash)
        VALUES (TG_OP, TG_TABLE_NAME, row_to_json(NEW), generate_hash (convert_to(row_data, 'UTF8')))
    RETURNING
        id INTO new_id;

    -- Send the transaction notification
    PERFORM pg_notify('transaction', new_id::text || '::' || TG_TABLE_NAME || '::' || TG_OP || '::' || row_data);

    -- Return the new row
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

-- Create triggers to log transactions for each table
-- Create a trigger to record the state change as a transaction.
CREATE TRIGGER after_transaction
    AFTER INSERT OR UPDATE OR DELETE ON vessels
    FOR EACH ROW
    EXECUTE FUNCTION log_transaction ();

-- Create a trigger to record the state change as a transaction.
CREATE TRIGGER after_transaction
    AFTER INSERT OR UPDATE OR DELETE ON medical_supplies
    FOR EACH ROW
    EXECUTE FUNCTION log_transaction ();

-- Create a trigger to record the state change as a transaction.
CREATE TRIGGER after_transaction
    AFTER INSERT OR UPDATE OR DELETE ON certificates
    FOR EACH ROW
    EXECUTE FUNCTION log_transaction ();

-- Create a trigger to record the state change as a transaction.
CREATE TRIGGER after_transaction
    AFTER INSERT OR UPDATE OR DELETE ON vessel_medical_supplies
    FOR EACH ROW
    EXECUTE FUNCTION log_transaction ();

-- Function to create the genesis block; this hashes all of the rows currently
-- existing in the specified tables and creates a genesis block for the chain
-- from the hash of all of those rows.
CREATE OR REPLACE FUNCTION create_genesis_block (table_names text[] DEFAULT ARRAY['vessels', 'medical_supplies', 'certificates', 'vessel_medical_supplies'])
    RETURNS void
    AS $$
DECLARE
    -- table_names text[] := ARRAY['vessels', 'medical_supplies', 'certificates', 'vessel_medical_supplies'];
    table_name text;
    row_data text;
    row_hash text;
    combined_hashes text := '';
    final_hash text;
    rec record;
BEGIN
    -- Iterate over each table and hash each row's contents
    FOREACH table_name IN ARRAY table_names LOOP
        FOR rec IN EXECUTE 'SELECT * FROM ' || table_name LOOP
            row_data := row_to_json(rec)::text;
            row_hash := generate_hash (convert_to(row_data, 'UTF8'));
            combined_hashes := combined_hashes || row_hash;
        END LOOP;
    END LOOP;
    -- Generate a final hash for the genesis block using the combined hashes of all rows
    final_hash := generate_hash (convert_to(now()::text || combined_hashes, 'UTF8'));
    -- Insert the genesis block into the blocks table
    INSERT INTO blocks (parent_hash, block_data, block_hash, transactions)
        VALUES (NULL, '{}'::jsonb, final_hash, '{}');
END;
$$
LANGUAGE plpgsql;

INSERT INTO vessels (name, imo_number, flag_country, owner_company)
    VALUES ('Voyager', 'IMO1234567', 'Liberia', 'Global Shipping Co.'), ('Navigator', 'IMO7654321', 'Panama', 'Oceanic Explorers Ltd.'), ('Explorer', 'IMO1928374', 'Malta', 'Maritime Adventures LLC');

INSERT INTO medical_supplies (name, description, quantity, expiration_date)
    VALUES ('Bandages', 'Medical bandages, size M', 100, '2025-12-31'), ('Antiseptic Solution', 'Solution for cleaning wounds', 50, '2024-06-30'), ('Painkillers', 'General use painkillers', 200, '2024-12-31');

INSERT INTO vessel_medical_supplies (vessel_id, supply_id, quantity, last_restocked)
    VALUES (1, 1, 50, '2024-01-01'), (1, 2, 20, '2024-01-01'), (2, 1, 30, '2024-01-02'), (2, 3, 100, '2024-01-02'), (3, 1, 20, '2024-01-03'), (3, 2, 10, '2024-01-03'), (3, 3, 50, '2024-01-03');

INSERT INTO certificates (vessel_id, certificate_type, issue_date, expiration_date, issuing_authority, certificate_details)
    VALUES (1, 'Safety Management', '2023-01-01', '2025-12-31', 'International Maritime Organization', 'Certifies compliance with international safety management code.'), (2, 'Pollution Prevention', '2023-06-15', '2026-06-14', 'Maritime Environmental Protection Agency', 'Certifies vessel meets anti-pollution requirements.'), (3, 'Radio License', '2023-07-01', '2024-06-30', 'Federal Communications Commission', 'Certifies compliance with international radio communication requirements.');

-- This function should be called at regular intervals to create new blocks.
CREATE OR REPLACE FUNCTION create_block ()
    RETURNS void
    AS $$
DECLARE
    new_block_id uuid;
    last_block_id uuid;
    last_block_hash varchar(255);
    transaction_ids uuid[];
    -- Array to hold the transaction IDs
    transaction_hashes text[];
    -- Array to hold the transaction hashes
    combined_hashes text;
    new_block_hash text;
BEGIN
    -- Retrieve the hash of the last block
    SELECT
        id,
        block_hash INTO last_block_id,
        last_block_hash
    FROM
        blocks
    ORDER BY
        seq DESC
    LIMIT 1;

    -- Select the IDs and hashes of the transactions that will be included in the new block
    SELECT
        array_agg(id),
        array_agg(transaction_hash) INTO transaction_ids,
        transaction_hashes
    FROM
        transactions
    WHERE
        block_id IS NULL;
        
    -- If there are no transactions to include, exit the function
    IF transaction_ids IS NULL THEN
        RETURN;
    END IF;
    -- Combine all transaction hashes with the current time to create a unique string
    combined_hashes := now()::text || array_to_string(transaction_hashes, '');
    -- Generate the hash for the new block
    new_block_hash := generate_hash (convert_to(combined_hashes, 'UTF8'));
    -- Insert the new block, including the calculated block hash and the transaction IDs
    INSERT INTO blocks (parent_hash, parent_id, block_data, block_hash, transactions)
        VALUES (last_block_hash, last_block_id, array_to_json(transaction_hashes)::jsonb, new_block_hash, transaction_ids)
    RETURNING
        id INTO new_block_id;

    -- Update the transaction records with the new block ID
    UPDATE
        transactions
    SET
        block_id = new_block_id
    WHERE
        id = ANY (transaction_ids);

    -- Send the block creation notification
    PERFORM pg_notify('block', new_block_id || '::' || new_block_hash);
END;
$$
LANGUAGE plpgsql;

-- Create the genesis block
SELECT
    create_genesis_block ();

