import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { InukaPlasticCredit } from "../typechain-types";
import { BigNumber } from "ethers";

describe("InukaPlasticCredit", function () {
  let accounts: SignerWithAddress[];
  let InukaPlasticCreditContract: InukaPlasticCredit;

  beforeEach(async () => {
    accounts = await ethers.getSigners();
    const InukaPlasticCreditContractFactory = await ethers.getContractFactory(
      "InukaPlasticCredit"
    );

    InukaPlasticCreditContract =
      (await InukaPlasticCreditContractFactory.deploy()) as InukaPlasticCredit;
    await InukaPlasticCreditContract.deployed();
  });

  describe("Deployment", async () => {
    it("Should show the right token symbol", async () => {
      const tokenSymbol = await InukaPlasticCreditContract.symbol();
      expect(tokenSymbol).to.eq("IPC");
    });
  });
});
