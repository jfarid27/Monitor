// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ForesightTokens.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BancorBondingCurve.sol";


/// @title Monitor
/// @notice Monitor Interface
contract Monitor is ReentrancyGuard, Ownable {
    using SafeMath for uint;

    /// @notice Foresight token reserve ratio.
    uint32 constant public RESERVE_RATIO = 900000;

    /// @notice Constant week for finalization.
    uint constant public A_WEEK = 604800;

    /// @notice Initalizer
    address public initializer;

    /// @notice Only allow initialization once.
    bool public initialized = false;

    /// @notice Vision ERC777 token contract.
    IERC20 public vision;

    /// @notice Foresight token ERC1155 contract that manages all Foresight.
    ForesightTokens public foresightTokens;

    /// @notice Bancor bonding curve contract.
    IBancorBondingCurve public bondingCurve;
    address public bondingCurveAddress;

    /// @notice Reality Market info
    struct RealityMarket {
        uint id;
        bool finalized;
        uint winningOutcome;
        uint leadTime;
        uint endTime;
        string question;
        uint tokenIndex;
        mapping(uint => uint) totalMinted; // Maps outcomes to total amount minted.
        mapping(uint => uint) totalStaked; // Maps outcomes to total amount staked.
        mapping(uint => mapping(address => uint)) totalStakedByAddress; // Outcomes to total amount staked by address.
        uint invalidStake;
    }

    // @notice Index of the current reality markets.
    uint public realityMarketCounts  = 0;
    // @notice Reality Market Data;
    mapping(uint => RealityMarket) public realityMarketRegistry;

    /// @notice Deploys Vision vault, Foresight tokens, and RealityMarket.
    /// @param _bondingCurveAddress Address of the bonding curve functions.
    function initialize(address _visionAddress, address _bondingCurveAddress) public onlyOwner {
        require(!initialized, "Contract can only be initialized once.");
        initialized = true;
        foresightTokens = new ForesightTokens();
        bondingCurve = IBancorBondingCurve(_bondingCurveAddress);
        vision = IERC20(_visionAddress);
    }

    modifier isInitialized { require(initialized, "Monitor is not initialized"); _; }

    /// @notice return details of the newly created reality market.
    event RealityMarketCreated(uint index, uint yesIndex, uint noIndex, uint invalidIndex, uint stake);

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
    ) public nonReentrant isInitialized {
        require(block.timestamp < endTime, "Market end time cannot be in the past.");
        uint index = realityMarketCounts.add(1);
        realityMarketCounts = index;
        uint totalTokens = foresightTokens.totalTokensMinted();
        realityMarketRegistry[index].id = index;
        realityMarketRegistry[index].finalized = false;
        realityMarketRegistry[index].endTime = endTime;
        realityMarketRegistry[index].question = question;
        realityMarketRegistry[index].tokenIndex = foresightTokens.registerNewSet();
        uint invalid = realityMarketRegistry[index].tokenIndex;
        realityMarketRegistry[index].winningOutcome = invalid;
        uint no = realityMarketRegistry[index].tokenIndex.add(1);
        uint yes = realityMarketRegistry[index].tokenIndex.add(2);
        vision.transferFrom(msg.sender, address(this), invalidStake);
        RealityMarketCreated(index, yes, no, invalid, invalidStake);
    }

    /// @notice Event capturing minted foresight, stake, and address.
    event ForesightMinted(uint marketIndex, uint outcome, uint foresight, uint stake, address addr);

    /// @notice Returns the amount of foresight for a given amount of staked Vision.
    function getPurchaseReturn(uint index, uint outcome, uint amount) public view returns (uint foresightAmount) {
        uint minted = realityMarketRegistry[index].totalMinted[outcome].add(1);
        uint staked = realityMarketRegistry[index].totalStaked[outcome].add(1);
        foresightAmount = bondingCurve.calculatePurchaseReturn(minted, staked, RESERVE_RATIO, amount);
    }

    /// @notice Buys a position in a reality market.
    /// @dev For a given starting token index n, n = Invalid, n+1 = No, n+2 = Yes.
    /// @param index Market index to buy the position in.
    /// @param outcome Token index of the outcome to buy into.
    /// @param amount Amount of Vision to stake on the outcome.
    /// @dev Invariant - User may not purchase positions once the market has been finalized.
    /// @dev Invariant - Market outcome may not be
    function buyPosition(uint index, uint outcome, uint amount) public nonReentrant isInitialized {
        require(!realityMarketRegistry[index].finalized, "Market already finalized.");
        require(amount > 0, "Amount to mint should be greater than 0.");
        uint invalid = realityMarketRegistry[index].tokenIndex;
        uint no = realityMarketRegistry[index].tokenIndex.add(1);
        uint yes = realityMarketRegistry[index].tokenIndex.add(2);
        require(
            (outcome == no || outcome == yes || outcome == invalid),
            "Market outcome selection does not match market index outcomes."
        );
        uint foresightAmount = getPurchaseReturn(index, outcome, amount);
        require(foresightAmount > 0, "Returned foresight should be greater than 0.");
        realityMarketRegistry[index].totalStaked[outcome] = realityMarketRegistry[index].totalStaked[outcome].add(amount);
        realityMarketRegistry[index].totalStakedByAddress[outcome][msg.sender] = realityMarketRegistry[index].totalStakedByAddress[outcome][msg.sender].add(amount);
        realityMarketRegistry[index].totalMinted[outcome] = realityMarketRegistry[index].totalMinted[outcome].add(foresightAmount);
        uint winningOutcome = realityMarketRegistry[index].winningOutcome;
        if (realityMarketRegistry[index].totalStaked[outcome] > realityMarketRegistry[index].totalStaked[winningOutcome]) {
            realityMarketRegistry[index].winningOutcome = outcome;
            realityMarketRegistry[index].leadTime = block.timestamp;
        }
        foresightTokens.mint(msg.sender, outcome, foresightAmount);
        vision.transferFrom(msg.sender, address(this), amount);
        emit ForesightMinted(index, outcome, foresightAmount, amount, msg.sender);
    }

    /// @notice Event to finalize a market.
    event RealityMarketFinalized(uint index, uint winningOutcome);

    /// @notice Finalize a market and update the Vision vault with the correct losing stake.
    /// @param index Market index to finalize.
    /// @dev For a given starting token index n, n = Invalid, n+1 = No, n+2 = Yes.
    /// @dev Invariant - Should not work if current block time is less than market end time.
    /// @dev Invariant - Should not reduce the price of Vision.
    /// @dev Invariant - Should not be able to finalize twice.
    /// @dev Invariant - Should only be able to finalize if the market is not finalized.
    /// @dev Event - Emits finalizedMarket event
    function finalizeMarket(uint index) public nonReentrant isInitialized {
        RealityMarket storage market = realityMarketRegistry[index];
        require(block.timestamp > market.endTime.add(A_WEEK), "Market has not reached End Time.");
        require(block.timestamp > market.leadTime.add(A_WEEK), "Leading outcome has not lead for more than 1 week.");
        require(!market.finalized, "Market already finalized.");
        uint invalid = realityMarketRegistry[index].tokenIndex;
        uint no = realityMarketRegistry[index].tokenIndex.add(1);
        uint yes = realityMarketRegistry[index].tokenIndex.add(2);
        market.finalized = true;
        RealityMarketFinalized(index, market.winningOutcome);
    }

    /// @notice Event to convert foresight into vision.
    event ForesightBurned(uint marketIndex, uint foresightId, uint foresightAmount, uint visionOwed, address addr);

    /// @notice Withdraw the senders user stake using the specified foresightToken id.
    /// @param index Market index.
    /// @param foresightId Id of the given foresight.
    /// @dev Invariant - Users should not be able to withdraw from a market that is not finalized.
    /// @dev Invariant - Users should not be able to withdraw using Foresight that is not reified.
    /// @dev Invariant - User should have stake in the winning outcome to withdraw.
    function withdrawWinningStake(uint index, uint foresightId) public nonReentrant isInitialized {
        RealityMarket storage market = realityMarketRegistry[index];
        require(market.finalized, "Market not finalized.");
        require(foresightId == market.winningOutcome, "Selected token is not redeemable.");
        uint userStake = realityMarketRegistry[index].totalStakedByAddress[market.winningOutcome][msg.sender];
        require(userStake > 0, "User has no stake in the winning outcome.");
        /// @notice Total vision lost.
        uint totalLost;
        /// @notice User's total owned foresight.
        uint tokensOwned = foresightTokens.balanceOf(msg.sender, foresightId);
        require(market.totalStakedByAddress[market.winningOutcome][msg.sender] > 0, "Hit");
        require(tokensOwned > 0, "Hit 2");
        uint invalid = market.tokenIndex;
        uint no = market.tokenIndex.add(1);
        uint yes = market.tokenIndex.add(2);
        // Invalid
        if (market.winningOutcome == invalid) {
            totalLost = market.totalStaked[no].add(market.totalStaked[yes]);
        }
        // No
        if (market.winningOutcome == no) {
            totalLost = market.totalStaked[invalid].add(market.totalStaked[yes]);
        }
        // Yes
        if (market.winningOutcome == yes) {
            totalLost = market.totalStaked[no].add(market.totalStaked[invalid]);
        }
        /// @notice User's computed earnings based on percent of total winning tokens.
        uint earnings = bondingCurve.mulDiv(totalLost, tokensOwned, market.totalMinted[market.winningOutcome]);
        require(earnings > 0, "Earnings is zero.");
        /// @notice User wins back stake + computed percent of the prize pool.
        uint owedVision = userStake + earnings;
        market.totalStakedByAddress[market.winningOutcome][msg.sender] = 0;
        foresightTokens.burn(msg.sender, foresightId, tokensOwned);
        vision.transfer(address(this), owedVision);
        emit ForesightBurned(index, foresightId, tokensOwned, owedVision, msg.sender);
    }
}
