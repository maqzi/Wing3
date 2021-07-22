var Test = require('../config/testConfig.js');
//var BigNumber = require('bignumber.js');

contract('Oracles', async (accounts) => {

  const TEST_ORACLES_COUNT = 20;
  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    // Watch contract events

  });
  const STATUS_CODE_UNKNOWN = 0;
  const STATUS_CODE_ON_TIME = 10;
  const STATUS_CODE_LATE_AIRLINE = 20;
  const STATUS_CODE_LATE_WEATHER = 30;
  const STATUS_CODE_LATE_TECHNICAL = 40;
  const STATUS_CODE_LATE_OTHER = 50;

  it('(airline) register flight', async () => {

    let airline = accounts[2];
    let flight = "XT312";
    let timestamp = new Date("10/03/2020 15:00:00").getTime();

    // ARRANGE
    await config.flightSuretyApp.registerAirline(airline, {from:config.owner});
    await config.flightSuretyApp.fund({from: airline, value: web3.utils.toWei("10", "ether")});

    // ACT
    await config.flightSuretyApp.registerFlight(airline, timestamp, flight,  {from: airline});
    let result = await config.flightSuretyData.isAirline.call(airline);

    // ASSERT
    assert.equal(result, true, "Airline should be registered");

    assert.equal(await config.flightSuretyApp.getFlightStatus.call(airline, flight, timestamp), "STATUS_CODE_UNKNOWN", "Flight should be registered with an unknown status code");

  });

  it('can register oracles', async () => {

    // ARRANGE
    let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

    // ACT
    for(let a=3; a<TEST_ORACLES_COUNT+3; a++) {
      await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
      let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
      console.log(`${a}: Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    }
  });

  it('can request flight status', async () => {

    // ARRANGE
    let airline = accounts[2];
    let flight = "XT312";
    let timestamp = new Date("10/03/2020 15:00:00").getTime();

    var success = 0;
    // Submit a request for oracles to get status information for a flight
    await config.flightSuretyApp.fetchFlightStatus(airline, flight, timestamp);
    // ACT

    // Since the Index assigned to each test account is opaque by design
    // loop through all the accounts and for each account, all its Indexes (indices?)
    // and submit a response. The contract will reject a submission if it was
    // not requested so while sub-optimal, it's a good test of that feature
    for(let a=3; a<TEST_ORACLES_COUNT+3; a++) {

      // Get oracle information
      let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
      for(let idx=0;idx<3;idx++) {

        try {
          // Submit a response...it will only be accepted if there is an Index match
          await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], airline, flight, timestamp, STATUS_CODE_ON_TIME, { from: accounts[a] });
          success += 1;
          console.log('Success', idx, oracleIndexes[idx].toNumber(), flight, timestamp);
        }
        catch(e) {
          // Enable this when debugging
          //console.log(e)
          console.log('Error', idx, oracleIndexes[idx].toNumber(), flight, timestamp);
        }

      }
    }
    assert.equal(success>0, true, "successful oracle response");
  });

});