// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RealityMarket.sol";


/// @title Monitor
/// @notice Code to create and stake for information markets.
contract RealityMarketRegistry is Ownable {

    /// @notice Map from market address to it's owner;
    mapping(address => address) public ownerForMarket;

    /// @notice Create a market registry.
    constructor() public {}

    /// @notice Create a market and register the given owner.
    /// @param setQuestion Question to set for the reality market.
    /// @param setEndTime End time for the reality market.
    /// @param ownerAddress Address of the market owner.
    /// @param stakeAddress Address of the stake token used to vote.
    /// @param currencyAddress Address of the token used to create complete sets.
    /// @return Created market address.
    function createMarket(
        string memory setQuestion,
        uint setEndTime,
        address ownerAddress,
        address stakeAddress,
        address currencyAddress
    ) public onlyOwner returns (address) {
        RealityMarket market = new RealityMarket(
            setQuestion,
            setEndTime,
            currencyAddress,
            stakeAddress
        );
        ownerForMarket[address(market)] = ownerAddress;
        return address(market);
    }

    /// @notice Gets the owner of the reality market.
    /// @param marketAddress MarketAddress to check who is the owner for.
    function getOwner(address marketAddress) public view returns (address) {
        return ownerForMarket[marketAddress];
    }

}
