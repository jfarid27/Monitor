// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "./Monitor.sol";
import "./YieldOffering.sol";


/// @title Deploy
/// @notice Deploys the Monitor and Yield Offering.
contract Deploy {

    /// @notice Monitor instance.
    Monitor public monitor;
    /// @notice Monitor address.
    address public monitorAddress;
    /// @notice Yield offering instance.
    YieldOffering public yieldOffering;
    /// @notice Yield offering address.
    address public yieldOfferingAddress;

    /// @notice Instantiates the monitor and Yield Offering.
    /// @param startTime1 Start time for pool.
    /// @param endTime1 End time for pool.
    /// @param startTime2 Start time for pool.
    /// @param endTime2 End time for pool.
    /// @param startTime3 Start time for pool.
    /// @param endTime3 End time for pool.
    /// @param startTime4 Start time for pool.
    /// @param endTime4 End time for pool.
    /// @param secondReward Amount to start in the stake reward contracts.
    /// @param monitorTradeToken Complete set minting token.
    /// @param yieldRewardStakeToken Token used to generate yield during staking.
    constructor(
        uint startTime1,
        uint endTime1,
        uint startTime2,
        uint endTime2,
        uint startTime3,
        uint endTime3,
        uint startTime4,
        uint endTime4,
        uint secondReward,
        address yieldRewardStakeToken,
        address monitorTradeToken
    ) public {
        yieldOffering = new YieldOffering(
            startTime1,
            endTime1,
            startTime2,
            endTime2,
            startTime3,
            endTime3,
            startTime4,
            endTime4,
            secondReward,
            yieldRewardStakeToken
        );
        yieldOfferingAddress = address(yieldOffering);

        monitor = new Monitor(yieldOffering.mainTokenAddress(), monitorTradeToken);
        monitorAddress = address(monitor);
    }
}
