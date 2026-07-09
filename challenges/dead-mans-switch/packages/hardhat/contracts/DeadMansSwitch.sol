//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "hardhat/console.sol";

contract DeadMansSwitch{
    mapping(address => uint) public balances;
    mapping(address => uint256) public userCheckIn;
    mapping(address => uint256) public userInterval;
    mapping(address => mapping(address => bool)) public isBeneficiary;

    event Deposit(address depositor, uint amount);
    event Withdrawal(address beneficiary, uint amount);
    event BeneficiaryAdded(address user, address beneficiary);
    event BeneficiaryRemoved(address user, address beneficiary);

    string public constant greeting = "Building Unstoppable Apps!!!";

    error InvalidAmount();
    error InsufficientBalance();
    error TransferFailed();
    error NotBeneficiary();
    error IntervalNotExceeded();
    error OnlyUsers();
    error InvalidBeneficiary();

    function withdraw(address account, uint256 amount) external payable{
        if (amount <= 0) revert InvalidAmount();
        if (balances[account] < amount) revert InsufficientBalance();

        if (msg.sender == account) {
            balances[account] -= amount;
            (bool success, ) = msg.sender.call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            if (!isBeneficiary[account][msg.sender]) revert NotBeneficiary();
            if (block.timestamp - userCheckIn[account] <= userInterval[account]) revert IntervalNotExceeded();
            balances[account] -= amount;
            (bool success, ) = msg.sender.call{value: amount}("");
            if (!success) revert TransferFailed();
            emit Withdrawal(msg.sender, amount);
        }
    }   

    receive() external payable {
        balances[msg.sender] += msg.value;
    }

    function deposit() external payable {
        if (msg.value <= 0) revert InvalidAmount();
        balances[msg.sender] += msg.value;
        uint amount = msg.value;
        emit Deposit(msg.sender, amount);
    }

    function checkIn() external {
        if (balances[msg.sender] <= 0) revert OnlyUsers();
        userCheckIn[msg.sender] = block.timestamp;
    }

    function setCheckInInterval(uint256 _interval) external {
        if (balances[msg.sender] <= 0) revert OnlyUsers();
        userInterval[msg.sender] = _interval;
    }

    function addBeneficiary(address _beneficiary) external {
        if (balances[msg.sender] <= 0) revert OnlyUsers();
        if (_beneficiary == msg.sender) revert InvalidBeneficiary();
        isBeneficiary[msg.sender][_beneficiary] = true;
        emit BeneficiaryAdded(msg.sender, _beneficiary);
    }

    function removeBeneficiary(address _beneficiary) external {
        if (isBeneficiary[msg.sender][_beneficiary] != true) revert NotBeneficiary();
        isBeneficiary[msg.sender][_beneficiary] = false;
        emit BeneficiaryRemoved(msg.sender, _beneficiary);
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function lastCheckIn(address account) external view returns (uint256) {
        return userCheckIn[account];
    }

    function checkInInterval(address account) external view returns (uint256) {
        return userInterval[account];
    }
}
