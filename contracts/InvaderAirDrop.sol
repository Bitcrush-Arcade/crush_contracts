// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

// This wrapper contract will handle the invader giveaways (airDrops) for candidates that have been whitelisted for a giveaway. 
// It will dispatch only ONE Invader NFT per account. It interacts directly with the MadInvaderNFT contract.
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./MadInvaderNFT.sol";

contract InvaderAirDrop is Ownable, IERC721Receiver{
  MadInvaderNFT public wrappedContract;

  /// 0 => not in map, 1 => candidate, 2 => no longer a candidate
  mapping (address => bool) public candidateStatus;

  event CandidateAdded(address);
  event CandidateRemoved(address);
  event InvaderDroppedTo(address);
  event MaxInvaders(uint256);

  constructor(address _NFTContractAddress){
    wrappedContract = MadInvaderNFT(_NFTContractAddress);
  }
  
  /// @notice Adds candidate to receive an invader NFT to map
  /// @param _candidate Address of said candidate
  function addCandidate(address _candidate) external onlyOwner {
    require (_candidate != address(0), "Invalid candidate");
    _addCandidate(_candidate);
  }

  /// @notice Adds candidate to receive an invader NFT to the candidates map 
  /// @param _candidates Array of receiver candidates 
  function addCandidateArray (address[] memory _candidates) external onlyOwner {
    require (_candidates.length > 0, "No array");
    for (uint i = 0; i < _candidates.length; i++){
      if (_candidates[i] == address(0)) continue;
      _addCandidate(_candidates[i]);
    }
  }

  /// @notice Removes candidate from map
  /// @param _candidate Address of said candidate to remove. 
  function removeCandidate(address _candidate) external onlyOwner {
    _removeCandidate(_candidate);
  }

  /// @notice Removes candidate array from map
  /// @param _candidates Address array of candidates to remove
  function removeCandidateArray(address[] memory _candidates) external onlyOwner {
    require (_candidates.length > 0, "No array");
    for (uint i = 0; i < _candidates.length ; i++){
      _removeCandidate(_candidates[i]);
    }
  }

  /// @notice Distributes the NFT's to the candidate if valid
  function dropToCandidate() external {
    require(candidateStatus[msg.sender] == true);
    _removeCandidate(msg.sender);
    wrappedContract.mint(1, false);
    uint256[] memory tokenId = wrappedContract.walletOfOwner(address(this));
    wrappedContract.safeTransferFrom(address(this), msg.sender, tokenId[0], "");
    emit InvaderDroppedTo(msg.sender);
  }

  /// @notice Makes this contract able to receive NFT's according to ERC721 standard
  function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4){
      return IERC721Receiver.onERC721Received.selector;
    }

  /// @notice Selfdestruct function and assets sent to owner
  function deleteWrapper() external onlyOwner {
    selfdestruct(payable(msg.sender));
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


