# Bitcrush Contracts

## Token Contract

CrushCoin Contract (CRUSH) is a simple BEP-20 token. 
* We've used `@pancakeswap/pancake-swap-lib` contracts as a base, because of this our contract is specified with `pragma solidity >= 0.6.2`.
* CRUSH has a maximum CAP of 30 million tokens minted.
* Burning tokens will reduce that maximum cap preventing more to be minted, keeping true to it's deflationary nature and preventing abuse by owners.
* Once DAO has a stable community, ownership of __*CRUSH will be transfered to DAO contract*__.


## Lottery

Function to test locally only, it's been removed from the contract
/// @notice HELPFUL FUNCTION TO TEST WINNERS LOCALLY THIS FUNCTION IS NOT MEANT TO GO LIVE
/// This function sets the random value for the winner.
/// @param randomness simulates a number given back by the randomness function
function setWinner( uint256 randomness, address _claimer ) public operatorOnly{
    currentIsActive = false;
    RoundInfo storage info = roundInfo[currentRound];
    info.winnerNumber = standardTicketNumber(uint32(randomness), WINNER_BASE);
    claimers[currentRound] = Claimer(_claimer, 0);
    distributeCrush();
    if(!pause){
        startRound();
        calcNextHour();
        roundInfo[currentRound].endTime = roundEnd;
    }
    emit WinnerPicked(currentRound, info.winnerNumber, "ADMIN_SET_WINNER");
}
