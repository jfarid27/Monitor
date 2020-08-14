// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";


/// @title Vision
/// @notice ERC777 for the Vision token
interface IVision is IERC777 {

    /// @notice Mints tokens for the given address.
    /// @param toAddress Address to send token.
    /// @param amount Amount to mint.
    function mint(address toAddress, uint amount) external;
}
