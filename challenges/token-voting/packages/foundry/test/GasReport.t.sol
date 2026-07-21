// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/DecentralizedResistanceToken.sol";
import "../contracts/Voting.sol";

contract GasReportTokenVoting is Test {
    DecentralizedResistanceToken token;
    Voting voting;

    address owner;
    address user1;
    address user2;

    struct GasItem {
        string functionName;
        uint256 gasUsed;
    }

    GasItem[] internal gasReport;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        token = new DecentralizedResistanceToken(1_000_000 ether);
        voting = new Voting(address(token), 3 days);

        token.setVotingContract(address(voting));

        token.transfer(user1, 1_000 ether);
        token.transfer(user2, 500 ether);
    }

    function _record(string memory name, uint256 gasUsed) internal {
        gasReport.push(GasItem(name, gasUsed));
    }

    function testGenerateGasReport() public {
        uint256 gasUsed;

        // user1 votes FOR
        gasUsed = _executeVoting(
            user1,
            abi.encodeWithSelector(voting.vote.selector, true)
        );
        _record("vote_user1_for", gasUsed);

        // user2 votes AGAINST
        gasUsed = _executeVoting(
            user2,
            abi.encodeWithSelector(voting.vote.selector, false)
        );
        _record("vote_user2_against", gasUsed);

        // user1 transfers tokens (triggers removeVotes)
        gasUsed = _executeToken(
            user1,
            abi.encodeWithSelector(token.transfer.selector, user2, 100 ether)
        );
        _record("transfer_trigger_removeVotes", gasUsed);

        // user1 votes again
        gasUsed = _executeVoting(
            user1,
            abi.encodeWithSelector(voting.vote.selector, true)
        );
        _record("vote_user1_again", gasUsed);

        // fast forward time
        vm.warp(block.timestamp + 4 days);

        // get result
        gasUsed = _executeVoting(
            address(this),
            abi.encodeWithSelector(voting.getResult.selector)
        );
        _record("getResult", gasUsed);

        _printJson();
    }

    function _executeVoting(address sender, bytes memory data)
        internal
        returns (uint256 gasUsed)
    {
        vm.prank(sender);
        uint256 gasStart = gasleft();
        (bool success,) = address(voting).call(data);
        require(success, "voting call failed");
        gasUsed = gasStart - gasleft();
    }

    function _executeToken(address sender, bytes memory data)
        internal
        returns (uint256 gasUsed)
    {
        vm.prank(sender);
        uint256 gasStart = gasleft();
        (bool success,) = address(token).call(data);
        require(success, "token call failed");
        gasUsed = gasStart - gasleft();
    }

    function _printJson() internal view {
        uint256 totalGas;

        console2.log("{");
        console2.log('  "gasReport": [');

        for (uint256 i = 0; i < gasReport.length; i++) {
            console2.log("    {");
            console2.log(
                '      "functionName": "%s",',
                gasReport[i].functionName
            );
            console2.log('      "gasUsed": %s', gasReport[i].gasUsed);
            console2.log(i == gasReport.length - 1 ? "    }" : "    },");

            totalGas += gasReport[i].gasUsed;
        }

        console2.log("  ],");
        console2.log('  "totalGasUsed": %s', totalGas);
        console2.log("}");
    }
}
