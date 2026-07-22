// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract Multisend {
    error LengthMismatch();
    error InvalidETHAmount();
    error ETHTransferFailed();
    error TokenTransferFailed();
    error ZeroAddress();

    event SuccessfulETHTransfer(
        address indexed sender,
        address payable[] receivers,
        uint256[] amounts
    );

    event SuccessfulTokenTransfer(
        address indexed sender,
        address[] indexed receivers,
        uint256[] amounts,
        address indexed token
    );

    function sendETH(address payable[] calldata receivers, uint256[] calldata amounts)
        external
        payable
    {
        uint256 length = receivers.length;
        if (length != amounts.length) revert LengthMismatch();

        uint256 total;
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                uint256 amount = amounts[i];
                total += amount;

                (bool success, ) = receivers[i].call{value: amount}("");
                if (!success) revert ETHTransferFailed();
            }
        }

        if (msg.value != total) revert InvalidETHAmount();

        emit SuccessfulETHTransfer(msg.sender, receivers, amounts);
    }

    function sendTokens(
        address[] calldata receivers,
        uint256[] calldata amounts,
        address token
    ) external {
        if (token == address(0)) revert ZeroAddress();

        uint256 length = receivers.length;
        if (length != amounts.length) revert LengthMismatch();

        IERC20 erc20 = IERC20(token);

        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                if (!erc20.transferFrom(msg.sender, receivers[i], amounts[i])) {
                    revert TokenTransferFailed();
                }
            }
        }

        emit SuccessfulTokenTransfer(msg.sender, receivers, amounts, token);
    }
}

