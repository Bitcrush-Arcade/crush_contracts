// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

// This wrapper contract will handle the invader giveaways (airDrops) for candidates that have been whitelisted for a giveaway. 
// It interacts directly with the MadInvaderNFT contract.
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MadInvaderNFT.sol";

contract InvaderAirDrop is Ownable{
  MadInvaderNFT public wrappedContract;

  uint256 maxInvaders;

  /// 0 => not in map, 1 => candidate, 2 => no longer a candidate
  mapping (address => uint8) public candidateStatus;

  event CandidateAdded(address);
  event CandidateRemoved(address);
  event InvaderDroppedTo(address);
  event MaxInvaders(uint256);

  constructor(address _NFTContractAddress){
    wrappedContract = MadInvaderNFT(_NFTContractAddress);
    maxInvaders =  wrappedContract.maxInvaders();
  }
  
  /// @notice Adds candidate to receive an invader NFT to map
  /// @param _candidate Address of said candidate
  function addCandidate(address _candidate) external onlyOwner {
    require (_candidate != address(0) || candidateStatus[_candidate] == 1 || wrappedContract.balanceOf(_candidate) < maxInvaders, "Invalid candidate");
    _addCandidate(_candidate);
  }

  /// @notice Adds candidate to receive an invader NFT to the candidates map 
  /// @param _candidates Array of receiver candidates 
  function addCandidateArray (address[] memory _candidates) external onlyOwner {
    require (_candidates.length > 0, "No array");
    for (uint i = 0; i < _candidates.length; i++){
      if (_candidates[i] == address(0) || candidateStatus[_candidates[i]] == 2 || wrappedContract.balanceOf(_candidates[i]) == maxInvaders) continue;
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
  function removeCandidateArray(address[] memory _candidates) external onlyOwner {
    require (_candidates.length > 0, "No array");
    for (uint i = 0; i < _candidates.length ; i++){
      if (_candidates[i] == address(0)) continue;
      _removeCandidate(_candidates[i]);
    }
  }

  /// @notice Distributes the NFT's to wallets that can receive the NFT's. Sets previous added candidates to false and cleans candidateArray
  function dropToCandidate() external {
    require(candidateStatus[msg.sender] == 1 && wrappedContract.balanceOf(msg.sender) < maxInvaders);
    wrappedContract.mint(1, false);
    emit InvaderDroppedTo(msg.sender);
    _removeCandidate(msg.sender);
  }

  /// @notice Selfdestruct function and assets sent to owner
  function endInvasion() public onlyOwner {
    selfdestruct(payable(msg.sender));
  }

  /// @notice Updates max invaders per wallet
  function updateMaxInvaders() public onlyOwner {
    maxInvaders = wrappedContract.maxInvaders();
    emit MaxInvaders(wrappedContract.maxInvaders());
  }

  // Internal functions

  /// @notice Adds candidate to receive an invader NFT to map
  /// @param _candidate Address of said candidate
  function _addCandidate(address _candidate) internal {
    candidateStatus[_candidate] = 1;
    emit CandidateAdded(_candidate);
  }

  /// @notice Removes candidate from map. It doesn't delete it from map but sets it to false so they can't become a candidate
  /// @param _candidate Address of said candidate to remove
  function _removeCandidate(address _candidate) internal {
    candidateStatus[_candidate] = 2;
    emit CandidateRemoved(_candidate);
  }
}


