// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.6.12;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Power.sol"; // Efficient power function.


/**
* @title Bancor formula by Bancor
*
* Licensed to the Apache Software Foundation (ASF) under one or more contributor license agreements;
* and to You under the Apache License, Version 2.0. "
*/
contract BancorBondingCurve is Power {
    using SafeMath for uint256;
    uint32 private constant MAX_RESERVE_RATIO = 1000000;

    /**
     * @dev given a continuous token supply, reserve token balance, reserve ratio, and a deposit amount (in the reserve token),
     * calculates the return for a given conversion (in the continuous token)
     *
     * Formula:
     * Return = _supply * ((1 + _depositAmount / _reserveBalance) ^ (_reserveRatio / MAX_RESERVE_RATIO) - 1)
     *
     * @param _supply              continuous token total supply
     * @param _reserveBalance    total reserve token balance
     * @param _reserveRatio     reserve ratio, represented in ppm, 1-1000000
     * @param _depositAmount       deposit amount, in reserve token
     *
     *  @return purchase return amount
    */
    function calculatePurchaseReturn(
        uint256 _supply,
        uint256 _reserveBalance,
        uint32 _reserveRatio,
        uint256 _depositAmount) public view returns (uint256)
    {

        require(_supply > 0, "Supply is less than zero.");
        require(_reserveBalance > 0, "Reserve balance is less than zero.");
        require(_reserveRatio > 0, "Reserve ratio is less than zero.");
        require(_reserveRatio <= MAX_RESERVE_RATIO, "Reserve ratio greater than max.");
        if (_depositAmount == 0) {
            return 0;
        }
         // special case if the ratio = 100%
        if (_reserveRatio == MAX_RESERVE_RATIO) {
            return _supply.mul(_depositAmount).div(_reserveBalance);
        }
        uint256 result;
        uint8 precision;
        uint256 baseN = _depositAmount.add(_reserveBalance);
        (result, precision) = power(
            baseN, _reserveBalance, _reserveRatio, MAX_RESERVE_RATIO
        );
        uint256 newTokenSupply = _supply.mul(result) >> precision;
        return newTokenSupply - _supply;
    }
    /**
     * @dev given a continuous token supply, reserve token balance, reserve ratio and a sell amount (in the continuous token),
     * calculates the return for a given conversion (in the reserve token)
     *
     * Formula:
     * Return = _reserveBalance * (1 - (1 - _sellAmount / _supply) ^ (1 / (_reserveRatio / MAX_RESERVE_RATIO)))
     *
     * @param _supply              continuous token total supply
     * @param _reserveBalance    total reserve token balance
     * @param _reserveRatio     constant reserve ratio, represented in ppm, 1-1000000
     * @param _sellAmount          sell amount, in the continuous token itself
     *
     * @return sale return amount
    */
    function calculateSaleReturn(
        uint256 _supply,
        uint256 _reserveBalance,
        uint32 _reserveRatio,
        uint256 _sellAmount) public view returns (uint256)
    {
        // validate input
        require(_supply > 0 && _reserveBalance > 0 && _reserveRatio > 0 && _reserveRatio <= MAX_RESERVE_RATIO && _sellAmount <= _supply);
         // special case for 0 sell amount
        if (_sellAmount == 0) {
            return 0;
        }
         // special case for selling the entire supply
        if (_sellAmount == _supply) {
            return _reserveBalance;
        }
         // special case if the ratio = 100%
        if (_reserveRatio == MAX_RESERVE_RATIO) {
            return _reserveBalance.mul(_sellAmount).div(_supply);
        }
        uint256 result;
        uint8 precision;
        uint256 baseD = _supply - _sellAmount;
        (result, precision) = power(
            _supply, baseD, MAX_RESERVE_RATIO, _reserveRatio
        );
        uint256 oldBalance = _reserveBalance.mul(result);
        uint256 newBalance = _reserveBalance << precision;
        return oldBalance.sub(newBalance).div(result);
    }

    /// @notice Implementation of Safe x * (y / z).
    /// @dev See https://medium.com/coinmonks/math-in-solidity-part-3-percents-and-proportions-4db014e080b1
    /// @param x First number to multiply.
    /// @param y First part of percent.
    /// @param z Second part of percent.
    /// @return Returns computation of x * (y / z)
    function mulDiv (uint x, uint y, uint z)
        public view returns (uint)
    {
        (uint j, uint h) = fullMul(x, y);
        return fullDiv(j, h, z);
    }

    /// @notice Multiplication. Necessary for mulDiv algorithm.
    /// @param x First number to multiply.
    /// @param y Second number to multiply.
    /// @return j Two part unsigned integers to return.
    /// @return h Two part unsigned integers to return.
    function fullMul (uint x, uint y)
        public view returns (uint j, uint h)
    {
        uint xl = uint128(x);
        uint xh = x >> 128;
        uint yl = uint128(y);
        uint yh = y >> 128;
        uint xlyl = xl * yl;
        uint xlyh = xl * yh;
        uint xhyl = xh * yl;
        uint xhyh = xh * yh;

        uint ll = uint128(xlyl);
        uint lh = (xlyl >> 128) + uint128(xlyh) + uint128(xhyl);
        uint hl = uint128(xhyh) + (xlyh >> 128) + (xhyl >> 128);
        uint hh = (xhyh >> 128);
        j = ll + (lh << 128);
        h = (lh >> 128) + hl + (hh << 128);
    }

    /// @notice Division of two part number j h by z. Necessary for mulDiv algorithm.
    /// @param j Part 1.
    /// @param h Part 2.
    /// @param z Second number to divide by.
    /// @return r Unsigned integer to return.
    function fullDiv (uint j, uint h, uint z)
        public view returns (uint r)
    {
        require(h < z);
        uint zShift = mostSignificantBit(z);
        uint shiftedZ = z;
        if (zShift <= 127) zShift = 0;
        else {
            zShift -= 127;
            shiftedZ = (shiftedZ - 1 >> zShift) + 1;
        }
        while (h > 0) {
            uint lShift = mostSignificantBit(h) + 1;
            uint hShift = 256 - lShift;
            uint e = ((h << hShift) + (j >> lShift)) / shiftedZ;
            if (lShift > zShift) {
                e <<= (lShift - zShift);
            } else {
                e >>= (zShift - lShift);
            }
            r += e;
            (uint tl, uint th) = fullMul(e, z);
            h -= th;
            if (tl > j) h -= 1;
            j -= tl;
        }
        r += j / z;
    }

    /// @notice Generates the most significant bit in given number x.
    /// @param x Number to retrieve bit from.
    /// @return r Most significant bit.
    function mostSignificantBit(uint x) public view returns (uint r) {
        require(x > 0);
        if (x >= 2**128) { x >>= 128; r += 128; }
        if (x >= 2**64) { x >>= 64; r += 64; }
        if (x >= 2**32) { x >>= 32; r += 32; }
        if (x >= 2**16) { x >>= 16; r += 16; }
        if (x >= 2**8) { x >>= 8; r += 8; }
        if (x >= 2**4) { x >>= 4; r += 4; }
        if (x >= 2**2) { x >>= 2; r += 2; }
        if (x >= 2**1) { x >>= 1; r += 1; }
    }
}
