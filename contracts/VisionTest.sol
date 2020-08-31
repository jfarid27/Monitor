// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";


/// @title VisionTest
/// @notice Test ERC777 for the Vision token with open mint function.
contract VisionTest is ERC777 {

    /// @notice Sets up the token.
    constructor() public ERC777("Vision", "VIS", new address[](0)) {}

    /// @notice Mints tokens for the given address.
    /// @param amount Amount to mint.
    function mint(uint amount) public {
        super._mint(msg.sender, amount, "", "");
    }
}
