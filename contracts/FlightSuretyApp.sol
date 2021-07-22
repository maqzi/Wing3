pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    mapping(uint8 => string) results;

    address private contractOwner; // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    mapping(bytes32 => Flight) private flights;
    mapping(bytes32 => bool) private flightExists;

    bool private operational;

    FlightSuretyData flightSuretyData;

    mapping(address => bool) registrationConsensus;
    address[] registrationConsensusParticipants;


    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
        // Modify to call data contract's status
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }
    // require is registered
    modifier requireIsRegistered(address airline)
    {
        require(flightSuretyData.isRegistered(airline), "Airline is not registered");
        _;
    }

    modifier requireFlightExists(address airline, string flight, uint256 timestamp){
        bytes32 key = getFlightKey(airline, flight, timestamp);
        require(flightExists[key],"Flight doesnt exist.");
        _;
    }
    modifier requireFlightNotAlreadyLate(address airline, string flight, uint256 timestamp){
        bytes32 key = getFlightKey(airline, flight, timestamp);
        if(flights[key].statusCode == STATUS_CODE_LATE_AIRLINE){
            revert("Can't buy insurance for already late flight.");
        }
        _;
    }
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
    (
        address dataContractAddress
    )
    public
    {
        flightSuretyData = FlightSuretyData(dataContractAddress);
        contractOwner = msg.sender;
        operational = true;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
    public
    view
    returns(bool)
    {
        return operational;  // Modify to call data contract's status
    }

    function setOperational(bool mode)
    public
    requireContractOwner
    {
        operational = mode;
    }

    function getFlightStatus(
        address airline,
        string flight,
        uint256 timestamp
    )
    external
    requireFlightExists(airline, flight, timestamp)
    returns(string)
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);

        results[STATUS_CODE_UNKNOWN] = "STATUS_CODE_UNKNOWN";
        results[STATUS_CODE_ON_TIME] = "STATUS_CODE_ON_TIME";
        results[STATUS_CODE_LATE_AIRLINE] = "STATUS_CODE_LATE_AIRLINE";
        results[STATUS_CODE_LATE_WEATHER] = "STATUS_CODE_LATE_WEATHER";
        results[STATUS_CODE_LATE_TECHNICAL] = "STATUS_CODE_LATE_TECHNICAL";
        results[STATUS_CODE_LATE_OTHER] = "STATUS_CODE_LATE_OTHER";

        return results[flights[key].statusCode];
    }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function buy(
        address airline,
        string flight,
        uint256 timestamp
    )
    external
    requireIsOperational
    requireFlightNotAlreadyLate(airline, flight, timestamp)
    payable
    {
        flightSuretyData.buy.value(msg.value)(msg.sender, airline, flight, timestamp);
    }

    event AirlineRegistered(address airline);

    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline
    (
        address airline
    )
    external
    requireIsOperational
    returns(bool, uint256)
    {
        if(msg.sender != contractOwner){
            if (!flightSuretyData.isRegistered(msg.sender)){
                revert("Flight not registered and caller not contract owner.");
            }
        }
        uint256 airlineCount = flightSuretyData.getAirlineCount();
        // register airline if less than 4 registrations
        if (airlineCount < 4){
            flightSuretyData.registerAirline(airline);
            emit AirlineRegistered(airline);

            return (true, 0);
        }

        // else if airline hasn't been yet registered
        if(!registrationConsensus[msg.sender]){
            registrationConsensus[msg.sender] = true;
            registrationConsensusParticipants.push(msg.sender);

            // if no. of votes is 50% of registered airlines
            if(registrationConsensusParticipants.length > airlineCount.div(2)){

                // clear consensus mapping
                uint votes = registrationConsensusParticipants.length;
                for(uint i=0; i<registrationConsensusParticipants.length; i++){
                    delete registrationConsensus[registrationConsensusParticipants[i]];
                    delete registrationConsensusParticipants[i];
                }
                registrationConsensusParticipants.length=0;

                // register and increment count
                flightSuretyData.registerAirline(airline);
                emit AirlineRegistered(airline);

                return (true, votes);
            }
        }
        return (false, registrationConsensusParticipants.length);
    }

    event FlightRegistered(address airline, string flight, uint timestamp);
    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight
    (
        address airline,
        uint256 timestamp,
        string flight
    )
    requireIsOperational
    external
    {
        bool isRegistered = flightSuretyData.isRegistered(airline);
        require(isRegistered,"Airline not added or funded.");

        Flight memory f = Flight(isRegistered, STATUS_CODE_UNKNOWN, timestamp, airline);

        bytes32 key = getFlightKey(airline, flight, timestamp);

        flights[key] = f;
        flightExists[key] = true;
        emit FlightRegistered(airline, flight, timestamp);
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus
    (
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    )
    internal
    requireIsOperational
    requireIsRegistered(airline)
    {
        if(flights[key].statusCode == statusCode){
            revert("No change in status.");
        }

        bytes32 key = getFlightKey(airline, flight, timestamp);

        flights[key].statusCode = statusCode;

        if(statusCode == STATUS_CODE_LATE_AIRLINE){
            flightSuretyData.creditInsurees(airline, flight, timestamp);
        }
    }

    function pay() requireIsOperational external{
        flightSuretyData.pay(msg.sender);
    }

    function fund() requireIsOperational external payable{
        flightSuretyData.fund.value(msg.value)(msg.sender);
    }

    function getCredits(address passenger) requireIsOperational external view{
        flightSuretyData.getCredits(passenger);
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
    (
        address airline,
        string flight,
        uint256 timestamp
    )
    external
    requireIsOperational
    requireFlightExists(airline, flight, timestamp)
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
        requester: msg.sender,
        isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }


    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
    (
    )
    external
    payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
        isRegistered: true,
        indexes: indexes
        });
    }

    function getMyIndexes
    (
    )
    view
    external
    returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
    (
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    )
    external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
    (
        address airline,
        string flight,
        uint256 timestamp
    )
    pure
    internal
    returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
    (
        address account
    )
    internal
    returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
    (
        address account
    )
    internal
    returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion

}

contract FlightSuretyData{

    //register
    function registerAirline
    (
        address add
    )
    external;

    //register first
    function registerFreeAirline
    (
        address owner,
        address add
    )
    external;

    //isRegistered
    function isRegistered(address add)
    public
    view
    returns(bool);

    //creditInsurees
    function creditInsurees
    (
        address airline,
        string flight,
        uint256 timestamp
    )
    external;

    // airline counter
    function getAirlineCount
    (
    )
    external
    view
    returns(uint256);

    // transfer the credit
    function pay
    (
        address add
    )
    external
    payable;

    // auth
    function authorizeCaller(address add) external;

    // fund
    function fund
    (
        address add
    )
    public
    payable;

    // buy
    function buy
    (
        address user,
        address airline,
        string flight,
        uint256 timestamp
    )
    external
    payable;

    // see credits
    function getCredits
    (
        address passenger
    )
    external
    view
    returns(uint256);

}