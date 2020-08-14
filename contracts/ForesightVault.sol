// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Foresight.sol";


/// @title ForesightVault
/// @notice Holds data to mint complete sets of Foresight tokens.
/// @dev Foresight Tokens are ERC777 for hooks usage if necessary.
///      Contract can only be controlled by owning contract.
contract ForesightVault is Ownable {
    /// @notice Address of the market connected to the Foresight Vault.
    address public marketAddress;
    /// @notice YesShort token pointer.
    Foresight public yesShortToken;
    /// @notice NoLong token pointer.
    Foresight public noLongToken;
    /// @notice Invalid token pointer.
    Foresight public invalidToken;
    /// @notice YesShort token address pointer.
    address public yesShortTokenAddress;
    /// @notice NoLong token address pointer.
    address public noLongTokenAddress;
    /// @notice Invalid token address pointer.
    address public invalidTokenAddress;

    /// @notice Create a minter and store market address data.
    /// @param setMarketAddress Pointer to the market Address linking the Foresight token.
    constructor(address setMarketAddress) public {
        marketAddress = setMarketAddress;
        yesShortToken = new Foresight("Foresight - Yes/Short", "FYS", setMarketAddress);
        noLongToken = new Foresight("Foresight - No/Long", "FNL", setMarketAddress);
        invalidToken = new Foresight("Foresight - Invalid", "FINV", setMarketAddress);
        yesShortTokenAddress = address(yesShortToken);
        noLongTokenAddress = address(noLongToken);
        invalidTokenAddress = address(invalidToken);
    }

    /// @notice Mints a complete set of Foresight Tokens.
    /// @dev Only the owner of the contract can mint tokens.
    /// @param amount Amount of each token to mint.
    /// @param to Address to send tokens to.
    function mintCompleteSets(address to, uint amount) public onlyOwner {
        noLongToken.mint(to, amount);
        yesShortToken.mint(to, amount);
        invalidToken.mint(to, amount);
    }

    /// @notice Burn the YesShort Foresight Token for the given address.
    /// @dev Only the owner of the contract can burn tokens.
    /// @param amount Amount of each token to mint.
    /// @param from Address to burn tokens from.
    function burnYesShort(address from, uint amount) public onlyOwner {
        yesShortToken.burn(from, amount);
    }

    /// @notice Burn the NoLong Foresight Token for the given address.
    /// @dev Only the owner of the contract can burn tokens.
    /// @param amount Amount of each token to mint.
    /// @param from Address to burn tokens from.
    function burnNoLong(address from, uint amount) public onlyOwner {
        noLongToken.burn(from, amount);
    }

    /// @notice Burn the NoLong Foresight Token for the given address.
    /// @dev Only the owner of the contract can burn tokens.
    /// @param amount Amount of each token to mint.
    /// @param from Address to burn tokens from.
    function burnInvalid(address from, uint amount) public onlyOwner {
        invalidToken.burn(from, amount);
    }

}
