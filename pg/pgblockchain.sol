// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Untested first pass at the core of the pg-blockchain contract.
// This contract will be called to convey the transaction and block details from the database blockchain into the
// Topos subnet. It will also be called (and will emit events which the database blockchain sequencer will listen for)
// when a contract wants to query the database or execute transactions on the database.
//
// IT IS CURRENTLY WIP!
//
// This contract is intended to be an illustrative proof-of-concept, and likely has security and performance issues.
// It is not intended to be used in a production environment as-is. Rather, it is intended to be a starting point for
// further development and testing.
contract PgBlockchain {
    // Event emitted when a query is issued
    event QueryIssued(bytes32 indexed queryKey, string query);
    // Event emitted when a result is ready
    event ResultReady(bytes32 indexed queryKey, string result);

    // Struct to hold transaction details
    struct Transaction {
        bytes32 id;
        bytes hash;
    }

    // Struct to hold block details, including an array of transaction IDs
    struct Block {
        bytes32 id;
        bytes32 previousBlockId;
        bytes hash;
        bytes32[] transactionIds;
    }

    // State variables to store transactions and blocks
    mapping(bytes32 => Transaction) public transactions;
    mapping(bytes32 => Block) public blocks;

    // Mapping from queryKey to query result
    mapping(bytes32 => string) private results;

    // Events for logging
    event TransactionAdded(bytes32 indexed id, bytes hash);
    event BlockAdded(
        bytes32 indexed id,
        bytes32 previousBlockId,
        bytes hash,
        bytes32[] transactionIds
    );

    // Function to insert a new transaction
    function insertTransaction(bytes32 _id, bytes calldata _hash) external {
        require(
            transactions[_id].id == bytes32(0),
            "Transaction already exists"
        );
        transactions[_id] = Transaction(_id, _hash);
        emit TransactionAdded(_id, _hash);
    }

    // Function to get a transaction by ID
    function getTransaction(
        bytes32 _id
    ) external view returns (bytes32, bytes memory) {
        return (transactions[_id].id, transactions[_id].hash);
    }

    // Function to insert a new block
    function insertBlock(
        bytes32 _id,
        bytes32 _previousBlockId,
        bytes calldata _hash,
        bytes32[] calldata _transactionIds
    ) external {
        require(blocks[_id].id == bytes32(0), "Block already exists");

        // Verify all transactions exist before adding the block
        for (uint i = 0; i < _transactionIds.length; i++) {
            require(
                transactions[_transactionIds[i]].id != bytes32(0),
                "Transaction does not exist"
            );
        }

        blocks[_id] = Block(_id, _previousBlockId, _hash, _transactionIds);
        emit BlockAdded(_id, _previousBlockId, _hash, _transactionIds);
    }

    // Function to get a block by ID
    function getBlock(
        bytes32 _id
    ) external view returns (bytes32, bytes32, bytes memory, bytes32[] memory) {
        return (
            blocks[_id].id,
            blocks[_id].previousBlockId,
            blocks[_id].hash,
            blocks[_id].transactionIds
        );
    }

    // Function to issue a query
    function issueQuery(string memory query) public returns (bytes32) {
        // Generate a unique key for the query
        bytes32 queryKey = keccak256(
            abi.encodePacked(query, address(this), block.timestamp)
        );
        // Emit the QueryIssued event with the query and unique key
        emit QueryIssued(queryKey, query);
        // Return the unique key
        return queryKey;
    }

    // Function to store the result of a query
    function storeResult(bytes32 queryKey, string memory result) public {
        // Store the result in the mapping
        results[queryKey] = result;
        // Emit the ResultReady event
        emit ResultReady(queryKey, result);
    }

    // Function to retrieve and delete the result of a query
    function retrieveAndDeleteResult(
        bytes32 queryKey
    ) public returns (string memory) {
        // Retrieve the result
        string memory result = results[queryKey];
        // Delete the result from storage
        delete results[queryKey];
        // Return the result
        return result;
    }
}
