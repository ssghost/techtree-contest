// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/EthStreaming.sol";

contract GasReportEthStreaming is Test {
    EthStreaming streaming;

    address owner;
    address recipient;

    struct GasItem {
        string functionName;
        uint256 gasUsed;
    }

    GasItem[] internal gasReport;

    function setUp() public {
        owner = address(this);
        recipient = address(0x1);

        streaming = new EthStreaming(30 days);

        vm.deal(address(this), 100 ether);
        (bool success,) = address(streaming).call{value: 100 ether}("");
        require(success);
    }

    function _record(string memory name, uint256 gasUsed) internal {
        gasReport.push(GasItem(name, gasUsed));
    }

    function testGenerateGasReport() public {
        uint256 gasUsed;
        vm.warp(30 days + 1);

        gasUsed = _execute(
            abi.encodeWithSelector(
                streaming.addStream.selector,
                recipient,
                10 ether
            )
        );
        _record("addStream", gasUsed);

        gasUsed = _executeAs(
            recipient,
            abi.encodeWithSelector(
                streaming.withdraw.selector,
                10 ether
            )
        );
        _record("withdraw_full_initial", gasUsed);

        console2.log("=== STEP 3: warp time ===");

        vm.warp(block.timestamp + 30 days);

        console2.log("=== STEP 4: withdraw full after unlock ===");

        gasUsed = _executeAs(
            recipient,
            abi.encodeWithSelector(
                streaming.withdraw.selector,
                10 ether
            )
        );
        _record("withdraw_full_after_unlock", gasUsed);

        _printJson();
    }

    function _execute(bytes memory data)
        internal
        returns (uint256 gasUsed)
    {
        uint256 gasStart = gasleft();
        (bool success,) = address(streaming).call(data);
        require(success, "call failed in _execute");
        gasUsed = gasStart - gasleft();
    }

    function _executeAs(address sender, bytes memory data)
        internal
        returns (uint256 gasUsed)
    {
        vm.prank(sender);
        uint256 gasStart = gasleft();
        (bool success,) = address(streaming).call(data);
        require(success, "call failed in _executeAs");
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