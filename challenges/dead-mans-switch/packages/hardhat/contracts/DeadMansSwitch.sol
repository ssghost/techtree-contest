//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Useful for debugging. Remove when deploying to a live network.
import "hardhat/console.sol";

// Use openzeppelin to inherit battle-tested implementations (ERC20, ERC721, etc)
// import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * A smart contract that allows changing a state variable of the contract and tracking the changes
 * It also allows the owner to withdraw the Ether in the contract
 * @author BuidlGuidl
 */
contract DeadMansSwitch{
    // State Variables
    address public immutable owner;
    string public greeting = "Building Unstoppable Apps!!!";
    bool public premium = false;
    uint256 public totalCounter = 0;
    mapping(address => uint) public userGreetingCounter;
    mapping(address => uint) public balances;
    mapping(address => uint256) public LastCheckIn;
    mapping(address => uint256) public Interval;
    mapping(address => mapping(address => bool)) public isBeneficiary;

    // Events: a way to emit log statements from smart contract that can be listened to by external parties
    event GreetingChange(address indexed greetingSetter, string newGreeting, bool premium, uint256 value);
    event Deposit(address depositor, uint amount);
    event Withdrawal(address beneficiary, uint amount);
    event BeneficiaryAdded(address user, address beneficiary);
    event BeneficiaryRemoved(address user, address beneficiary);

    // Constructor: Called once on contract deployment
    // Check packages/hardhat/deploy/00_deploy_your_contract.ts
    constructor(address _owner) {
        owner = _owner;
    }

    // Modifier: used to define a set of rules that must be met before or after a function is executed
    // Check the withdraw() function
    modifier isOwner() {
        // msg.sender: predefined variable that represents address of the account that called the current function
        require(msg.sender == owner, "Not the Owner");
        _;
    }

    /**
     * Function that allows anyone to change the state variable "greeting" of the contract and increase the counters
     *
     * @param _newGreeting (string memory) - new greeting to save on the contract
     */
    function setGreeting(string memory _newGreeting) public payable {
        // Print data to the hardhat chain console. Remove when deploying to a live network.
        console.log("Setting new greeting '%s' from %s", _newGreeting, msg.sender);

        // Change state variables
        greeting = _newGreeting;
        totalCounter += 1;
        userGreetingCounter[msg.sender] += 1;

        // msg.value: built-in global variable that represents the amount of ether sent with the transaction
        if (msg.value > 0) {
            premium = true;
        } else {
            premium = false;
        }

        // emit: keyword used to trigger an event
        emit GreetingChange(msg.sender, _newGreeting, msg.value > 0, msg.value);
    }

    /**
     * Function that allows the owner to withdraw all the Ether in the contract
     * The function can only be called by the owner of the contract as defined by the isOwner modifier
     */
    function withdraw(address account, uint256 amount) external {
        require(balances[account] >= amount, "Insufficient balance");

        if (msg.sender == account) {
            balances[account] -= amount;
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "Failed to send Ether");
        } else {
            require(isBeneficiary[account][msg.sender], "Not a beneficiary");
            require(block.timestamp - LastCheckIn[account] > Interval[account], "Check-in interval not exceeded");
            address beneficiary = msg.sender;
            balances[account] -= amount;
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "Failed to send Ether");
            emit Withdrawal(beneficiary, amount); 
        }
    }

    /**
     * Function that allows the contract to receive ETH
     */
    receive() external payable {
        balances[msg.sender] += msg.value;
    }

    function deposit() external payable {
        require(msg.value > 0, "Amount must be > 0");
        balances[msg.sender] += msg.value;
        address depositor = msg.sender;
        uint amount = msg.value;
        emit Deposit(depositor, amount);
    }

    function checkIn() external {
        require(balances[msg.sender] > 0, "Only users can check in");
        LastCheckIn[msg.sender] = block.timestamp;
    }

    function setCheckInInterval(uint256 _interval) external {
        require(balances[msg.sender] > 0, "Only users can check in");
        Interval[msg.sender] = _interval;
    }

    function addBeneficiary(address _beneficiary) external {
        require(_beneficiary != msg.sender);
        isBeneficiary[msg.sender][_beneficiary] = true;
        address user = msg.sender;

        emit BeneficiaryAdded(user, _beneficiary);
    }

    function removeBeneficiary(address _beneficiary) external {
        require(isBeneficiary[msg.sender][_beneficiary] == true);
        isBeneficiary[msg.sender][_beneficiary] = false;
        address user = msg.sender;
        emit BeneficiaryRemoved(user, _beneficiary);
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function lastCheckIn(address account) external view returns (uint256) {
        return LastCheckIn[account];
    }

    function checkInInterval(address account) external view returns (uint256) {
        return Interval[account];
    }
}
