pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";


contract Token is ERC20Detailed, ERC20 {
    constructor(uint256 amount, string memory name, string memory symbol) public ERC20Detailed(name, symbol, 18) {
        _mint(msg.sender, amount * (10 ** 18));
    }
}

