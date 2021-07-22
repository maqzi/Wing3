const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = function(deployer) {

    let firstAirline = '0x627306090abaB3A6e1400e9345bC60c78a8BEf57';
    deployer.deploy(FlightSuretyData) //todo: run init here?
        .then(() => {
            return deployer.deploy(FlightSuretyApp, FlightSuretyData.address)
                .then(async () => {
                    let config = {
                        localhost: {
                            url: 'http://localhost:8545',
                            dataAddress: FlightSuretyData.address,
                            appAddress: FlightSuretyApp.address
                        }
                    }
                    await fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                    await fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');

                    let flightSuretyData = await FlightSuretyData.deployed();
                    await flightSuretyData.authorizeCaller(FlightSuretyApp.address);
                    await flightSuretyData.registerFreeAirline(firstAirline)
                });
        });
}