import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
let config = Config['localhost'];

import Web3 from 'web3';

const TruffleContract = require("truffle-contract");
let web3Provider = new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws'));
let flightSuretyApp = TruffleContract(FlightSuretyApp);
flightSuretyApp.setProvider(web3Provider);

import 'regenerator-runtime/runtime';
import Oracles from './Oracles';

(async ()=>{
    let instance, oracleApp;
    try {
        instance = await flightSuretyApp.at(config.appAddress);
        oracleApp = new Oracles({
            numOracles: 20,
            statusCodes: [0, 10, 20, 30, 40, 50],
            airlineStatusCodeProbability: 0.8
        }, instance, new Web3(web3Provider));
        await oracleApp.init();
    } catch (e) {
        console.log(e);
    }

    instance
        .OracleRequest()
        .on("data", async event => {
            let flightStatusRequest = {
                index: event.returnValues.index,
                airline: event.returnValues.airline,
                flight: event.returnValues.flight,
                timestamp: event.returnValues.timestamp
            };

            let flightStatusResponses;
            try {
                flightStatusResponses = await oracleApp.getFlightStatus(flightStatusRequest);
            } catch (e) {
                console.log(e);
            }

            console.log(flightStatusResponses);
            flightStatusResponses.forEach(async response => {
                try {
                    await instance.submitOracleResponse(
                        response.index,
                        response.airline,
                        response.flight,
                        response.timestamp,
                        response.statusCode,
                        {from: response.address, gas: 6721975});
                } catch (e) {
                    console.log(e);
                }

            });
        })
        .on("error", err => {
            console.log(err);
        });
})();