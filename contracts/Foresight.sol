// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/// @title Foresight
/// @notice ERC777 Foresight tokens.
/// @dev Only owner can mint and burn tokens, so it is expected that it
///      handles all accounting.
contract Foresight is ERC777, Ownable {
    /// @notice Address of the information market the token is attached to.
    address public marketAddress;

    /// @notice Create token with given name and symb.
    /// @param name Token name.
    /// @param symb Token symbol.
    /// @param setMarketAddress Pointer to the market Address linking the Foresight token.
    constructor(
        string memory name,
        string memory symb,
        address setMarketAddress
    ) public ERC777(name, symb, new address[](0)) {
        marketAddress = setMarketAddress;
    }

    /// @notice Mints given amount of tokens for address to.
    /// @dev Only the owner of the contract can mint tokens.
    /// @param to Address to send tokens to.
    /// @param amount Amount to mint.
    function mint(address to, uint amount) public onlyOwner {
        super._mint(to, amount, "", "");
    }

    /// @notice Mints given amount of tokens for address to.
    /// @dev Only the owner of the contract can mint tokens.
    /// @param to Address to burn tokens from.
    /// @param amount Amount to burn.
    function burn(address to, uint amount) public onlyOwner {
        super._burn(to, amount, "", "");
    }
}
