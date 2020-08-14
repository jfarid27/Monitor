// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RealityMarket.sol";


/// @title Monitor
/// @notice Code to create and stake for information markets.
contract RealityMarketRegistry is Ownable {
    /// @notice Map from market address to it's owner;
    mapping(address => address) public ownerForMarket;

    /// @notice Create a market and register the given owner.
    /// @param setMarketTypeBinary True if the market is binary. Otherwise Linear.
    /// @param setQuestion Question to set for the reality market.
    /// @param setEndTime End time for the reality market.
    /// @param setRangeStart If the market is linear, store the start of the range mapped from 0 to 1.
    /// @param setRangeEnd If the market is linear, store the end of the range mapped from 0 to 1.
    /// @param ownerAddress Address of the market owner.
    /// @param stakeAddress Address of the stake token used to vote.
    /// @param currencyAddress Address of the token used to create complete sets.
    /// @return Created market address.
    function createMarket(
        bool setMarketTypeBinary,
        string memory setQuestion,
        uint setEndTime,
        string memory setRangeStart,
        string memory setRangeEnd,
        address ownerAddress,
        address stakeAddress,
        address currencyAddress
    ) public onlyOwner returns (address) {
        RealityMarket market = new RealityMarket(
            setMarketTypeBinary,
            setQuestion,
            setEndTime,
            currencyAddress,
            stakeAddress,
            setRangeStart,
            setRangeEnd
        );
        ownerForMarket[address(market)] = ownerAddress;
        return address(market);
    }

}
