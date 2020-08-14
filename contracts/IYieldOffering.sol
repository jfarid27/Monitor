// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;


interface IYieldOffering {

    /// @notice Returns the current amount of user's stake.
    /// @param a Amount of stake token to stake.
    function balances(address a) external returns (uint);

    /// @notice Updates the balance of yield tokens for the given user.
    /// @param toAddress User to update balance for.
    /// @param amount Amount of yield to update.
    function updateBalance(address toAddress, uint amount) external;

}
