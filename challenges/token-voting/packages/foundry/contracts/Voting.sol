// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract Voting {
    IERC20 public token;
    address public tokenAddress;
    uint256 public votingDeadline;

    uint256 public votesFor;
    uint256 public votesAgainst;

    mapping(address => bool) public hasVoted;
    mapping(address => bool) public voteChoice; // true = For, false = Against
    mapping(address => uint256) public voteWeight;

    event VoteCasted(address voter, bool vote, uint256 weight);
    event VotesRemoved(address voter, uint256 weight);

    constructor(address _tokenAddress, uint256 _votingPeriod) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_votingPeriod > 0, "Invalid voting period");

        token = IERC20(_tokenAddress);
        tokenAddress = _tokenAddress;
        votingDeadline = block.timestamp + _votingPeriod;
    }

    function vote(bool _vote) external {
        require(block.timestamp <= votingDeadline, "Voting period ended");
        require(!hasVoted[msg.sender], "Already voted");

        uint256 balance = token.balanceOf(msg.sender);
        require(balance > 0, "No voting power");

        hasVoted[msg.sender] = true;
        voteChoice[msg.sender] = _vote;
        voteWeight[msg.sender] = balance;

        if (_vote) {
            votesFor += balance;
        } else {
            votesAgainst += balance;
        }

        emit VoteCasted(msg.sender, _vote, balance);
    }

    function removeVotes(address from) external {
        require(msg.sender == tokenAddress, "Only token contract");

        if (!hasVoted[from]) {
            return;
        }

        uint256 weight = voteWeight[from];
        bool choice = voteChoice[from];

        if (choice) {
            votesFor -= weight;
        } else {
            votesAgainst -= weight;
        }

        hasVoted[from] = false;
        voteWeight[from] = 0;

        emit VotesRemoved(from, weight);
    }

    function getResult() external view returns (bool) {
        require(block.timestamp > votingDeadline, "Voting still active");
        return votesFor > votesAgainst;
    }
}
