// SPDX-License-Identifier: Unlicense

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";


/// @title MarketVoting
/// @notice Defines a market where users may vote on int values. Voting requires
///         sending an equivalent amount of real StakeTokens. Losers are penalized by burning
///         their stake. User addresses may only vote for a single outcome.
/// @dev Market voting for the Monitor platform has two possible outcomes. Users may only vote for Outcomes
///      0, -1 or 1.
contract MarketVoting {
    using SafeMath for uint;
    using SignedSafeMath for int;

    /// @notice Address of the stakeToken backing votes.
    address public stakeAddress;
    /// @notice StakeToken interface to call transactions on.
    IERC20 public stakeToken;

    /// @notice Time to total the votes and allow withdraws/burns.
    uint public votingEndTime;

    /// @notice Outcomes that were voted on
    int[] public votedOutcomes;
    /// @notice Total votes for Outcomes
    mapping(int => uint) public totalvotesForOutcome;
    /// @notice What outcome users voted on
    mapping(address => int) public usersVotedOutcome;
    /// @notice How much users voted on their Outcome
    mapping(address => uint) public usersAmountOutcome;

    /// @notice Boolean for whether the realizedOutcome was set.
    bool public marketFinalized;
    /// @notice The reified outcome that won the market voting.
    int public realizedOutcome;

    /// @notice Sets market data for given vote.
    /// @param setVotingEndTime Set the time when voting may stop.
    /// @param setStakeAddress Set the address of the ERC20 token used for staking votes.
    constructor(
        uint setVotingEndTime,
        address setStakeAddress
    ) public {
        stakeAddress = setStakeAddress;
        stakeToken = IERC20(stakeAddress);
        votingEndTime = setVotingEndTime;
    }

    /// @notice Collects a users stakeToken and records a vote.
    /// @dev Approve token amount before calling.
    /// @param outcome Specific outcome to vote on
    /// @param amount Amount of tokens to stake on the vote. (Requires approval)
    function vote(int outcome, uint amount) public {
        require(block.timestamp < votingEndTime, "voting has ended");
        require(amount > 0, "Cannot vote with 0 stake.");
        voteBinary(outcome, amount);
    }

    /// @notice Returns the market's winning outcome.
    function winningOutcome() public assertVotingCompleted returns (int) {
        if (marketFinalized) {
            return realizedOutcome;
        }
        int winning;
        if (votedOutcomes.length == 0) {
            return -1e18;
        }
        winning = votedOutcomes[0];
        for (uint i = 1; i < votedOutcomes.length; i++) {
            int curr = votedOutcomes[i];
            uint votesCurr = totalvotesForOutcome[curr];
            if (totalvotesForOutcome[winning] < votesCurr) {
                winning = curr;
            }
        }
        realizedOutcome = winning;
        marketFinalized = true;
        return winning;
    }

    /// @notice Safe withdraw stakeToken only if user voted on winning outcome and voting is over.
    function withdraw() public assertVotingCompleted {
        require(usersVotedOutcome[msg.sender] == winningOutcome(), "User did not vote on winning outcome");
        uint amount = usersAmountOutcome[msg.sender];
        usersAmountOutcome[msg.sender] = 0;
        stakeToken.transfer(msg.sender, amount);
    }

    /// @notice Asserts voting is completed.
    /// @dev Votes are completed when the timestamp is after the votingEndTime.
    modifier assertVotingCompleted {
        require(block.timestamp > votingEndTime, "Vote is not yet completed");
        _;
    }

    /// @notice Asserts given outcome is a valid binary vote.
    /// @dev Votes are binary if they are either 1e18 or 0 inclusive or -1e18.
    /// @param outcome Specific outcome to check
    modifier assertBinaryVote(int outcome) {
        bool voteOk =
            outcome == 1e18 ||
            outcome == 0 ||
            outcome == -1e18;
        require(voteOk, "Vote is not in correct Binary Vote Format.");
        _;
    }

    /// @notice Collects a users stakeToken and records a Binary Market vote.
    /// @dev Approve token amount before calling.
    /// @param outcome Specific outcome to vote on
    /// @param amount Amount of tokens to stake on the vote.
    function voteBinary(int outcome, uint amount) private assertBinaryVote(outcome) {
        adjustVoteAccounting(outcome, amount);
        stakeToken.transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Adjusts the market accounting of vote data for the given user and amount.
    /// @param outcome Specific outcome to vote on
    /// @param amount Amount of tokens to stake on the vote.
    function adjustVoteAccounting(int outcome, uint amount) private {
        if (totalvotesForOutcome[outcome] == 0) {
            votedOutcomes.push(outcome);
        }
        totalvotesForOutcome[outcome] += amount;
        usersVotedOutcome[msg.sender] += outcome;
        usersAmountOutcome[msg.sender] += amount;
    }
}
