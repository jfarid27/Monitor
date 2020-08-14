// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "./IYieldOffering.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/// @title StakePool
/// @notice Creates a stake pool that generates yield with a given staking token.
interface IStakePool {

    /// @notice Returns the start of the user's staking at current amount.
    /// @param a Amount of stake token to stake.
    function timeOfStake(address a) external returns (uint);

    /// @notice Returns the current amount of user's stake.
    /// @param a Amount of stake token to stake.
    function balances(address a) external returns (uint);

    /// @notice Deposits stake token into the pool with the given amount.
    /// @dev Fetches the yield offering balance, computes the amount of yield earned
    ///      since the last deposit, and updates the balance of deposited stake and
    ///      earned yield.
    function startTime() external returns (uint);

    /// @notice Deposits stake token into the pool with the given amount.
    /// @dev Fetches the yield offering balance, computes the amount of yield earned
    ///      since the last deposit, and updates the balance of deposited stake and
    ///      earned yield.
    function endTime() external returns (uint);

    /// @notice Deposits stake token into the pool with the given amount.
    /// @dev Fetches the yield offering balance, computes the amount of yield earned
    ///      since the last deposit, and updates the balance of deposited stake and
    ///      earned yield.
    function secondReward() external returns (uint);


    /// @notice Deposits stake token into the pool with the given amount.
    /// @dev Fetches the yield offering balance, computes the amount of yield earned
    ///      since the last deposit, and updates the balance of deposited stake and
    ///      earned yield.
    /// @param amount Amount of stake token to stake.
    function deposit(uint amount) external returns (uint);

    /// @notice Withdraws the given amount of stake token out of the pool.
    /// @dev Fetches the yield offering balance, computes the amount of yield earned
    ///      since the last deposit, and updates the balance of deposited stake and
    ///      earned yield.
    /// @param amount Amount of stake token to return.
    function withdraw(uint amount) external returns (uint);

}
