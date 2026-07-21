// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract Voting {
    error NoVotingPower();
    error AlreadyVoted();
    error VotingEnded();
    error VotingActive();
    error NotToken();

    IERC20 public immutable token;
    address public immutable tokenAddress;
    uint64 public immutable votingDeadline;

    uint256 public votesFor;
    uint256 public votesAgainst;

    struct Voter {
        uint128 weight;
        bool votedFor;
    }

    mapping(address => Voter) public voters;

    event VoteCasted(address voter, bool vote, uint256 weight);
    event VotesRemoved(address voter, uint256 weight);

    constructor(address _tokenAddress, uint256 _votingPeriod) {
        token = IERC20(_tokenAddress);
        tokenAddress = _tokenAddress;
        votingDeadline = uint64(block.timestamp + _votingPeriod);
    }

    function vote(bool _vote) external {
        if (block.timestamp > votingDeadline) revert VotingEnded();

        Voter storage voter = voters[msg.sender];
        if (voter.weight != 0) revert AlreadyVoted();

        uint256 balance = token.balanceOf(msg.sender);
        if (balance == 0) revert NoVotingPower();

        uint128 weight = uint128(balance);

        voter.weight = weight;
        voter.votedFor = _vote;

        if (_vote) {
            votesFor += weight;
        } else {
            votesAgainst += weight;
        }

        emit VoteCasted(msg.sender, _vote, weight);
    }

    function removeVotes(address from) external {
        if (msg.sender != tokenAddress) revert NotToken();

        Voter storage voter = voters[from];
        uint128 weight = voter.weight;

        if (weight == 0) return;

        if (voter.votedFor) {
            votesFor -= weight;
        } else {
            votesAgainst -= weight;
        }

        delete voters[from];

        emit VotesRemoved(from, weight);
    }

    function getResult() external view returns (bool) {
        if (block.timestamp <= votingDeadline) revert VotingActive();
        return votesFor > votesAgainst;
    }
}
