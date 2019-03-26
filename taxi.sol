
pragma solidity >=0.4.22 <0.6.0;
// The value of this.balance in payable methods is increased by msg.value before the body of your payable 
// method executes. If your contract has a starting balance of 1 and you pass in a msg.value of 2, 
// the payable method will already have a this.balance of 3 when it executes.

// @author Eyupcan Bodur
contract Taxi{
    uint8 private MAXIMUM_PARTICIPANT = 100;
    address private owner;
    // More sopistichate way to pay dividends. Maybe new comers will pay more participant_fee. Or maybe want to gain more dividend.
    struct Participant{
        bool isParticipant;
        uint dividend;
    }
    
    struct Driver{
        address payable driver;
        uint balance;
    }
    
    struct ProposeCar{
        uint32 carId;
        uint price;
        uint offer_valid_time;
        bool set;
    }
    
    struct ProposePurchase{
        uint32 carId;
        uint price;
        uint offer_valid_time;
        uint approval_state; // TODO: will be change to state.
        bool set;
        mapping (address=>bool) approvedAccounts;
    }

    struct PayDate{
        uint date;
        bool paid;
    }
    
    mapping (address=>Participant) private participants;
    address[] private participants_accounts;  // Stake holders, maximum of 100. This for sending dividends into account. Because we can not iterate over map in solidity.
    
    address private manager;
    Driver taxi_driver; 
    uint private driver_fee; // 5 ether
    address payable private car_dealer;
    uint private contract_balance; 
    uint private fix_expenses; // 5 ether
    uint private participant_fee; // 10 ether
    uint32 private owned_car;
    ProposeCar proposed_car;
    ProposePurchase proposed_purchase;
    // For checking paying the monthly payments. If function's called date is not bigger then given dates, we cannot pay.
    PayDate private dateDriverSalary;
    PayDate private dateExpensesFee;
    uint private dateDividend;

    constructor() public payable{
        // Owner is the deployer of the contract. At first he/she is the manager. It can be change later.
        owner = msg.sender;
        manager = msg.sender;
        contract_balance = address(this).balance;
        driver_fee = 5 ether;
        fix_expenses = 5 ether;
        participant_fee = 10 ether;
        
    }
    
    function join() public payable {
        require(participants_accounts.length < MAXIMUM_PARTICIPANT ," Party is full, sorry !"); // Check for the participant number is not bigger than the maximum
        require(msg.value >= participant_fee,"You have to send enough participant fee to join the club !"); // Checking the received participant fee.
        require(!participants[msg.sender].isParticipant,"Address has been already joined"); // Check the sender if it's already a participant
        participants[msg.sender].isParticipant = true;
        participants_accounts.push(msg.sender);
        contract_balance += participant_fee; // Add money to contract balance;
        // Send back to remaning ether to the message sender.
        uint remaining_ether = msg.value - participant_fee; 
        if(remaining_ether > 0) msg.sender.transfer(remaining_ether);
    }
    
    function setCarDealer(address payable _car_dealer) public isManager{
        car_dealer = _car_dealer;
    }
    
    // Only CarDealer can call this, sets Proposed Car values, such as CarID, price, and offer valid time
    // Offer valid time can be seconds, times,date etc.  It automatically converts into seconds. 
    function carPropose(uint32 _carId, uint _price, uint _offer_valid_time) public isCarDealer{
        // We are setting valid time as a now + offer_valid_time. And we are expecting seconds, minutes, days hours etc except specific dates.
        proposed_car = ProposeCar(_carId,_price,now + _offer_valid_time,true);
    }
    // Only Manager can call this function, sends the CarDealer the price of the proposed car if the offer valid time is not passed yet.
    function purchaseCar() public isManager{
        require(proposed_car.set,"There is no proposed car !!!");   // Check for proposed_car set or not.
        require(proposed_car.offer_valid_time >= now,"Offer has been experied !!!"); // Check for offer time.
        require(contract_balance >= proposed_car.price,"There is not enough money to purchase !!!"); // Check contract balance.
        car_dealer.transfer(proposed_car.price); // Pay the price directly to the carDealer address.
        owned_car = proposed_car.carId;
        proposed_car.set = false; // For preventing the paying more than once for a car.
        contract_balance -= proposed_car.price;
    }
    
    // Offering a price for the car that he want to buy.
    function purchasePropose(uint32 _carId, uint _price, uint _offer_valid_time) public isCarDealer{
        require(_carId == owned_car,"This is not the car that contract owned !!!"); // First check CardDealer is sending the correct carId or not.
        // If you delete a struct, it will reset all members that are not mappings and also recurse 
        // into the members unless they are mappings. However, individual keys and what they map to can be deleted.
        // If a is a mapping, then delete a[x] will delete the value stored at x.
        // This is for clearing votes that have been given by the accounts.
        for(uint i = 0 ; i < participants_accounts.length;i++){
            address aa =participants_accounts[i];
            delete proposed_purchase.approvedAccounts[aa];
        }
        // delete proposed_purchase; Extra operation. can be unnecessary.
        proposed_purchase = ProposePurchase(_carId,_price,now + _offer_valid_time,0,true); // No need to set approval_state 0 but anyway.
    
    }
    
    // With hasPurchasePropose modifier, we check if there is a propositon or not for our car.
    function approveSellProposal() public isParticipant hasPurchasePropose{
        // require(proposed_purchase.set,"There is no proposition !!!"); // We can check there is a proposition or not.
        require(!proposed_purchase.approvedAccounts[msg.sender],"You've approved once.");
        proposed_purchase.approval_state += 1;
        proposed_purchase.approvedAccounts[msg.sender] = true; // Preventing more than once voting situation
    }
    
    // TODO: How can i send car dealer to my address in this contract ?
    function sellCar() public isCarDealer hasPurchasePropose payable{
        require(proposed_purchase.set,"There is no propositon to buy Car Dealer!!!"); // Check for proposed_car set or not.
        require(proposed_purchase.offer_valid_time >= now,"Propositon has been experied !!!"); // Check for offer time.
        require(proposed_purchase.approval_state > participants_accounts.length/2,"Approval State ratio must be bigger then %50 !!!");
        delete owned_car; // We have no car right now.
        proposed_purchase.set = false; // After buying the car, set purchase proposition to false. Because we used that offer.
    }
    
    // In order to get paid, taxi driver's address must be payable.
    function setDriver(address payable _taxi_driver) public isManager{
        taxi_driver.driver = _taxi_driver;
    }
    
    function getCharge() public payable{
        // Take whatever you want.
        contract_balance += msg.value;
    }
    
    function paySalary() public isManager everyGivenMonth(1,0){
        // Check if there is enough money to pay.
        require(contract_balance >= driver_fee,"There is not enough money to pay driver's salary");
        taxi_driver.balance += driver_fee;
        contract_balance -= driver_fee;
        if(now < dateDriverSalary.date) dateDriverSalary.paid = true; // For calculating dividends's profit
    }
    
    // No need to check for contract_balance == 0. Because i extracting from contract_balance.
    // So money in the contract and safe.
    function getSalary() public isDriver{
        require(taxi_driver.balance > 0,"There is no money in the balance !!!");
        taxi_driver.driver.transfer(taxi_driver.balance);
        taxi_driver.balance = 0;
    }
    
    function carExpenses() public isManager everyGivenMonth(6,1){
        require(contract_balance >= fix_expenses,"There is not enough money to pay to expenses");
        car_dealer.transfer(fix_expenses);
        contract_balance -= fix_expenses;
        if(now < dateExpensesFee.date) dateExpensesFee.paid = true; // For calculating dividends's profit
    }
    
    function payDividend() public isManager everyGivenMonth(6,2){
        require(participants_accounts.length > 0,"There are no participants right now !!!");
        require(contract_balance > 0,"There is no money in the contract !!!");
        uint profit = calculateProfit();
        uint profit_per_dividend = profit / participants_accounts.length;
        for(uint index = 0; index < participants_accounts.length;index++){
            participants[participants_accounts[index]].dividend += profit_per_dividend;
        }
        contract_balance -= profit; // Reset the contract balance 
        
    }
    // Only Participants can call this function, if there is any money in participants’ account, it will be send to his/her address
    function getDividend() public payable isParticipant{
        // TODO: research about broking after transaction
        require(participants[msg.sender].dividend > 0, "There is not any money in your account , sorry :( ");
        msg.sender.transfer(participants[msg.sender].dividend);
        participants[msg.sender].dividend = 0;
    }
    event prof(uint profit,uint contract_balance);
    function calculateProfit() private returns(uint){
        uint profit = contract_balance;
        // Check if expenses and driver's salary paid or not.
        // If they have not been paid, exclude them from the profit.
        if(!dateExpensesFee.paid){
            profit -= fix_expenses;
        }
        if(!dateDriverSalary.paid){
            profit -= driver_fee;
        }
         emit prof(profit,contract_balance);
        return profit;
    }
    
    // Fallback function
    function() external  {
        revert();
    }
    // MODIFIERS -------------------------------------------
    modifier isManager(){
        require(msg.sender == manager,"You are not the Manager !!!");
        _;
    }
    
    modifier isCarDealer(){
        require(msg.sender == car_dealer,"You are not the Car Dealer !!!");
        _;
    }
    // Check participant_fee for participantance.
    modifier isParticipant(){
        require(participants[msg.sender].isParticipant,"You are not part of the family !!!");
          _;
    }
    
    modifier isDriver(){
        require(msg.sender == taxi_driver.driver,"You have to be the driver !!!");
        _;
    }
    
    modifier hasPurchasePropose(){
        require(proposed_purchase.set,"There is no proposition right now!!!");
        _;
    }
    
    // For paying salary, expenses and dividend. We have to check,manager is not calling this funciton more than given 
    // First parameter is the month that you want to check, second parameter is to which date you want to check like:
    // 0 -> Driver's Salary date
    // 1 -> Expenses' date
    // 2 -> Dividend's pay date
    // These are all for preventing to more than once paying in a given month interval.
    modifier everyGivenMonth(uint month,uint8 dateType){
        // If it's the first time paying, or it has been 1 month from the last pay.
        // Both of are uint.If we check like == 30days there will be overflow integer. So we are checking only now > dateSalary.
        
        // require(date == 0 || now > date,"You can pay only ONCE in a given MONTH INTERVAL !!!");
        
        if(dateType == 0){          // For driver salary
            require(dateDriverSalary.date == 0 || now > dateDriverSalary.date,"You can pay only ONCE in a given MONTH INTERVAL !!!");
            if(dateDriverSalary.date == 0) dateDriverSalary.date = now + 30 days * month;
            else dateDriverSalary.date += 30 days * month;
        }else if(dateType == 1){    // For expenses fees
            require(dateExpensesFee.date == 0 || now > dateExpensesFee.date,"You can pay only ONCE in a given MONTH INTERVAL !!!");
            if(dateExpensesFee.date == 0) dateExpensesFee.date = now + 30 days * month;
            else dateExpensesFee.date += 30 days * month;
        }else if(dateType == 2){    // For dividend  
            require(dateDividend == 0 || now > dateDividend,"You can pay only ONCE in a given MONTH INTERVAL !!!");
            if(dateDividend == 0) dateDividend = now + 30 days * month;
            else dateDividend += 30 days * month;
        }else{
            // Do nothing
        }
        _;
    }
}