// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IMockUsdc {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IInukaPlasticCredit {
    // modifier onlyProjectCreator (uint256 _projectId);
    struct Project {
        address projectOwner;
        bytes32 projectName;
        bytes32 location;
        bytes32 polymerType;
        bytes32 plasticForm;
    }
    // enum AuditStatus { None, Partial, Complete}

    function getProject(uint256 _projectId) external view returns (Project memory _project);
}

contract InukaPartnerTokenMarketplace is Ownable {
    IMockUsdc public mockUsdc;
    IInukaPlasticCredit private inukaPlasticCredit;

    mapping (uint256 => bool) pollActive;

    // TODO: Add events here

    // TODO: Add modifiers here

    modifier onlyProjectCreator(uint256 _projectId) {
        address projectOwner = inukaPlasticCredit.getProject(_projectId).projectOwner;
        require(projectOwner == msg.sender, "Not project creator");
        _;
    }

    function setMockUsdc (address _mockUsdcAddress) external onlyOwner {
        mockUsdc = IMockUsdc(_mockUsdcAddress);
    }

    function setInukaPlasticCredit (address _inukaPlasticCreditAddress) external onlyOwner {
        inukaPlasticCredit = IInukaPlasticCredit(_inukaPlasticCreditAddress);
    }

    // Include number of phases and funds needed for each phase
    // number of
    /**
    @dev To add option for bonding curve next to test if it incentivises early purchase
    */
    function listToken () external {}

    // Need to delist all
    // USDC paid by buyers can now be redeemed
    function delistToken () external {}

    function buyToken () external {}

    // triggers one-week voting. 50% of holders must vote, with 50% saying yes
    // only project creator can request fund release
    function requestFundRelease (uint256 _projectId) external onlyProjectCreator( _projectId) {}

    // poll created within requestFundRelease
    // disables token transfer
    function createPoll () internal {}

    // only project creator can release fund 
    function releaseFund () external {} 

    function getPollActive (uint256 _projectId) external view returns (bool pollStatus) {
        pollStatus = pollActive[_projectId];
    }

    // Can only be set through function controlled only by project creator
    function setPollActive (uint256 _projectId, bool _status) internal {
        pollActive[_projectId] = _status;
    }

}