import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { InukaPlasticCredit } from "../typechain-types";
import { BigNumber } from "ethers";

describe("InukaPlasticCredit", function () {
  let accounts: SignerWithAddress[];
  let InukaPlasticCreditContract: InukaPlasticCredit;
  let projectCreator: SignerWithAddress;
  let projectName: string;
  let projectLocation: string;
  let polymerType: string;
  let plasticForm: string;

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

    it("Should show the right token name", async () => {
      const tokenSymbol = await InukaPlasticCreditContract.name();
      expect(tokenSymbol).to.eq("Inuka Plastic Credit");
    });
  });

  beforeEach(async () => {
    projectCreator = accounts[1];
    // NOTE: Set variables here
    projectName = "My New Project";
    projectLocation = "Singapore";
    polymerType = "PET";
    plasticForm = "Water bottles";
    const createProjectTx = await InukaPlasticCreditContract.connect(
      projectCreator
    ).createProject(
      ethers.utils.formatBytes32String(projectName),
      ethers.utils.formatBytes32String(projectLocation),
      ethers.utils.formatBytes32String(polymerType),
      ethers.utils.formatBytes32String(plasticForm)
    );
    await createProjectTx.wait();
  });

  describe("Create project", async () => {
    it("Should set creator as project owner", async () => {
      const projectOwnerExpected = await (
        await InukaPlasticCreditContract.projectIdentifier(1)
      ).projectOwner;
      expect(projectOwnerExpected).to.eq(projectCreator.address);
    });

    it("Should set project name correctly", async () => {
      const projectNameBytes32Expected = await (
        await InukaPlasticCreditContract.projectIdentifier(1)
      ).projectName;
      const projectNameStringExpected = ethers.utils.parseBytes32String(
        projectNameBytes32Expected
      );
      expect(projectNameStringExpected).to.eq(projectName);
    });
  });

  describe("Create Plastic Credits", async () => {
    it("Should mint the correct amount of tokens to project creator", async () => {
      // NOTE: Set variables here
      const projectId: number = 1;
      const plasticCreditsToCreateString: string = "100.0";
      const plasticCreditsToCreateBN = ethers.utils.parseEther(
        plasticCreditsToCreateString
      );
      const createPlasticCreditTransaction =
        await InukaPlasticCreditContract.connect(
          projectCreator
        ).createPlasticCredit(projectId, plasticCreditsToCreateBN);
      await createPlasticCreditTransaction.wait();
      const creditBalanceExpectedBN =
        await InukaPlasticCreditContract.balanceOf(
          projectCreator.address,
          projectId
        );
      const creditBalanceExpectedString = ethers.utils.formatEther(
        creditBalanceExpectedBN
      );
      expect(creditBalanceExpectedString).to.eq(plasticCreditsToCreateString);
    });

    it("Should not allow non-project creator to mint", async () => {
      // NOTE: Set variables here
      const projectId: number = 1;
      const plasticCreditsToCreateString: string = "100.0";
      const plasticCreditsToCreateBN = ethers.utils.parseEther(
        plasticCreditsToCreateString
      );
      const thief: SignerWithAddress = accounts[2];

      await expect(
        InukaPlasticCreditContract.connect(thief).createPlasticCredit(
          projectId,
          plasticCreditsToCreateBN
        )
      ).to.be.revertedWith("Not project creator");
    });

    it("Should not allow minting after project is finalised", async () => {
      // NOTE: Set variables here
      const projectId: number = 1;
      const plasticCreditsToCreateString: string = "100.0";
      const plasticCreditsToCreateBN = ethers.utils.parseEther(
        plasticCreditsToCreateString
      );
      const finaliseProjectTx = await InukaPlasticCreditContract.connect(
        projectCreator
      ).finaliseProject(projectId);
      await finaliseProjectTx.wait();

      await expect(
        InukaPlasticCreditContract.connect(projectCreator).createPlasticCredit(
          projectId,
          plasticCreditsToCreateBN
        )
      ).to.be.revertedWith("Project finalised");
    });
  });
});
