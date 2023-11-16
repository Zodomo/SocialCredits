// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

import "../lib/solady/src/tokens/ERC20.sol";
import "../lib/solady/src/auth/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "../lib/LayerZero/contracts/interfaces/ILayerZeroReceiver.sol";
import "../lib/solidity-bytes-utils/contracts/BytesLib.sol";
import "../lib/LayerZero/contracts/interfaces/ILayerZeroEndpoint.sol";
import "./libraries/Structs.sol";

contract GOODPERSON is ERC20, Ownable, Initializable, ILayerZeroReceiver {
    using BytesLib for bytes;

    error Overflow();
    error Underflow();

    event LZSent(address indexed _from, address indexed _to, uint256 indexed _amount);
    event LZReceived(address indexed _recipient, uint256 indexed _amount);
    event LZAllocation(uint16 indexed _dstChainId, address indexed _minter, uint256 indexed _allocation);
    event SetAllocation(address indexed _minter, uint256 indexed _amount);

    string internal _name;
    string internal _symbol;

    mapping(address minter => Structs.Allocation allocation) public allocations;
    mapping(address minter => mapping(uint16 dstChainId => uint256 allocation)) public lzAllocations;
    uint256 public totalAllocated;
    uint256 public maxSupply;
    address public lzEndpoint;
    bool public isMainnet;

    modifier onlyMainnet() {
        if (!isMainnet) revert Unauthorized();
        _;
    }

    constructor() {}

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 _maxSupply,
        address _lzEndpoint,
        address _owner,
        bool _isMainnet
    ) external initializer {
        _name = name_;
        _symbol = symbol_;
        maxSupply = _maxSupply;
        lzEndpoint = _lzEndpoint;
        _initializeOwner(_owner);
        isMainnet = _isMainnet;
    }

    function disableInitializers() external {
        _disableInitializers();
    }

    function name() public view override returns (string memory) {
        return _name;
    }
    
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function allocate(address _minter, uint256 _allocation) external onlyOwner onlyMainnet {
        if (totalAllocated + _allocation > maxSupply) revert Overflow();
        if (_allocation < allocations[_minter].used + lzAllocations[_minter][0]) revert Underflow();
        uint256 existingAllocation = allocations[_minter].allocated;
        if (_allocation > existingAllocation) {
            unchecked { totalAllocated += _allocation - existingAllocation; }
        } else {
            unchecked { totalAllocated -= existingAllocation - _allocation; }
        }
        allocations[_minter].allocated = _allocation;
        emit SetAllocation(_minter, _allocation);
    }

    function lzAllocate(
        uint16 _dstChainId,
        address _zroPaymentAddress,
        uint256 _nativeFee,
        bytes memory _adapterParams,
        address _minter,
        uint256 _allocation
    ) internal {
        if (totalAllocated + _allocation > maxSupply) revert Overflow();
        uint256 existingAllocation = lzAllocations[_minter][_dstChainId];
        if (_allocation <= existingAllocation) revert Underflow();
        unchecked { totalAllocated += _allocation - existingAllocation; }
        lzAllocations[_minter][_dstChainId] = _allocation;
        bytes memory payload = abi.encodePacked(_minter, _allocation, true);
        ILayerZeroEndpoint(lzEndpoint).send{ value: _nativeFee }(
            _dstChainId,
            abi.encodePacked(address(this), address(this)),
            payload,
            payable(msg.sender),
            _zroPaymentAddress,
            _adapterParams
        );
        emit LZAllocation(_dstChainId, _minter, _allocation);
    }

    function lzSend(
        uint16 _dstChainId,
        address _zroPaymentAddress,
        uint256 _nativeFee,
        bytes memory _adapterParams,
        address _recipient,
        uint256 _amount
    ) external {
        _burn(msg.sender, _amount);
        bytes memory payload = abi.encodePacked(_recipient, _amount, false, false);
        ILayerZeroEndpoint(lzEndpoint).send{ value: _nativeFee }(
            _dstChainId,
            abi.encodePacked(address(this), address(this)),
            payload,
            payable(msg.sender),
            _zroPaymentAddress,
            _adapterParams
        );
        emit LZSent(msg.sender, _recipient, _amount);
    }

    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64,
        bytes calldata _payload
    ) external {
        if (msg.sender != lzEndpoint) revert Unauthorized();
        if (!_srcAddress.equal(abi.encodePacked(address(this), address(this)))) revert Unauthorized();
        address recipient = _payload.slice(0, 20).toAddress(0);
        uint256 amount = _payload.slice(20, 32).toUint256(0);
        bool isAllocation = (_payload.slice(52, 1).toUint8(0) == 1) ? true : false;
        bool isDeduction  = (_payload.slice(53, 1).toUint8(0) == 1) ? true : false; // TODO: Handle allocation deductions;
        emit LZReceived(recipient, amount);
        if (!isAllocation) {
            _mint(recipient, amount);
        } else {
            // TODO: Process allocation logic
        }
    }
}