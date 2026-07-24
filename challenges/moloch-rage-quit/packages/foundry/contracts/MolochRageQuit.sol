// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MolochRageQuit {
    error NotMember();
    error AlreadyVoted();
    error ProposalNotFound();
    error DeadlineNotPassed();
    error NoMajority();
    error OnlySelf();
    error NoShares();
    error InvalidProposal();

    struct Proposal {
        address proposer;   // 20 bytes
        address target;     // 20 bytes
        uint64 deadline;    // 8 bytes
        uint128 votes;      // 16 bytes
        bytes data;         // dynamic
    }

    mapping(uint256 => Proposal) private proposals;
    mapping(uint256 => mapping(address => uint128)) private voted;

    mapping(address => uint128) public shares;
    uint128 public totalShares;
    uint128 public proposalCount;

    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address contractToCall,
        bytes dataToCallWith,
        uint256 deadline
    );

    event MemberAdded(address newMember);
    event Voted(uint256 proposalId, address member);
    event ProposalExecuted(uint256 proposalId);
    event RageQuit(address member, uint256 returnedETH);

    constructor(uint256 initialShares) {
        uint128 s = uint128(initialShares);
        shares[msg.sender] = s;
        totalShares = s;
    }

    receive() external payable {}

    function isMember(address account) external view returns (bool) {
        return shares[account] != 0;
    }

    function propose(
        address contractToCall,
        bytes calldata data,
        uint256 deadline
    ) external returns (uint256 id) {
        if (shares[msg.sender] == 0) revert NotMember();
        if (contractToCall == address(0) || deadline <= block.timestamp)
            revert InvalidProposal();

        id = ++proposalCount;

        Proposal storage p = proposals[id];
        p.proposer = msg.sender;
        p.target = contractToCall;
        p.deadline = uint64(deadline);
        p.data = data;

        emit ProposalCreated(id, msg.sender, contractToCall, data, deadline);
    }

    function vote(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        if (p.proposer == address(0)) revert ProposalNotFound();
        if (shares[msg.sender] == 0) revert NotMember();
        if (voted[proposalId][msg.sender] != 0)
            revert AlreadyVoted();

        uint128 weight = shares[msg.sender];
        voted[proposalId][msg.sender] = weight;

        unchecked {
            p.votes += weight;
        }

        emit Voted(proposalId, msg.sender);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];

        if (p.proposer == address(0)) revert ProposalNotFound();
        if (block.timestamp <= p.deadline) revert DeadlineNotPassed();
        if (p.deadline == 0) revert ProposalNotFound();

        if (p.votes <= totalShares >> 1) revert NoMajority();

        p.deadline = 0;

        (bool ok,) = p.target.call(p.data);
        require(ok);

        emit ProposalExecuted(proposalId);
    }

    function addMember(address newMember, uint256 _shares) external {
        if (msg.sender != address(this)) revert OnlySelf();

        uint128 s = uint128(_shares);

        unchecked {
            shares[newMember] += s;
            totalShares += s;
        }

        emit MemberAdded(newMember);
    }

    function rageQuit() external {
        uint128 memberShares = shares[msg.sender];
        if (memberShares == 0) revert NoShares();

        uint256 ts = totalShares;
        uint256 bal = address(this).balance;

        uint256 amount = (bal * memberShares) / ts;

        unchecked {
            totalShares = uint128(ts - memberShares);
        }

        delete shares[msg.sender];

        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok);

        emit RageQuit(msg.sender, amount);
    }

    function getProposal(uint256 proposalId)
        external
        view
        returns (
            address proposer,
            address contractAddr,
            bytes memory data,
            uint256 votes,
            uint256 deadline
        )
    {
        Proposal storage p = proposals[proposalId];
        if (p.proposer == address(0)) revert ProposalNotFound();

        return (p.proposer, p.target, p.data, p.votes, p.deadline);
    }
}
