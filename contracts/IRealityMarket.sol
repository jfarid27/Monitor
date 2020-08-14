// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;


/// @title IRealityMarket
/// @notice Generate a reality market and appropriate mint/burn tokens.
interface IRealityMarket {
    /// @notice Return the winning outcome for a market.
    function winningOutcome() external returns (int);
}
