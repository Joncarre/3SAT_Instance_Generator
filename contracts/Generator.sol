// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

/// @title 
/// @author J. Carrero
contract Generator is VRFConsumerBase {
    // Researcher information
    struct Researcher {
        string name;
        string email;
        bool registered;
        uint256[] idInstance;
        uint256[] numberGenerated;
    }
    mapping(uint256 => Researcher) researchers; // secret => researcher

    // Linked information
    struct Link {
        uint256 secret;
    }
    mapping(uint256 => Link) links; // orcid => secret
    
    // Instance information
    struct Instance {
        uint256 id;
        string chain;
        uint256 size;
        uint256 dateCreated;
        string solution;
        bool solved;
        uint256 dateSolution;
    }
    mapping(uint256 => Instance) instances; // id => instance

    struct Hash {
        string solution_hash;
        string algorithm_hash;
        string hash_method;
    }
    mapping(uint256 => Hash) hashes; // id => hash information

    // VRF variables
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;

    // General variables
    uint256 nonce;
    uint256 idInstance;
    
    // MAX-3SAT variables
    uint256 clausesLength;
    uint256 maxRandonNumbers;
    
    /// @notice Main constructor
    constructor() 
      VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
            0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
        )
    {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK (it varies by network)
        nonce = 0;
        idInstance = 0;
        clausesLength = 3;
        maxRandonNumbers = 2100;
    }
    
    // ---------------------------------- Researchers functions ----------------------------------

    /// @notice Registers a new Researcher 
    function setResearcher(uint256 _secret, string memory _name, string memory _email, uint256 _orcid) public {
        require(!researchers[_secret].registered, "This ORCID is already registered.");
        uint256[] memory empty;
        researchers[_secret] = Researcher(_name, _email, true, empty, empty);
        links[_orcid] = Link(_secret);
    }
    
    /// @notice Get the array which contains all the dates for the random numbers generated
    function getDateNumber(uint256 _secret) public view returns (uint256[] memory){
        return researchers[_secret].numberGenerated;
    }

    /// @notice Check the secret number
    function checkPass(uint _secret) public view returns (bool) {
        return researchers[_secret].registered;
    }

    // ---------------------------------- General functions ----------------------------------

    /// @notice Get instance
    function getInstance(uint256 _id) public view returns (uint256, string memory, uint256, uint256, string memory, bool, uint256){
        return (instances[_id].id, instances[_id].chain, instances[_id].size, instances[_id].dateCreated, instances[_id].solution, instances[_id].solved, instances[_id].dateSolution);
    }

    /// @notice Get hash information about a instance
    function getHash(uint256 _id) public view returns (string memory, string memory, string memory){
        return (hashes[_id].solution_hash, hashes[_id].algorithm_hash, hashes[_id].hash_method);
    }

    /// @notice Get all instances
    function getAllInstances(uint256 _orcid) public view returns (Instance[] memory) {
        uint256 secret = links[_orcid].secret;
        Instance[] memory result = new Instance[](researchers[secret].idInstance.length);
        for(uint256 i = 0; i < researchers[secret].idInstance.length; i++)
            result[i] = instances[researchers[secret].idInstance[i]];
        return result;
    }
    
    /// @notice Set the solution for the _id instance
    function solveInstance(uint256 _secret, uint256 _id, string memory _solution, string memory _algorithm_hash, string memory _hash_method) public returns (bool) {
        bool validResearcher = false;
        uint256 i = 0;
        while(validResearcher == false && i < researchers[_secret].idInstance.length){
            if(researchers[_secret].idInstance[i] == _id)
                validResearcher = true;
            i++;
        }
        if(validResearcher == true){
            instances[_id].solution = _solution;
            instances[_id].solved = true;
            instances[_id].dateSolution = block.timestamp;
            hashes[_id].solution_hash = _solution;
            hashes[_id].algorithm_hash = _algorithm_hash;
            hashes[_id].hash_method = _hash_method;      
        }
        return validResearcher;
    }

    // ------------------------------- MAX-3SAT functions --------------------------------
    
    /// @notice Generates a new Instance from A generator
    function createAInstance(uint256 _p, uint256 _q, uint256 _secret, uint256 _numInstances) public {
        uint256[] memory randoms = expand();
        uint256 cont = 0;
        uint256 maxClauses = 100;
        for(uint k = 0; k < _numInstances; k++){
            string memory prepositions = "";
            uint256 symbols = 1;
            uint256 numClauses = 0;
            // First round of symbols
            for(uint256 i = 0; i < clausesLength-1; i++){
                if(randoms[cont] < _p)
                    symbols++; 
                cont++;
            }      
            // We create the first clause
            for(uint256 i = 0; i < clausesLength; i++)
                prepositions = append(prepositions, intToString(random(symbols)));
            numClauses++;
            // We create the rest of clauses
            while((randoms[cont] < _q) && (numClauses < maxClauses)){
                cont++;
                for(uint256 i = 0; i < clausesLength; i++){
                    if(randoms[cont]  < _p)
                        symbols++; 
                    cont++;
                }  
                for(uint256 i = 0; i < clausesLength; i++)
                    prepositions = append(prepositions, intToString(random(symbols)));
                numClauses++;
            }
            instances[idInstance] = Instance(idInstance, prepositions, numClauses, block.timestamp, "Unresolved", false, 0);
            researchers[_secret].idInstance.push(idInstance);
            idInstance++;
        }
    }

    /// @notice Generates a new Instance from B generator
    function createBInstance(uint256 _p, uint256 _q, uint256 _secret, uint256 _numInstances) public {
        uint256[] memory randoms = expand();
        uint256 cont = 0;
        uint256 maxClauses = 100;
        for(uint k = 0; k < _numInstances; k++){
            string memory prepositions = "";
            uint256 symbols = 1;
            uint256 numClauses = 0;
            // Decide the number of clauses
            while((randoms[cont] < _q) && (numClauses < maxClauses)){
                numClauses++;
                cont++;
            }
            // Add symbols
            for(uint256 i = 0; i < (3*numClauses)-1; i++){
                if(randoms[cont] < _p)
                    symbols++; 
                cont++;
            }
            // Fill the blanks   
            for(uint256 i = 0; i < 3*numClauses; i++)
                prepositions = append(prepositions, intToString(random(symbols)));
            instances[idInstance] = Instance(idInstance, prepositions, numClauses, block.timestamp, "Unresolved", false, 0);
            researchers[_secret].idInstance.push(idInstance);
            idInstance++;
        }
    }

    // --------------------------------- VRF functions ----------------------------------

    /// @notice Set the date of the new random number generated
    function getRandomNumber(uint256 _secret) public returns (bytes32 requestId) {
        //require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        researchers[_secret].numberGenerated.push(block.timestamp); 
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }

    function expand() internal view returns (uint256[] memory expandedValues) {
        expandedValues = new uint256[](maxRandonNumbers);
        for (uint256 i = 0; i < maxRandonNumbers; i++) {
            expandedValues[i] = uint256(keccak256(abi.encode(randomResult, i))) % 100;
        }
        return expandedValues;
    }

    function getRemainingLINK() external view returns (uint256) {
        return LINK.balanceOf(address(this));
    }
   
    // -------------------------------- Support functions --------------------------------

    /// @notice Generates a random number within an interval
    /// @param _interval upper index of the (open) interval of the random value
    /// @dev now, msg.sender and nonce are the timestamp of the block, who made the call and an incremental number respectively
    /// @return The number generated
    function random(uint256 _interval) internal returns (uint256) {
        uint256 randNumber = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % _interval;
        nonce++;
        return randNumber;
    }

    function append(string memory _a, string memory _b) internal pure returns (string memory) {
        return string(abi.encodePacked(_a, _b));
    }

    function intToString(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}