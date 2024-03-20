// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Untested first pass at the core of the pg-blockchain contract.
// This contract will be called to convey the transaction and block details from the database blockchain into the
// Topos subnet. It will also be called (and will emit events which the database blockchain sequencer will listen for)
// when a contract wants to query the database or execute transactions on the database.
//
// IT IS CURRENTLY WIP!
/
// This contract is intended to be an illustrative proof-of-concept, and likely has security and performance issues.
// It is not intended to be used in a production environment as-is. Rather, it is intended to be a starting point for
// further development and testing. 
contract PgBlockchain {
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

    // Events for logging
    event TransactionAdded(bytes32 indexed id, bytes hash);
    event BlockAdded(bytes32 indexed id, bytes32 previousBlockId, bytes hash, bytes32[] transactionIds);

    // Function to insert a new transaction
    function insertTransaction(bytes32 _id, bytes calldata _hash) external {
        require(transactions[_id].id == bytes32(0), "Transaction already exists");
        transactions[_id] = Transaction(_id, _hash);
        emit TransactionAdded(_id, _hash);
    }

    // Function to insert a new block
    function insertBlock(bytes32 _id, bytes32 _previousBlockId, bytes calldata _hash, bytes32[] calldata _transactionIds) external {
        require(blocks[_id].id == bytes32(0), "Block already exists");

        // Verify all transactions exist before adding the block
        for(uint i = 0; i < _transactionIds.length; i++) {
            require(transactions[_transactionIds[i]].id != bytes32(0), "Transaction does not exist");
        }

        blocks[_id] = Block(_id,_previousBlockId, _hash, _transactionIds);
        emit BlockAdded(_id, _previousBlockId, _hash, _transactionIds);
    }
}
