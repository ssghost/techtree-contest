// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract EthStreaming {
    error NotOwner();
    error InvalidRecipient();
    error NoStream();
    error AmountExceedsUnlocked();
    error InsufficientBalance();

    uint256 public immutable unlockTime;
    address public immutable owner;

    struct Stream {
        uint128 cap;
        uint128 lastWithdrawalTime;
    }

    mapping(address => Stream) public streams;

    event AddStream(address recipient, uint256 cap);
    event Withdraw(address recipient, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(uint256 _unlockTime) {
        if (_unlockTime == 0) revert();
        unlockTime = _unlockTime;
        owner = msg.sender;
    }

    receive() external payable {}

    function addStream(address recipient, uint256 cap) external onlyOwner {
        if (recipient == address(0)) revert InvalidRecipient();

        streams[recipient] = Stream({
            cap: uint128(cap),
            lastWithdrawalTime: uint128(block.timestamp - unlockTime)
        });

        emit AddStream(recipient, cap);
    }

    function withdraw(uint256 amount) external {
        Stream storage stream = streams[msg.sender];
        uint256 cap = stream.cap;
        if (cap == 0) revert NoStream();

        uint256 elapsed = block.timestamp - stream.lastWithdrawalTime;
        uint256 unlocked = (elapsed * cap) / unlockTime;

        if (unlocked > cap) {
            unlocked = cap;
        }

        if (amount > unlocked) revert AmountExceedsUnlocked();
        if (address(this).balance < amount) revert InsufficientBalance();

        unchecked {
            uint256 timeAdvance = (amount * unlockTime) / cap;
            stream.lastWithdrawalTime += uint128(timeAdvance);
        }

        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
    }
}
