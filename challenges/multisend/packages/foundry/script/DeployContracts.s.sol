// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../contracts/Multisend.sol";
import "./DeployHelpers.s.sol";

contract DeployContracts is ScaffoldETHDeploy {
    function run() external ScaffoldEthDeployerRunner {
        Multisend multisend = new Multisend();

        console.logString(
            string.concat(
                "Multisend deployed at: ",
                vm.toString(address(multisend))
            )
        );
    }
}