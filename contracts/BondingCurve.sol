// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";


/// @title Monitor
/// @notice Math for Quadratic Bonding Curves. Used in the Foresight Token Distribution.
contract BondingCurve {
    using SafeMath for uint;
    using SignedSafeMath for int;

    /// @notice Returns the cost of a token delta using Quadratic pricing, as well as the new token price.
    /// @param currentAmount Current Amount of the tokens in circulation.
    /// @param deltaAmount Change in tokens to compute cost for.
    /// @return cost Returns the cost of the new deltaAmount.
    function computeCostForAmount(
        uint currentAmount,
        uint deltaAmount
    ) public view returns (uint cost) {
        uint currentBalance = ((currentAmount ** 3) / 3);
        cost = (((currentAmount + deltaAmount) ** 3) / 3) - currentBalance;
    }

    /// @notice Returns the square root of x using the Babylonian method.
    /// @param x Value.
    /// @return y Returns the square root.
    function sqrt(uint x) public returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
