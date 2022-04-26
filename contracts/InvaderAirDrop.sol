// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

// This wrapper contract will handle the invader giveaways (airDrops) for candidates that have been whitelisted for a giveaway. 
// It interacts directly with the MadInvaderNFT contract.
import "@openzeppelin/contracts/access/Ownable.sol";
import "../MadInvaderNFT.sol";

contract InvaderAirDrop is Ownable{
  MadInvaderNFT public immutable wrappedContract;

  /// true = isCandidate
  mapping (address => boolean) public candidateStatus;

  event CandidateAdded(address);
  event CandidateRemoved(address);
  event InvaderDroppedTo(address);

  constructor(address _NFTContractAddress){
    wrappedContract = MadInvaderNFT(_NFTContractAddress);
  }
  
  /// @notice Adds candidate to receive an invader NFT to map
  /// @param _candidate Address of said candidate
  function addCandidate(address _candidate) external onlyOwner {
    require (_candidate != address(0) || candidateStatus[_candidate] != false || wrappedContract.balanceOf(_candidate) < 5, "Invalid candidate");
    _addCandidate(_candidate);
  }

  /// @notice Adds candidate to receive an invader NFT to the candidates map 
  /// @param _candidates Array of receiver candidates 
  function addCandidateArray (address[] _candidates) external onlyOwner {
    require (_candidates.length > 0, "No array");
    for (uint i = 0; i < _candidates.length; i++){
      if (_candidates[i] == address(0) || candidateStatus[_candidates[i]] == false || wrappedContract.balanceOf(_candidates[i]) == 5) continue;
      _addCandidate(_candidates[i]);
    }
  }

  /// @notice Removes candidate from map
  /// @param _candidate Address of said candidate to remove. 
  function removeCandidate(address _candidate) external onlyOwner {
    require (_candidate != address(0));
    _removeCandidate(_candidate);
  }

  /// @notice Removes candidate array from map
  /// @param _candidates Address array of candidates to remove
  function removeCandidateArray(address[] _candidates) external onlyOwner {
    require (_candidates.length > 0, "No array");
    for (uint i = 0; i < _candidates; i++){
      if (_candidates[i] == address(0)) continue;
      _removeCandidate(_candidates[i]);
    }
  }

  /// @notice Distributes the NFT's to wallets that can receive the NFT's. Sets previous added candidates to false and cleans candidateArray
  function dropToCandidates() external {
    require(candidateStatus[msg.sender] == true);
    wrappedContract.mint(1, false);
    emit InvaderDroppedTo(msg.sender);
    _removeCandidate(msg.sender);
  }

  /// @notice selfdestruct function and assets sent to owner
  function selfdestruct() external onlyOwner{
    selfdestruct(msg.sender);
  }

  // Internal functions

  /// @notice Adds candidate to receive an invader NFT to map
  /// @param _candidate Address of said candidate
  function _addCandidate(address _candidate) internal {
    candidateStatus[_candidate] = true;
    emit CandidateAdded(_candidate);
  }

  /// @notice Removes candidate from map. It doesn't delete it from map but sets it to false so they can't become a candidate
  /// @param _candidate Address of said candidate to remove
  function _removeCandidate(address _candidate) internal {
    candidateStatus[_candidate] = false;
    emit CandidateRemoved(_candidate);
  }
}


