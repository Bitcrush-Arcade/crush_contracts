// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

// This wrapper contract will handle the invader giveaways (airDrops) for candidates that have been whitelisted for a giveaway. 
// It interacts directly with the MadInvaderNFT contract.
import "@openzeppelin/contracts/access/Ownable.sol";
import "../MadInvaderNFT.sol";

contract InvaderAirDrop is Ownable{
  MadInvaderNFT public immutable wrappedContract;

  address[] candidateArray;

  mapping (address => boolean) public candidateStatus;

  event CandidateAdded(address);
  event CandidateArrayAdded(address[]);
  event CandidateRemoved(address);
  event CandidateArrayRemoved(address[]);

  constructor(address _NFTContractAddress){
    wrappedContract = MadInvaderNFT(_NFTContractAddress);
  }
  
  /// @notice Adds candidate to receive an invader NFT to the candidates map
  /// @param candidateAddress is the address of said candidate
  function addCandidate(address _candidate) external onlyOwner{
    require (_candidateAddress != address(0) || candidates[_candidateAddress] != true || wrappedContract.balanceOf(msg.sender) < 5, "Invalid candidate");
    candidateStatus[_candidate] = true;
    emit CandidateAdded(_candidate);
  }

  /// @notice Adds candidate to receive an invader NFT to the candidates map 
  /// @param candidateArray is the array of receiver candidates 
  function addCandidateArray (address[] _candidates) external onlyOwner{
    require(_candidates.length > 0, "No array");
    for (uint i = 0; i < _candidates.length; i++){
      if (_candidates[i] == address(0) || wrappedContract.balanceOf(msg.sender) == 5) continue;
      candidateStatus[_candidates[i]] = true;
    }
    emit CandidateArrayAdded(_candidates);
  }

  /// @notice Removes candidate from map
  /// @param candidateAddress is the address of said candidate to remove
  function removeCandidate(address _candidate) internal{
    require (_candidate != address(0), "Invalid candidate");
    delete(candidateStatus[_candidate]);
    emit CandidateRemoved(_candidate);
  }

  /// @notice Removes candidate array from map
  /// @param candidateAddress is the address array of candidates to remove
  function removeCandidateArray(address[] _candidates) internal{
    require(_candidates.length > 0, "No array");
    for(uint i = 0; i < _candidates; i++){
      if(_candidates[i] == address(0)) continue;
      delete(candidates[_candidates[i]]);
    }
    emit CandidateArrayRemoved(_candidates);
  }

  /// @notice distributes the NFT's to wallets that can receive the NFT's. It resets the 
  /// @param candidateAddress is the address array of candidates to remove
  function dropToCandidates() external{
    require(candidates[msg.sender] == true || wrappedContract.balanceOf(msg.sender) < 5, "Invalid candidate");
        wrappedContract.mint(1, true);
  }

  function selfdestruct() external onlyOwner{

  }

}

