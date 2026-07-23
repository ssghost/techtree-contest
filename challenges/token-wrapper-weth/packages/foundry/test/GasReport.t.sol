// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/WrappedETH.sol";

contract GasReportWrappedETH is Test {
    WrappedETH weth;

    address user1;
    address user2;

    struct GasItem {
        string functionName;
        uint256 gasUsed;
    }

    GasItem[] internal gasReport;

    function setUp() public {
        user1 = address(0x1);
        user2 = address(0x2);

        weth = new WrappedETH();

        vm.deal(user1, 100 ether);
    }

    function _record(string memory name, uint256 gasUsed) internal {
        gasReport.push(GasItem(name, gasUsed));
    }

    function testGenerateGasReport() public {
        uint256 gasUsed;

        // deposit
        vm.prank(user1);
        gasUsed = _executeWithValue(
            user1,
            abi.encodeWithSelector(weth.deposit.selector),
            10 ether
        );
        _record("deposit", gasUsed);

        // transfer
        vm.prank(user1);
        gasUsed = _execute(
            user1,
            abi.encodeWithSelector(
                weth.transfer.selector,
                user2,
                5 ether
            )
        );
        _record("transfer", gasUsed);

        // approve
        vm.prank(user1);
        gasUsed = _execute(
            user1,
            abi.encodeWithSelector(
                weth.approve.selector,
                user2,
                2 ether
            )
        );
        _record("approve", gasUsed);

        // transferFrom
        vm.prank(user2);
        gasUsed = _execute(
            user2,
            abi.encodeWithSelector(
                weth.transferFrom.selector,
                user1,
                user2,
                2 ether
            )
        );
        _record("transferFrom", gasUsed);

        // withdraw
        vm.prank(user2);
        gasUsed = _execute(
            user2,
            abi.encodeWithSelector(
                weth.withdraw.selector,
                7 ether
            )
        );
        _record("withdraw", gasUsed);

        _printJson();
    }

    function _execute(address sender, bytes memory data)
        internal
        returns (uint256 gasUsed)
    {
        uint256 gasStart = gasleft();
        (bool success,) = address(weth).call(data);
        require(success, "call failed");
        gasUsed = gasStart - gasleft();
    }

    function _executeWithValue(
        address sender,
        bytes memory data,
        uint256 value
    ) internal returns (uint256 gasUsed) {
        uint256 gasStart = gasleft();
        (bool success,) = address(weth).call{value: value}(data);
        require(success, "call with value failed");
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