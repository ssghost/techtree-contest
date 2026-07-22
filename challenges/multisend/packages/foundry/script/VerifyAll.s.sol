// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";
import "forge-std/console2.sol";

contract VerifyAll is Script {
    function run() external {
        string memory root = vm.projectRoot();
        string memory path =
            string.concat(root, "/broadcast/Deploy.s.sol/", vm.toString(block.chainid), "/run-latest.json");

        string memory content = vm.readFile(path);

        address contractAddr =
            abi.decode(vm.parseJson(content, ".transactions[0].contractAddress"), (address));

        string memory contractPath = "contracts/Multisend.sol:Multisend";

        string[] memory inputs = new string[](6);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(contractAddr);
        inputs[3] = contractPath;
        inputs[4] = "--chain";
        inputs[5] = vm.toString(block.chainid);

        bytes memory result = vm.ffi(inputs);

        console2.logString(string(result));
    }
}