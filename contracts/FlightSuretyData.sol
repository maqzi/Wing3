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

    struct purchase{                                                    // Individual purchases
        uint256 amount;                                                 // Amount insured
        bool isCredited;                                                // Has it been credited
    }

    mapping(address => airlineAccount) registrations;                          // Registered airlines
    mapping(bytes32 => purchase) purchases;                             // Purchases

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

    modifier requireFunded(){
        require(registrations[msg.sender].isRegistered, "Airline registered but hasn't submitted the stake yet");
        _;
    }

    modifier requireAirlineExists(){
        require(registrations[msg.sender].isValue, "Airline hasn't been registered yet");
        _;
    }

    modifier requireAuthorizedCaller(){
        require(callers[msg.sender], "Caller is not authorized");
        _;
    }
    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function authorizeCaller(address airline) requireContractOwner external{
        callers[airline] = true;
    }

    function denounceCaller(address airline) requireContractOwner external{
        delete callers[airline];
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
    requireAirlineExists
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
        string flight,
        uint256 timestamp
    )
    requireIsOperational
    requireAirlineExists
    requireFunded
    external
    payable
    {
        require(msg.value > 0, "Invalid ether value");

        bytes32 key = getFlightKey(msg.sender, flight, timestamp);
        purchases[key].amount = msg.value;
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
    external
    {
        //airline exists and funded
        require(registrations[airline].isValue, "Airline hasn't been registered yet");
        require(isRegistered(airline), "Airline hasn't been funded yet");

        bytes32 key = getFlightKey(airline, flight, timestamp);

        // check if already credited
        require(!purchases[key].isCredited, "Already credited!");

        // credit 1.25 times the purchase
        uint256 value = purchases[key].amount;
        registrations[airline].accountValue = value.mul(5).div(4);

        // set credited to true
        purchases[key].isCredited = true;
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
    (
    )
    requireIsOperational
    requireAirlineExists
    requireFunded
    external
    payable
    {
        require(registrations[msg.sender].accountValue > 0, "Insufficient balance to transfer");

        uint value = registrations[msg.sender].accountValue;
        registrations[msg.sender].accountValue = 0;

        msg.sender.transfer(value);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund
    (
    )
    requireIsOperational
    requireAirlineExists
    public
    payable
    {
        require(!registrations[msg.sender].isRegistered, "Airline already registered");
        require(msg.value == 10, "Payment should exactly equal 10 ethers");

        registrations[msg.sender].isRegistered = true;
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
        fund();
    }


}

