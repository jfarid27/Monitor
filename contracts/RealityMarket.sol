// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";
import "./ForesightVault.sol";
import "./MarketVoting.sol";

/// @title RealityMarket
/// @notice Generate a reality market and appropriate mint/burn tokens.
contract RealityMarket is ReentrancyGuard {
    using SafeMath for uint;
    using SignedSafeMath for int;
    /// @notice Base currency token address used to mint Foresight.
    address public currencyAddress;
    /// @notice Base currency token used to mint Foresight.
    IERC20 public currencyToken;
    /// @notice Address for the Vision token.
    address public visionAddress;
    /// @notice Vision token Instance.
    IERC20 public visionToken;
    /// @notice Market Question.
    string public question;
    /// @dev Constant representing the YESSHORT option.
    string private constant YESSHORT = "YES";
    /// @dev Constant representing the NOLONG option.
    string private constant NOLONG = "NO";
    /// @dev Constant representing the INVALID option.
    string private constant INVALID = "INVALID";

    /// @notice Least range endpoint. Necessary for reification of markets and UIs.
    string public rangeStart;
    /// @notice Maximum range endpoint. Necessary for reification of markets and UIs.
    string public rangeEnd;
    /// @notice Winning outcome after voting.
    /// @notice Close of public voting on market outcomes.
    uint public votingEndTime;

    /// @notice Instance of the voting contract.
    MarketVoting public voting;
    /// @notice Address for the Voting contract.
    address public votingAddress;
    /// @notice Instance of the Foresight Vault contract.
    ForesightVault public foresightVault;

    /// @notice Sets all base values for the market and sets up Voting and Token Vault.
    /// @param setQuestion Determines market question.
    /// @param setVotingEndTime Sets the end of public voting on market outcomes.
    /// @param setCurrencyAddress Location of the currency used to mint Foresight.
    /// @param setVisionAddress Location of the Voting currency used to determine market reification.
    /// @param setRangeStart Least range endpoint. Necessary for reification of markets and UIs.
    /// @param setRangeEnd Maximum range endpoint. Necessary for reification of markets and UIs.
    constructor(
        string memory setQuestion,
        uint setVotingEndTime,
        address setCurrencyAddress,
        address setVisionAddress,
        string memory setRangeStart,
        string memory setRangeEnd
    ) public {
        require(block.timestamp < setVotingEndTime, "end time must be after start");
        votingEndTime = setVotingEndTime;
        question = setQuestion;
        currencyToken = IERC20(setCurrencyAddress);
        currencyAddress = setCurrencyAddress;
        visionToken = IERC20(setVisionAddress);
        visionAddress = setVisionAddress;
        rangeStart = setRangeStart;
        rangeEnd = setRangeEnd;
        foresightVault = new ForesightVault(address(this));
        voting = new MarketVoting(setVotingEndTime, visionAddress);
        votingAddress = address(voting);
    }

    /// @notice Create a complete set of tokens using the currencyToken 1 to 1 and store it.
    /// @dev Requires currency token approval.
    /// @param amount Amount of currency to take and number of shares to mint.
    function mintCompleteSets(uint amount) public {
        currencyToken.transferFrom(msg.sender, address(this), amount);
        foresightVault.mintCompleteSets(msg.sender, amount);
    }

    /// @notice Burns a complete set of Foresight tokens for the given amount and returns currency.
    /// @param amount Amount of Foresight of each token to burn.
    function burnCompleteSets(uint amount) public nonReentrant {
        foresightVault.burnYesShort(msg.sender, amount);
        foresightVault.burnNoLong(msg.sender, amount);
        foresightVault.burnInvalid(msg.sender, amount);
        currencyToken.transferFrom(address(this), msg.sender, amount);
    }

    /// @notice Passes vote to the voting construct.
    /// @param outcome Outcome to vote on.
    /// @param amount Amount of Vision token to stake on a vote.
    function vote(int outcome, uint amount) public {
        voting.vote(outcome, amount);
    }

    /// @notice returns voting winning outcome.
    function winningOutcome() public returns (int) {
        return voting.winningOutcome();
    }

    /// @notice Asserts voting is completed.
    /// @dev Votes are completed when the timestamp is after the votingEndTime.
    modifier assertVotingCompleted {
        require(block.timestamp > votingEndTime, "Vote is not yet completed");
        _;
    }

    /// @notice Withdraws winning token currency based on voting outcomes for binary market.
    /// @param amount Amount of currency to swap.
    function withdrawPayoutBinary(uint amount) public assertVotingCompleted nonReentrant {
        // Case if voting was deemed invalid.
        if (voting.winningOutcome() == -1e18) {
            foresightVault.burnInvalid(msg.sender, amount);
            currencyToken.transfer(msg.sender, 1e18);
        }
        //Case if
        if (voting.winningOutcome() == 1e18) {
            foresightVault.burnYesShort(msg.sender, amount);
            currencyToken.transfer(msg.sender, 1e18);
        }
        if (voting.winningOutcome() == 0) {
            foresightVault.burnNoLong(msg.sender, amount);
            currencyToken.transfer(msg.sender, 0);
        }
    }

}
