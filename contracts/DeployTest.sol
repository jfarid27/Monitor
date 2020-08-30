// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "./Monitor.sol";
import "./VisionTest.sol";


/// @title DeployTest
/// @notice Deploys the Monitor and Yield Offering.
contract DeployTest {

    /// @notice Instantiates the monitor and Yield Offering.
    constructor() public {
        VisionTest testToken = new VisionTest();
        Monitor monitor = new Monitor(address(testToken), address(testToken));
    }
}
