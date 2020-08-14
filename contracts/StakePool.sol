// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IYieldOffering.sol";


/// @title StakePool
/// @notice Creates a stake pool that generates yield with a given staking token.
contract StakePool is ReentrancyGuard {
    using SafeMath for uint;

    /// @notice Token used to stake and generate yield.
    IERC20 public stakeToken;
    /// @notice Balance holder for the Staking Pool.
    IYieldOffering public yieldOffering;

    /// @notice Returns the start of the user's staking at current amount.
    mapping(address => uint) public timeOfStake;
    /// @notice Returns the current amount of user's stake.
    mapping(address => uint) public balances;
    /// @notice Start of the staking pool.
    uint public startTime;
    /// @notice End of the staking pool
    uint public endTime;
    /// @notice Staking reward per second.
    uint public secondReward;

    /// @notice Sets default values for the staking pool.
    /// @param setYieldOffering Address of the balance holder for staking.
    /// @param setStakeToken Token used for Staking.
    /// @param setStartTime Unix timestamp when staking may begin.
    /// @param setEndTime Unix timestamp when staking ends.
    /// @param setSecondReward Amount of yield to give per second of 1 stake token.
    constructor (
        address setYieldOffering,
        address setStakeToken,
        uint setStartTime,
        uint setEndTime,
        uint setSecondReward
    ) public {
        yieldOffering = IYieldOffering(setYieldOffering);
        stakeToken = IERC20(setStakeToken);
        startTime = setStartTime;
        endTime = setEndTime;
        secondReward = setSecondReward;
    }

    /// @notice Deposits stake token into the pool with the given amount.
    /// @dev Fetches the yield offering balance, computes the amount of yield earned
    ///      since the last deposit, and updates the balance of deposited stake and
    ///      earned yield.
    /// @param amount Amount of stake token to stake.
    function deposit(uint amount) public nonReentrant returns (uint) {
        uint t = block.timestamp;
        require(t < endTime, "staking pool has closed");
        uint currYield = yieldOffering.balances(msg.sender);
        uint currOwed = updateCurrentOwned();
        balances[msg.sender] = balances[msg.sender].add(amount);
        yieldOffering.updateBalance(msg.sender, currOwed + currYield);
        stakeToken.transferFrom(msg.sender, address(this), amount);
        return balances[msg.sender];
    }

    /// @notice Withdraws the given amount of stake token out of the pool.
    /// @dev Fetches the yield offering balance, computes the amount of yield earned
    ///      since the last deposit, and updates the balance of deposited stake and
    ///      earned yield.
    /// @param amount Amount of stake token to return.
    function withdraw(uint amount) public nonReentrant returns (uint) {
        uint currYield = yieldOffering.balances(msg.sender);
        uint currOwed = updateCurrentOwned();
        balances[msg.sender] = balances[msg.sender].sub(amount);
        require(balances[msg.sender] >= 0, "Balance cannot be less than 0.");
        yieldOffering.updateBalance(msg.sender, currOwed + currYield);
        stakeToken.transfer(msg.sender, amount);
        return balances[msg.sender];
    }

    /// @notice Computes the current owned generated yield since the last time of
    ///         stake, updating the time of stake.
    /// @dev Before start, maintains the current owed yield is 0. Otherwise updates.
    function updateCurrentOwned() private nonReentrant returns (uint) {
        uint t = block.timestamp;
        uint currBalance = balances[msg.sender];
        uint prevStart = timeOfStake[msg.sender];
        uint currOwed = 0;
        if (t < startTime) {
            timeOfStake[msg.sender] = startTime;
        } else {
            currOwed = (t.sub(prevStart)).mul(secondReward).mul(currBalance);
            timeOfStake[msg.sender] = t;
        }
        return currOwed;
    }

}
