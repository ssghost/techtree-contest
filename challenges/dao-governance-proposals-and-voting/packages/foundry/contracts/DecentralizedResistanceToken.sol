// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IGovernance {
    function removeVotes(address voter) external;
}

contract DecentralizedResistanceToken {
    error NotOwner();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAddress();

    string public constant name = "Decentralized Resistance Token";
    string public constant symbol = "DRT";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    address public owner;
    address public votingContract;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);


    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(uint256 initialSupply) {
        owner = msg.sender;
        _mint(msg.sender, initialSupply);
    }


    function setVotingContract(address _votingContract) external onlyOwner {
        votingContract = _votingContract;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _update(msg.sender, to, amount);
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

        unchecked {
            allowance[from][msg.sender] = allowed - amount;
        }

        emit Approval(from, msg.sender, allowance[from][msg.sender]);

        _update(from, to, amount);
        return true;
    }

    function _update(address from, address to, uint256 amount) internal {
        if (from != address(0)) {
            uint256 bal = balanceOf[from];
            if (bal < amount) revert InsufficientBalance();

            if (votingContract != address(0)) {
                IGovernance(votingContract).removeVotes(from);
            }

            unchecked {
                balanceOf[from] = bal - amount;
            }
        } else {
            totalSupply += amount;
        }

        if (to == address(0)) revert ZeroAddress();

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }
}
