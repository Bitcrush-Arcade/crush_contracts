// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library LotteryStructs {
    struct ClaimRounds {
        uint256 roundId;
        uint256 nonWinners;
        uint256 winners;
    }
    struct NewTicket {
        uint32 ticketNumber;
        uint256 round;
    }
    struct TicketView {
        uint256 id;
        uint256 round;
        uint256 ticketNumber;
    }
}

interface IBitcrushLottery {
    // External functions
    /// @notice Buy Tickets to participate in current round from a partner
    /// @param _ticketNumbers takes in an array of uint values as the ticket number to buy
    /// @param _partnerId the id of the partner to send the funds to if 0, no partner is checked.
    function buyTickets(uint32[] calldata _ticketNumbers, uint256 _partnerId)
        external;

    /// @notice add/remove/edit partners
    /// @param _partnerAddress the address where funds will go to.
    /// @param _split the negotiated split percentage. Value goes from 0 to 90.
    /// @dev their ID doesn't change, nor is it removed once partnership ends.
    function editPartner(address _partnerAddress, uint8 _split) external;

    /// @notice retrieve a provider wallet ID
    /// @param _checkAddress the address to check
    /// @return _id the ID of the provider
    function getProviderId(address _checkAddress)
        external
        view
        returns (uint256 _id);

    /// @notice Give Redeemable Tickets to a particular user
    /// @param _rewardee Address the tickets will be awarded to
    /// @param ticketAmount number of tickets awarded
    function rewardTicket(address _rewardee, uint256 ticketAmount) external;

    /// @notice Exchange awarded tickets for the current round
    /// @param _ticketNumbers array of numbers to add to the caller as tickets
    function exchangeForTicket(uint32[] calldata _ticketNumbers) external;

    /// @notice Start of new Round. This function is only needed for the first round, next rounds will be automatically started once the winner number is received
    function firstStart() external;

    /// @notice Ends current round
    /// @dev WIP - the end of the round will always happen at set intervals
    function endRound() external;

    /// @notice Add or remove operator
    /// @param _operator address to add / remove operator
    function toggleOperator(address _operator) external;

    // SETTERS
    /// @notice Change the claimer's fee
    /// @param _fee the value of the new fee
    /// @dev Fee cannot be greater than noMatch percentage ( since noMatch percentage is the amount given out to nonWinners )
    function setClaimerFee(uint256 _fee) external;

    /// @notice Set the token that will be used as a Bonus for a particular round
    /// @param _partnerToken Token address
    /// @param _round round where this token applies
    function setBonusCoin(
        address _partnerToken,
        uint256 _amount,
        uint256 _round,
        uint256 _roundAmount
    ) external;

    /// @notice Set the ticket value
    /// @param _newValue the new value of the ticket
    /// @dev Ticket value MUST BE IN WEI format, minimum is left as greater than 1 due to the deflationary nature of CRUSH
    function setTicketValue(uint256 _newValue) external;

    /// @notice Edit the times array
    /// @param _newTimes Array of hours when Lottery will end
    /// @dev adding a sorting algorithm would be nice but honestly we have too much going on to add that in. So help us out and add your times sorted
    function setEndHours(uint8[] calldata _newTimes) external;

    /// @notice Setup the burn threshold
    /// @param _threshold new threshold in percent amount
    /// @dev setting the minimum threshold as 0 will always burn, setting max as 50
    function setBurnThreshold(uint256 _threshold) external;

    /// @notice toggle pause state of lottery
    /// @dev if the round is over and the lottery is unpaused then the round is started
    function togglePauseStatus() external;

    /// @notice Destroy contract and retrieve funds
    /// @dev This function is meant to retrieve funds in case of non usage and/or upgrading in the future.
    function crushTheContract() external;

    /// @notice Set the distribution percentage amounts... all amounts must be given for this to work
    /// @param _newDistribution array of distribution amounts
    /// @dev we expect all values to sum 100 and that all items are given. The new distribution only applies to next rounds
    /// @dev all values are in the one onehundreth percentile amount.
    /// @dev expected order [ jackpot, match5, match4, match3, match2, match1, noMatch, burn]
    function setDistributionPercentages(uint256[] calldata _newDistribution)
        external;

    /// @notice Claim all tickets for selected Rounds
    /// @param _rounds the round info to look at
    /// @param _ticketIds array of ticket Ids that will be claimed
    /// @param _matches array of match per ticket Id
    /// @dev _ticketIds and _matches have to be same length since they are matched 1-to-1
    function claimAllPendingTickets(
        LotteryStructs.ClaimRounds[] calldata _rounds,
        uint256[] calldata _ticketIds,
        uint256[] calldata _matches
    ) external;

    // External functions that are view
    /// @notice Get Tickets for the caller for during a specific round
    /// @param _round The round to query
    function getRoundTickets(uint256 _round)
        external
        view
        returns (LotteryStructs.NewTicket[] memory);

    /// @notice Get a specific round's distribution percentages
    /// @param _round the round to check
    /// @dev this is necessary since solidity doesn't return the nested array in a struct when calling the variable containing the struct
    function getRoundDistribution(uint256 _round)
        external
        view
        returns (uint256[7] memory distribution);

    /// @notice Get all Claimable Tickets
    /// @return TicketView array
    /// @dev this is specific to UI, returns ID and ROUND number in order to make the necessary calculations.
    function ticketsToClaim()
        external
        view
        returns (LotteryStructs.TicketView[] memory);

    /// @notice Check if number is the winning number
    /// @param _round Round the requested ticket belongs to
    /// @param luckyTicket ticket number to check
    /// @return _match Number of winning matches
    function isNumberWinner(uint256 _round, uint32 luckyTicket)
        external
        view
        returns (uint8 _match);

    /// @notice Add funds to pool directly, only applies funds to currentRound
    /// @param _amount the amount of CRUSH to transfer from current account to current Round
    /// @dev Approve needs to be run beforehand so the transfer can succeed.
    function addToPool(uint256 _amount) external;
}
