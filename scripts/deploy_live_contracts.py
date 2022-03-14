# singleAsset pending
from brownie import (
    BitcrushBankroll,
    BitcrushStaking,
    CRUSHToken,
    BitcrushLiveWallet,
    BitcrushLottery,
    Presale,
    singleAssetStaking,
    accounts,
)
from scripts.helpful_scripts import isDevNetwork
from web3 import Web3


# def deploy_libraries():


def deployBankroll():
    bankroll = BitcrushBankroll.deploy({"from": accounts[0]})

    return bankroll


def deployStaking():
    staking = BitcrushStaking.deploy({"from": accounts[0]})

    return staking


def deployCrushToken():
    crushToken = CRUSHToken.deploy({"from": accounts[0]})

    return crushToken


def deployLiveWallet():
    wallet = BitcrushLiveWallet.deploy({"from": accounts[0]})

    return wallet


def deployLottery():
    lottery = BitcrushLottery.deploy({"from": accounts[0]})

    return lottery


def deployPresale():
    presale = Presale.deploy({"from": accounts[0]})

    return presale


def deploySingleAssetStaking():
    singleAssetStaking = singleAssetStaking.deploy({"from": accounts[0]})


def main():
    if isDevNetwork():
        # deploy_libraries()
        bankroll = deployBankroll()
        staking = deployStaking()
        crushToken = deployCrushToken()
        wallet = deployLiveWallet()
        lottery = deployLottery()
        presale = deployPresale()
        singleAssetStaking = deploySingleAssetStaking()

    # if isDevNetwork():
    #     tx = crushToken.transfer(
    #         accounts[1], Web3.toWei("1", "ether"), {"from": accounts[0]}
    #     )
    #     tx.wait(1)
    #     balance = crushToken.balanceOf(accounts[0])
    #     print(f"Minter Balance {balance}")
    else:
        account = accounts.load("deployment_acc")
        print(account)
