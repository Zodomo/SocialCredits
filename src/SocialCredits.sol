// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

// >>>>>>>>>>>> [ IMPORTS ] <<<<<<<<<<<<

import "../lib/solady/src/tokens/ERC20.sol";
import "../lib/solady/src/auth/OwnableRoles.sol";
import "./libraries/Structs.sol";

/**
 * @title SocialCredits
 * @notice A social good token programmatically distributable to those who do good things onchain.
 * @author Zodomo.eth (Farcaster/Telegram/Discord/Github: @zodomo, X: @0xZodomo, Email: zodomo@proton.me)
 * @custom:github https://github.com/Zodomo/SocialCredits
 */
contract SocialCredits is ERC20, OwnableRoles {

    // >>>>>>>>>>>> [ ERRORS ] <<<<<<<<<<<<

    error Locked();
    error Invalid();
    error Overflow();
    error Underflow();

    // >>>>>>>>>>>> [ EVENTS ] <<<<<<<<<<<<

    event Unlocked(bool indexed _status);
    event SupplyReduced(uint256 indexed _maxSupply);
    event SetAllocation(address indexed _minter, uint256 indexed _amount);
    event SetLockExemptSender(address indexed _addr, bool indexed _status);
    event SetLockExemptRecipient(address indexed _addr, bool indexed _status);

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
    address public router;
    address public pair;
    bool public unlocked;

    // >>>>>>>>>>>> [ MODIFIERS ] <<<<<<<<<<<<

    /// @notice Prevents mint supply errors
    /// @dev Allows owner or role 0 to mint if enough unallocated supply, otherwise check caller allocation and adjust it
    /// @custom:securitylevel 0
    modifier mintable(address _to, uint256 _amount) {
        if (msg.sender == owner() || hasAllRoles(msg.sender, _ROLE_0)) {
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

    /// @dev Restrict function to token holder or approved address, used only for burning
    modifier isApprovedOrHolder(address _from, uint256 _amount) {
        if (_from != msg.sender) _spendAllowance(_from, msg.sender, _amount);
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
        _grantRoles(_owner, _ROLE_5);
        _grantRoles(_owner, _ROLE_6);
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

    /// @notice Allocate supply to a specific address to mint
    /// @dev Also used to reduce allocation as long as it doesn't go below what has been used
    /// @param _minter approved minter
    /// @param _allocation mintable token allocation
    /// @custom:securitylevel 1
    function allocate(address _minter, uint256 _allocation) external onlyOwnerOrRoles(_ROLE_1) {
        if (totalAllocated + _allocation + totalSupply() > maxSupply) revert Overflow();
        if (_allocation < allocations[_minter].used) revert Underflow();
        // Give or remove minter forfeit() permissions
        if (!hasAllRoles(_minter, _ROLE_7)) _grantRoles(_minter, _ROLE_7);
        if (_allocation == 0) _removeRoles(_minter, _ROLE_7);
        uint256 existingAllocation = allocations[_minter].allocated;
        if (_allocation > existingAllocation) {
            unchecked { totalAllocated += _allocation - existingAllocation; }
        } else {
            unchecked { totalAllocated -= existingAllocation - _allocation; }
        }
        allocations[_minter].allocated = _allocation;
        emit SetAllocation(_minter, _allocation);
    }

    /// @notice Toggle transaction lock on/off
    /// @custom:securitylevel 2
    function toggleLock() external onlyOwnerOrRoles(_ROLE_2) {
        bool status = !unlocked;
        unlocked = status;
        emit Unlocked(status);
    }

    /// @notice Reduce max supply
    /// @dev Cannot reduce beneath sum of both minted and allocated supply
    /// @param _amount max supply reduction amount
    /// @custom:securitylevel 3
    function reduceMaxSupply(uint256 _amount) external onlyOwnerOrRoles(_ROLE_3) {
        if (maxSupply - _amount < totalSupply() + totalAllocated) revert Underflow();
        unchecked { maxSupply -= _amount; }
        emit SupplyReduced(_amount);
    }

    /// @notice Adjust transfer lock exemption for a sender address
    /// @dev Must exempt Uniswap pair and router to remove liquidity and allow buys during lock
    /// @param _addr exempted address
    /// @param _status exemption status
    /// @custom:securitylevel 4
    function setLockExemptSender(address _addr, bool _status) external onlyOwnerOrRoles(_ROLE_4) {
        // Owner must always be exempt and is automatically managed
        if (_addr == owner()) revert Invalid();
        if (_status) _grantRoles(_addr, _ROLE_5);
        else _removeRoles(_addr, _ROLE_5);
        emit SetLockExemptSender(_addr, _status);
    }

    /// @notice Adjust transfer lock exemption for a recipient address
    /// @dev Useful for exempting platform smart contracts to control how token is utilized
    /// @param _addr exempted address
    /// @param _status exemption status
    /// @custom:securitylevel 4
    function setLockExemptRecipient(address _addr, bool _status) external onlyOwnerOrRoles(_ROLE_4) {
        // Owner must always be exempt and is automatically managed
        if (_addr == owner()) revert Invalid();
        if (_status) _grantRoles(_addr, _ROLE_6);
        else _removeRoles(_addr, _ROLE_6);
        emit SetLockExemptRecipient(_addr, _status);
    }

    // >>>>>>>>>>>> [ MINT / BURN FUNCTIONS ] <<<<<<<<<<<<

    /// @notice Mint tokens to a recipient if caller is an approved minter
    /// @dev owner() is always approved as long as supply allows, everyone else must have supply allocated
    /// @param _to token recipient
    /// @param _amount token quantity
    /// @custom:securitylevel 0
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
    function forfeit(address _from, uint256 _amount) external onlyOwnerOrRoles(_ROLE_0 | _ROLE_7) {
        _burn(_from, _amount);
        if (hasAllRoles(_from, _ROLE_7)) {
            unchecked {
                allocations[msg.sender].used -= _amount;
                totalAllocated += _amount;
            }
        }
        emit Forfeit(_from, _amount);
    }

    // >>>>>>>>>>>> [ OVERRIDE FUNCTIONS ] <<<<<<<<<<<<

    /// @notice Pre-transfer hook to apply transfer lock and exempt mints and burns from it
    /// @param _from sender address (address(0) for mints)
    /// @param _to recipient address (address(0) for burns)
    function _beforeTokenTransfer(address _from, address _to, uint256) internal view override {
        // Revert when transfers are locked (mints/burns always exempt)
        if (_from == address(0)) return; // mint exemption
        if (_to == address(0)) return; // burn exemption
        if (hasAllRoles(_from, _ROLE_5)) return; // sender address exemption (includes: owner, uniswap pair, uniswap router)
        if (hasAllRoles(_to, _ROLE_6)) return; // recipient exemption to allow platform-controlled token movement
        if (!unlocked) revert Locked(); // Impose transfer lock on everyone else if enabled
    }

    /// @dev OwnableRoles.sol override to disable roles if primary ownership is renounced
    /// @param _roles roles to check for
    function _checkOwnerOrRoles(uint256 _roles) internal view override {
        if (owner() == address(0)) revert Unauthorized();
        else super._checkOwnerOrRoles(_roles);
    }

    /// @dev OwnableRoles.sol override to disable roles if primary ownership is renounced
    /// @param _user address being checked
    /// @param _roles roles to check for
    /// @return status role status
    function hasAllRoles(address _user, uint256 _roles) public view override returns (bool status) {
        if (owner() == address(0)) return false;
        else return super.hasAllRoles(_user, _roles);
    }

    /// @dev _setOwner override to adjust owner transfer lock exemptions upon ownership transfers
    /// @param _newOwner new owner address
    function _setOwner(address _newOwner) internal override {
        _removeRoles(owner(), _ROLE_5);
        _removeRoles(owner(), _ROLE_6);
        if (_newOwner != address(0)) {
            _grantRoles(_newOwner, _ROLE_5);
            _grantRoles(_newOwner, _ROLE_6);
        }
        super._setOwner(_newOwner);
    }
}