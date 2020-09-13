// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


/// @title Vision
/// @notice ERC777 for the Vision token
contract Vision is ERC777, Ownable, ReentrancyGuard {

    /// @notice Sets up the token.
    constructor() public ERC777("Vision", "VIS", new address[](0)) {}

    /// @notice Mints tokens for the given address.
    /// @param toAddress Address to send token.
    /// @param amount Amount to mint.
    function mint(address toAddress, uint amount) public onlyOwner nonReentrant {
        _mint(toAddress, amount, "", "");
    }

    /// @notice Burn the amount of Vision for the given address.
    /// @param acct Address to burn from.
    /// @param amount Amount of tokens to burn.
    function burn(address acct, uint amount) public onlyOwner nonReentrant {
        _burn(acct, amount, "", "");
    }
}
