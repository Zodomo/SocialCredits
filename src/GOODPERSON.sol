// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

import "../lib/solady/src/tokens/ERC20.sol";
import "../lib/solady/src/auth/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "../lib/LayerZero/contracts/interfaces/ILayerZeroReceiver.sol";
import "../lib/solidity-bytes-utils/contracts/BytesLib.sol";
import "../lib/LayerZero/contracts/interfaces/ILayerZeroEndpoint.sol";

contract GOODPERSON is ERC20, Ownable, Initializable, ILayerZeroReceiver {
    using BytesLib for bytes;

    event LZSent(address indexed _from, address indexed _to, uint256 indexed _amount);
    event LZReceived(address indexed _recipient, uint256 indexed _amount);

    string internal _name;
    string internal _symbol;

    uint256 public maxSupply;
    address public lzEndpoint;

    constructor() {}

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 _maxSupply,
        address _lzEndpoint,
        address _owner
    ) external initializer {
        _name = name_;
        _symbol = symbol_;
        maxSupply = _maxSupply;
        lzEndpoint = _lzEndpoint;
        _initializeOwner(_owner);
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

    function lzSend(
        uint16 _dstChainId,
        address _zroPaymentAddress,
        uint256 _nativeFee,
        bytes memory _adapterParams,
        address _recipient,
        uint256 _amount
    ) public {
        _burn(msg.sender, _amount);
        bytes memory payload = abi.encodePacked(_recipient, _amount);
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
        uint16,
        bytes calldata _srcAddress,
        uint64,
        bytes calldata _payload
    ) external {
        if (msg.sender != lzEndpoint) revert Unauthorized();
        if (!_srcAddress.equal(abi.encodePacked(address(this), address(this)))) revert Unauthorized();
        address recipient;
        uint256 amount;
        recipient = _payload.slice(0, 20).toAddress(0);
        amount = _payload.slice(20, 32).toUint256(0);
        emit LZReceived(recipient, amount);
        _mint(recipient, amount);
    }
}