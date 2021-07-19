pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    struct airlineAccount{
        address accountAddress;                                         // Address of the airline account
        bool isRegistered;                                              // Blocks airlines that haven't submitted a stake
        uint256 accountValue;                                           // Monetary value of the account
        bool isValue;                                                   // Value exists in the mapping or not
    }
    uint256 airlineCount;                                               // # of registered airlines

    struct purchase{                                                    // Individual plans
        uint256[] amount;                                               // Amount insured
        bool isCredited;                                                // Has it been credited
        address[] insurees;
    }

    mapping(address => airlineAccount) registrations;                   // Registered airlines
    mapping(bytes32 => purchase) purchases;                             // Purchases
    mapping(address => uint256) credits;                                // Withdrawals available

    mapping(address => bool) callers;                                   // Authorized callers to this contract
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
    (
    )
    public
    {
        contractOwner = msg.sender;
        callers[contractOwner] = true;
    }

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

    modifier requireFunded(address airline){
        require(registrations[airline].isRegistered, "Airline registered but hasn't submitted the stake yet");
        _;
    }

    modifier requireAirlineExists(address airline){
        require(isAirline(airline), "Airline hasn't been registered yet");
        _;
    }

    modifier requireAuthorizedCaller(){
        require(callers[msg.sender], "Caller is not authorized");
        _;
    }

    modifier requireAuthorizedCallerOrRegisteredAirline(){
        require(callers[msg.sender] || registrations[msg.sender].isRegistered, "Caller is not authorized or a registered airline");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function authorizeCaller(address add) requireContractOwner public{
        callers[add] = true;
    }

    function deauthorizeCaller(address add) requireContractOwner public{
        delete callers[add];
    }

    function isAirline(address add) public view returns(bool){
        return registrations[add].isValue;
    }
    /**
        * @dev Get registration status of an airline
        *
        * @return A bool that is the current registration status
        */
    function isRegistered(address airline)
    public
    view
    returns(bool)
    {
        return registrations[airline].isRegistered;
    }

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational()
    public
    view
    returns(bool)
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus
    (
        bool mode
    )
    external
    requireContractOwner
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
    function getAirlineCount() external view returns(uint256){
        return airlineCount;
    }

    function registerFreeAirline
    (
        address add
    )
    requireIsOperational
    requireAuthorizedCaller
    public
    {
        airlineAccount memory newAirline = airlineAccount(add, true, 0, true);
        registrations[add] = newAirline;
        airlineCount++;
    }
    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline
    (
        address add
    )
    requireIsOperational
    requireAuthorizedCaller
    external
    {
        airlineAccount memory newAirline = airlineAccount(add, false, 0, true);
        registrations[add] = newAirline;
    }


    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy
    (
        address user,
        address airline,
        string flight,
        uint256 timestamp
    )
    requireIsOperational
    requireAuthorizedCaller
    requireAirlineExists(airline)
    requireFunded(airline)
    external
    payable
    {
        require(msg.value > 0 && msg.value <= 1000000000000000000, "Invalid ether value (valid ranges: [0-1) eths");

        bytes32 key = getFlightKey(airline, flight, timestamp);
        purchases[key].amount.push(msg.value);
        purchases[key].insurees.push(user);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
    (
        address airline,
        string flight,
        uint256 timestamp
    )
    requireIsOperational
    requireAuthorizedCaller
    requireAirlineExists(airline)
    requireFunded(airline)
    external
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);

        // check if already credited
        require(!purchases[key].isCredited, "Already credited!");

        // credit 1.5 times the purchase
        for(uint i=0; i<purchases[key].amount.length; i++){
            uint256 value = purchases[key].amount[i];
            credits[purchases[key].insurees[i]] = value.mul(3).div(2);
        }

        // set credited to true so accounts aren't recredited
        purchases[key].isCredited = true;
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
    (
        address add //user
    )
    requireIsOperational
    requireAuthorizedCaller
    external
    payable
    {
        require(credits[add] > 0, "Insufficient balance to transfer");

        uint value = uint(credits[add]);
        delete credits[add];

        add.transfer(value);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund
    (
        address add
    )
    requireIsOperational
    requireAuthorizedCaller
    requireAirlineExists(add)
    public
    payable
    {
        require(!isRegistered(add), "Airline already registered");
        require(msg.value == 10000000000000000000, "Payment should exactly equal 10 ethers + gas");

        registrations[add].isRegistered = true;
        airlineCount++;
    }

    function getFlightKey
    (
        address airline,
        string memory flight,
        uint256 timestamp
    )
    pure
    internal
    returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function()
    external
    payable
    {
        require(msg.data.length == 0, "No data allowed in the fallback function");
        fund(msg.sender);
    }


}
