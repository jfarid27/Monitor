// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/// @title Vision
/// @notice ERC777 for the Vision token
contract Vision is ERC777, Ownable {

    /// @notice Sets up the token.
    constructor() public ERC777("Vision", "VIS", new address[](0)) {}

    /// @notice Mints tokens for the given address.
    /// @param toAddress Address to send token.
    /// @param amount Amount to mint.
    function mint(address toAddress, uint amount) public onlyOwner {
        super._mint(toAddress, amount, "", "");
    }
}
