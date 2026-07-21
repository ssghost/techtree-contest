// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/RebasingERC20.sol";

contract GasReportTest is Test {
    RebasingERC20 token;

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

        token = new RebasingERC20(10_000_000 ether);
    }

    function _record(string memory name, uint256 gasUsed) internal {
        gasReport.push(GasItem(name, gasUsed));
    }

    function testGenerateGasReport() public {
        uint256 gasUsed;

        // transfer
        gasUsed = _execute(address(this), abi.encodeWithSelector(token.transfer.selector, user1, 1_000 ether));
        _record("transfer", gasUsed);

        // approve
        gasUsed = _execute(user1, abi.encodeWithSelector(token.approve.selector, user2, 500 ether));
        _record("approve", gasUsed);

        // transferFrom
        gasUsed = _execute(user2, abi.encodeWithSelector(token.transferFrom.selector, user1, user2, 200 ether));
        _record("transferFrom", gasUsed);

        // positive rebase
        gasUsed = _execute(address(this), abi.encodeWithSelector(token.rebase.selector, int256(9_000_000 ether)));
        _record("rebase_positive", gasUsed);

        // negative rebase
        gasUsed = _execute(address(this), abi.encodeWithSelector(token.rebase.selector, int256(-9_000_000 ether)));
        _record("rebase_negative", gasUsed);

        _printJson();
    }

    function _execute(address sender, bytes memory data) internal returns (uint256 gasUsed) {
        vm.prank(sender);
        uint256 gasStart = gasleft();
        (bool success,) = address(token).call(data);
        require(success, "call failed");
        gasUsed = gasStart - gasleft();
    }

    function _printJson() internal view {
        uint256 totalGas;

        console2.log("{");
        console2.log('  "gasReport": [');

        for (uint256 i = 0; i < gasReport.length; i++) {
            console2.log("    {");
            console2.log('      "functionName": "%s",', gasReport[i].functionName);
            console2.log('      "gasUsed": %s', gasReport[i].gasUsed);
            console2.log(i == gasReport.length - 1 ? "    }" : "    },");

            totalGas += gasReport[i].gasUsed;
        }

        console2.log("  ],");
        console2.log('  "totalGasUsed": %s', totalGas);
        console2.log("}");
    }
}
