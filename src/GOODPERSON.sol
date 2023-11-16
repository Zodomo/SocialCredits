// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

import "../lib/solady/src/tokens/ERC20.sol";
import "../lib/solady/src/auth/Ownable.sol";

contract GOODPERSON is ERC20, Ownable {
    string internal _name;
    string internal _symbol;

    uint256 public maxSupply;

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
}