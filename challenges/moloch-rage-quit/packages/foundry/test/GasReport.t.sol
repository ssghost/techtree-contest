// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/MolochRageQuit.sol";

contract GasReportMolochRageQuit is Test {
    MolochRageQuit dao;

    address owner;
    address member1;
    address member2;

    struct GasItem {
        string functionName;
        uint256 gasUsed;
    }

    GasItem[] internal gasReport;

    function setUp() public {
        owner = address(this);
        member1 = address(0x1);
        member2 = address(0x2);

        dao = new MolochRageQuit(100);

        vm.deal(address(dao), 100 ether);
    }

    function _record(string memory name, uint256 gasUsed) internal {
        gasReport.push(GasItem(name, gasUsed));
    }

    function testGenerateGasReport() public {
        uint256 gasStart;
        uint256 gasUsed;

        // propose
        gasStart = gasleft();
        dao.propose(address(dao), abi.encodeWithSelector(dao.addMember.selector, member1, 50), block.timestamp + 1 days);
        gasUsed = gasStart - gasleft();
        _record("propose", gasUsed);

        // vote by owner
        gasStart = gasleft();
        dao.vote(1);
        gasUsed = gasStart - gasleft();
        _record("vote_owner", gasUsed);

        // warp after deadline
        vm.warp(block.timestamp + 2 days);

        // execute proposal
        gasStart = gasleft();
        dao.executeProposal(1);
        gasUsed = gasStart - gasleft();
        _record("executeProposal", gasUsed);

        // rageQuit member1
        vm.prank(member1);
        gasStart = gasleft();
        dao.rageQuit();
        gasUsed = gasStart - gasleft();
        _record("rageQuit_member1", gasUsed);

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