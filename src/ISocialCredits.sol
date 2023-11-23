// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

import "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

interface ISocialCredits is IERC20 {
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

    function getAllocation(address _minter) external view returns (uint256);
    function hasAllRoles(address _user, uint256 _roles) external view returns (bool status);

    function allocate(address _minter, uint256 _allocation) external;
    function toggleLock() external;
    function reduceMaxSupply(uint256 _amount) external;
    function setLockExemptSender(address _addr, bool _status) external;
    function setLockExemptRecipient(address _addr, bool _status) external;

    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
    function forfeit(address _from, uint256 _amount) external;
}