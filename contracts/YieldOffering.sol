// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Vision.sol";
import "./StakePool.sol";


/// @title YieldOffering
/// @notice Maintains balances from staking pools, minting Vision when balance is redeemed.
/// @dev
contract YieldOffering is ReentrancyGuard {
    using SafeMath for uint;
    /// @notice Created staking pools.
    StakePool public pool1;
    /// @notice Created staking pools.
    StakePool public pool2;
    /// @notice Created staking pools.
    StakePool public pool3;
    /// @notice Created staking pools.
    StakePool public pool4;
    /// @notice Mapping of user balances.
    mapping(address => uint) public balances;
    /// @notice Created Yield token.
    Vision public mainToken;
    /// @notice Yield Token address.
    address public mainTokenAddress;
    /// @notice Token to be used for staking.
    address public stakeToken;

    /// @notice Initializes the Vision token, Monitor, and staking pools.
    /// @dev note each pool will drop it's reward by a one order of magnitude each pool round.
    /// @param startTime1 Start time for pool.
    /// @param endTime1 End time for pool.
    /// @param startTime2 Start time for pool.
    /// @param endTime2 End time for pool.
    /// @param startTime3 Start time for pool.
    /// @param endTime3 End time for pool.
    /// @param startTime4 Start time for pool.
    /// @param endTime4 End time for pool.
    /// @param secondReward Reward to set for each token.
    /// @param setStakeToken Address of the staking token.
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
        address setStakeToken
    ) public {
        stakeToken = setStakeToken;
        mainToken = new Vision();
        mainTokenAddress = address(mainToken);
        pool1 = new StakePool(address(this), setStakeToken, startTime1, endTime1, secondReward);
        pool2 = new StakePool(address(this), setStakeToken, startTime2, endTime2, secondReward.div(10));
        pool3 = new StakePool(address(this), setStakeToken, startTime3, endTime3, secondReward.div(100));
        pool4 = new StakePool(address(this), setStakeToken, startTime4, endTime4, secondReward.div(1000));
    }

    /// @notice Retrieves pool addresses.
    function getPoolAddresses() public view returns (address[4] memory) {
        return [address(pool1), address(pool2), address(pool3), address(pool4)];
    }

    /// @notice Updates the balance of yield tokens for the given user.
    /// @param toAddress User to update balance for.
    /// @param amount Amount of yield to update.
    function updateBalance(address toAddress, uint amount) public {
        bool updateAllowed =
            msg.sender == address(pool1) ||
            msg.sender == address(pool2) ||
            msg.sender == address(pool3) ||
            msg.sender == address(pool4);
        require(updateAllowed);
        balances[toAddress] = amount;
    }

    /// @notice Redeem yield tokens.
    function redeem() public nonReentrant {
        uint balance = balances[msg.sender];
        require(balance > 0);
        balances[msg.sender] = 0;
        mainToken.mint(msg.sender, balance);
    }
}
