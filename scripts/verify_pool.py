from brownie import InvaderPool


def main():
    pool = InvaderPool.at("0x38A5885f84a415804A5c1009fA2E3F9703a2678C")
    InvaderPool.publish_source(pool)
