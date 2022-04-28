from brownie import accounts, chain, MadInvaderNFT, InvaderAirDrop 
import brownie
import pytest
from web3 import Web3

# This wrapper contract will handle the invader giveaways for candidates that have been whitelisted. 
# The contract should ask the MadInvaderNFT.sol to mint the whitelisted person (receiver). This contract should be the owner of the existing MadInvaderNFT Contract.

@pytest.fixture(scope="function", autouse=True)
def setup():
  nft = MadInvaderNFT.deploy(
      "Mad Nice Invaders for WT",
      "MNIWT",
      "ipfs://Qmb9jvtyQFMXxx5Cd7XUkpAyfwGHwGaNLi376qAFyUwFvB/",
      "ipfs://QmQ5JMCG8wha57Lp4cBV7BgiDzxWE8xJMk9DoXCa5TrUtj/",
      "ipfs://QmNqMSj8ptnu6xJhwJr59vf7nF9oacr1h7mTPx3CjtLyGS/",
      {"from": accounts[0]},
  )
  wrapper = InvaderAirDrop.deploy(nft, {"from" : accounts[0]})
  nft.transferOwnership(wrapper)

  return nft, wrapper

# It should add a single receiver candidate to a map. function addCandidate onlyOwner. 
def test_addCandidate(setup):
  nft, wrapper = setup 

  wrapper.addCandidate(accounts[1], {"from" : accounts[0]})
  assert wrapper.candidateStatus(accounts[1]) == True

# It should add to map from an array of receiver candidates. function addCandidateArray onlyOwner. 
def test_addCandidateArray(setup):
  nft, wrapper = setup
  candidateArray = [accounts[1], accounts[2], accounts[3], accounts[4]]

  # Adding candidates by array
  wrapper.addCandidateArray(candidateArray, {"from": accounts[0]})

  # accounts[4] should no longer be able to be a candidate
  assert wrapper.candidateStatus(accounts[1]) == True
  assert wrapper.candidateStatus(accounts[2]) == True
  assert wrapper.candidateStatus(accounts[3]) == True
  assert wrapper.candidateStatus(accounts[4]) == True


# It should remove a single receiver candidate from map. function removeCandidate onlyOwner.
def test_removeCandidate(setup):
  nft, wrapper = setup 

  wrapper.addCandidate(accounts[1], {"from" : accounts[0]})
  wrapper.removeCandidate(accounts[1], {"from" : accounts[0]})

  assert wrapper.candidateStatus(accounts[1]) == False

# It should remove an array of receiver candidates from map. function removeCandidateArray onlyOwner.
def test_removeCandidateArray(setup):
  nft, wrapper = setup
  candidateArray = [accounts[1], accounts[2], accounts[3]]

  wrapper.addCandidateArray(candidateArray, {"from": accounts[0]})
  wrapper.removeCandidateArray(candidateArray, {"from": accounts[0]})

  assert wrapper.candidateStatus(accounts[1]) == False
  assert wrapper.candidateStatus(accounts[2]) == False
  assert wrapper.candidateStatus(accounts[3]) == False

# It should have an external function that asks the MadInvaderNFT to mint to user wallet if user address is in the whitelist. function NftAirDrop external. 
def test_dropToCandidate(setup):
  nft, wrapper = setup
  candidateArray = [accounts[1], accounts[2], accounts[3]]

  wrapper.addCandidateArray(candidateArray, {"from": accounts[0]})
  wrapper.dropToCandidate({"from": accounts[1]})
  wrapper.dropToCandidate({"from": accounts[2]})

  assert nft.balanceOf(accounts[1]) == 1
  assert wrapper.candidateStatus(accounts[1]) == False

  assert nft.balanceOf(accounts[2]) == 1
  assert wrapper.candidateStatus(accounts[2]) == False

  with brownie.reverts():
    wrapper.dropToCandidate({"from": accounts[2]})



