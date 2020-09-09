// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ForesightTokens.sol";
import "./Vision.sol";


/// @title Monitor
/// @notice Monitor Interface
contract Monitor is ReentrancyGuard, BondingCurve {

    /// @notice Vision Vault that controls it's bonding curve.

    /// @notice Vision ERC777 token contract.
    Vision vision;
    /// @notice Total supply of Vision.
    uint mintedVision = 0;
    /// @notice Total StakeToken in Vision Pool.
    uint totalStakeInVisionVault = 0;

    /// @notice Stake token for Vision pool.
    IERC20 stakeToken;

    /// @notice Foresight token ERC1155 contract that manages all Foresight.
    ForesightTokens foresightTokens;

    // @notice Reality Market info
    struct RealityMarket {
        uint id;
        bool finalized;
        uint winningOutcome;
        uint winningToken;
        uint endTime;
        string question;
        uint tokenIndex;
        uint totalYes;
        uint totalNo;
        uint totalInvalid;
        uint totalStakedYes;
        uint totalStakedNo;
        uint totalStakedInvalid;
        uint invalidStake;
        mapping(uint => mapping(address => uint)) stakeByOutcomeForAddress;
    }

    // @notice Index of the current reality markets.
    uint realityMarketCounts  = 0;
    // @notice Reality Market Data;
    mapping(uint => RealityMarket) realityMarketRegistry;

    /// @notice Mint a new amount of Foresight Tokens for the given address.
    /// @param _stakeToken Address of the allowed stakeToken for Vision.
    constructor(address _stakeToken) public {
        stakeToken = IERC20(_stakeToken);
    }

    /// @notice Deploys Vision vault, Foresight tokens, and RealityMarket.
    function initialize() {
        vision = new Vision();
    }

    /// @notice Mints new Vision based on the current price, using the amount deposited.
    /// @param amountDeposited Amount of stake to deposit.
    /// @dev Note you must supply the amount of Stake Token to produce new Vision. Also must approve.
    function mintVision(uint amountDeposited) public nonReentrant {
        visionRate = mintedVision / totalStakeInVisionVault;
        visionToMint = visionRate * amountDeposited;
        mintedVision += visionToMint;
        totalStakeInVisionVault += amountDeposited;
        vision.mint(msg.sender, visionToMint);
        stakeToken.transfer(msg.sender, address(this), amountDeposited);
    }

    /// @notice Burns Vision based on the current price and returns allocated stake.
    /// @param visionToBurn Amount of vision to burn.
    function burnVision(uint visionToBurn) public nonReentrant {
        stakeRate = totalStakeInVisionVault / mintedVision;
        stakeToReturn = stakeRate * visionToBurn;
        mintedVision -= visionToBurn;
        totalStakeInVisionVault -= stakeToReturn;
        vision.burn(msg.sender, visionToBurn);
        stakeToken.transfer(address(this), msg.sender, stakeToReturn);
    }

    /// @notice return details of the newly created reality market.
    event RealityMarketCreated(uint index, uint yesIndex, uint noIndex, uint invalidIndex);

    /// @notice Creates a new RealityMarket instance.
    /// @param question Market question.
    /// @param endTime Time to end market.
    /// @param invalidStake Vision stake to place on market
    /// @dev Invariant - A Reality Market's endTime should not be before the current block.
    /// @dev Event - Emits RealityMarketCreated with the market's index and Foresight set.
    function createRealityMarket(
      string question,
      uint endTime,
      uint invalidStake
    ) nonReentrant {
        require(block.timestamp < market.endTime, "Market end time cannot be in the past.");
        uint index = realityMarketCounts + 1;
        realityMarketCounts += 1;
        totalTokens = foresightTokens.totalTokensMinted();
        uint yesIndex = totalTokens + 1;
        uint noIndex = totalTokens + 2;
        uint invalidIndex = totalTokens + 3;
        realityMarketRegistry[index].index = index;
        realityMarketRegistry[index].finalized = false;
        realityMarketRegistry[index].endTime = endTime;
        realityMarketRegistry[index].question = question;
        realityMarketRegistry[index].tokenIndex = foresightTokens.registerNewSet();
        vision.transferFrom(msg.sender, address(this), invalidStake);
        RealityMarketCreated(index, yesIndex, noIndex, invalidIndex);
    }

    /// @notice Buys a position in a reality market.
    function buyPosition() {

    }

    /// @notice Event to finalize a market.
    event realityMarketFinalized(uint index, uint burned, int winningOutcome);

    /// @notice Finalize a market and update the Vision vault with the correct losing stake.
    /// @param index Market index to finalize.
    /// @dev Invariant - Should not work if current block time is less than market end time.
    /// @dev Invariant - Should not reduce the price of Vision.
    /// @dev Invariant - Should not be able to finalize twice.
    /// @dev Invariant - Should only be able to finalize if the market is not finalized.
    /// @dev Event - Emits finalizedMarket event
    function finalizeMarket(uint index) public nonReentrant {
        RealityMarket storage market = realityMarketRegistry[index];
        require(block.timestamp > market.endTime, "Market has not reached End Time.");
        require(!market.finalized, "Market already finalized.");
        currentVisionPrice = totalStakeInVisionVault / mintedVision;
        uint winningOutcome = -1;
        if (market.totalYes > market.totalNo && market.totalYes > market.totalInvalid) {
            winningOutcome = 1;
            mintedVision -= (market.totalStakedInvalid + market.totalStakedNo);
            vision.burn(address(this), market.totalStakedInvalid);
            vision.burn(address(this), market.totalStakedNo);
        }
        if (market.totalNo > market.totalYes && market.totalNo > market.totalInvalid) {
            winningOutcome = 0;
            mintedVision -= (market.totalStakedInvalid + market.totalStakedYes);
            vision.burn(address(this), market.totalStakedInvalid);
            vision.burn(address(this), market.totalStakedYes);
        }
        if (winningOutcome == -1) {
            mintedVision -= (market.totalStakedYes + market.totalStakedNo + market.invalidStake);
            vision.burn(address(this), market.invalidStake);
            vision.burn(address(this), market.totalStakedYes);
            vision.burn(address(this), market.totalStakedNo);
        }
        market.finalized = true;
        market.winningOutcome = winningOutcome;
        market.winningToken = (market.tokenIndex + (winningOutcome + 1));
    }

    /// @notice Withdraw the senders user stake using the specified foresightToken id.
    /// @param index Market index.
    /// @param foresightId Id of the given foresight.
    /// @dev Invariant - Users should not be able to withdraw from a market that is not finalized.
    /// @dev Invariant - Users should not be able to withdraw using Foresight that is not reified.
    function withdrawWinningStake(uint index, uint foresightId) public nonReentrant {
        RealityMarket storage market = realityMarketRegistry[index];
        require(market.finalized, "Market not finalized.");
        require(foresightId == market.winningToken, "Selected token is not redeemable.");
        uint perc;
        uint owed;
        uint balance;
        if (market.winningOutcome == -1) {
            perc = market.stakeByOutcomeForAddress[-1][msg.sender] / market.totalInvalid;
            owed = perc * (market.totalStakedNo + market.totalStakedYes);
            balance = foresightTokens.balanceOf(msg.sender, market.tokenIndex);
            foresightTokens.burn(msg.sender, market.tokenIndex, balance);
            vision.transfer(address(this), owed);
        }
        if (market.winningOutcome == 0) {
            perc = market.stakeByOutcomeForAddress[0][msg.sender] / market.totalNo;
            owed = perc * (market.totalStakedInvalid + market.totalStakedYes);
            balance = foresightTokens.balanceOf(msg.sender, market.tokenIndex + 1);
            foresightTokens.burn(msg.sender, market.tokenIndex + 1, balance);
            vision.transfer(address(this), owed);
        }
        if (market.winningOutcome == 1) {
            perc = market.stakeByOutcomeForAddress[1][msg.sender] / market.totalYes;
            owed = perc * (market.totalStakedNo + market.totalStakedInvalid);
            balance = foresightTokens.balanceOf(msg.sender, market.tokenIndex + 2);
            foresightTokens.burn(msg.sender, market.tokenIndex + 2, balance);
            vision.transfer(address(this), owed);
        }

    }

    /// @notice Invariant - Token price delta in a market bonding curve should never be negative.

    /// @notice Invariant - Vision token withdraw should never reduce Vision price.


}
