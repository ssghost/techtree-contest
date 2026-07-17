// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract RebasingERC20 {
    string public constant name = "Rebasing Token";
    string public constant symbol = "RBT";
    uint8 public constant decimals = 18;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    uint256 private _totalSupply; // fragments
    uint256 private immutable _totalGons;
    uint256 private _gonsPerFragment;

    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Rebase(uint256 totalSupply);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(uint256 initialSupply) {
        require(initialSupply > 0, "Initial supply must be > 0");

        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);

        _totalSupply = initialSupply;

        _totalGons = initialSupply * 1e18;
        _gonsPerFragment = _totalGons / _totalSupply;

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
        require(currentAllowance >= amount, "ERC20: insufficient allowance");

        _allowances[from][msg.sender] = currentAllowance - amount;
        emit Approval(from, msg.sender, _allowances[from][msg.sender]);

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from zero");
        require(to != address(0), "ERC20: transfer to zero");

        uint256 gonAmount = amount * _gonsPerFragment;
        require(_gonBalances[from] >= gonAmount, "ERC20: transfer exceeds balance");

        _gonBalances[from] -= gonAmount;
        _gonBalances[to] += gonAmount;

        emit Transfer(from, to, amount);
    }

    // ================= Rebase =================

    function rebase(int256 supplyDelta) external onlyOwner returns (uint256) {
        if (supplyDelta == 0) {
            emit Rebase(_totalSupply);
            return _totalSupply;
        }

        if (supplyDelta < 0) {
            uint256 decrease = uint256(-supplyDelta);
            require(decrease < _totalSupply, "Rebase underflow");
            _totalSupply -= decrease;
        } else {
            _totalSupply += uint256(supplyDelta);
        }

        _gonsPerFragment = _totalGons / _totalSupply;

        emit Rebase(_totalSupply);
        return _totalSupply;
    }
}
