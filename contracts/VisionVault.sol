// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./BancorBondingCurve.sol";
import "./Vision.sol";


/// @notice Controlling bonding curve for vision token.
contract VisionVault is ReentrancyGuard {
    using SafeMath for uint;
    /// @notice Vision ERC777 token contract.
    Vision public vision;
    /// @notice Address Vision ERC777 token contract.
    address public visionAddress;
    /// @notice Stake token for Vision pool.
    IERC20 public stakeToken;
    /// @notice Total supply of Vision. Note this needs to start with 1 for minting.
    uint public mintedVision = 1;
    /// @notice Total StakeToken in Vision Pool. Note this needs to start with 1 for minting.
    uint public totalStakeInVisionVault = 1;
    /// @notice Initializiation boolean.
    bool public initialized;
    /// @notice Bancor bonding curve contract.
    IBancorBondingCurve public bondingCurve;

    constructor(address _stakeTokenAddress, address _monitorAddress, address _bondingCurveAddress) public {
        stakeToken = IERC20(_stakeTokenAddress);
        vision = new Vision();
        visionAddress = address(vision);
        bondingCurve = IBancorBondingCurve(_bondingCurveAddress);
    }

    /// @notice Event capturing minted vision, cost, and address.
    event VisionMinted(uint minted, uint cost, address addr);

    /// @notice Mints new Vision based on the current price, using the amount deposited.
    /// @param amountDeposited Amount of stake to deposit.
    /// @dev Note you must supply the amount of Stake Token to produce new Vision.
    /// @dev Must approve stake token.
    function mintVision(uint amountDeposited) public nonReentrant {
        require(totalStakeInVisionVault != 0, "totalStakeInVisionVault should not be 0.");
        uint visionRate = mintedVision.div(totalStakeInVisionVault);
        uint visionToMint = visionRate.mul(amountDeposited);
        mintedVision = mintedVision.add(visionToMint);
        totalStakeInVisionVault = totalStakeInVisionVault.add(amountDeposited);
        vision.mint(msg.sender, visionToMint);
        stakeToken.transferFrom(msg.sender, address(this), amountDeposited);
        emit VisionMinted(visionToMint, amountDeposited, msg.sender);
    }

    /// @notice Event capturing burned vision, cost, and address.
    event VisionBurned(uint burned, uint cost, address addr);

    /// @notice Burns Vision based on the current price and returns 99% of allocated stake.
    /// @param visionToBurn Amount of vision to burn.
    /// @dev Invariant - totalStakeInVisionVault cannot be less than 1.
    /// @dev Invariant - mintedVision cannot be less than 1.
    /// @dev Note vision does not need to be approved to be burnt.
    function burnVision(uint visionToBurn) public nonReentrant {
        uint stakeRate = totalStakeInVisionVault.div(mintedVision);
        uint stakeToReturn = bondingCurve.mulDiv(stakeRate.mul(visionToBurn), 990000, 1000000);
        mintedVision = mintedVision.sub(visionToBurn);
        totalStakeInVisionVault = totalStakeInVisionVault.sub(stakeToReturn);
        require(totalStakeInVisionVault > 1, "Total Stake In Vision Vault must be greater than 1.");
        require(mintedVision > 1, "Minted Vision must be greater than 1.");
        vision.burn(msg.sender, visionToBurn);
        stakeToken.transfer(msg.sender, stakeToReturn);
        emit VisionBurned(visionToBurn, stakeToReturn, msg.sender);
    }

}
