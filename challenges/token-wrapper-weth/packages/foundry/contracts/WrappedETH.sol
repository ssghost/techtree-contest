// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract WrappedETH {

    error InsufficientBalance();
    error InsufficientAllowance();
    error ETHTransferFailed();

    string public constant name = "Wrapped Ether";
    string public constant symbol = "WETH";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256 bal = balanceOf[msg.sender];
        if (bal < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[msg.sender] = bal - amount;
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();

        uint256 bal = balanceOf[from];
        if (bal < amount) revert InsufficientBalance();

        unchecked {
            allowance[from][msg.sender] = allowed - amount;
            balanceOf[from] = bal - amount;
            balanceOf[to] += amount;
        }

        emit Approval(from, msg.sender, allowance[from][msg.sender]);
        emit Transfer(from, to, amount);

        return true;
    }

    function deposit() public payable {
        uint256 amount = msg.value;

        unchecked {
            balanceOf[msg.sender] += amount;
            totalSupply += amount;
        }

        emit Deposit(msg.sender, amount);
        emit Transfer(address(0), msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        uint256 bal = balanceOf[msg.sender];
        if (bal < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[msg.sender] = bal - amount;
            totalSupply -= amount;
        }

        emit Transfer(msg.sender, address(0), amount);
        emit Withdrawal(msg.sender, amount);

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert ETHTransferFailed();
    }

    receive() external payable {
        deposit();
    }

    fallback() external payable {
        deposit();
    }
}