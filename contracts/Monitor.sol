// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ForesightTokens.sol";
import "./Vision.sol";


/// @title Monitor
/// @notice Monitor Interface
contract Monitor is ReentrancyGuard, BondingCurve {
    /// @notice Only allow initialization once.
    bool public initalized;

    /// @notice Vision ERC777 token contract.
    Vision public vision;
    /// @notice Total supply of Vision.
    uint public mintedVision = 0;
    /// @notice Total StakeToken in Vision Pool.
    uint public totalStakeInVisionVault = 0;

    /// @notice Stake token for Vision pool.
    IERC20 public stakeToken;

    /// @notice Foresight token ERC1155 contract that manages all Foresight.
    ForesightTokens public foresightTokens;

    // @notice Reality Market info
    struct RealityMarket {
        uint id;
        bool finalized;
        uint winningOutcome;
        uint endTime;
        string question;
        uint tokenIndex;
        mapping(uint => uint) totalMinted;
        mapping(uint => uint) totalStaked;
        uint invalidStake;
    }

    // @notice Index of the current reality markets.
    uint public realityMarketCounts  = 0;
    // @notice Reality Market Data;
    mapping(uint => RealityMarket) public realityMarketRegistry;

    /// @notice Mint a new amount of Foresight Tokens for the given address.
    /// @param _stakeToken Address of the allowed stakeToken for Vision.
    constructor(address _stakeToken) public {
        stakeToken = IERC20(_stakeToken);
    }

    /// @notice Deploys Vision vault, Foresight tokens, and RealityMarket.
    function initialize() public {
        require(!initialized, "Contract can only be initialized once.");
        initialized = true;
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
        string memory question,
        uint endTime,
        uint invalidStake
    ) public nonReentrant {
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
    /// @dev For a given starting token index n, n = Invalid, n+1 = No, n+2 = Yes.
    /// @param index Market index to buy the position in.
    /// @param outcome Token index of the outcome to buy into.
    /// @param amount Amount of Vision to stake on the outcome.
    function buyPosition(uint index, uint outcome, uint amount) public nonReentrant {
        uint currentAmount;
        bool selected = false;
        if (outcome == realityMarketRegistry[index].tokenIndex) {
            selected = true;
        }
        if (outcome == realityMarketRegistry[index].tokenIndex + 1) {
            selected = true;
        }
        if (outcome == realityMarketRegistry[index].tokenIndex + 2) {
            selected = true;
        }
        require(selected, "Market outcome selection does not match market index outcomes.");
        currentAmount = realityMarketRegistry[index].totalMinted[outcome];
        visionCost = computeCostForAmount(currentAmount, amount);
        realityMarketRegistry[index].totalStaked[outcome] += visionCost;
        realityMarketRegistry[index].totalMinted[outcome] += amount;
        foresightTokens.mint(msg.sender, outcome, amount);
    }

    /// @notice Event to finalize a market.
    event RealityMarketFinalized(uint index, uint burned, uint winningOutcome);

    /// @notice Finalize a market and update the Vision vault with the correct losing stake.
    /// @param index Market index to finalize.
    /// @dev For a given starting token index n, n = Invalid, n+1 = No, n+2 = Yes.
    /// @dev Invariant - Should not work if current block time is less than market end time.
    /// @dev Invariant - Should not reduce the price of Vision.
    /// @dev Invariant - Should not be able to finalize twice.
    /// @dev Invariant - Should only be able to finalize if the market is not finalized.
    /// @dev Event - Emits finalizedMarket event
    function finalizeMarket(uint index) public nonReentrant {
        RealityMarket storage market = realityMarketRegistry[index];
        require(block.timestamp > market.endTime, "Market has not reached End Time.");
        require(!market.finalized, "Market already finalized.");
        uint yes = realityMarketRegistry[index].tokenIndex + 2;
        uint no = realityMarketRegistry[index].tokenIndex + 1;
        uint invalid = realityMarketRegistry[index].tokenIndex;
        uint winningOutcome = realityMarketRegistry[index].tokenIndex;
        if (market.totalYes > market.totalNo && market.totalYes > market.totalInvalid) {
            winningOutcome = yes;
        }
        if (market.totalNo > market.totalYes && market.totalNo > market.totalInvalid) {
            winningOutcome = no;
        }
        if (winningOutcome == realityMarketRegistry[index].tokenIndex) {
            winningOutcome = invalid;
        }
        market.finalized = true;
        market.winningOutcome = winningOutcome;
        RealityMarketFinalized(index, burned, winningOutcome);
    }

    /// @notice Withdraw the senders user stake using the specified foresightToken id.
    /// @param index Market index.
    /// @param foresightId Id of the given foresight.
    /// @dev Invariant - Users should not be able to withdraw from a market that is not finalized.
    /// @dev Invariant - Users should not be able to withdraw using Foresight that is not reified.
    function withdrawWinningStake(uint index, uint foresightId) public nonReentrant {
        RealityMarket storage market = realityMarketRegistry[index];
        require(market.finalized, "Market not finalized.");
        require(foresightId == market.winningOutcome, "Selected token is not redeemable.");
        /// @notice Total vision lost.
        uint totalLost;
        /// @notice User's total owned foresight.
        uint tokensOwned = foresightTokens.balanceOf(msg.sender, foresightId);
        uint yes = realityMarketRegistry[index].tokenIndex + 2;
        uint no = realityMarketRegistry[index].tokenIndex + 1;
        uint invalid = realityMarketRegistry[index].tokenIndex;
        // Invalid
        if (market.winningOutcome == invalid) {
            totalLost = market.totalStaked[no] + market.totalStaked[yes];
        }
        // No
        if (market.winningOutcome == no) {
            totalLost = market.totalStaked[invalid] + market.totalStaked[yes];
        }
        // Yes
        if (market.winningOutcome == yes) {
            totalLost = market.totalStaked[no] + market.totalStaked[invalid];
        }
        /// @notice User's computed percent of the prize pool.
        uint percentWon = tokensOwned / market.totalStaked[market.winningOutcome];
        uint currentAmount = realityMarketRegistry[index].totalMinted[market.winningOutcome];
        /// @notice User wins back stake + computed percent of the prize pool.
        uint owedVision = computeCostForAmount(currentAmount, tokensOwned) + (percentWon * totalLost);
        foresightTokens.burn(msg.sender, foresightId, tokensOwned);
        vision.transfer(address(this), owedVision);
    }
}
