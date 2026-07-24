// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/Governance.sol";
import "../contracts/DecentralizedResistanceToken.sol";

contract GasReportGovernance is Test {
    Governance governance;
    DecentralizedResistanceToken token;

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
        governance = new Governance(address(token), 7 days);

        token.transfer(user1, 1_000 ether);
        token.transfer(user2, 500 ether);

        token.setVotingContract(address(governance));
    }

    function _record(string memory name, uint256 gasUsed) internal {
        gasReport.push(GasItem(name, gasUsed));
    }

    function testGenerateGasReport() public {
        uint256 gasStart;
        uint256 gasUsed;

        // propose
        vm.prank(user1);
        gasStart = gasleft();
        governance.propose("Expand the network");
        gasUsed = gasStart - gasleft();
        _record("propose", gasUsed);

        // vote FOR
        vm.prank(user1);
        gasStart = gasleft();
        governance.vote(1);
        gasUsed = gasStart - gasleft();
        _record("vote_for", gasUsed);

        // vote AGAINST
        vm.prank(user2);
        gasStart = gasleft();
        governance.vote(0);
        gasUsed = gasStart - gasleft();
        _record("vote_against", gasUsed);

        // warp after deadline
        vm.warp(block.timestamp + 8 days);

        // getResult
        gasStart = gasleft();
        governance.getResult(1);
        gasUsed = gasStart - gasleft();
        _record("getResult", gasUsed);

        _printJson();
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