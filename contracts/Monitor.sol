// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MarketVoting.sol";
import "./RealityMarketRegistry.sol";
import "./IRealityMarket.sol";


/// @title Monitor
/// @notice Code to create and stake for information markets.
contract Monitor is ReentrancyGuard {
    /// @notice Amount of Vision staked on the market.
    mapping(address => uint) public stakeForMarket;
    /// @notice Owner for the given market.
    mapping(address => address) public ownerForMarket;
    /// @notice Token used to generate Foresight in given markets.
    address public currencyAddress;
    /// @notice Address for the Vision token.
    address public visionAddress;
    /// @notice Vision token instance.
    IERC20 public visionToken;

    RealityMarketRegistry public markets;

    /// @notice Initializes the Monitor.
    /// @param setVisionAddress Address for the vision token.
    /// @param setCurrencyAddress Address for the currency used to create Foresight.
    constructor(
        address setVisionAddress,
        address setCurrencyAddress
    ) public {
        visionAddress = setVisionAddress;
        visionToken = IERC20(visionAddress);
        currencyAddress = setCurrencyAddress;
        markets = new RealityMarketRegistry();
    }

    /// @notice Create a market and stake the set amount of vision token.
    /// @dev Added non-reentrant but likely don't need it since the stake is added for a
    ///      new market each time.
    /// @param setMarketTypeBinary True if the market is binary. Otherwise Linear.
    /// @param setQuestion Question to set for the reality market.
    /// @param setEndTime End time for the reality market.
    /// @param setRangeStart If the market is linear, store the start of the range mapped from 0 to 1.
    /// @param setRangeEnd If the market is linear, store the end of the range mapped from 0 to 1.
    /// @param stake Amount of Vision to stake on the market.
    /// @return Created market address.
    function createMarket(
        bool setMarketTypeBinary,
        string memory setQuestion,
        uint setEndTime,
        string memory setRangeStart,
        string memory setRangeEnd,
        uint stake
    ) public nonReentrant returns (address) {
        address marketAddress = markets.createMarket(
            setMarketTypeBinary,
            setQuestion,
            setEndTime,
            setRangeStart,
            setRangeEnd,
            address(msg.sender),
            visionAddress,
            currencyAddress
        );
        stakeForMarket[marketAddress] = stake;
        ownerForMarket[marketAddress] = address(msg.sender);
        visionToken.transferFrom(msg.sender, address(this), stake);
        return marketAddress;
    }

    /// @notice Withdraws stake from a given market.
    /// @param marketAddress Market to withdraw stake from.
    function withdrawStake(address marketAddress) public nonReentrant {
        require(stakeForMarket[marketAddress] > 0, "No stake to withdraw");
        IRealityMarket market = IRealityMarket(marketAddress);
        require(market.winningOutcome() != -1e18, "Market was deemed invalid. Stake lost");
        uint owedStake = stakeForMarket[marketAddress];
        stakeForMarket[marketAddress] = 0;
        visionToken.transfer(ownerForMarket[marketAddress], owedStake);
    }
}
