// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


/// @title ForesightTokens
/// @notice Manages Foresight tokens.
/// @dev Foresight tokens are a set of ERC1155 tokens representing positions in the
///      Monitor system. Each market will have 3 tokens representing Yes, No, and Invalid.
contract ForesightTokens is ERC1155, Ownable, ReentrancyGuard {
    using SafeMath for uint;

    /// @notice Token Ids created.
    uint public totalTokensMinted = 0;

    /// @notice Setup ERC1155.
    constructor() public ERC1155("") {}

    /// @notice Register a new set of Foresight Tokens when a new market is created.
    /// @return currentSet starting index of the market's new set.
    function registerNewSet() public onlyOwner nonReentrant returns (uint currentSet) {
        currentSet = totalTokensMinted + 1;
        totalTokensMinted += 3;
    }

    /// @notice Mint a new amount of Foresight Tokens for the given address.
    /// @param acct Account to send created tokens.
    /// @param id Id of the token to mint.
    /// @param amount Amount of tokens to mint.
    function mint(address acct, uint id, uint amount) public onlyOwner nonReentrant {
        _mint(acct, id, amount, "");
    }

    /// @notice Burn the amount of Foresight Tokens for the given address.
    /// @param acct Address of the Foresight to burn from.
    /// @param id Id of the token to burn.
    /// @param amount Amount of tokens to burn.
    function burn(address acct, uint id, uint amount) public onlyOwner nonReentrant {
        _burn(acct, id, amount);
    }
}
