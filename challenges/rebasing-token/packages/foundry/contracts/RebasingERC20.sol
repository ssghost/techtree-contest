// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract RebasingERC20 {
    string public constant name = "Rebasing Token";
    string public constant symbol = "RBT";
    uint8 public constant decimals = 18;

    error NotOwner();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidInitialSupply();
    error RebaseUnderflow();

    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    uint256 private _totalSupply;
    uint256 private immutable _totalGons;
    uint256 private _gonsPerFragment;

    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Rebase(uint256 totalSupply);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(uint256 initialSupply) {
        if (initialSupply == 0) revert InvalidInitialSupply();

        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        _totalSupply = initialSupply;
        _totalGons = initialSupply * 1e18;
        _gonsPerFragment = 1e18; // since _totalGons / _totalSupply = 1e18 initially

        _gonBalances[msg.sender] = _totalGons;

        emit Transfer(address(0), msg.sender, initialSupply);
    }

    // ================= ERC20 View =================

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _gonBalances[account] / _gonsPerFragment;
    }

    function allowance(address holder, address spender) external view returns (uint256) {
        return _allowances[holder][spender];
    }

    // ================= ERC20 Logic =================

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();

        unchecked {
            _allowances[from][msg.sender] = currentAllowance - amount;
        }
        emit Approval(from, msg.sender, _allowances[from][msg.sender]);

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();

        uint256 gonAmount = amount * _gonsPerFragment;
        uint256 fromBalance = _gonBalances[from];
        if (fromBalance < gonAmount) revert InsufficientBalance();

        unchecked {
            _gonBalances[from] = fromBalance - gonAmount;
            _gonBalances[to] += gonAmount;
        }

        emit Transfer(from, to, amount);
    }

    // ================= Rebase =================

    function rebase(int256 supplyDelta) external onlyOwner returns (uint256) {
        uint256 supply = _totalSupply;

        if (supplyDelta == 0) {
            emit Rebase(supply);
            return supply;
        }

        if (supplyDelta < 0) {
            uint256 decrease = uint256(-supplyDelta);
            if (decrease >= supply) revert RebaseUnderflow();
            unchecked {
                supply -= decrease;
            }
        } else {
            unchecked {
                supply += uint256(supplyDelta);
            }
        }

        _totalSupply = supply;
        _gonsPerFragment = _totalGons / supply;

        emit Rebase(supply);
        return supply;
    }
}
