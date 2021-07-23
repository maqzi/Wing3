import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
const TruffleContract = require("truffle-contract");

export default class Contract {
    constructor(network, callback) {

        this.config = Config[network];
        let web3Provider = new Web3.providers.WebsocketProvider(this.config.url.replace('http', 'ws'));
        this.web3 = new Web3(web3Provider);
        this.flightSuretyApp = TruffleContract(FlightSuretyApp);
        this.flightSuretyApp.setProvider(web3Provider);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {

            this.owner = accts[0];

            let counter = 1;

            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    async getContractInstance(){
        return await this.flightSuretyApp.at(this.config.appAddress);
    }

    async getOperationalStatus(request) {
        let self = this;
        let caller = request.from || self.owner;
        let instance = await this.getContractInstance();
        return await instance.isOperational({from: caller});
    }

    async fetchFlightStatus(request, callback) {
        let caller = request.from || this.owner;
        let instance = await this.getContractInstance();
        instance.OracleRequest().on("data", async event => {
            console.log(event.returnValues);
        });
        instance.FlightStatusInfo().on("data", async (event) => {
            console.log(event.returnValues);
            callback(await event.returnValues);
        });
        console.log("fetching status");
        await instance.fetchFlightStatus(request.airline, request.flight, request.departure, {from: caller, gas:6721975});
    }

    async registerAirline(request) {
        let caller = request.from || this.owner;
        let instance = await this.getContractInstance();
        return await instance.registerAirline(request.airline, {from: caller});
    }

    async registerFlight(request){
        let caller = request.from || this.owner;
        let instance = await this.getContractInstance();
        return await instance.registerFlight(request.airline, request.departure, request.flight, {from: caller});
    }

    async getFlightStatus(request){
        let caller = request.from || this.owner;
        let instance = await this.getContractInstance();
        // no 'from' required
        return await instance.getFlightStatus.call(request.airline, request.flight, request.departure, {from: caller});
    }

    async buyInsurance(request){
        console.log(request);
        let instance = await this.getContractInstance();
        let paid = this.web3.utils.toWei(request.paid.toString(), "ether");
        let gasEstimateUnits = await instance.buy.estimateGas(request.airline, request.flight, request.departure, {from: request.from, value: paid});
        console.log(gasEstimateUnits);
        console.log(paid);
        return await instance.buy(request.airline, request.flight, request.departure, {from: request.from, value: paid, gas: gasEstimateUnits});
    }

    async getCreditedAmount(request){
        let instance = await this.getContractInstance();
        return  this.web3.utils.fromWei(await instance.getCredits(request.address), "ether");
    }

    async withdrawAmount(request){
        let instance = await this.getContractInstance();
        return await instance.pay({from: request.address});
    }
}