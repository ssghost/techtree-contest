// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract Governance {

    error NoVotingPower();
    error NoActiveProposal();
    error AlreadyVoted();
    error VotingActive();
    error VotingNotActive();
    error NotToken();
    error InvalidVote();


    IERC20 public immutable token;
    address public immutable tokenAddress;
    uint64 public immutable votingPeriod;

    uint256 public proposalCount;

    struct Proposal {
        string title;
        address creator;
        uint64 deadline;
        uint128 votesFor;
        uint128 votesAgainst;
        uint128 votesAbstain;
    }

    mapping(uint256 => Proposal) private proposals;

    // proposalId => voter => voteType (0/1/2)
    mapping(uint256 => mapping(address => uint8)) private voteChoice;
    // proposalId => voter => weight
    mapping(uint256 => mapping(address => uint128)) private voteWeight;

    uint256 public activeProposalId;
    uint256 public queuedProposalId;


    event ProposalCreated(
        uint256 proposalId,
        string title,
        uint256 votingDeadline,
        address creator
    );

    event VoteCasted(
        uint256 proposalId,
        address voter,
        uint8 vote,
        uint256 weight
    );

    event VotesRemoved(
        address voter,
        uint8 vote,
        uint256 weight
    );

    constructor(address _tokenAddress, uint256 _votingPeriod) {
        token = IERC20(_tokenAddress);
        tokenAddress = _tokenAddress;
        votingPeriod = uint64(_votingPeriod);
    }

    function propose(string calldata title) external returns (uint256 id) {
        _rollProposal();

        if (token.balanceOf(msg.sender) == 0) revert NoVotingPower();

        id = ++proposalCount;

        Proposal storage p = proposals[id];
        p.title = title;
        p.creator = msg.sender;
        p.deadline = uint64(block.timestamp) + votingPeriod;

        if (activeProposalId == 0) {
            activeProposalId = id;
        } else {
            if (queuedProposalId != 0) revert VotingActive();
            queuedProposalId = id;
        }

        emit ProposalCreated(id, title, p.deadline, msg.sender);
    }

    function getProposal(uint256 id)
        external
        view
        returns (string memory title, uint256 deadline, address creator)
    {
        Proposal storage p = proposals[id];
        return (p.title, p.deadline, p.creator);
    }

    function vote(uint8 _vote) external {
        _rollProposal();

        uint256 id = activeProposalId;
        if (id == 0) revert NoActiveProposal();

        Proposal storage p = proposals[id];
        if (block.timestamp > p.deadline) revert VotingNotActive();

        if (_vote > 2) revert InvalidVote();

        uint256 bal = token.balanceOf(msg.sender);
        if (bal == 0) revert NoVotingPower();

        if (voteWeight[id][msg.sender] != 0) revert AlreadyVoted();

        uint128 weight = uint128(bal);
        voteWeight[id][msg.sender] = weight;
        voteChoice[id][msg.sender] = _vote;

        if (_vote == 0) {
            p.votesAgainst += weight;
        } else if (_vote == 1) {
            p.votesFor += weight;
        } else {
            p.votesAbstain += weight;
        }

        emit VoteCasted(id, msg.sender, _vote, weight);
    }

    function removeVotes(address from) external {
        if (msg.sender != tokenAddress) revert NotToken();

        uint256 id = activeProposalId;
        if (id == 0) revert NoActiveProposal();

        uint128 weight = voteWeight[id][from];
        if (weight == 0) return;

        uint8 choice = voteChoice[id][from];

        Proposal storage p = proposals[id];

        if (choice == 0) {
            p.votesAgainst -= weight;
        } else if (choice == 1) {
            p.votesFor -= weight;
        } else {
            p.votesAbstain -= weight;
        }

        delete voteWeight[id][from];
        delete voteChoice[id][from];

        emit VotesRemoved(from, choice, weight);
    }

    function getResult(uint256 id) external view returns (bool) {
        Proposal storage p = proposals[id];
        if (block.timestamp <= p.deadline) revert VotingActive();
        return p.votesFor > p.votesAgainst;
    }

    function _rollProposal() internal {
        uint256 id = activeProposalId;
        if (id == 0) return;

        Proposal storage p = proposals[id];

        if (block.timestamp > p.deadline) {
            activeProposalId = queuedProposalId;
            queuedProposalId = 0;
        }
    }
}
