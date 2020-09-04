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

    /// @notice Market creation envent
    event MarketCreatedEvent(address created);

    /// @notice instance of the Market Registry.
    RealityMarketRegistry public markets;

    /// @notice address of the Market Registry.
    address public marketRegistry;

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
        marketRegistry = address(markets);
    }

    /// @notice getter for the market registry.
    function getMarketRegistry() public view returns (address) {
        return marketRegistry;
    }

    /// @notice Create a market and stake the set amount of vision token.
    /// @dev Added non-reentrant but likely don't need it since the stake is added for a
    ///      new market each time.
    /// @param setQuestion Question to set for the reality market.
    /// @param setEndTime End time for the reality market.
    /// @param stake Amount of Vision to stake on the market.
    function createMarket(
        string memory setQuestion,
        uint setEndTime,
        uint stake
    ) public nonReentrant {
        address marketAddress = markets.createMarket(
            setQuestion,
            setEndTime,
            msg.sender,
            visionAddress,
            currencyAddress
        );
        stakeForMarket[marketAddress] = stake;
        ownerForMarket[marketAddress] = address(msg.sender);
        visionToken.transferFrom(msg.sender, address(this), stake);
        emit MarketCreatedEvent(marketAddress);
    }

    /// @notice Withdraws stake from a given market.
    /// @param marketAddress Market to withdraw stake from.
    function withdrawStake(address marketAddress) public nonReentrant {
        require(stakeForMarket[marketAddress] > 0, "No stake to withdraw");
        IRealityMarket market = IRealityMarket(marketAddress);
        require(market.winningOutcome() != -1, "Market was deemed invalid. Stake lost");
        uint owedStake = stakeForMarket[marketAddress];
        stakeForMarket[marketAddress] = 0;
        visionToken.transfer(ownerForMarket[marketAddress], owedStake);
    }
}
