
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

var Web3 = require('web3');
var web3= new Web3('ws://localhost:8545');

contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address, {from: config.owner});
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try
        {
            await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
        }
        catch(e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try
        {
            await config.flightSuretyData.setOperatingStatus(false);
        }
        catch(e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try
        {
            await config.flightSurety.setTestingMode(true);
        }
        catch(e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

    });

    it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

        // ARRANGE
        let newAirline = accounts[2];

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
        }
        catch(e) {

        }
        let result = await config.flightSuretyData.isRegistered.call(newAirline);

        // ASSERT
        assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

    });

    it('(airline) can register an Airline using registerAirline() if it is funded', async () => {

        // ARRANGE
        let newAirline = accounts[3];

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
            await config.flightSuretyApp.fund({from: newAirline, value:10000000000000000000});
        }
        catch(e) {

        }
        let result = await config.flightSuretyData.isRegistered.call(newAirline);

        // ASSERT
        assert.equal(result, true, "Airline should be able to register another airline if it has provided funding");

    });

    it('(airline) consensus works', async () => {

        // ARRANGE
        let newAirline0 = accounts[4];
        let newAirline1 = accounts[5];
        let newAirline2 = accounts[6];

        // ACT
        await config.flightSuretyApp.registerAirline(newAirline0, {from: config.firstAirline});
        await config.flightSuretyApp.fund({from: newAirline0, value:10000000000000000000});
        assert.equal(await config.flightSuretyData.getAirlineCount.call(), 3, "3 airlines registered at this point") //c#3

        await config.flightSuretyApp.registerAirline(newAirline1, {from: newAirline0});
        await config.flightSuretyApp.fund({from: newAirline1, value:10000000000000000000});
        assert.equal(await config.flightSuretyData.getAirlineCount.call(), 4, "4 airlines registered at this point") //c#4

        await config.flightSuretyApp.registerAirline(newAirline2, {from:newAirline0});
        assert.equal(await config.flightSuretyData.isAirline.call(newAirline2), false, "not enough votes, should not be registered");

        await config.flightSuretyApp.registerAirline(newAirline2, {from:newAirline1});
        assert.equal(await config.flightSuretyData.isAirline.call(newAirline2), false, "not enough votes, should not be registered");

        try {
            await config.flightSuretyApp.registerAirline(newAirline2, {from:accounts[2]}); //accounts[2] isn't registered
        }catch(e){}
        assert.equal(await config.flightSuretyData.isAirline.call(newAirline2), false, "not enough votes, should not be registered");

        await config.flightSuretyApp.registerAirline(newAirline2, {from:config.firstAirline});
        assert.equal(await config.flightSuretyData.isAirline.call(newAirline2), true, "3/4 votes, should be registered");

    });

    it('(airline) consensus works the second time - counts and voters are reset', async () => {

        // ARRANGE
        let newAirline = accounts[7];

        // ACT
        await config.flightSuretyApp.registerAirline.call(newAirline, {from:accounts[3]});
        assert.equal(await config.flightSuretyData.isAirline.call(newAirline), false, "not enough votes, should not be registered");

        await config.flightSuretyApp.registerAirline(newAirline, {from:accounts[4]});
        assert.equal(await config.flightSuretyData.isAirline.call(newAirline), false, "not enough votes, should not be registered");

        await config.flightSuretyApp.registerAirline(newAirline, {from:accounts[3]}); //accounts[3] is repeated
        assert.equal(await config.flightSuretyData.isAirline.call(newAirline), false, "not enough votes, should not be registered");

        await config.flightSuretyApp.registerAirline(newAirline, {from:config.firstAirline});
        assert.equal(await config.flightSuretyData.isAirline.call(newAirline), true, "3/4 votes, should be registered");

    });

    it('(passenger) passengers can buy insurance', async () => {

        let airline = accounts[4];
        let flight = "XT312";
        let timestamp = new Date("10/03/2020 15:00:00").getTime();
        let passenger = accounts[49];
        let balance = await web3.eth.getBalance(passenger);
        let insurance = 1000000000000000000;

        let response = await config.flightSuretyApp.buy(airline, flight, timestamp, {from:passenger, value:insurance});
        let newBalance = await web3.eth.getBalance(passenger);

        assert.equal(newBalance <= balance - web3.utils.toWei(JSON.stringify(insurance),'wei') - web3.utils.toWei(JSON.stringify(response.receipt.gasUsed),'wei')
            , true, "Current balance different from what's expected");

    });

    it('(passenger) insurance is credited', async () => {

        let airline = accounts[4];
        let flight = "XT312";
        let timestamp = new Date("10/03/2020 15:00:00").getTime();

        let passenger = accounts[49];
        let balance = await web3.eth.getBalance(passenger);
        // console.log('init user balance: ', balance);

        await config.flightSuretyData.creditInsurees(airline, flight, timestamp, {from:config.owner});
        await config.flightSuretyApp.pay({from:passenger});

        let newBalance = await web3.eth.getBalance(passenger);
        // console.log('new user balance: ', newBalance);

        assert.equal(parseFloat(web3.utils.fromWei(newBalance)) > parseFloat(web3.utils.fromWei(balance)), true, "New balance different from what's expected");

    });
});
