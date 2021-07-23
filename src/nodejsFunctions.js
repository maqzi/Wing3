// A collection of functions one might find useful while testing

var FlightSuretyApp = require('../build/contracts/FlightSuretyApp.json');
var Config = require('./server/config.json')
let config = Config['localhost'];
var Web3 = require('web3')
const TruffleContract = require("truffle-contract");
let web3Provider = new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws'));
let flightSuretyApp = TruffleContract(FlightSuretyApp);
flightSuretyApp.setProvider(web3Provider);

async function fundAirline(airline, amount){
    // airline address is string, amount is numerical in wei
    let instance = await flightSuretyApp.at(config.appAddress);

    await instance.fund({from:airline, value:amount, gas:6721975})
}
module.exports.fundAirline = fundAirline;