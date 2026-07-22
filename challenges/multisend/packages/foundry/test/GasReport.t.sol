// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/Multisend.sol";
import "../contracts/MockToken.sol";

contract GasReportMultisend is Test {
    Multisend multisend;
    MockToken token;

    address owner;
    address user1;
    address user2;
    address user3;

    struct GasItem {
        string functionName;
        uint256 gasUsed;
    }

    GasItem[] internal gasReport;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);

        multisend = new Multisend();
        token = new MockToken("MockToken", "MTK");

        token.mint(10_000 ether);
        token.approve(address(multisend), type(uint256).max);
    }

    function _record(string memory name, uint256 gasUsed) internal {
        gasReport.push(GasItem(name, gasUsed));
    }

    function testGenerateGasReport() public {
        uint256 gasUsed;

        // sendETH
        address payable[] memory receiversETH = new address payable[](3);
        receiversETH[0] = payable(user1);
        receiversETH[1] = payable(user2);
        receiversETH[2] = payable(user3);

        uint256[] memory amountsETH = new uint256[](3);
        amountsETH[0] = 1 ether;
        amountsETH[1] = 2 ether;
        amountsETH[2] = 3 ether;

        vm.deal(address(this), 10 ether);

        gasUsed = _executeWithValue(
            abi.encodeWithSelector(
                multisend.sendETH.selector,
                receiversETH,
                amountsETH
            ),
            6 ether
        );
        _record("sendETH", gasUsed);

        // sendTokens
        address[] memory receiversToken = new address[](3);
        receiversToken[0] = user1;
        receiversToken[1] = user2;
        receiversToken[2] = user3;

        uint256[] memory amountsToken = new uint256[](3);
        amountsToken[0] = 100 ether;
        amountsToken[1] = 200 ether;
        amountsToken[2] = 300 ether;

        gasUsed = _execute(
            abi.encodeWithSelector(
                multisend.sendTokens.selector,
                receiversToken,
                amountsToken,
                address(token)
            )
        );
        _record("sendTokens", gasUsed);

        _printJson();
    }

    function _execute(bytes memory data)
        internal
        returns (uint256 gasUsed)
    {
        uint256 gasStart = gasleft();
        (bool success,) = address(multisend).call(data);
        require(success, "call failed");
        gasUsed = gasStart - gasleft();
    }

    function _executeWithValue(bytes memory data, uint256 value)
        internal
        returns (uint256 gasUsed)
    {
        uint256 gasStart = gasleft();
        (bool success,) = address(multisend).call{value: value}(data);
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
