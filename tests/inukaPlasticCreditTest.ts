import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { InukaPlasticCredit, InukaPartnerToken } from "../typechain-types";

describe("InukaPlasticCredit", function () {
  let accounts: SignerWithAddress[];
  let InukaPlasticCreditContract: InukaPlasticCredit;
  let projectCreator: SignerWithAddress;
  let projectName: string;
  let projectLocation: string;
  let polymerType: string;
  let plasticForm: string;
  let InukaPartnerTokenContract: InukaPartnerToken;

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
        await InukaPlasticCreditContract.getProject(1)
      ).projectOwner;
      expect(projectOwnerExpected).to.eq(projectCreator.address);
    });

    it("Should set project name correctly", async () => {
      const projectNameBytes32Expected = await (
        await InukaPlasticCreditContract.getProject(1)
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

  describe("Mint IPT", async () => {
    beforeEach(async () => {
      accounts = await ethers.getSigners();
      const InukaPartnerTokenContractFactory = await ethers.getContractFactory(
        "InukaPartnerToken"
      );

      InukaPartnerTokenContract =
        (await InukaPartnerTokenContractFactory.deploy(
          InukaPlasticCreditContract.address
        )) as InukaPartnerToken;
      await InukaPartnerTokenContract.deployed();
      console.log(
        `Inuka Plastic Credit Contract address: ${InukaPlasticCreditContract.address}`
      );
    });

    it("Should mint the right number of tokens", async () => {
      // NOTE: Set variables here
      const numberOfTokensString: string = "50.0";
      const projectId: number = 1;
      const numberOfTokensBN = ethers.utils.parseEther(numberOfTokensString);
      const createTokenTx = await InukaPartnerTokenContract.connect(
        projectCreator
      ).createToken(numberOfTokensBN, projectId);
      await createTokenTx.wait();
      const numberOfTokensExpectedBN =
        await InukaPartnerTokenContract.balanceOf(
          projectCreator.address,
          projectId
        );
      const numberOfTokensExpectedString = ethers.utils.formatEther(
        numberOfTokensExpectedBN
      );
      expect(numberOfTokensExpectedString).to.eq(numberOfTokensString);
    });

    it("Should not allow non-project creator to mint", async () => {
      // NOTE: Set variables here
      const numberOfTokensString: string = "50.0";
      const projectId: number = 1;
      const numberOfTokensBN = ethers.utils.parseEther(numberOfTokensString);
      const thief: SignerWithAddress = accounts[2];

      await expect(
        InukaPartnerTokenContract.connect(thief).createToken(
          projectId,
          numberOfTokensBN
        )
      ).to.be.revertedWith("Not project creator");
    });
    describe("Set project status", async () => {
      // it("Should show default audit status as None i.e. 0", async () => {
      //   const auditStatusExpected =
      //     await InukaPlasticCreditContract.getAuditStatus(1);
      //   expect(auditStatusExpected).to.eq(0);
      //   console.log(`Audit status: ${auditStatusExpected}`);
      // });

      it("Should update the audit status from project creator", async () => {});
    });
  });
});
