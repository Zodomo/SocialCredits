// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

import "../lib/solady/src/tokens/ERC20.sol";
import "../lib/solady/src/auth/Ownable.sol";
import "./libraries/Structs.sol";

contract GOODPERSON is ERC20, Ownable {

    error Locked();
    error Overflow();
    error Underflow();

    event Unlocked(bool indexed _status);
    event SetAllocation(address indexed _minter, uint256 indexed _amount);
    event SupplyReduced(uint256 indexed _maxSupply);

    event OwnerMint(address indexed _to, uint256 indexed _amount);
    event AllocationMint(address indexed _minter, address indexed _to, uint256 indexed _amount);
    event Burn(address indexed _burner, uint256 indexed _amount);

    string internal _name;
    string internal _symbol;

    mapping(address minter => Structs.Allocation allocation) public allocations;
    uint256 public totalAllocated;
    uint256 public maxSupply;
    bool public unlocked;

    modifier mintable(address _to, uint256 _amount) {
        if (msg.sender == owner()) {
            if (totalSupply() + totalAllocated + _amount > maxSupply) revert Overflow();
            _;
            emit OwnerMint(_to, _amount);
        } else {
            if (allocations[msg.sender].allocated - allocations[msg.sender].used < _amount) revert Unauthorized();
            unchecked {
                allocations[msg.sender].used += _amount;
                totalAllocated -= _amount;
            }
            _;
            emit AllocationMint(msg.sender, _to, _amount);
        }
    }

    modifier isApprovedOrHolder(address _from, uint256 _amount) {
        if (_from != msg.sender && allowance(_from, msg.sender) < _amount) revert Unauthorized();
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 _maxSupply,
        address _owner
    ) {
        _name = name_;
        _symbol = symbol_;
        maxSupply = _maxSupply;
        _initializeOwner(_owner);
    }

    function name() public view override returns (string memory) {
        return _name;
    }
    
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function toggleLock() external onlyOwner {
        bool status = !unlocked;
        unlocked = status;
        emit Unlocked(status);
    }

    function allocate(address _minter, uint256 _allocation) external onlyOwner {
        if (totalAllocated + _allocation + totalSupply() > maxSupply) revert Overflow();
        if (_allocation < allocations[_minter].used) revert Underflow();
        uint256 existingAllocation = allocations[_minter].allocated;
        if (_allocation > existingAllocation) {
            unchecked { totalAllocated += _allocation - existingAllocation; }
        } else {
            unchecked { totalAllocated -= existingAllocation - _allocation; }
        }
        allocations[_minter].allocated = _allocation;
        emit SetAllocation(_minter, _allocation);
    }

    function reduceMaxSupply(uint256 _maxSupply) external onlyOwner {
        if (_maxSupply < totalSupply() + totalAllocated) revert Underflow();
        maxSupply = _maxSupply;
        emit SupplyReduced(_maxSupply);
    }

    function mint(address _to, uint256 _amount) external mintable(_to, _amount) {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external isApprovedOrHolder(_from, _amount) {
        _burn(_from, _amount);
        unchecked { maxSupply -= _amount; }
        emit Burn(_from, _amount);
    }

    function _beforeTokenTransfer(address _from, address _to, uint256) internal view override {
        if (_to == address(0)) return;
        if (_from != address(0)) {
            if (_from != owner() && !unlocked) revert Locked();
        }
    }
}