//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DeadMansSwitch {
    struct User {
        uint96 balance;
        uint32 lastCheckIn;
        uint32 interval;
    }

    mapping(address => User) internal users;
    mapping(address => mapping(address => bool)) public isBeneficiary;

    event Deposit(address depositor, uint amount);
    event Withdrawal(address beneficiary, uint amount);
    event BeneficiaryAdded(address user, address beneficiary);
    event BeneficiaryRemoved(address user, address beneficiary);
    event CheckIn(address account, uint timestamp);

    error InvalidAmount();
    error InsufficientBalance();
    error NotBeneficiary();
    error IntervalNotExceeded();
    error InvalidBeneficiary();
    error TransferFailed();

    /* ========== INTERNAL CHECKIN ========== */

    function _checkIn(User storage u, address account, uint32 ts) internal {
        u.lastCheckIn = ts;
        emit CheckIn(account, ts);
    }

    /* ========== CORE LOGIC ========== */

    function withdraw(address account, uint amount) external {
        if (amount == 0) revert InvalidAmount();

        User storage u = users[account];
        uint96 bal = u.balance;

        if (bal < amount) revert InsufficientBalance();

        if (msg.sender == account) {
            unchecked {
                u.balance = bal - uint96(amount);
            }

            uint32 ts = uint32(block.timestamp);
            _checkIn(u, account, ts);

            (bool success, ) = msg.sender.call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            if (!isBeneficiary[account][msg.sender])
                revert NotBeneficiary();

            if (block.timestamp - u.lastCheckIn <= u.interval)
                revert IntervalNotExceeded();

            unchecked {
                u.balance = bal - uint96(amount);
            }

            (bool success, ) = msg.sender.call{value: amount}("");
            if (!success) revert TransferFailed();

            emit Withdrawal(msg.sender, amount);
        }
    }

    /* ========== PAYABLE ========== */

    receive() external payable {
        User storage u = users[msg.sender];
        unchecked {
            u.balance += uint96(msg.value);
        }

        uint32 ts = uint32(block.timestamp);
        _checkIn(u, msg.sender, ts);

        emit Deposit(msg.sender, msg.value);
    }

    fallback() external payable {
        User storage u = users[msg.sender];
        unchecked {
            u.balance += uint96(msg.value);
        }

        uint32 ts = uint32(block.timestamp);
        _checkIn(u, msg.sender, ts);

        emit Deposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        if (msg.value == 0) revert InvalidAmount();

        User storage u = users[msg.sender];
        unchecked {
            u.balance += uint96(msg.value);
        }

        uint32 ts = uint32(block.timestamp);
        _checkIn(u, msg.sender, ts);

        emit Deposit(msg.sender, msg.value);
    }

    function checkIn() external {
        User storage u = users[msg.sender];
        uint32 ts = uint32(block.timestamp);
        _checkIn(u, msg.sender, ts);
    }

    function setCheckInInterval(uint interval) external {
        if (interval == 0) revert InvalidAmount();

        User storage u = users[msg.sender];
        u.interval = uint32(interval);

        uint32 ts = uint32(block.timestamp);
        _checkIn(u, msg.sender, ts);
    }

    function addBeneficiary(address beneficiary) external {
        if (beneficiary == address(0) || beneficiary == msg.sender)
            revert InvalidBeneficiary();

        if (isBeneficiary[msg.sender][beneficiary])
            revert InvalidBeneficiary();

        isBeneficiary[msg.sender][beneficiary] = true;

        emit BeneficiaryAdded(msg.sender, beneficiary);

        User storage u = users[msg.sender];
        uint32 ts = uint32(block.timestamp);
        _checkIn(u, msg.sender, ts);
    }

    function removeBeneficiary(address beneficiary) external {
        if (!isBeneficiary[msg.sender][beneficiary])
            revert NotBeneficiary();

        delete isBeneficiary[msg.sender][beneficiary];

        emit BeneficiaryRemoved(msg.sender, beneficiary);

        User storage u = users[msg.sender];
        uint32 ts = uint32(block.timestamp);
        _checkIn(u, msg.sender, ts);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function balanceOf(address account) external view returns (uint) {
        return users[account].balance;
    }

    function lastCheckIn(address account) external view returns (uint) {
        return users[account].lastCheckIn;
    }

    function checkInInterval(address account)
        external
        view
        returns (uint)
    {
        return users[account].interval;
    }
}
