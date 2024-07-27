// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";

contract SUERC20 is ERC20 {
    using Address for address;

    address public currentImplementation;
    mapping(address => address) public supportedImplementation;
    mapping(address => uint256) public totalSupportForImplementation;

    event ImplementationSupported(address indexed supporter, address indexed newImplementation, uint256 support);
    event ImplementationChanged(address indexed oldImplementation, address indexed newImplementation);
    event SupportWithdrawn(address indexed supporter, address indexed implementation, uint256 amount);

    constructor(string memory name, string memory symbol, uint256 _totalSupply) ERC20(name, symbol) {
        _mint(msg.sender, _totalSupply);
        
        currentImplementation = address(this);
        totalSupportForImplementation[address(this)] = _totalSupply;
        supportedImplementation[msg.sender] = address(this);
    }

function supportImplementation(address newImplementation) external {
    require(newImplementation != address(0) && newImplementation.code.length > 1, "Invalid implementation");
    uint256 supportAmount = balanceOf(msg.sender);
    
    address previouslySupported = supportedImplementation[msg.sender];
    if (previouslySupported != address(0)) {
        totalSupportForImplementation[previouslySupported] -= supportAmount;
        emit SupportWithdrawn(msg.sender, previouslySupported, supportAmount);
    }
    
    supportedImplementation[msg.sender] = newImplementation;
    totalSupportForImplementation[newImplementation] += supportAmount;

    emit ImplementationSupported(msg.sender, newImplementation, supportAmount);

    if (totalSupportForImplementation[newImplementation] > totalSupply() / 2) currentImplementation = newImplementation;

}

    function withdrawSupport() external {
        address supportedImpl = supportedImplementation[msg.sender];
        require(supportedImpl != address(0), "No supported implementation");
        uint256 supportAmount = balanceOf(msg.sender);

        supportedImplementation[msg.sender] = address(0);
        totalSupportForImplementation[supportedImpl] -= supportAmount;

        emit SupportWithdrawn(msg.sender, supportedImpl, supportAmount);

    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        bool result = super.transfer(recipient, amount);
        if (result) {
            _adjustSupport(msg.sender, recipient, amount);
        }
        return result;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        bool result = super.transferFrom(sender, recipient, amount);
        if (result) {
            _adjustSupport(sender, recipient, amount);
        }
        return result;
    }

    function _adjustSupport(address sender, address recipient, uint256 amount) internal {
        totalSupportForImplementation[supportedImplementation[sender]] -= amount;

    }



    fallback() external payable {
        address impl = currentImplementation;

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    receive() external payable {}
}