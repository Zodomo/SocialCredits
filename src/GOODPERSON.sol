// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

// >>>>>>>>>>>> [ IMPORTS ] <<<<<<<<<<<<

import "../lib/solady/src/tokens/ERC20.sol";
import "../lib/solady/src/auth/Ownable.sol";
import "./libraries/Structs.sol";

/**
 * @title GOODPERSON
 * @notice A social good token programmatically distributable to those who do good things onchain.
 * @author Zodomo.eth (Farcaster/Telegram/Discord/Github: @zodomo, X: @0xZodomo, Email: zodomo@proton.me)
 * @custom:github https://github.com/Zodomo/GOODPERSON
 */
contract GOODPERSON is ERC20, Ownable {

    // >>>>>>>>>>>> [ ERRORS ] <<<<<<<<<<<<

    error Locked();
    error Overflow();
    error Underflow();

    // >>>>>>>>>>>> [ EVENTS ] <<<<<<<<<<<<

    event Unlocked(bool indexed _status);
    event SetAllocation(address indexed _minter, uint256 indexed _amount);
    event SupplyReduced(uint256 indexed _maxSupply);

    event OwnerMint(address indexed _to, uint256 indexed _amount);
    event AllocationMint(address indexed _minter, address indexed _to, uint256 indexed _amount);
    event Burned(address indexed _burner, uint256 indexed _amount);
    event Forfeit(address indexed _forfeiter, uint256 indexed _amount);

    // >>>>>>>>>>>> [ STORAGE VARIABLES ] <<<<<<<<<<<<

    string internal _name;
    string internal _symbol;

    mapping(address minter => Structs.Allocation allocation) public allocations;
    uint256 public totalAllocated;
    uint256 public maxSupply;
    bool public unlocked;

    // >>>>>>>>>>>> [ MODIFIERS ] <<<<<<<<<<<<

    /// @notice Prevents mint supply errors
    /// @dev Allows owner to mint if enough unallocated supply, otherwise check caller allocation and adjust it
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

    /// @notice Restrict function to token holder or approved address, used only for burning
    modifier isApprovedOrHolder(address _from, uint256 _amount) {
        if (_from != msg.sender && allowance(_from, msg.sender) < _amount) revert Unauthorized();
        _;
    }

    // >>>>>>>>>>>> [ CONSTRUCTOR ] <<<<<<<<<<<<

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

    // >>>>>>>>>>>> [ METADATA / VIEW FUNCTIONS ] <<<<<<<<<<<<

    /// @notice Metadata function for returning token name
    /// @return name_ token name
    function name() public view override returns (string memory name_) {
        name_ = _name;
    }
    
    /// @notice Metadata function for returning token symbol
    /// @return symbol_ token symbol
    function symbol() public view override returns (string memory symbol_) {
        symbol_ = _symbol;
    }

    /// @notice Return allocation for a given minter
    /// @param _minter minter address
    /// @return _allocation mint allocation
    function getAllocation(address _minter) external view returns (uint256 _allocation) {
        _allocation = allocations[_minter].allocated;
    }

    // >>>>>>>>>>>> [ MANAGEMENT FUNCTIONS ] <<<<<<<<<<<<

    /// @notice Toggle transaction lock on/off
    function toggleLock() external onlyOwner {
        bool status = !unlocked;
        unlocked = status;
        emit Unlocked(status);
    }

    /// @notice Allocate supply to a specific address to mint
    /// @dev Also used to reduce allocation as long as it doesn't go below what has been used
    /// @param _minter approved minter
    /// @param _allocation mintable token allocation
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

    /// @notice Reduce max supply
    /// @dev Cannot reduce beneath sum of both minted and allocated supply
    /// @param _maxSupply new max supply value
    function reduceMaxSupply(uint256 _maxSupply) external onlyOwner {
        if (_maxSupply < totalSupply() + totalAllocated) revert Underflow();
        maxSupply = _maxSupply;
        emit SupplyReduced(_maxSupply);
    }

    // >>>>>>>>>>>> [ MINT / BURN FUNCTIONS ] <<<<<<<<<<<<

    /// @notice Mint tokens to a recipient if caller is an approved minter
    /// @dev owner() is always approved as long as supply allows, everyone else must have supply allocated
    /// @param _to token recipient
    /// @param _amount token quantity
    function mint(address _to, uint256 _amount) external mintable(_to, _amount) {
        _mint(_to, _amount);
    }

    /// @notice Burn token supply
    /// @dev Callable by approved addresses, also reduces maxSupply
    /// @param _from address to burn from
    /// @param _amount token amount to burn
    function burn(address _from, uint256 _amount) external isApprovedOrHolder(_from, _amount) {
        _burn(_from, _amount);
        unchecked { maxSupply -= _amount; }
        emit Burned(_from, _amount);
    }

    /// @notice Burn minted tokens and return to minter allocation
    /// @dev Doesn't reduce maxSupply
    /// @param _from address to forfeit from
    /// @param _amount token amount to forfeit
    function forfeit(address _from, uint256 _amount) external isApprovedOrHolder(_from, _amount) {
        _burn(_from, _amount);
        unchecked {
            allocations[msg.sender].used -= _amount;
            totalAllocated += _amount;
        }
        emit Forfeit(_from, _amount);
    }

    // >>>>>>>>>>>> [ INTERNAL FUNCTIONS ] <<<<<<<<<<<<

    /// @notice Pre-transfer hook to apply transfer lock and exempt mints and burns from it
    /// @param _from sender address (address(0) for mints)
    /// @param _to recipient address (address(0) for burns)
    function _beforeTokenTransfer(address _from, address _to, uint256) internal view override {
        // Revert when transfers are locked (mints/burns always exempt)
        if (_from == address(0)) return; // mint exemption
        if (_to == address(0)) return; // burn exemption
        if (_from != owner() && !unlocked) revert Locked(); // Impose transfer lock on everyone but owner
    }
}