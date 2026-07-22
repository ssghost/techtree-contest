// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract EthStreaming {
    uint256 public immutable unlockTime;
    address public owner;

    struct Stream {
        uint256 cap;
        uint256 lastWithdrawalTime;
        uint256 withdrawnSinceLast; // amount withdrawn since last full unlock cycle
    }

    mapping(address => Stream) public streams;

    event AddStream(address recipient, uint256 cap);
    event Withdraw(address recipient, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 _unlockTime) {
        require(_unlockTime > 0, "Invalid unlock time");
        unlockTime = _unlockTime;
        owner = msg.sender;
    }

    receive() external payable {}

    function addStream(address recipient, uint256 cap) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");

        Stream storage stream = streams[recipient];
        stream.cap = cap;

        if (stream.lastWithdrawalTime == 0) {
            stream.lastWithdrawalTime = block.timestamp;
        }

        emit AddStream(recipient, cap);
    }

    function withdraw(uint256 amount) external {
        Stream storage stream = streams[msg.sender];
        require(stream.cap > 0, "No stream");

        uint256 available = _unlockedAmount(msg.sender);
        require(amount <= available, "Amount exceeds unlocked");
        require(address(this).balance >= amount, "Insufficient contract balance");

        stream.withdrawnSinceLast += amount;

        // If fully drained, reset timer
        if (stream.withdrawnSinceLast >= stream.cap) {
            stream.withdrawnSinceLast = 0;
            stream.lastWithdrawalTime = block.timestamp;
        }

        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
    }

    function _unlockedAmount(address recipient) internal view returns (uint256) {
        Stream memory stream = streams[recipient];

        uint256 elapsed = block.timestamp - stream.lastWithdrawalTime;
        uint256 unlocked = (elapsed * stream.cap) / unlockTime;

        if (unlocked > stream.cap) {
            unlocked = stream.cap;
        }

        if (unlocked <= stream.withdrawnSinceLast) {
            return 0;
        }

        return unlocked - stream.withdrawnSinceLast;
    }
}
