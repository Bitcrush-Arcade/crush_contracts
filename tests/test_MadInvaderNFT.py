# from brownie import accounts, MadInvaderNFT, MadInvaderNFT2, chain
import brownie
import pytest


@pytest.fixture(scope="function", autouse=True)
def setup():
    nft = MadInvaderNFT.deploy(
        "Mad Nice Invaders",
        "MNI",
        "ipfs://Qmb9jvtyQFMXxx5Cd7XUkpAyfwGHwGaNLi376qAFyUwFvB/",
        "ipfs://QmQ5JMCG8wha57Lp4cBV7BgiDzxWE8xJMk9DoXCa5TrUtj/",
        "ipfs://QmNqMSj8ptnu6xJhwJr59vf7nF9oacr1h7mTPx3CjtLyGS/",
        {"from": accounts[0]},
    )
    nft2 = MadInvaderNFT2.deploy(
        "Mad Nice Invaders",
        "MNI",
        "ipfs://Qmb9jvtyQFMXxx5Cd7XUkpAyfwGHwGaNLi376qAFyUwFvB/",
        "ipfs://QmQ5JMCG8wha57Lp4cBV7BgiDzxWE8xJMk9DoXCa5TrUtj/",
        "ipfs://QmNqMSj8ptnu6xJhwJr59vf7nF9oacr1h7mTPx3CjtLyGS/",
        {"from": accounts[0]},
    )
    return nft, nft2


def test_emperor_minting(setup):
    nft, nft2 = setup

    # Setting up max emisions for emperors
    nft.mint(100, True, {"from": accounts[0]})

    # Testing if owner can mint emperors over 100
    with brownie.reverts():
        nft.mint(1, True, {"from": accounts[0]})

    # Testing if user can mint emperors over 100
    with brownie.reverts():
        nft.mint(1, True, {"from": accounts[1]})


def test_invader_minting(setup):
    nft, nft2 = setup

    nft2.mint(78, False, {"from": accounts[0]})

    # Testing if owner can mint invaders over 8888
    with brownie.reverts():
        nft2.mint(1, False, {"from": accounts[0]})

    # Testing if user can mint invaders over 8888
    with brownie.reverts():
        nft.mint(1, False, {"from": accounts[1]})


# def test_max_per_wallet(setup):
#     nft, nft2 = setup

#     # Minting max emperors to single wallet
#     nft.mint(2, True, {"from": accounts[1]}).send("0.6 ether", {"from": accounts[1]})
#     # nft.mint(2, True, {"from": accounts[1]}).send("0.06 ether", {"from": accounts[1]})
#     # nft.mint(5, False, {"from": accounts[1]}).accounts[1].transfer(
#     #     accounts[0], "0.25 ether"
#     # )

#     # # Testing if accounts[1] can mint more invaders or emperors
#     # with brownie.reverts():
#     #     nft.mint(1, True, {"from": accounts[1]}).accounts[1].transfer(
#     #         accounts[0], "0.4 ether"
#     #     )
#     # with brownie.reverts():
#     #     nft.mint(1, False, {"from": accounts[1]}).accounts[1].transfer(
#     #         accounts[0], "0.05 ether"
#     #     )
