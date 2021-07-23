import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        let navs = ["contract-resource", "airlines-resource", "flights-resource", "insurances-resource"].map(item=>{
            return DOM.elid(item);
        });
        let formContainers = ["contract-resource-forms", "airlines-resource-forms", "flights-resource-forms", "insurances-resource-forms"].map(item=>{
            return DOM.elid(item);
        });
        let displayWrapper = DOM.elid("display-wrapper");
        navs.forEach((navItem, index, arr) =>{
            navItem.addEventListener("click", ()=>{
                arr.forEach((item, idx, array) =>{
                    item.classList.remove("active");
                    formContainers[idx].style.display = "none";
                });
                navItem.classList.add("active");
                formContainers[index].style.display = "block";
                displayWrapper.innerHTML = "";
            });
        });

        DOM.elid("operational-status-get").addEventListener("click", async () => {
            let request = {
                from: DOM.elid("operational-status-get-from").value
            };
            let err, result;
            try {
                result = await contract.getOperationalStatus(request);
            } catch (e) {
                console.log(e);
                err = e;
            } finally {
                display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: err, value: result} ]);

            }
        });

        DOM.elid("airline-register").addEventListener("click", async () => {
            let airlineAddress = DOM.elid("airline-address");
            let from = DOM.elid("airline-register-from");
            let request = {
                airline: airlineAddress.value,
                from: from.value
            };
            let err, result, label
            try {
                await contract.registerAirline(request);
                label = "Success";
                result = "Airline is registered";
            } catch(e){
                console.log(e);
                label = "Failure";
                err = e;
            } finally {
                display(
                    "Register Airline",
                    "Registers new airline in the system, but does not allow it to vote without registration fee paid",
                    [{label: label, error: err, value: result}]
                )
            }
        });

        DOM.elid("register-flight").addEventListener("click", async ()=>{
            let request = {
                flight: DOM.elid("register-flight-flight-code").value,
                airline: DOM.elid("register-flight-airline-address").value,
                departure: new Date(DOM.elid("register-flight-departure").value).valueOf() / 1000,
                from: DOM.elid("register-flight-from").value
            };

            let err, result, label;
            try {
                await contract.registerFlight(request);
                label = "Success";
            } catch (e) {
                err = e;
                console.log(e);
                label = "Failure";
            } finally {
                display('Register Flight', 'Creates new flight in the system', [ { label: label, error: err, value: "Flight is registered"} ]);
            }
        });

        DOM.elid("submit-oracle").addEventListener("click", async () => {
            let request = {
                airline: DOM.elid("submit-oracle-airline-address").value,
                flight: DOM.elid("submit-oracle-flight-code").value,
                departure: new Date(DOM.elid("submit-oracle-departure").value).valueOf()/1000
            };
            let err, result;
            try {
                await contract.fetchFlightStatus(request, (values) => {
                    result = JSON.stringify(values);
                });
            } catch (e) {
                err = e;
            } finally {
                display('Flight Status',
                    'Send the request to Oracle server to get the flight status code for this flight',
                    [
                        { label: 'Fetching...', error: err, value: "Click \`show latest status\` in a few seconds to update."}
                    ]
                );
            }
        });

        DOM.elid("get-flight-status").addEventListener("click", async ()=>{
            let request = {
                airline: DOM.elid("submit-oracle-airline-address").value,
                flight: DOM.elid("submit-oracle-flight-code").value,
                departure: new Date(DOM.elid("submit-oracle-departure").value).valueOf()/1000
            };

            let err, result, label;
            try {
                result = await contract.getFlightStatus(request);
                label = "Success";
                console.log(result)
            } catch (e) {
                err = e;
                console.log(e);
                label = "Failure";
            } finally {
                display('Get Flight',
                    'Get flight status from the system',
                    [
                        { label: "Airline Address", error: err, value: request.airline },
                        { label: "Code", error: err, value: request.flight },
                        { label: "Status", error: err, value: result },
                        { label: "Departure", error: err, value: request.departure},
                    ]
                );
            }
        });

        DOM.elid("buy-insurance").addEventListener("click", async ()=>{
            let request = {
                airline: DOM.elid("buy-insurance-airline-address").value,
                flight: DOM.elid("buy-insurance-flight-code").value,
                departure: new Date(DOM.elid("buy-insurance-departure").value).valueOf()/1000,
                paid: DOM.elid("buy-insurance-paid-amount").value,
                from: DOM.elid("buy-insurance-passenger-address").value
            };

            let err, result, label;
            try {
                await contract.buyInsurance(request);
                label = "Success";
            } catch (e) {
                err = e;
                console.log(e);
                label = "Failure";
            } finally {
                display('Buy Insurance', 'Purchases a plan for the passenger', [ { label: label, error: err, value: "Insurance purchased!"} ]);
            }
        });

        // User-submitted transaction
        DOM.elid('get-credited-amount').addEventListener('click', async () => {
            let request = {
                address: DOM.elid('buy-insurance-passenger-address').value
            };
            let err, result, label;
            label = "Credits Available";
            try {
                result = await contract.getCreditedAmount(request);
            } catch (e) {
                err = e;
                console.log(e);
            } finally {
                display('Show available credits', 'Displays the amount (in ether) available to withdraw', [ { label: label, error: err, value: result} ]);
            }
        });

        DOM.elid('withdraw-credited-amount').addEventListener('click', async () => {
            let request = {
                address: DOM.elid('buy-insurance-passenger-address').value,
            };
            let err, result, label;

            try {
                result = await contract.withdrawAmount(request);
                label = "Success";
            } catch (e) {
                err = e;
                label = "Failure";
                console.log(e);
            } finally {
                display('Withdraw Amount', 'Pays out the credits to passenger\'s address', [ { label: label, error: err, value: "Amount Withdrawn"} ]);
            }
        });

    });
})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    displayDiv.innerHTML = "";

    let section = DOM.section();
    let row = DOM.div({className: "row"});
    let titleContainer = DOM.div({className: "col-12"});
    titleContainer.appendChild(DOM.h5(title));
    let descContainer = DOM.div({className:"col-12"});
    descContainer.appendChild(DOM.p(description));
    row.appendChild(titleContainer);
    row.appendChild(descContainer);
    results.map((result) => {
        // let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    });
    displayDiv.append(section);

}
