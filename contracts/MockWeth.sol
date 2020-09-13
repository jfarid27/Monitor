// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MockWeth is ERC20 {
    constructor(uint256 initialSupply) public ERC20("WETH", "WETH") {
        _mint(msg.sender, initialSupply);
    }
}
